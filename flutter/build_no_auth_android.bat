@echo off
echo Building No-Auth RustDesk for Android...

REM Navigate to project root
cd /d "%~dp0.."

REM Check if config file exists, if not create it
if not exist "flutter_rust_bridge.yaml" (
    echo Creating flutter_rust_bridge.yaml config file...
    echo rust_input: "src/flutter_ffi.rs" > flutter_rust_bridge.yaml
    echo dart_output: "flutter/lib/generated_bridge.dart" >> flutter_rust_bridge.yaml
    echo rust_root: "." >> flutter_rust_bridge.yaml
    echo dart_root: "flutter" >> flutter_rust_bridge.yaml
    echo c_output: "flutter/ios/Classes/bridge_generated.h" >> flutter_rust_bridge.yaml
)

REM Generate bridge using config file
echo Generating Rust-Flutter bridge...
flutter_rust_bridge_codegen generate

if %ERRORLEVEL% neq 0 (
    echo Bridge generation failed! Trying with explicit parameters...
    flutter_rust_bridge_codegen generate ^
        --rust-input src/flutter_ffi.rs ^
        --dart-output flutter/lib/generated_bridge.dart
    
    if %ERRORLEVEL% neq 0 (
        echo Bridge generation failed!
        echo Checking if existing bridge files can be used...
        if exist "flutter\lib\generated_bridge.dart" (
            echo Using existing bridge file...
        ) else (
            echo No bridge file found. Please check your flutter_ffi.rs file exists.
            echo Location should be: src/flutter_ffi.rs
            pause
            exit /b 1
        )
    )
)

REM Ensure Android target is installed
echo Checking Android targets...
rustup target add aarch64-linux-android

REM Build Rust for Android
echo Building Rust for Android...
cargo ndk --target aarch64-linux-android --android-platform 21 -- build --release --features "flutter,no-auth"

if %ERRORLEVEL% neq 0 (
    echo Rust build failed!
    echo.
    echo Common issues:
    echo 1. Make sure ANDROID_NDK_HOME is set
    echo 2. Make sure cargo-ndk is installed: cargo install cargo-ndk
    echo 3. Check if the 'no-auth' feature exists in Cargo.toml
    echo.
    pause
    exit /b 1
)

REM Create directories and copy libraries
echo Copying native libraries...
if not exist "flutter\android\app\src\main\jniLibs\arm64-v8a" mkdir "flutter\android\app\src\main\jniLibs\arm64-v8a"

if exist "target\aarch64-linux-android\release\libflutter_hbb.so" (
    copy "target\aarch64-linux-android\release\libflutter_hbb.so" "flutter\android\app\src\main\jniLibs\arm64-v8a\"
) else (
    echo Error: libflutter_hbb.so not found!
    echo Expected location: target\aarch64-linux-android\release\libflutter_hbb.so
    pause
    exit /b 1
)

REM Build Flutter
echo Building Flutter APK...
cd flutter

REM Get dependencies
echo Getting Flutter dependencies...
flutter pub get

if %ERRORLEVEL% neq 0 (
    echo Flutter pub get failed!
    pause
    exit /b 1
)

REM Copy config if it exists
if exist "assets\no_auth_config.json" (
    echo Copying no-auth configuration...
    copy "assets\no_auth_config.json" "assets\custom_config.json"
) else (
    echo Warning: no_auth_config.json not found in assets folder
    echo Creating a basic config...
    mkdir assets 2>nul
    echo {"default_servers":{"id_server":"aws.vpn.saphi.engineer","relay_server":"aws.vpn.saphi.engineer","api_server":"https://aws.vpn.saphi.engineer","key":"m5sOjeGP7+4g61D8tF3DwrhO4hXJXFLD7UZ1jndWXv8="},"security":{"auto_accept_connections":true,"require_password":false,"approve_mode":"","verification_method":""},"behavior":{"auto_start_service":true,"start_on_boot":true,"hide_ui":false,"force_background":true}} > assets\custom_config.json
)

REM Build APK
echo Building release APK...
flutter build apk --release --dart-define=NO_AUTH=true

if %ERRORLEVEL% neq 0 (
    echo Flutter build failed!
    echo.
    echo Try running: flutter doctor
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo SUCCESS: No-Auth APK built!
echo ========================================
echo Location: build\app\outputs\flutter-apk\app-release.apk
echo.
echo To install: adb install build\app\outputs\flutter-apk\app-release.apk
echo.
pause