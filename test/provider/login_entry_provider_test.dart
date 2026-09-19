import 'package:archinfotech/models/login_entry.dart';
import 'package:archinfotech/models/profile.dart';
import 'package:archinfotech/provider/db_helper.dart';
import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_database.dart';

LoginEntry _entry(String id, {String title = 'GitHub'}) => LoginEntry(
      id: id,
      title: title,
      username: 'octocat',
      password: 'pw-$id',
      website: 'https://github.com',
    );

final _profile = ProfileEntry(
  id: 'p1',
  name: 'ritesh',
  password: '1234',
  hint: 'Favorite color?',
  answer: 'Blue',
);

void main() {
  late LoginEntryProvider provider;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initTestDatabase();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearTables();
    provider = LoginEntryProvider();
  });

  group('entries', () {
    test('starts empty', () {
      expect(provider.entries, isEmpty);
    });

    test('loadEntries reads saved entries and notifies once', () async {
      await DbHelper.instance.insertEntry(_entry('1'));
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.loadEntries();

      expect(provider.entries.map((e) => e.id), ['1']);
      expect(notifications, 1);
    });

    test('entries cannot be modified from outside', () {
      expect(() => provider.entries.add(_entry('x')), throwsUnsupportedError);
    });

    test('addLoginEntry saves the entry to the database', () async {
      await provider.addLoginEntry(_entry('1'));

      expect((await DbHelper.instance.fetchEntries()).map((e) => e.id), ['1']);
    });

    test('addEntry saves entries with distinct generated ids', () async {
      for (final title in ['GitHub', 'Gmail']) {
        await provider.addEntry(
          title: title,
          username: 'octocat',
          password: 'pw',
          website: 'https://example.com',
        );
      }

      final ids = (await DbHelper.instance.fetchEntries()).map((e) => e.id);
      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(2));
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    });

    test('updateEntry saves the change to the database', () async {
      await DbHelper.instance.insertEntry(_entry('1', title: 'Old'));

      await provider.updateEntry(_entry('1', title: 'New'));

      expect((await DbHelper.instance.fetchEntries()).single.title, 'New');
    });

    test('deleteEntry removes the entry from the database and from entries', () async {
      await DbHelper.instance.insertEntry(_entry('1'));
      await DbHelper.instance.insertEntry(_entry('2'));
      await provider.loadEntries();

      await provider.deleteEntry('1');

      expect(provider.entries.map((e) => e.id), ['2']);
      expect((await DbHelper.instance.fetchEntries()).map((e) => e.id), ['2']);
    });

    test(
      'addLoginEntry refreshes entries before completing',
      () async {
        await provider.addLoginEntry(_entry('1'));

        expect(provider.entries.map((e) => e.id), ['1']);
      },
      skip: 'ISSUES.md #21: loadEntries() is not awaited',
    );

    test(
      'addEntry adds the new entry to entries',
      () async {
        await provider.addEntry(
          title: 'GitHub',
          username: 'octocat',
          password: 'pw',
          website: 'https://github.com',
        );

        expect(provider.entries.map((e) => e.title), ['GitHub']);
      },
      skip: 'ISSUES.md #21: addEntry never refreshes entries',
    );

    test(
      'updateEntry refreshes entries before completing',
      () async {
        await DbHelper.instance.insertEntry(_entry('1', title: 'Old'));
        await provider.loadEntries();

        await provider.updateEntry(_entry('1', title: 'New'));

        expect(provider.entries.single.title, 'New');
      },
      skip: 'ISSUES.md #21: loadEntries() is not awaited',
    );
  });

  group('profile', () {
    test('getProfile returns null when no profile exists', () async {
      expect(await provider.getProfile(), isNull);
    });

    test('addProfile then getProfile returns it', () async {
      await provider.addProfile(_profile);

      expect((await provider.getProfile())?.toMap(), _profile.toMap());
    });

    test('addProfile rejects a second profile', () async {
      await provider.addProfile(_profile);

      await expectLater(
        provider.addProfile(_profile.copyWith(id: 'p2', name: 'someone')),
        throwsStateError,
      );
      expect((await provider.getProfile())?.id, 'p1');
    });

    test('updateProfile changes the stored passcode', () async {
      await provider.addProfile(_profile);

      await provider.updateProfile(_profile.copyWith(password: '5678'));

      expect((await provider.getProfile())?.password, '5678');
    });

  });

  group('first-run setup', () {
    Future<ProfileEntry> create() => provider.createVault(
          name: ' ritesh ',
          passcode: '1234',
          hintQuestion: ' Favorite color? ',
          hintAnswer: ' Blue ',
        );

    test('createVault saves the passcode, question and answer in their own columns', () async {
      final created = await create();

      final stored = await provider.getProfile();
      expect(stored?.toMap(), created.toMap());
      expect(stored?.name, 'ritesh');
      expect(stored?.password, '1234');
      // ISSUES.md #14: the question used to be overwritten with the passcode.
      expect(stored?.hint, 'Favorite color?');
      expect(stored?.answer, 'Blue');
    });

    test('createVault gives the profile a UUID', () async {
      final created = await create();

      expect(created.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('createVault refuses to create a second vault', () async {
      await create();

      await expectLater(create(), throwsStateError);
      expect(await DbHelper.instance.fetchProfileEntries(), hasLength(1));
    });
  });

  group('recovery', () {
    test('recoveryQuestion is null when there is no vault', () async {
      expect(await provider.recoveryQuestion(), isNull);
    });

    test('recoveryQuestion returns the stored question', () async {
      await provider.addProfile(_profile);

      expect(await provider.recoveryQuestion(), 'Favorite color?');
    });

    test('recoveryQuestion never reveals a passcode stored as the hint (#14 legacy data)', () async {
      await provider.addProfile(_profile.copyWith(hint: _profile.password));

      expect(await provider.recoveryQuestion(), isNull);
    });

    test('verifyRecoveryAnswer accepts the answer ignoring case and spaces', () async {
      await provider.addProfile(_profile);

      expect(await provider.verifyRecoveryAnswer('Blue'), isTrue);
      expect(await provider.verifyRecoveryAnswer('  bLUE '), isTrue);
    });

    test('verifyRecoveryAnswer rejects a wrong or empty answer', () async {
      await provider.addProfile(_profile);

      expect(await provider.verifyRecoveryAnswer('Red'), isFalse);
      expect(await provider.verifyRecoveryAnswer(''), isFalse);
      expect(await provider.verifyRecoveryAnswer('   '), isFalse);
    });

    test('verifyRecoveryAnswer is false when there is no vault', () async {
      expect(await provider.verifyRecoveryAnswer('Blue'), isFalse);
    });

    test('verifyRecoveryAnswer still works for #14 legacy data', () async {
      await provider.addProfile(_profile.copyWith(hint: _profile.password));

      expect(await provider.verifyRecoveryAnswer('blue'), isTrue);
    });

    test('resetPasscode replaces the passcode without needing the old one', () async {
      await provider.addProfile(_profile);

      expect(await provider.resetPasscode('9999'), isTrue);

      final stored = await provider.getProfile();
      expect(stored?.password, '9999');
      expect(stored?.hint, _profile.hint);
      expect(stored?.answer, _profile.answer);
    });

    test('resetPasscode returns false when there is no vault', () async {
      expect(await provider.resetPasscode('9999'), isFalse);
      expect(await provider.getProfile(), isNull);
    });
  });

  group('session prefs', () {
    test('saveLoginDetails stores the username', () async {
      await provider.saveLoginDetails('ritesh');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('username'), 'ritesh');
    });
  });
}
