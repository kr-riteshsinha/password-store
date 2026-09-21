import 'package:archinfotech/models/login_entry.dart';
import 'package:archinfotech/provider/db_helper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

LoginEntry _entry(String id, {String title = 'GitHub'}) => LoginEntry(
      id: id,
      title: title,
      username: 'octocat',
      password: 'pw-$id',
      website: 'https://github.com',
      totpSecret: 'JBSWY3DPEHPK3PXP',
    );

void main() {
  final db = DbHelper.instance;

  setUpAll(initEncryptedTestDatabase);

  setUp(() async {
    await resetVault();
    await openTestVault();
    DbHelper.deviceId = 'device-a';
    DbHelper.now = () => 1000;
  });

  tearDown(() {
    DbHelper.now = () => DateTime.now().toUtc().millisecondsSinceEpoch;
    DbHelper.deviceId = '';
  });

  tearDownAll(resetVault);

  group('stamping changes', () {
    test('a new entry starts at revision 1 with the current time and device', () async {
      await db.insertEntry(_entry('1'));

      final saved = (await db.fetchEntries()).single;
      expect(saved.revision, 1);
      expect(saved.updatedAt, 1000);
      expect(saved.deviceId, 'device-a');
      expect(saved.deletedAt, isNull);
      expect(saved.isDeleted, isFalse);
    });

    test('updating an entry raises the revision and the time', () async {
      await db.insertEntry(_entry('1'));
      DbHelper.now = () => 2000;

      await db.updateEntry(_entry('1', title: 'GitHub Inc'));

      final saved = (await db.fetchEntries()).single;
      expect(saved.title, 'GitHub Inc');
      expect(saved.revision, 2);
      expect(saved.updatedAt, 2000);
    });

    test('the writing device is recorded, not the one that wrote before', () async {
      await db.insertEntry(_entry('1'));
      DbHelper.deviceId = 'device-b';

      await db.updateEntry(_entry('1', title: 'Changed'));

      expect((await db.fetchEntries()).single.deviceId, 'device-b');
    });

    test('an entry cannot be saved with a stale revision from the caller', () async {
      await db.insertEntry(_entry('1'));
      await db.updateEntry(_entry('1', title: 'Second'));

      // A caller passing revision 1 must not undo the count.
      await db.updateEntry(_entry('1', title: 'Third'));

      expect((await db.fetchEntries()).single.revision, 3);
    });
  });

  group('soft delete', () {
    test('a deleted entry leaves a tombstone and disappears from the list', () async {
      await db.insertEntry(_entry('1'));
      DbHelper.now = () => 5000;

      await db.deleteEntry('1');

      expect(await db.fetchEntries(), isEmpty);
      final tombstone = (await db.fetchTombstones()).single;
      expect(tombstone.id, '1');
      expect(tombstone.deletedAt, 5000);
      expect(tombstone.isDeleted, isTrue);
    });

    test('deleting raises the revision, so the deletion wins over older edits', () async {
      await db.insertEntry(_entry('1'));

      await db.deleteEntry('1');

      expect((await db.fetchTombstones()).single.revision, 2);
    });

    test('a tombstone keeps only the id and the timestamps', () async {
      await db.insertEntry(_entry('1'));

      await db.deleteEntry('1');

      final tombstone = (await db.fetchTombstones()).single;
      expect(tombstone.id, '1');
      expect(tombstone.deletedAt, isNotNull);
      expect(tombstone.password, isEmpty);
      expect(tombstone.totpSecret, isNull);
      // A title or a website is a fact about the user too.
      expect(tombstone.title, isEmpty);
      expect(tombstone.username, isEmpty);
      expect(tombstone.website, isEmpty);
    });

    test('nothing the user typed survives in the row', () async {
      await db.insertEntry(_entry('1', title: 'Very Private Bank'));

      await db.deleteEntry('1');

      final row = (await (await db.database)
              .query('login_entries', where: 'id = ?', whereArgs: ['1']))
          .single;
      expect(row.values.join(' '), isNot(contains('Very Private Bank')));
      expect(row.values.join(' '), isNot(contains('octocat')));
    });

    test('deleting an entry that is not there does nothing', () async {
      await db.deleteEntry('nope');

      expect(await db.fetchEntriesForSync(), isEmpty);
    });

    test('fetchEntriesForSync returns live entries and tombstones', () async {
      await db.insertEntry(_entry('1'));
      await db.insertEntry(_entry('2'));
      await db.deleteEntry('2');

      expect((await db.fetchEntriesForSync()).map((e) => e.id).toSet(), {'1', '2'});
      expect((await db.fetchEntries()).map((e) => e.id), ['1']);
    });

    test('purgeTombstone removes a tombstone but never a live entry', () async {
      await db.insertEntry(_entry('1'));
      await db.insertEntry(_entry('2'));
      await db.deleteEntry('2');

      await db.purgeTombstone('1');
      await db.purgeTombstone('2');

      expect((await db.fetchEntriesForSync()).map((e) => e.id), ['1']);
    });
  });

  group('races and tombstones', () {
    test('two saves at once cannot lose a revision', () async {
      await db.insertEntry(_entry('1'));

      // Both start before either finishes — a double-tapped Save button.
      await Future.wait([
        db.updateEntry(_entry('1', title: 'First')),
        db.updateEntry(_entry('1', title: 'Second')),
      ]);

      expect((await db.fetchEntries()).single.revision, 3);
    });

    test('updating a deleted entry does not bring it back', () async {
      await db.insertEntry(_entry('1'));
      await db.deleteEntry('1');

      await db.updateEntry(_entry('1', title: 'Back from the dead'));

      expect(await db.fetchEntries(), isEmpty);
      expect((await db.fetchTombstones()).single.title, isEmpty);
    });

    test('saving the same id again is a deliberate new entry, not a revival', () async {
      await db.insertEntry(_entry('1'));
      await db.deleteEntry('1');

      // insertEntry is "save this", so it does clear the tombstone.
      await db.insertEntry(_entry('1', title: 'Recreated'));

      final live = (await db.fetchEntries()).single;
      expect(live.title, 'Recreated');
      expect(live.deletedAt, isNull);
      expect(live.revision, 3, reason: 'the history continues, it does not restart');
    });

    test('deleting twice does not bump the revision again', () async {
      await db.insertEntry(_entry('1'));
      await db.deleteEntry('1');

      await db.deleteEntry('1');

      expect((await db.fetchTombstones()).single.revision, 2);
    });
  });

  group('the model', () {
    test('round-trips the tracking columns', () {
      final entry = _entry('1').copyWith(
        updatedAt: 42,
        deletedAt: 43,
        revision: 7,
        deviceId: 'device-z',
      );

      final restored = LoginEntry.fromMap(entry.toMap());

      expect(restored.updatedAt, 42);
      expect(restored.deletedAt, 43);
      expect(restored.revision, 7);
      expect(restored.deviceId, 'device-z');
    });

    test('copyWith can clear the nullable fields', () {
      final entry = _entry('1').copyWith(deletedAt: 5);

      expect(entry.copyWith(deletedAt: null).deletedAt, isNull);
      expect(entry.copyWith(totpSecret: null).totpSecret, isNull);
      // Not passing them leaves them alone.
      expect(entry.copyWith(title: 'x').deletedAt, 5);
      expect(entry.copyWith(title: 'x').totpSecret, isNotNull);
    });

    test('reads a row written before change tracking existed', () {
      final old = {
        'id': '1',
        'title': 'GitHub',
        'username': 'octocat',
        'password': 'pw',
        'website': 'https://github.com',
        'totpSecret': null,
      };

      final entry = LoginEntry.fromMap(old);

      expect(entry.updatedAt, 0);
      expect(entry.revision, 1);
      expect(entry.deviceId, isEmpty);
      expect(entry.isDeleted, isFalse);
    });
  });
}
