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
    test('findProfileByName returns null when no profile exists', () async {
      expect(await provider.findProfileByName('ritesh'), isNull);
    });

    test('addProfile then findProfileByName returns it', () async {
      await provider.addProfile(_profile);

      expect((await provider.findProfileByName('ritesh'))?.toMap(), _profile.toMap());
    });

    test('getAllProfiles returns the saved profile', () async {
      await provider.addProfile(_profile);

      expect((await provider.getAllProfiles()).map((p) => p.id), ['p1']);
    });

    test('updateProfile changes the stored passcode', () async {
      await provider.addProfile(_profile);

      await provider.updateProfile(_profile.copyWith(password: '5678'));

      expect((await provider.findProfileByName('ritesh'))?.password, '5678');
    });

    test('forgetPassword matches only the exact name, hint and answer', () async {
      await provider.addProfile(_profile);

      expect(await provider.forgetPassword('ritesh', 'Favorite color?', 'Blue'), isNotNull);
      expect(await provider.forgetPassword('ritesh', 'Favorite color?', 'Red'), isNull);
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
