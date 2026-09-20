@echo off
rem ===========================================================================
rem  Password Vault - development environment setup (Windows).
rem
rem    install.bat            install what's missing, then set the project up
rem    install.bat /check     report what's missing, install nothing
rem    install.bat /yes       don't prompt (for CI or unattended installs)
rem    install.bat /help      usage
rem
rem  Installs the Flutter SDK pinned to the version CI uses, adds it to your
rem  PATH for future terminals, then runs `flutter pub get` and `flutter
rem  doctor`. Safe to re-run: anything already present is left alone.
rem
rem  Note: sqflite has no Windows support yet, so the app builds on Windows but
rem  its database will not open. See "Supported platforms" in README.md.
rem ===========================================================================

setlocal EnableDelayedExpansion

rem Keep in sync with .github/workflows/ci.yml and dart.yml.
set "FLUTTER_VERSION=3.32.6"
set "FLUTTER_CHANNEL=stable"

if not defined FLUTTER_INSTALL_DIR set "FLUTTER_INSTALL_DIR=%USERPROFILE%\development"
set "FLUTTER_ROOT=%FLUTTER_INSTALL_DIR%\flutter"
set "PROJECT_DIR=%~dp0"
set "ASSUME_YES=0"
set "CHECK_ONLY=0"
set "NOTE_COUNT=0"
set "FLUTTER_BIN_DIR="

rem vswhere lives under the x86 Program Files; read it before any ( ) block,
rem because the ")" in the variable name breaks parsing inside one.
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="/yes" (
  set "ASSUME_YES=1"
  shift
  goto parse_args
)
if /i "%~1"=="/y" (
  set "ASSUME_YES=1"
  shift
  goto parse_args
)
if /i "%~1"=="/check" (
  set "CHECK_ONLY=1"
  shift
  goto parse_args
)
if /i "%~1"=="/c" (
  set "CHECK_ONLY=1"
  shift
  goto parse_args
)
if /i "%~1"=="/help" goto usage
if /i "%~1"=="/h" goto usage
if /i "%~1"=="/?" goto usage
echo error: unknown option %~1  ^(try install.bat /help^)
exit /b 1
:args_done

echo Password Vault - dev environment setup
echo flutter: %FLUTTER_VERSION% (%FLUTTER_CHANNEL%)
echo project: %PROJECT_DIR%

rem ------------------------------------------------------- prerequisites ----

echo.
echo ==^> Checking prerequisites

set "MISSING="
call :need git
if errorlevel 1 set "MISSING=!MISSING! git"
call :need curl
if errorlevel 1 set "MISSING=!MISSING! curl"
call :need tar
if errorlevel 1 set "MISSING=!MISSING! tar"

if defined MISSING (
  echo   x missing required tools:!MISSING!
  echo     curl and tar ship with Windows 10 1803 and later.
  echo     Install Git from https://git-scm.com/download/win
  if "%CHECK_ONLY%"=="0" exit /b 1
)

rem ------------------------------------------------------------- flutter ----

echo.
echo ==^> Checking Flutter

for /f "delims=" %%i in ('where flutter 2^>nul') do (
  if not defined FLUTTER_BIN_DIR for %%d in ("%%i") do set "FLUTTER_BIN_DIR=%%~dpd"
)

if not defined FLUTTER_BIN_DIR if exist "%FLUTTER_ROOT%\bin\flutter.bat" (
  set "FLUTTER_BIN_DIR=%FLUTTER_ROOT%\bin"
  call :note "Flutter is installed at %FLUTTER_ROOT% but is not on your PATH."
)

if defined FLUTTER_BIN_DIR goto flutter_found

echo   x Flutter is not installed
if "%CHECK_ONLY%"=="1" (
  call :note "Run install.bat to install Flutter %FLUTTER_VERSION% into %FLUTTER_ROOT%"
  goto toolchains
)
if "%ASSUME_YES%"=="0" (
  set "REPLY="
  set /p "REPLY=  ? Install Flutter %FLUTTER_VERSION% into %FLUTTER_ROOT%? [y/N] "
  if /i not "!REPLY:~0,1!"=="y" (
    echo.
    echo error: Flutter is required. https://docs.flutter.dev/get-started/install/windows
    exit /b 1
  )
)
call :install_flutter
if errorlevel 1 exit /b 1
set "FLUTTER_BIN_DIR=%FLUTTER_ROOT%\bin"

:flutter_found
rem Strip any trailing backslash left by %%~dpd, then make flutter callable here.
if "!FLUTTER_BIN_DIR:~-1!"=="\" set "FLUTTER_BIN_DIR=!FLUTTER_BIN_DIR:~0,-1!"
set "PATH=!FLUTTER_BIN_DIR!;%PATH%"

set "FOUND_VERSION="
for /f "tokens=2" %%v in ('flutter --version 2^>nul ^| findstr /b /c:"Flutter "') do (
  if not defined FOUND_VERSION set "FOUND_VERSION=%%v"
)
if not defined FOUND_VERSION (
  echo   ! Found flutter in !FLUTTER_BIN_DIR! but could not read its version
) else if "!FOUND_VERSION!"=="%FLUTTER_VERSION%" (
  echo   + Flutter !FOUND_VERSION! in !FLUTTER_BIN_DIR!
) else (
  echo   ! Flutter !FOUND_VERSION! in !FLUTTER_BIN_DIR!, CI pins %FLUTTER_VERSION%
  call :note "Your Flutter is !FOUND_VERSION!, CI uses %FLUTTER_VERSION%. To match CI: flutter version %FLUTTER_VERSION%"
)

rem ---------------------------------------------------------------- PATH ----

echo.
echo ==^> Checking PATH
if "%CHECK_ONLY%"=="1" (
  echo   - skipped in /check mode
) else (
  call :add_to_path
)

rem -------------------------------------------------- platform toolchains ----

:toolchains
echo.
echo ==^> Checking platform toolchains

rem Windows desktop builds need Visual Studio with the C++ workload.
set "VS_PATH="
if exist "%VSWHERE%" (
  for /f "usebackq delims=" %%p in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath 2^>nul`) do set "VS_PATH=%%p"
)
if defined VS_PATH (
  echo   + Visual Studio with the C++ desktop workload
) else if exist "%VSWHERE%" (
  echo   x Visual Studio is installed, but the C++ desktop workload is missing
  call :note "Add the 'Desktop development with C++' workload in the Visual Studio Installer."
) else (
  echo   x Visual Studio not found ^(needed for Windows desktop builds^)
  call :note "Install Visual Studio 2022 Community with the 'Desktop development with C++' workload:"
  call :note "  winget install --id Microsoft.VisualStudio.2022.Community"
)

rem Android is a large, interactive install, so this only ever reports on it.
set "ANDROID_FOUND="
where adb >nul 2>&1
if not errorlevel 1 set "ANDROID_FOUND=1"
if exist "%LOCALAPPDATA%\Android\Sdk" set "ANDROID_FOUND=1"
if defined ANDROID_FOUND (
  echo   + Android SDK found
) else (
  echo   ! Android SDK not found ^(only needed for Android builds^)
  call :note "For Android, install Android Studio from https://developer.android.com/studio"
  call :note "  then run: flutter doctor --android-licenses"
)

echo   ! sqflite has no Windows support, so the app builds but its database will not open.

rem -------------------------------------------------------------- project ----

if "%CHECK_ONLY%"=="1" (
  echo.
  echo ==^> Check complete
  goto notes
)

echo.
echo ==^> Setting up the project
pushd "%PROJECT_DIR%"
call flutter pub get
if errorlevel 1 (
  popd
  echo.
  echo error: flutter pub get failed
  exit /b 1
)
echo   + Dependencies installed

echo.
echo ==^> Running flutter doctor
call flutter doctor
popd

rem ---------------------------------------------------------------- notes ----

:notes
if not "%NOTE_COUNT%"=="0" (
  echo.
  echo ==^> Things to finish by hand
  for /l %%i in (1,1,%NOTE_COUNT%) do echo   - !NOTE_%%i!
)

echo.
echo ==^> Next steps
echo   flutter run -d windows        run the app on Windows desktop
echo   flutter run                   run on a connected device or emulator
echo   flutter test                  run the test suite
echo   flutter analyze               run static analysis
echo.
echo   Read CONTRIBUTING.md before opening a pull request.
exit /b 0

rem =============================================================== helpers ====

:need
where %~1 >nul 2>&1
if errorlevel 1 (
  echo   x %~1 is missing
  exit /b 1
)
echo   + %~1
exit /b 0

:note
set /a NOTE_COUNT+=1
set "NOTE_!NOTE_COUNT!=%~1"
exit /b 0

:install_flutter
set "ARCHIVE=flutter_windows_%FLUTTER_VERSION%-%FLUTTER_CHANNEL%.zip"
set "URL=https://storage.googleapis.com/flutter_infra_release/releases/%FLUTTER_CHANNEL%/windows/%ARCHIVE%"
set "TMPDIR=%TEMP%\flutter-install-%RANDOM%"
mkdir "%TMPDIR%" 2>nul
mkdir "%TMPDIR%\out" 2>nul
if not exist "%FLUTTER_INSTALL_DIR%" mkdir "%FLUTTER_INSTALL_DIR%" 2>nul

echo   ! Downloading Flutter %FLUTTER_VERSION% ^(about 1 GB, this takes a few minutes^)
curl -fL --progress-bar -o "%TMPDIR%\%ARCHIVE%" "%URL%"
if errorlevel 1 goto install_via_git

echo   ! Extracting to %FLUTTER_ROOT%
tar -xf "%TMPDIR%\%ARCHIVE%" -C "%TMPDIR%\out"
if errorlevel 1 goto install_via_git
if exist "%FLUTTER_ROOT%" rmdir /s /q "%FLUTTER_ROOT%"
move "%TMPDIR%\out\flutter" "%FLUTTER_ROOT%" >nul
if errorlevel 1 goto install_via_git
rmdir /s /q "%TMPDIR%" 2>nul
echo   + Installed Flutter %FLUTTER_VERSION%
exit /b 0

:install_via_git
rem The CDN archive is the fast path; a shallow clone of the tag is the
rem fallback if that URL ever moves or the download is blocked.
echo   ! Archive download failed, cloning the SDK at tag %FLUTTER_VERSION% instead
rmdir /s /q "%TMPDIR%" 2>nul
if exist "%FLUTTER_ROOT%" rmdir /s /q "%FLUTTER_ROOT%"
git clone --depth 1 --branch %FLUTTER_VERSION% https://github.com/flutter/flutter.git "%FLUTTER_ROOT%"
if errorlevel 1 (
  echo.
  echo error: could not install Flutter ^(download and clone both failed^)
  exit /b 1
)
echo   + Installed Flutter %FLUTTER_VERSION%
exit /b 0

:add_to_path
rem setx writes the user PATH for future terminals; it does not change this one.
set "USER_PATH="
for /f "skip=2 tokens=2,*" %%a in ('reg query HKCU\Environment /v PATH 2^>nul') do set "USER_PATH=%%b"
if defined USER_PATH (
  echo !USER_PATH! | find /i "!FLUTTER_BIN_DIR!" >nul
  if not errorlevel 1 (
    echo   + PATH already contains !FLUTTER_BIN_DIR!
    exit /b 0
  )
)
if "%ASSUME_YES%"=="0" (
  set "REPLY="
  set /p "REPLY=  ? Add Flutter to your user PATH? [y/N] "
  if /i not "!REPLY:~0,1!"=="y" (
    call :note "Add this to your PATH yourself: !FLUTTER_BIN_DIR!"
    exit /b 0
  )
)
if defined USER_PATH (
  setx PATH "!USER_PATH!;!FLUTTER_BIN_DIR!" >nul
) else (
  setx PATH "!FLUTTER_BIN_DIR!" >nul
)
echo   + Added !FLUTTER_BIN_DIR! to your user PATH
call :note "Open a new terminal to pick up the PATH change."
exit /b 0

:usage
echo Password Vault - development environment setup ^(Windows^).
echo.
echo   install.bat            install what's missing, then set the project up
echo   install.bat /check     report what's missing, install nothing
echo   install.bat /yes       don't prompt ^(for CI or unattended installs^)
echo   install.bat /help      usage
echo.
echo Installs the Flutter SDK pinned to the version CI uses, adds it to your
echo PATH for future terminals, then runs flutter pub get and flutter doctor.
echo Safe to re-run: anything already present is left alone.
exit /b 0
