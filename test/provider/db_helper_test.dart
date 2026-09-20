import 'package:archinfotech/models/login_entry.dart';
import 'package:archinfotech/models/profile.dart';
import 'package:archinfotech/provider/db_helper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

LoginEntry _entry(String id, {String title = 'GitHub', String? totpSecret}) =>
    LoginEntry(
      id: id,
      title: title,
      username: 'octocat',
      password: 'pw-$id',
      website: 'https://github.com',
      totpSecret: totpSecret,
    );

final _profile = ProfileEntry(id: 'p1', name: 'ritesh');

void main() {
  final db = DbHelper.instance;

  setUpAll(initEncryptedTestDatabase);
  setUp(clearTables);

  group('login entries', () {
    test('a new database has no entries', () async {
      expect(await db.fetchEntries(), isEmpty);
    });

    test('insertEntry then fetchEntries returns the same data', () async {
      final entry = _entry('1', totpSecret: 'JBSWY3DPEHPK3PXP');
      await db.insertEntry(entry);

      final rows = await db.fetchEntries();
      expect(rows, hasLength(1));
      expect(rows.single.toMap(), entry.toMap());
    });

    test('insertEntry with an existing id replaces the row', () async {
      await db.insertEntry(_entry('1', title: 'Old'));
      await db.insertEntry(_entry('1', title: 'New'));

      final rows = await db.fetchEntries();
      expect(rows.map((e) => e.title), ['New']);
    });

    test('a null totpSecret is stored as null', () async {
      await db.insertEntry(_entry('1'));

      expect((await db.fetchEntries()).single.totpSecret, isNull);
    });

    test('updateEntry changes only the matching row', () async {
      await db.insertEntry(_entry('1', title: 'GitHub'));
      await db.insertEntry(_entry('2', title: 'Gmail'));

      await db.updateEntry(_entry('1', title: 'GitHub (work)'));

      final titles = {for (final e in await db.fetchEntries()) e.id: e.title};
      expect(titles, {'1': 'GitHub (work)', '2': 'Gmail'});
    });

    test('deleteEntry removes only the matching row', () async {
      await db.insertEntry(_entry('1'));
      await db.insertEntry(_entry('2'));

      await db.deleteEntry('1');

      expect((await db.fetchEntries()).map((e) => e.id), ['2']);
    });

    test('deleteEntry with an unknown id does nothing', () async {
      await db.insertEntry(_entry('1'));

      await db.deleteEntry('missing');

      expect(await db.fetchEntries(), hasLength(1));
    });
  });

  group('profile', () {
    test('fetchVaultProfile returns null when no profile exists', () async {
      expect(await db.fetchVaultProfile(), isNull);
    });

    test('AddProfile then fetchVaultProfile returns the same data', () async {
      await db.AddProfile(_profile);

      expect((await db.fetchVaultProfile())?.toMap(), _profile.toMap());
    });

    test('the profile stores only an id and a name', () async {
      await db.AddProfile(_profile);

      final columns = await (await db.database).rawQuery('PRAGMA table_info(profile)');

      expect(columns.map((c) => c['name']), ['id', 'name']);
    });

    test('fetchVaultProfile returns the oldest profile when several exist', () async {
      final raw = await db.database;
      await raw.insert('profile', _profile.toMap());
      await raw.insert('profile', _profile.copyWith(id: 'p2', name: 'someone').toMap());

      expect((await db.fetchVaultProfile())?.id, 'p1');
    });

    test('AddProfile with the same id replaces the profile', () async {
      await db.AddProfile(_profile);

      await db.AddProfile(_profile.copyWith(name: 'someone else'));

      expect((await db.fetchProfileEntries()).single.name, 'someone else');
    });

    test('fetchProfileEntries lists the saved profile', () async {
      await db.AddProfile(_profile);

      expect((await db.fetchProfileEntries()).map((p) => p.name), ['ritesh']);
    });

    test('updateProfile changes the name, matched by id', () async {
      await db.AddProfile(_profile);

      final updated = await db.updateProfile(_profile.copyWith(name: 'someone'));

      expect(updated, 1);
      expect((await db.fetchVaultProfile())?.name, 'someone');
    });

    test('updateProfile for an unknown id updates nothing', () async {
      await db.AddProfile(_profile);

      final updated = await db.updateProfile(_profile.copyWith(id: 'nope'));

      expect(updated, 0);
      expect((await db.fetchVaultProfile())?.name, 'ritesh');
    });

    test('only one profile can be stored (single-profile design)', () async {
      await db.AddProfile(_profile);
      try {
        await db.AddProfile(_profile.copyWith(id: 'p2', name: 'someone'));
      } catch (_) {
        // Rejecting the second profile with an error is also acceptable.
      }

      expect(await db.fetchProfileEntries(), hasLength(1));
    });
  });
}
