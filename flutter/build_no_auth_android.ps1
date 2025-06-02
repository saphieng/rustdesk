Write-Host "Building No-Auth RustDesk for Android..." -ForegroundColor Green

# Navigate to project root
Set-Location ".."

# Check if source file exists
if (-not (Test-Path "src/flutter_ffi.rs")) {
    Write-Host "Error: src/flutter_ffi.rs not found!" -ForegroundColor Red
    Write-Host "Make sure you're in the correct project directory." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Remove any existing problematic config file
if (Test-Path "flutter_rust_bridge.yaml") {
    Remove-Item "flutter_rust_bridge.yaml" -Force
    Write-Host "Removed problematic config file" -ForegroundColor Yellow
}

# Try to generate bridge with explicit parameters
Write-Host "Generating Rust-Flutter bridge..." -ForegroundColor Yellow

# Method 1: Try with explicit parameters
try {
    flutter_rust_bridge_codegen generate --rust-input src/flutter_ffi.rs --dart-output flutter/lib/generated_bridge.dart
    Write-Host "✓ Bridge generated successfully" -ForegroundColor Green
} catch {
    Write-Host "Method 1 failed, trying alternative..." -ForegroundColor Yellow
    
    # Method 2: Try newer syntax
    try {
        flutter_rust_bridge_codegen generate -r src/flutter_ffi.rs -d flutter/lib/generated_bridge.dart
    } catch {
        Write-Host "Method 2 failed, checking existing files..." -ForegroundColor Yellow
        
        # Check if bridge files already exist
        if (Test-Path "flutter/lib/generated_bridge.dart") {
            Write-Host "✓ Using existing bridge file" -ForegroundColor Green
        } elseif (Test-Path "flutter/lib/bridge_generated.dart") {
            Write-Host "✓ Using existing bridge file (bridge_generated.dart)" -ForegroundColor Green
        } else {
            Write-Host "❌ No bridge file found and generation failed" -ForegroundColor Red
            Write-Host "Let's try to continue without regenerating the bridge..." -ForegroundColor Yellow
        }
    }
}

# Ensure Android target is installed
Write-Host "Ensuring Android target is installed..." -ForegroundColor Yellow
rustup target add aarch64-linux-android | Out-Null

# Check if cargo-ndk is installed
Write-Host "Checking cargo-ndk..." -ForegroundColor Yellow
try {
    cargo ndk --version | Out-Null
    Write-Host "✓ cargo-ndk is installed" -ForegroundColor Green
} catch {
    Write-Host "Installing cargo-ndk..." -ForegroundColor Yellow
    cargo install cargo-ndk
}

# Build Rust for Android
Write-Host "Building Rust for Android..." -ForegroundColor Yellow

# Check if cargo-ndk is installed
Write-Host "Checking cargo-ndk..." -ForegroundColor Yellow
try {
    cargo ndk --version | Out-Null
    Write-Host "✓ cargo-ndk is installed" -ForegroundColor Green
} catch {
    Write-Host "Installing cargo-ndk..." -ForegroundColor Yellow
    cargo install cargo-ndk
}

# Build with cargo ndk (correct syntax)
Write-Host "Building Rust library..." -ForegroundColor Yellow

# Check if no-auth feature exists in Cargo.toml
$cargoContent = Get-Content "Cargo.toml" -Raw
if ($cargoContent -match "no-auth") {
    Write-Host "✓ Using no-auth feature" -ForegroundColor Green
    cargo ndk -t aarch64-linux-android build --release --features "flutter,no-auth"
} else {
    Write-Host "⚠ no-auth feature not found, building with flutter feature only" -ForegroundColor Yellow
    cargo ndk -t aarch64-linux-android build --release --features "flutter"
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Rust build failed!" -ForegroundColor Red
    Write-Host "Common solutions:" -ForegroundColor Yellow
    Write-Host "1. Set ANDROID_NDK_HOME environment variable"
    Write-Host "2. Install Android NDK through Android Studio"
    Write-Host "3. Check that aarch64-linux-android target is installed"
    Read-Host "Press Enter to exit"
    exit 1
}

# Create directories and copy libraries
Write-Host "Copying native libraries..." -ForegroundColor Yellow
$jniLibsPath = "flutter/android/app/src/main/jniLibs/arm64-v8a"
if (-not (Test-Path $jniLibsPath)) {
    New-Item -ItemType Directory -Path $jniLibsPath -Force | Out-Null
}

$soPath = "target/aarch64-linux-android/release/libflutter_hbb.so"
if (Test-Path $soPath) {
    Copy-Item $soPath "$jniLibsPath/" -Force
    Write-Host "✓ Library copied successfully" -ForegroundColor Green
} else {
    Write-Host "❌ libflutter_hbb.so not found at: $soPath" -ForegroundColor Red
    Write-Host "Checking what files were built..." -ForegroundColor Yellow
    Get-ChildItem "target/aarch64-linux-android/release/" -Name "*.so" | ForEach-Object {
        Write-Host "Found: $_" -ForegroundColor Cyan
    }
    Read-Host "Press Enter to exit"
    exit 1
}

# Build Flutter
Write-Host "Building Flutter APK..." -ForegroundColor Yellow
Set-Location "flutter"

# Get dependencies
Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter pub get failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Handle configuration
if (Test-Path "assets/no_auth_config.json") {
    Write-Host "✓ Copying no-auth configuration..." -ForegroundColor Green
    Copy-Item "assets/no_auth_config.json" "assets/custom_config.json" -Force
} else {
    Write-Host "⚠ no_auth_config.json not found, creating default..." -ForegroundColor Yellow
    if (-not (Test-Path "assets")) {
        New-Item -ItemType Directory -Path "assets" -Force | Out-Null
    }
    
    # Create a minimal config
    $defaultConfig = @{
        default_servers = @{
            id_server = "aws.vpn.saphi.engineer"
            relay_server = "aws.vpn.saphi.engineer"
            api_server = "https://aws.vpn.saphi.engineer"
            key = "m5sOjeGP7+4g61D8tF3DwrhO4hXJXFLD7UZ1jndWXv8="
        }
        security = @{
            auto_accept_connections = $true
            require_password = $false
            approve_mode = ""
            verification_method = ""
        }
    }
    
    $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content "assets/custom_config.json" -Encoding UTF8
}

# Build APK
Write-Host "Building release APK..." -ForegroundColor Yellow
flutter build apk --release --dart-define=NO_AUTH=true

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter build failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Run: flutter doctor"
    Write-Host "2. Run: flutter clean && flutter pub get"
    Write-Host "3. Check Android SDK installation"
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "🎉 SUCCESS: No-Auth APK built!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host "📱 APK Location: build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 To install on device:" -ForegroundColor Yellow
Write-Host "   adb install build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor White
Write-Host ""
Write-Host "📋 To install and run:" -ForegroundColor Yellow
Write-Host "   adb install build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor White
Write-Host "   adb shell am start -n com.carriez.flutter_hbb/.MainActivity" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to exit"