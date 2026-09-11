# Known Issues

This is the full list of known issues in Password Store. Fixes are being made on the `issue-fix` branch.

Issue numbers are stable. A unit test that covers a bug is marked `skip: 'ISSUES.md #N ...'`. When you fix issue #N, remove that `skip` so the test guards the fix.

**Severity:** 🔴 Critical (security, data loss or crash) · 🟠 High (a feature is broken) · 🟡 Medium · ⚪ Low / cleanup · ✅ Fixed

Line numbers refer to commit `65a5a5a`.

---

## Security

| # | Sev | Issue | Location |
|---|:---:|-------|----------|
| 1 | 🔴 | **No encryption at rest.** Every saved login (including passwords and TOTP secrets) is stored as plain text in `logins.db`. | `lib/provider/db_helper.dart:54-76` |
| 2 | 🔴 | **Passcode stored and compared as plain text.** There's no hashing or key derivation (such as Argon2 or PBKDF2). | `db_helper.dart:67-73`, `screens/password_auth.dart:98`, `screens/change_password.dart:57` |
| 3 | 🔴 | **Recovery answer stored as plain text.** Recovery relies on a single knowledge question. | `db_helper.dart:130-142` |
| 4 | 🟠 | Copied passwords stay on the clipboard forever. They're never auto-cleared. | `screens/item_login.dart:145`, `screens/add-login.dart:32`, `screens/edit_login.dart:53` |
| 5 | 🟠 | No auto-lock. The vault stays open when the app is idle or in the background. | `lib/password-manager.dart` |
| 6 | ⚪ | The database path is logged with `debugPrint`, and the second log prints `dbPath` instead of `path`. | `db_helper.dart:26-29` |

## Login and passcode

| # | Sev | Issue | Location |
|---|:---:|-------|----------|
| 7 | 🔴 | **Successful login saves a `null` username.** `saveLoginDetails(entry?.name)` is called with `entry`, which is always `null`, so `name!` throws (as an unawaited async error). The `username` pref is never written, the drawer shows "Guest", and changing the passcode breaks (#11). | `screens/password_auth.dart:84,102`, `provider/login_entry_provider.dart:80-83` |
| 8 | 🟠 | A wrong passcode for an existing user shows **no message at all**. The `else` branch only runs when no profile is found. | `password_auth.dart:97-112` |
| 9 | 🟡 | Empty username or passcode shows a snackbar, but the code still runs the lookup (missing `return`). | `password_auth.dart:86-91` |
| 10 | 🟡 | Login uses `Navigator.push`, so pressing Back from the vault goes back to the login screen. | `password_auth.dart:105` |
| 11 | 🟠 | **Change passcode always fails.** It looks up the profile using the `username` pref, which is never set (#7), so it always shows "Old Password does not match". | `screens/change_password.dart:28,52-62` |
| 12 | 🟡 | The 15-minute "skip login" and the username prefill read the `lastAuthTime` and `lastLoggedInUser` prefs, which nothing ever writes. | `password_auth.dart:36-66` |
| 13 | ⚪ | `_allProfiles == null` checks a non-nullable list, so it's dead code. `_loadLastLoggedInUser` also races `_loadAllProfiles`. | `password_auth.dart:43-46` |

## Profile and recovery

| # | Sev | Issue | Location |
|---|:---:|-------|----------|
| 14 | 🔴 | **Creating a profile stores the passcode in the `hint` column** (`hint: passwordController.text`), so the hint question is lost. | `screens/new_profile_screen.dart:37` |
| 15 | 🟠 | Recovery lowercases the name, question and answer, but stored values keep their original case, so mixed-case values never match. The database comparison is case-sensitive. | `screens/forget_password.dart:21-23` |
| 16 | 🟠 | **Recovery can't reset the passcode.** On success it opens `ChangePasswordScreen`, which asks for the *current* passcode and uses the `username` pref. | `forget_password.dart:31-35` |
| 17 | 🟡 | Recovery makes the user retype the hint question exactly, instead of showing the stored question. | `forget_password.dart:17,22` |
| 18 | 🟠 | **The app is single-profile by design** (like macOS Passwords), but "Create Account" is always available, a user-switch dialog appears when there are multiple profiles, and `switchProfile` / `_currentProfileName` are leftovers from multi-profile code. | `password_auth.dart:116-147,273-289`, `login_entry_provider.dart:84-91` |
| 19 | 🟡 | `profile.name` isn't unique in the schema, yet profiles are looked up and updated by name. | `db_helper.dart:67-73,126` |
| 20 | ⚪ | The profile id is a timestamp rather than a UUID. `addProfile` isn't awaited before navigating away. `hintAnswerController` is never disposed. The answer validator says "Please enter a hint question". | `new_profile_screen.dart:24-29,34,50,171` |

## Vault entries

| # | Sev | Issue | Location |
|---|:---:|-------|----------|
| 21 | 🟡 | `LoginEntryProvider` mutations return before the list is refreshed, because `loadEntries()` isn't awaited. `addEntry` never refreshes the list at all. | `provider/login_entry_provider.dart:18-54` |
| 22 | 🟡 | Undo after swipe-to-delete uses the dismissed item's `BuildContext`, which may already be unmounted, so Undo can throw. *(Likely; needs confirming on a device.)* | `screens/item_login.dart:60-62` |
| 23 | ⚪ | The add screen uses a timestamp id instead of a UUID, and closes before the save finishes. | `screens/add-login.dart:47,55-56` |
| 24 | ⚪ | The edit screen masks the **username** by default, as if it were a password. | `screens/edit_login.dart:19-22` |
| 25 | ⚪ | `insertEntry` and `AddProfile` run an extra `fetchEntries()` query and discard the result. | `db_helper.dart:81,104` |

## Database and platforms

| # | Sev | Issue | Location |
|---|:---:|-------|----------|
| 26 | 🟠 | `_onUpgrade` isn't version-aware. It creates `profile` whenever `oldVersion < newVersion`, so the next schema bump will fail with "table profile already exists". | `db_helper.dart:39-52` |
| 27 | 🟠 | Windows and Linux never initialize `sqflite_common_ffi`, so the database can't open there. The web isn't supported by `sqflite`. | `lib/main.dart` |

## Build, CI and tests

| # | Sev | Issue | Location |
|---|:---:|-------|----------|
| 28 | ⚪ | Legacy mock code: `PasswordProvider` holds sample passwords and is registered **twice**, `password-store.dart` is unused, and `PasswordEntry.fromMap` drops `url`. | `lib/main.dart:15-16`, `lib/service/password_provider.dart`, `lib/password-store.dart`, `lib/models/passwordEntry.dart:32-41` |
| 29 | ⚪ | `BuildContext` is used across async gaps without `mounted` checks. Some controllers are never disposed: `usernameController` in `password_auth.dart:153-156`, and all three in `forget_password.dart`. | several screens |
| 30 | ⚪ | UI polish: the `LoadingOverlay` is placed as the login screen's `floatingActionButton`, `withOpacity` is deprecated, the title "change Password" is lowercase, the Forgot Password AppBar says "Add Login", and there's a "No Exenses Found" typo. | `password_auth.dart:298`, `utils/loadingOverlay.dart`, `change_password.dart:97`, `forget_password.dart:51`, `password-store.dart:17` |
| 31 | 🟠 | `build-windows.yml` sits in `.github/workflow/` (missing "s"), so GitHub Actions never runs it. | `.github/workflow/build-windows.yml` |
| 32 | 🟠 | The CI Windows artifact path is `build/windows/runner/Release`, but Flutter ≥ 3.15 outputs to `build/windows/x64/runner/Release`, so the upload finds nothing. | `.github/workflows/dart.yml:67` |
| 33 | ✅ | **Fixed:** `.github/workflows/ci.yml` runs `flutter analyze` and `flutter test` on every pull request and on pushes to `main`. Existing lint warnings don't fail the build yet. | `.github/workflows/ci.yml` |
| 34 | ⚪ | The `flutter_icons` config points to `assets/icons/APPIcon.png`, but the file is `AppIcon.png`. That breaks icon generation on case-sensitive filesystems such as Linux. | `pubspec.yaml:62,65` |
| 35 | ⚪ | The pubspec `description` is still "A new Flutter project.", and the package is named `archinfotech`. | `pubspec.yaml:1-2` |
