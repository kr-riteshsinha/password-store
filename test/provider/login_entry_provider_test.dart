import 'package:archinfotech/models/login_entry.dart';
import 'package:archinfotech/models/profile.dart';
import 'package:archinfotech/provider/db_helper.dart';
import 'package:archinfotech/provider/login_entry_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

import 'package:archinfotech/crypto/vault_meta.dart';

import '../helpers/test_database.dart';

LoginEntry _entry(String id, {String title = 'GitHub'}) => LoginEntry(
      id: id,
      title: title,
      username: 'octocat',
      password: 'pw-$id',
      website: 'https://github.com',
    );

final _profile = ProfileEntry(id: 'p1', name: 'ritesh');

void main() {
  late LoginEntryProvider provider;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initEncryptedTestDatabase();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await resetVault();
    await clearTables();
    provider = LoginEntryProvider();
  });

  tearDownAll(resetVault);

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

    test('updateProfile changes the stored name', () async {
      await provider.addProfile(_profile);

      await provider.updateProfile(_profile.copyWith(name: 'someone'));

      expect((await provider.getProfile())?.name, 'someone');
    });

  });

  group('first-run setup', () {
    Future<ProfileEntry> create() async {
      // Setup creates the encrypted database itself, so nothing may be open.
      await resetVault();
      return provider.createVault(
        name: ' ritesh ',
        passcode: '1234',
        hintQuestion: ' Favorite color? ',
        hintAnswer: ' Blue ',
      );
    }

    test('createVault stores the profile but never the passcode or answer', () async {
      final created = await create();

      final stored = await provider.getProfile();
      expect(stored?.toMap(), created.toMap());
      expect(stored?.name, 'ritesh');
      // ISSUES.md #2 and #3: the row holds nothing but an id and a name.
      expect(stored?.toMap().keys, ['id', 'name']);
    });

    test('createVault writes the vault metadata next to the database', () async {
      await create();

      final store = VaultMetaStore(await DbHelper.instance.vaultDirectory());
      final meta = await store.read();

      expect(meta, isNotNull);
      expect(meta!.hasRecovery, isTrue);
      expect(meta.recoveryQuestion, 'Favorite color?');
    });

    test('the passcode opens the vault and a wrong one does not', () async {
      await create();
      await DbHelper.instance.close();

      expect(await provider.unlockWithPasscodeAndOpen('9999'), isFalse);
      expect(await provider.unlockWithPasscodeAndOpen('1234'), isTrue);
      expect((await provider.getProfile())?.name, 'ritesh');
    });

    test('createVault gives the profile a UUID', () async {
      final created = await create();

      expect(created.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('createVault refuses to create a second vault', () async {
      await create();

      await expectLater(
        provider.createVault(
          name: 'someone',
          passcode: '5678',
          hintQuestion: 'q',
          hintAnswer: 'a',
        ),
        throwsStateError,
      );
    });

    test('vaultState does not create a database file', () async {
      await resetVault();

      expect(await provider.vaultState(), VaultState.none);

      // Creating the file here would leave a plaintext database that
      // SQLCipher cannot open, breaking setup on a fresh install.
      expect(File(await DbHelper.instance.databaseFile()).existsSync(), isFalse);
    });

    test('setup moves aside a database left without its metadata', () async {
      await resetVault();
      await openTestVault();
      await DbHelper.instance.close();
      final path = await DbHelper.instance.databaseFile();
      expect(File(path).existsSync(), isTrue);

      await provider.createVault(
        name: 'ritesh',
        passcode: '1234',
        hintQuestion: 'Favorite color?',
        hintAnswer: 'Blue',
      );

      expect((await provider.getProfile())?.name, 'ritesh');
      // The old file is kept, renamed, rather than deleted.
      final orphans = Directory(await DbHelper.instance.vaultDirectory())
          .listSync()
          .where((e) => e.path.contains('.orphan-'));
      expect(orphans, hasLength(1));
    });

    test('vaultState reports what is on the device', () async {
      await resetVault();
      expect(await provider.vaultState(), VaultState.none);

      await create();
      expect(await provider.vaultState(), VaultState.encrypted);
    });
  });

  group('recovery', () {
    Future<void> createVault() async {
      await resetVault();
      await provider.createVault(
        name: 'ritesh',
        passcode: '1234',
        hintQuestion: 'Favorite color?',
        hintAnswer: 'Blue',
      );
      await DbHelper.instance.close();
    }

    test('recoveryQuestion is null when there is no vault', () async {
      await resetVault();

      expect(await provider.recoveryQuestion(), isNull);
    });

    test('recoveryQuestion comes from the metadata, before unlocking', () async {
      await createVault();

      expect(await provider.recoveryQuestion(), 'Favorite color?');
      expect(DbHelper.instance.isOpen, isFalse);
    });

    test('the answer unlocks the vault, ignoring case and spaces', () async {
      await createVault();

      expect(await provider.verifyRecoveryAnswer('  bLUE '), isTrue);
      expect((await provider.getProfile())?.name, 'ritesh');
    });

    test('a wrong or empty answer is refused', () async {
      await createVault();

      expect(await provider.verifyRecoveryAnswer('Red'), isFalse);
      expect(await provider.verifyRecoveryAnswer('   '), isFalse);
    });

    test('resetPasscode swaps the passcode and keeps the entries', () async {
      await createVault();
      await provider.unlockWithPasscodeAndOpen('1234');
      await provider.addLoginEntry(_entry('1'));

      expect(await provider.resetPasscode('9999'), isTrue);
      await DbHelper.instance.close();

      expect(await provider.unlockWithPasscodeAndOpen('1234'), isFalse);
      expect(await provider.unlockWithPasscodeAndOpen('9999'), isTrue);
      expect((await DbHelper.instance.fetchEntries()).single.id, '1');
    });

    test('recovery still works after the passcode changes', () async {
      await createVault();
      await provider.unlockWithPasscodeAndOpen('1234');
      await provider.resetPasscode('9999');
      await DbHelper.instance.close();

      expect(await provider.verifyRecoveryAnswer('Blue'), isTrue);
    });

    test('changePasscode needs the current passcode', () async {
      await createVault();

      expect(await provider.changePasscode('wrong', '9999'), isFalse);
      expect(await provider.changePasscode('1234', '9999'), isTrue);
      await DbHelper.instance.close();

      expect(await provider.unlockWithPasscodeAndOpen('9999'), isTrue);
    });

    test('lock closes the vault', () async {
      await createVault();
      await provider.unlockWithPasscodeAndOpen('1234');

      await provider.lock();

      expect(DbHelper.instance.isOpen, isFalse);
      expect(provider.entries, isEmpty);
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
