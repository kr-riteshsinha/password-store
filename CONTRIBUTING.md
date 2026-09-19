# Contributing to Password Store

Thanks for your interest in contributing. Bug fixes, roadmap features, tests, docs and UI polish are all welcome, whatever their size.

Please read this guide before you open an issue or pull request. Everyone taking part in this project is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

- **Read the warning in the [README](README.md).** The app is in early development and doesn't encrypt data yet.
- **Look for something to work on.** [ISSUES.md](ISSUES.md) lists every known bug with its severity and file location, and the [issue tracker](https://github.com/kr-riteshsinha/password-store/issues) has issues labelled `good first issue`.
- **Say what you're taking on.** Comment on the issue before you start, so two people don't fix the same thing. For a larger feature, open an issue to discuss the approach first.
- **Keep to the design:** Password Store is a **single-user vault**, like the Passwords app on macOS: one profile, unlocked with one passcode. Please don't add multi-profile or multi-user features.

## Development setup

Fork the repository, clone your fork, and run the setup script:

```bash
git clone https://github.com/<your-username>/password-store.git
cd password-store

./install.sh          # macOS and Linux
install.bat           # Windows
```

It installs the Flutter SDK at the version CI uses (**3.32.6**), adds it to your
PATH, installs the system packages the tests need, and runs `flutter pub get`.
It skips anything you already have, so it's safe to re-run. Use `--check`
(`/check` on Windows) to see what's missing without installing anything.

Anything that needs admin rights - Xcode's toolchain switch, Android Studio,
Visual Studio - is reported with the exact command to run, never run for you.

Then run the app:

```bash
flutter run -d macos      # or: flutter run
```

<details>
<summary>Setting it up by hand instead</summary>

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install). CI uses **3.32.6**, and the Dart SDK must be `^3.7.0`.
2. Run `flutter pub get` in the project directory.
3. On Linux, install the system SQLite library the database tests need: `sudo apt-get install libsqlite3-dev`.
4. On macOS, point the toolchain at Xcode: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

</details>

## Making a change

1. Create a branch from `main` with a descriptive name, such as `fix/login-crash` or `feat/password-generator`.
2. Keep each pull request focused on one change. Smaller PRs get reviewed faster.
3. Before pushing, run:
   ```bash
   flutter analyze
   flutter test
   ```
4. Open a pull request against `main` and fill in the template.

### Code style

- Follow the lints in `analysis_options.yaml` (`flutter_lints`). Don't introduce new analyzer warnings.
- Use `snake_case` for new Dart files. Leave existing file names alone unless the PR is specifically about renaming them.
- Match the patterns already in the code: `provider` / `ChangeNotifier` for state, and `DbHelper` for all SQLite access.

### Tests

- Unit tests live in `test/models` and `test/provider`. Add or update tests for any logic you change.
- Database tests run SQLite on your computer through `sqflite_common_ffi`. Call `initTestDatabase()` from `test/helpers/test_database.dart` in `setUpAll`, and `clearTables()` in `setUp`.
- Tests for known bugs are marked `skip: 'ISSUES.md #N ...'`. If your PR fixes issue #N, remove that `skip`, check the test passes, and mark the issue fixed in `ISSUES.md`.

### Commit messages

Write short, imperative summaries, such as `Fix crash when saving login details` or `Add password generator`. Reference issues where relevant (`Fixes #12`).

## Security-sensitive changes

Changes to storage, encryption, the passcode or recovery get extra review. In the PR, explain:

- the threat you're addressing,
- the libraries and algorithms you chose, and why,
- how existing users' data is migrated.

Never commit real passwords, keystores, signing files or API keys.

To report a vulnerability, **don't open a public issue**. Follow [SECURITY.md](SECURITY.md).

## Reporting bugs and requesting features

Use the [issue templates](https://github.com/kr-riteshsinha/password-store/issues/new/choose). Check [ISSUES.md](ISSUES.md) and the existing issues first, to avoid duplicates.

## License

Password Store is licensed under the [MIT License](LICENSE). By submitting a contribution, you agree that it is licensed under the same terms.
