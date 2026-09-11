# Password Store (Password Vault)

An open-source, cross-platform password manager built with Flutter. Like the **Passwords app on macOS**, it's a personal vault for a single user: one profile, unlocked with one passcode. The goal is one app to keep your logins safe, with multi-device support and strong encryption.

> [!WARNING]
> **Early development: do not store real passwords yet.**
> The app does **not encrypt data yet**. Saved logins, the vault passcode and the recovery answer are stored as **plain text** in a local SQLite database. Encryption and multi-device sync are on the roadmap below but not implemented. Use it only with test data until encryption lands.

---

## Table of contents

- [Features](#features)
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
| Passcode login | Unlock the vault with your name and passcode (show/hide passcode toggle). |
| Password recovery | Recover access with your hint question and answer. |
| Change passcode | Change your passcode from the settings drawer. |
| Save logins | Store a title, username, password, website and an optional TOTP secret for each account. |
| Edit and delete | Tap an entry to edit it. Swipe left to delete it, with **Undo**. |
| Search | Filter saved logins by title, username or website. |
| Copy to clipboard | One-tap copy of a username or password. |
| Offline and local | All data stays on the device in SQLite. There is no server and no account, and nothing is sent over the network. |

## Roadmap

These features are **planned, not yet built**. Contributions are welcome.

- [ ] Encryption at rest for the whole database or each field (for example SQLCipher or AES-GCM with a key derived from the passcode)
- [ ] Hashed passcodes and recovery answers instead of plain text
- [ ] Auto-lock and session timeout
- [ ] TOTP code generation from the stored secret
- [ ] Password generator and strength indicator
- [ ] Encrypted backup, import and export
- [ ] Multi-device sync (the "iCloud" item in the settings drawer is a placeholder)
- [ ] Biometric unlock (Face ID / fingerprint)
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

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install). CI uses **3.32.6**. The Dart SDK must be `^3.7.0`.
- The platform toolchain for your target: Xcode for iOS/macOS, Android Studio / Android SDK for Android, or Visual Studio for Windows.

### Setup and run

```bash
git clone https://github.com/kr-riteshsinha/password-store.git
cd password-store
flutter pub get
flutter run            # pick a device, or e.g. `flutter run -d macos`
```

On first launch, tap **Create Account** on the login screen, set a name, passcode and recovery hint, then log in.

### Useful commands

```bash
flutter analyze                      # static analysis / lint
flutter test                         # run all tests
flutter test test/models/login_entry_test.dart   # run one test file
flutter build apk                    # Android (also: appbundle, ios, macos, windows)
dart run flutter_launcher_icons      # regenerate app icons
```

### Continuous integration

GitHub Actions (`.github/workflows/dart.yml`) builds macOS, iOS (simulator), Android and Windows on every push to `main`, and uploads the builds as workflow artifacts.

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
