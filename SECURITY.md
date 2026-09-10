# Security Policy

## Project status

Password Store is in **early development**. It doesn't encrypt stored data yet, so don't use it for real passwords. See the warning in the [README](README.md).

## Supported versions

There are no releases yet. Security fixes go to the latest `main` branch only.

## Reporting a vulnerability

**Don't report security vulnerabilities through public GitHub issues, discussions or pull requests.**

Report them privately through GitHub:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**, or open https://github.com/kr-riteshsinha/password-store/security/advisories/new directly.

Please include:

- a description of the vulnerability and its impact,
- steps to reproduce it, or a proof of concept,
- the affected platforms (Android, iOS, macOS, Windows or Linux) and the commit or version,
- a suggested fix, if you have one.

The maintainer will reply in the private advisory thread. Please allow time for a fix to be released before you disclose the issue publicly. Reporters are credited in the advisory unless they ask not to be.

## Already-known weaknesses

These are public and tracked in [ISSUES.md](ISSUES.md). You don't need to report them privately, and they can be discussed openly:

- **#1:** Vault data isn't encrypted at rest.
- **#2:** The passcode is stored and compared as plain text.
- **#3:** The recovery answer is stored as plain text.
- **#4:** Copied passwords are never cleared from the clipboard.
- **#5:** There's no auto-lock.

Contributions that fix these are very welcome. See [CONTRIBUTING.md](CONTRIBUTING.md#security-sensitive-changes).

## Scope

In scope: the code in this repository.

Out of scope: vulnerabilities in third-party packages (please report those to the package maintainers), and attacks that require an already-compromised device.
