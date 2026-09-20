# Password Store (Password Vault)

An open-source, cross-platform password manager built with Flutter. Like the **Passwords app on macOS**, it's a personal vault for a single user: one profile, unlocked with one passcode. The goal is one app to keep your logins safe, with multi-device support and strong encryption.

> [!WARNING]
> **Early development: do not store real passwords yet.**
> The app does **not encrypt data yet**. Saved logins, the vault passcode and the recovery answer are stored as **plain text** in a local SQLite database. Encryption and multi-device sync are on the roadmap below but not implemented. Use it only with test data until encryption lands.

---

## Table of contents

- [Features](#features)
- [Your storage, your control](#your-storage-your-control)
- [Share a credential](#share-a-credential)
- [Roadmap](#roadmap)
- [Supported platforms](#supported-platforms)
- [Getting started](#getting-started)
- [Project structure](#project-structure)
- [Known issues](#known-issues)
- [Contributing](#contributing)
- [Reporting security issues](#reporting-security-issues)
- [License](#license)

---

## Features

**Available today**

| Area | What it does |
|------|--------------|
| Single-user vault | One local profile protected by a passcode, like the macOS Passwords app. Set it up once on first launch. |
| Passcode login | Unlock the vault with your passcode alone. There is no username (show/hide passcode toggle). |
| Passcode recovery | Forgot the passcode? Answer your recovery question and set a new one. |
| Change passcode | Change your passcode from the settings drawer. |
| Save logins | Store a title, username, password, website and an optional TOTP secret for each account. |
| Edit and delete | Tap an entry to edit it. Swipe left to delete it, with **Undo**. |
| Search | Filter saved logins by title, username or website. |
| Copy to clipboard | One-tap copy of a username or password. |
| Offline and local | All data stays on the device in SQLite. There is no server and no account, and nothing is sent over the network. |

## Your storage, your control

**Planned, not yet built.** See the [Roadmap](#roadmap).

The vault is designed to be *bring your own storage*. Instead of syncing your passwords through a server run by this project, you choose where the encrypted vault file lives, and you keep the account that holds it:

- **iCloud Drive** on iOS and macOS
- **Google Drive** on Android and elsewhere
- **Any third-party bucket or folder** you already use, such as S3-compatible object storage, Dropbox, OneDrive or a self-hosted WebDAV share

Because the destination is yours, your credentials stay under your control and are managed by you. There is no project-operated account, no project-operated server, and no copy of your vault that we can read, hand over or lose.

Two rules make that safe, and both are prerequisites for the feature:

1. **The vault is encrypted on the device, before it ever leaves it.** The storage provider only ever receives ciphertext, so an iCloud, Google or bucket account compromise does not expose your logins.
2. **The key never goes to the provider.** It is derived from your passcode and stays on your devices, which means the provider cannot decrypt the file and neither can we.

The trade-off is that recovery is yours too: if you lose the passcode and your recovery key, no one can restore the vault for you.

## Share a credential

**Planned, not yet built.** See the [Roadmap](#roadmap).

Sometimes a login belongs to more than one person: a streaming account shared with family, a Wi-Fi password, a tool a small team signs into. Rather than sending it over chat or email in plain text, you will be able to share a single credential from your vault with another person, and only that credential — the rest of your vault is never involved.

You pick an entry, tap **Share**, and name the recipient:

- **Another Password Vault user**, if they already use this app
- **A phone number**, which the app matches to a Password Vault user

The shared entry lands in the recipient's own vault, where they unlock it with their own passcode. Sharing is per entry: you choose one login, not a folder and not the whole vault.

Some things still to be designed before this can be built:

- **The credential must be encrypted for the recipient**, on your device, so that whatever carries it between the two phones never sees the password.
- **Matching a phone number to a user needs a directory**, and a directory is a service. The app has no server today, and adding one has to be weighed against the "your data stays yours" design in [Your storage, your control](#your-storage-your-control).
- **Revoking a share** cannot claw back a password the other person has already read, so the honest behaviour is to stop future updates and prompt you to change the password.
- **Sharing is a trust decision, not just a transfer.** The recipient can read, copy and re-share what you send them.

## Roadmap

These features are **planned, not yet built**. Contributions are welcome.

- [ ] Encryption at rest for the whole database or each field (for example SQLCipher or AES-GCM with a key derived from the passcode)
- [ ] Hashed passcodes and recovery answers instead of plain text
- [ ] Auto-lock and session timeout
- [ ] TOTP code generation from the stored secret
- [ ] Password generator and strength indicator
- [ ] Encrypted backup, import and export
- [ ] Bring-your-own-storage sync: the encrypted vault file synced through the user's own iCloud Drive, Google Drive or third-party bucket (the "iCloud" item in the settings drawer is a placeholder) — see [Your storage, your control](#your-storage-your-control)
- [ ] Conflict resolution and merge when the same vault is edited on two devices
- [ ] Share a single credential with another Password Vault user, by user or phone number, end-to-end encrypted — see [Share a credential](#share-a-credential)
- [ ] Manage and revoke shares, and see what has been shared with you
- [ ] Quick unlock with Face ID / Touch ID / fingerprint or a short PIN: the vault key is kept in the OS Keychain / Keystore, and after a few wrong PINs the app falls back to the full passcode, which is also required after a restart and every few days ([#37](https://github.com/kr-riteshsinha/password-store/issues/37))
- [ ] Recovery key shown once at setup, replacing the hint question and answer, so recovery still works once the vault is encrypted ([#38](https://github.com/kr-riteshsinha/password-store/issues/38))
- [ ] Windows and Linux database support

## Supported platforms

| Platform | Builds | Works |
|----------|:------:|:-----:|
| Android | ✅ | ✅ |
| iOS | ✅ | ✅ |
| macOS | ✅ | ✅ |
| Windows | ✅ | ❌ The database can't open yet (needs `sqflite_common_ffi`) |
| Linux | ✅ | ❌ The database can't open yet (needs `sqflite_common_ffi`) |
| Web | – | ❌ `sqflite` has no web support |

## Getting started

### Quick start

```bash
git clone https://github.com/kr-riteshsinha/password-store.git
cd password-store

./install.sh           # macOS and Linux
install.bat            # Windows

flutter run            # or: flutter run -d macos
```

That's the whole setup. `install.sh` / `install.bat` build the development
environment from nothing: they install the Flutter SDK at the version CI uses,
put it on your `PATH`, install the system packages the tests need, and run
`flutter pub get`.

On first launch, tap **Set Up Vault**, then enter your name, a passcode and a
recovery question and answer. The vault opens straight away.

### Setting up the development environment

You don't need Flutter installed before you start. The setup script handles it.

**What it does**

| Step | Detail |
|------|--------|
| Installs Flutter | Version **3.32.6**, the same version CI pins, into `~/development/flutter` (`%USERPROFILE%\development\flutter` on Windows). Set `FLUTTER_INSTALL_DIR` to put it elsewhere. |
| Puts it on your `PATH` | Appends to `~/.zshrc`, `~/.bashrc`, `~/.bash_profile` or fish config; `setx` on Windows. Open a new terminal afterwards. |
| Installs test dependencies | On Linux, `libsqlite3-dev` and the GTK desktop build packages. The database tests fail without it. |
| Sets the project up | Runs `flutter pub get`, then `flutter doctor`. |
| Reports the rest | Xcode, CocoaPods, Android Studio and Visual Studio are checked and reported with the exact command to install them. |

**What it won't do**

It never runs `sudo` behind your back, and it never installs a multi-gigabyte
IDE for you. Anything needing admin rights is either confirmed first or printed
for you to run yourself. Anything already installed is left alone, so the script
is safe to re-run.

**Options**

| macOS / Linux | Windows | What it does |
|---------------|---------|--------------|
| `./install.sh` | `install.bat` | Install what's missing, then set the project up |
| `./install.sh --check` | `install.bat /check` | Report what's missing, change nothing |
| `./install.sh --yes` | `install.bat /yes` | Don't prompt, for CI or unattended installs |
| `./install.sh --help` | `install.bat /help` | Usage |

Start with `--check` if you'd rather see what it plans to touch:

```console
$ ./install.sh --check
==> Checking Flutter
  x Flutter is not installed
==> Checking platform toolchains
  + Xcode is installed
  x xcode-select points at /Library/Developer/CommandLineTools, not Xcode
```

### Toolchain for each build target

The setup script reports on all of these; only install the ones you'll build for.

| You want to build for | You also need |
|-----------------------|---------------|
| macOS or iOS | Xcode from the App Store, plus CocoaPods (`sudo gem install cocoapods`). Point the toolchain at Xcode: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| Android | [Android Studio](https://developer.android.com/studio) and a JDK, then `flutter doctor --android-licenses` |
| Windows desktop | Visual Studio 2022 with the **Desktop development with C++** workload |
| Linux desktop | `clang cmake ninja-build pkg-config libgtk-3-dev` (the script installs these) |
| Running the tests | On Linux, `libsqlite3-dev` (the script installs this) |

Run `flutter doctor` at any point to see what Flutter itself thinks is missing.

<details>
<summary>Setting it up by hand instead</summary>

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install). CI uses **3.32.6**, and the Dart SDK must be `^3.7.0`.
2. Add `<sdk>/bin` to your `PATH`.
3. In the project directory, run `flutter pub get`.
4. On Linux, install the SQLite headers the database tests need: `sudo apt-get install libsqlite3-dev`.
5. On macOS, point the toolchain at Xcode: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
6. Run `flutter doctor` and fix whatever it flags for your target.

</details>

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| `flutter: command not found` right after the script ran | The `PATH` change only applies to new shells. Open a new terminal, or `source ~/.zshrc`. |
| Database tests fail on Linux with a missing-library error | `sudo apt-get install libsqlite3-dev` — `sqflite_common_ffi` needs the system SQLite. |
| `CocoaPods not installed` on macOS | `sudo gem install cocoapods`, then `cd ios && pod install`. |
| Xcode build fails with a command-line-tools error | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`, then `sudo xcodebuild -runFirstLaunch`. |
| The app runs but no data saves on Windows or Linux | Expected. `sqflite` has no desktop support yet — see [Supported platforms](#supported-platforms). |
| Your Flutter is a different version from CI | Usually fine. To match exactly: `flutter version 3.32.6`. |

### Useful commands

```bash
flutter analyze                      # static analysis / lint
flutter test                         # run all tests
flutter test test/models/login_entry_test.dart   # run one test file
flutter run -d macos                 # run on macOS desktop
flutter build apk                    # Android (also: appbundle, ios, macos, windows)
dart run flutter_launcher_icons      # regenerate app icons
```

### Continuous integration

Two GitHub Actions workflows run on this repository:

- **`.github/workflows/ci.yml`** runs on every pull request and on pushes to `main`. It runs `flutter analyze --no-fatal-infos --no-fatal-warnings` (so only analyzer *errors* fail the build) and `flutter test`. Run both locally before you push.
- **`.github/workflows/dart.yml`** builds macOS, iOS (simulator), Android and Windows on pushes to `main`, and uploads the builds as workflow artifacts.

Both pin Flutter **3.32.6**, which is the version the setup script installs.

## Project structure

```
lib/
├── main.dart                 # App entry, Provider setup, starts at the login screen
├── password-manager.dart     # Main vault screen (list, drawer, add button)
├── models/                   # LoginEntry, ProfileEntry (map <-> SQLite rows)
├── provider/
│   ├── db_helper.dart        # SQLite singleton: login_entries + profile tables
│   ├── login_entry_provider.dart  # Main app state (ChangeNotifier)
│   └── LoadingProvider.dart  # Global loading overlay state
├── screens/                  # Login, create profile, list/add/edit logins, settings, recovery
└── utils/                    # Loading overlay, page transitions
```

- **State management:** [`provider`](https://pub.dev/packages/provider)
- **Storage:** [`sqflite`](https://pub.dev/packages/sqflite) and [`shared_preferences`](https://pub.dev/packages/shared_preferences)
- **UI:** Material 3 and [`lottie`](https://pub.dev/packages/lottie) animations

## Known issues

The full numbered list, with severity and file locations, is in **[ISSUES.md](ISSUES.md)**. Fixes are in progress on the `issue-fix` branch, and many make good first contributions. The main ones:

- Data is stored unencrypted (see the warning at the top).
- Logging in can crash, because a `null` profile name is force-unwrapped when saving login details.
- Creating a profile saves the passcode into the hint field instead of the hint.
- The "15-minute skip login" check reads preferences that are never written, so it never triggers.
- Recovery lowercases your input, but stored values keep their original case, so mixed-case answers never match.
- The app is designed for a single profile, but the login screen still lets you create more than one account and switch between them.
- The database upgrade logic isn't safe for future schema versions.

## Contributing

Contributions of all sizes are welcome: bug fixes, features from the roadmap, tests, docs and UI polish.

Read **[CONTRIBUTING.md](CONTRIBUTING.md)** for setup, code style, tests and the pull request process. In short:

1. Pick an issue from [ISSUES.md](ISSUES.md) or one labelled `good first issue`, and comment that you're working on it.
2. Fork the repository, and create a branch from `main`.
3. Run `flutter analyze` and `flutter test` before pushing.
4. Open a pull request against `main`.

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

By contributing, you agree that your contributions are licensed under the project's [MIT License](LICENSE).

## Reporting security issues

Full policy: [SECURITY.md](SECURITY.md).

**Don't open a public issue for security vulnerabilities.** Report them privately through GitHub's **Security → Report a vulnerability** (private vulnerability reporting) on this repository. Give a description, steps to reproduce and the affected platforms. Please allow time for a fix before disclosing publicly.

Weaknesses already listed under [Known issues](#known-issues), such as the lack of encryption, are public and can be discussed openly.

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for the full text.

You may use, copy, modify, merge, publish, distribute, sublicense and sell copies of the software, provided the copyright notice and license text are included. The software is provided **"as is", without warranty of any kind**. The authors are not liable for any loss of data or credentials resulting from its use.
