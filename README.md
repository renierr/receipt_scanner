# Receipt Scanner

A standalone Flutter app for scanning long receipts and extracting their text.

On Android, the app keeps the camera open while you capture overlapping receipt sections. It detects and removes repeated lines between adjacent photos, then shows the combined OCR result. Images can also be imported from the device or desktop.

## Features

- Capture multiple receipt sections with the Android camera
- Visual overlap guide for consecutive photos
- Import JPG, JPEG, PNG, and WebP images
- On-device Latin-script OCR via Google ML Kit
- Automatic removal of repeated text between adjacent sections
- Copyable extracted text

## Requirements

- Flutter 3.47.2 or a compatible stable SDK
- Android SDK for Android builds
- Linux desktop development dependencies for Linux builds

Install dependencies before running or building the app:

```bash
flutter pub get
```

## Run

Run the app on a connected Android device or emulator:

```bash
flutter run
```

OCR is currently available on Android. On Linux, images can be imported but text extraction is not available.

## Build

Use `build.sh` from the project root. Release artifacts are copied to the ignored `dist/` directory.

Build a universal signed Android APK:

```bash
./build.sh apk
```

Build a smaller signed APK for 64-bit ARM Android devices:

```bash
./build.sh apks1
```

Build the Linux desktop bundle:

```bash
./build.sh linux
```

Clean Flutter outputs and release artifacts:

```bash
./build.sh clean
```

## Android Release Signing

Release builds use `android/key.properties`. This file and the referenced keystore are intentionally excluded from Git. Create it locally with the following properties:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=/absolute/path/to/upload-keystore.jks
```

Without this file, the Android configuration falls back to the debug key. Do not publish a production APK signed with the debug key.

## Linux Installation

After `./build.sh linux`, install the generated Linux bundle locally:

```bash
./install.sh
```

This installs the app into `~/.local/share/ReceiptScanner`, creates the `receipt-scanner` command in `~/.local/bin`, and adds a desktop launcher.

Remove the local installation with:

```bash
./install.sh --uninstall
```

## Privacy

Text recognition runs on-device through Google ML Kit. Captured images and extracted text stay on the device unless you share them yourself.
