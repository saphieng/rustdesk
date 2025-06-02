#!/bin/bash
echo "Building No-Auth RustDesk for Android..."

# Generate bridge
flutter_rust_bridge_codegen \
    --rust-input src/flutter_ffi.rs \
    --dart-output flutter/lib/generated_bridge.dart \
    --class-name RustdeskImpl

# Build Rust for Android
cargo ndk --target aarch64-linux-android --android-platform 21 -- build --release --features "flutter,no-auth"

# Copy libraries
mkdir -p flutter/android/app/src/main/jniLibs/arm64-v8a
cp target/aarch64-linux-android/release/libflutter_hbb.so flutter/android/app/src/main/jniLibs/arm64-v8a/

# Build Flutter
cd flutter
flutter pub get
cp assets/no_auth_config.json assets/custom_config.json
flutter build apk --release --dart-define=NO_AUTH=true

echo "No-Auth APK built!"