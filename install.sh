#!/usr/bin/env bash
#
# Password Vault - development environment setup (macOS and Linux).
#
#   ./install.sh              install what's missing, then set the project up
#   ./install.sh --yes        don't prompt (for CI or unattended installs)
#   ./install.sh --check      report what's missing, install nothing
#   ./install.sh --help       usage
#
# Installs the Flutter SDK pinned to the version CI uses, adds it to your PATH,
# installs the Linux system packages the tests need, then runs `flutter pub get`
# and `flutter doctor`. Safe to re-run: anything already present is left alone.
#
# It never runs `sudo` behind your back. Steps that need admin rights are either
# confirmed first or printed for you to run yourself.

set -euo pipefail

# Keep in sync with .github/workflows/ci.yml and dart.yml.
FLUTTER_VERSION="3.32.6"
FLUTTER_CHANNEL="stable"

INSTALL_DIR="${FLUTTER_INSTALL_DIR:-$HOME/development}"
FLUTTER_ROOT="$INSTALL_DIR/flutter"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ASSUME_YES=0
CHECK_ONLY=0
MISSING=()
NOTES=()

# ---------------------------------------------------------------- output ----

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

step() { printf '\n%s==>%s %s%s%s\n' "$BLUE" "$RESET" "$BOLD" "$1" "$RESET"; }
ok()   { printf '  %s+%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
fail() { printf '  %sx%s %s\n' "$RED" "$RESET" "$1"; }
note() { NOTES+=("$1"); }
die()  { printf '\n%serror:%s %s\n' "$RED" "$RESET" "$1" >&2; exit 1; }

usage() {
  sed -n '3,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

confirm() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  [ -t 0 ] || return 1
  local reply
  printf '  %s?%s %s [y/N] ' "$YELLOW" "$RESET" "$1"
  read -r reply
  [[ "$reply" =~ ^[Yy] ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------ arguments ----

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)   ASSUME_YES=1 ;;
    -c|--check) CHECK_ONLY=1 ;;
    -h|--help)  usage ;;
    *)          die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# -------------------------------------------------------------- platform ----

case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux" ;;
  *)      die "unsupported OS: $(uname -s). On Windows, run install.bat instead." ;;
esac

case "$(uname -m)" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64)  ARCH="x64" ;;
  *)             die "unsupported CPU architecture: $(uname -m)" ;;
esac

printf '%sPassword Vault - dev environment setup%s\n' "$BOLD" "$RESET"
printf 'platform: %s/%s   flutter: %s (%s)   project: %s\n' \
  "$OS" "$ARCH" "$FLUTTER_VERSION" "$FLUTTER_CHANNEL" "$PROJECT_DIR"

# ------------------------------------------------------- prerequisites ----

step "Checking prerequisites"

for tool in git curl unzip; do
  if have "$tool"; then
    ok "$tool"
  else
    fail "$tool is missing"
    MISSING+=("$tool")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  if [ "$OS" = "macos" ]; then
    note "Install the missing tools with: xcode-select --install"
  else
    note "Install the missing tools with: sudo apt-get install -y ${MISSING[*]}"
  fi
  [ "$CHECK_ONLY" -eq 1 ] || die "missing required tools: ${MISSING[*]}"
fi

# ------------------------------------------------------------- flutter ----

flutter_version_of() {
  # Prints the version of the flutter on PATH, or nothing if it can't be read.
  "$1" --version --machine 2>/dev/null \
    | sed -n 's/.*"frameworkVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1
}

install_flutter() {
  local base="https://storage.googleapis.com/flutter_infra_release/releases"
  local archive url tmp
  if [ "$OS" = "macos" ]; then
    if [ "$ARCH" = "arm64" ]; then
      archive="flutter_macos_arm64_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
    else
      archive="flutter_macos_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
    fi
    url="$base/$FLUTTER_CHANNEL/macos/$archive"
  else
    archive="flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
    url="$base/$FLUTTER_CHANNEL/linux/$archive"
  fi

  mkdir -p "$INSTALL_DIR"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  warn "Downloading Flutter $FLUTTER_VERSION (about 1 GB, this takes a few minutes)"
  # A progress bar is only useful on a terminal; in a log or CI it just emits
  # thousands of percentage lines, so fall back to errors-only there.
  local progress="--progress-bar"
  [ -t 1 ] || progress="-sS"
  if curl -fL $progress -o "$tmp/$archive" "$url"; then
    warn "Extracting to $FLUTTER_ROOT"
    case "$archive" in
      *.zip)    unzip -q "$tmp/$archive" -d "$tmp/out" ;;
      *.tar.xz) mkdir -p "$tmp/out" && tar -xJf "$tmp/$archive" -C "$tmp/out" ;;
    esac
    rm -rf "$FLUTTER_ROOT"
    mv "$tmp/out/flutter" "$FLUTTER_ROOT"
  else
    # The CDN archive is the fast path; a shallow clone of the tag is the
    # fallback if that URL ever moves or the download is blocked.
    warn "Archive download failed, cloning the SDK at tag $FLUTTER_VERSION instead"
    rm -rf "$FLUTTER_ROOT"
    git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git "$FLUTTER_ROOT" \
      || die "could not install Flutter (download and clone both failed)"
  fi

  # Git marks the SDK dir unsafe when its owner differs from the current user.
  git config --global --get-all safe.directory 2>/dev/null \
    | grep -qxF "$FLUTTER_ROOT" || git config --global --add safe.directory "$FLUTTER_ROOT"
}

step "Checking Flutter"

FLUTTER_BIN=""
if have flutter; then
  FLUTTER_BIN="$(command -v flutter)"
elif [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"
  note "Flutter is installed at $FLUTTER_ROOT but is not on your PATH."
fi

if [ -n "$FLUTTER_BIN" ]; then
  found="$(flutter_version_of "$FLUTTER_BIN")"
  if [ "$found" = "$FLUTTER_VERSION" ]; then
    ok "Flutter $found at $FLUTTER_BIN"
  elif [ -n "$found" ]; then
    warn "Flutter $found at $FLUTTER_BIN (CI pins $FLUTTER_VERSION)"
    note "Your Flutter is $found, CI uses $FLUTTER_VERSION. Usually fine, but if you see"
    note "  build differences, switch with: flutter version $FLUTTER_VERSION"
  else
    warn "Found $FLUTTER_BIN but could not read its version"
  fi
else
  fail "Flutter is not installed"
  if [ "$CHECK_ONLY" -eq 1 ]; then
    note "Run ./install.sh to install Flutter $FLUTTER_VERSION into $FLUTTER_ROOT"
  elif confirm "Install Flutter $FLUTTER_VERSION into $FLUTTER_ROOT?"; then
    install_flutter
    FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"
    ok "Installed Flutter $FLUTTER_VERSION"
  else
    die "Flutter is required. Install it from https://docs.flutter.dev/get-started/install"
  fi
fi

[ -n "$FLUTTER_BIN" ] && export PATH="$(dirname "$FLUTTER_BIN"):$PATH"

# ----------------------------------------------------------------- PATH ----

add_to_path() {
  # Appends the Flutter bin dir to the user's shell rc file, once.
  local bin_dir="$1" rc line
  case "$(basename "${SHELL:-/bin/bash}")" in
    zsh)  rc="$HOME/.zshrc" ;;
    bash) [ "$OS" = "macos" ] && rc="$HOME/.bash_profile" || rc="$HOME/.bashrc" ;;
    fish) rc="$HOME/.config/fish/config.fish" ;;
    *)    rc="" ;;
  esac
  [ -z "$rc" ] && { note "Add this to your shell profile: export PATH=\"$bin_dir:\$PATH\""; return; }

  if [ -f "$rc" ] && grep -qF "$bin_dir" "$rc"; then
    ok "PATH already set in $rc"
    return
  fi
  if [ "$CHECK_ONLY" -eq 1 ] || ! confirm "Add Flutter to your PATH in $rc?"; then
    note "Add this to $rc yourself: export PATH=\"$bin_dir:\$PATH\""
    return
  fi

  if [ "${rc##*/}" = "config.fish" ]; then
    mkdir -p "$(dirname "$rc")"
    line="fish_add_path $bin_dir"
  else
    line="export PATH=\"$bin_dir:\$PATH\""
  fi
  printf '\n# Flutter SDK (added by password-store/install.sh)\n%s\n' "$line" >> "$rc"
  ok "Added Flutter to $rc"
  note "Run 'source $rc' or open a new terminal to pick up the PATH change."
}

step "Checking PATH"
if [ "$CHECK_ONLY" -eq 1 ]; then
  have flutter && ok "flutter is on your PATH" || fail "flutter is not on your PATH"
elif [ -n "$FLUTTER_BIN" ]; then
  add_to_path "$(dirname "$FLUTTER_BIN")"
fi

# --------------------------------------------------- platform toolchains ----

step "Checking platform toolchains"

if [ "$OS" = "macos" ]; then
  if [ -d /Applications/Xcode.app ]; then
    ok "Xcode is installed"
    selected="$(xcode-select -p 2>/dev/null || true)"
    case "$selected" in
      *Xcode.app*) ok "xcode-select points at Xcode" ;;
      *)
        fail "xcode-select points at ${selected:-nothing}, not Xcode"
        note "macOS and iOS builds need the full Xcode toolchain. Run this yourself:"
        note "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        note "  sudo xcodebuild -runFirstLaunch"
        ;;
    esac
    have pod && ok "CocoaPods $(pod --version 2>/dev/null)" || {
      fail "CocoaPods is missing (needed for iOS and macOS builds)"
      note "Install CocoaPods with: sudo gem install cocoapods   (or: brew install cocoapods)"
    }
  else
    fail "Xcode is not installed (needed for macOS and iOS builds)"
    note "Install Xcode from the App Store, then run:"
    note "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  fi
else
  # sqflite_common_ffi runs the database tests against the system SQLite.
  if [ -f /usr/include/sqlite3.h ] || ldconfig -p 2>/dev/null | grep -q libsqlite3; then
    ok "SQLite development library"
  else
    fail "libsqlite3-dev is missing (the database tests need it)"
    if have apt-get && [ "$CHECK_ONLY" -eq 0 ] && confirm "Install libsqlite3-dev and the Linux desktop build deps with sudo?"; then
      sudo apt-get update
      sudo apt-get install -y libsqlite3-dev clang cmake ninja-build pkg-config libgtk-3-dev
      ok "Installed Linux build dependencies"
    else
      note "Install them with:"
      note "  sudo apt-get install -y libsqlite3-dev clang cmake ninja-build pkg-config libgtk-3-dev"
    fi
  fi
fi

# Android is a large, interactive install, so this only ever reports on it.
if have adb || [ -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}" ] || [ -d "$HOME/Android/Sdk" ]; then
  ok "Android SDK found"
else
  warn "Android SDK not found (only needed for Android builds)"
  note "For Android, install Android Studio from https://developer.android.com/studio"
  note "  then run: flutter doctor --android-licenses"
fi

if have java; then
  ok "Java $(java -version 2>&1 | head -1 | sed 's/.*"\(.*\)".*/\1/')"
else
  warn "Java not found (only needed for Android builds)"
fi

# --------------------------------------------------------------- project ----

if [ "$CHECK_ONLY" -eq 1 ]; then
  step "Check complete"
else
  step "Setting up the project"
  cd "$PROJECT_DIR"
  if have flutter; then
    flutter pub get || die "flutter pub get failed"
    ok "Dependencies installed"

    step "Running flutter doctor"
    flutter doctor || true
  else
    warn "Skipping pub get: flutter is not available in this shell yet"
  fi
fi

# ----------------------------------------------------------------- notes ----

if [ "${#NOTES[@]}" -gt 0 ]; then
  step "Things to finish by hand"
  for n in "${NOTES[@]}"; do printf '  - %s\n' "$n"; done
fi

step "Next steps"
cat <<EOF
  flutter run -d macos          run the app on macOS desktop
  flutter run                   run on a connected device or emulator
  flutter test                  run the test suite
  flutter analyze               run static analysis

  Read CONTRIBUTING.md before opening a pull request.
EOF
