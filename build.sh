#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ReceiptScanner"
DIST_DIR="dist"
VERSION=$(grep '^version: ' pubspec.yaml | cut -d' ' -f2 | tr '+' '_')

case "${1:-}" in
  apk)
    flutter build apk --release
    mkdir -p "$DIST_DIR"
    cp build/app/outputs/flutter-apk/app-release.apk "$DIST_DIR/${APP_NAME}-v${VERSION}-release.apk"
    ;;
  apks1)
    flutter build apk --release --target-platform android-arm64 --split-per-abi
    mkdir -p "$DIST_DIR"
    cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$DIST_DIR/${APP_NAME}-v${VERSION}-arm64-v8a-release.apk"
    ;;
  linux)
    flutter build linux --release
    rm -rf "$DIST_DIR/${APP_NAME}-linux"
    mkdir -p "$DIST_DIR/${APP_NAME}-linux"
    cp -r build/linux/x64/release/bundle/. "$DIST_DIR/${APP_NAME}-linux/"
    cp install.sh "$DIST_DIR/${APP_NAME}-linux/"
    ;;
  clean)
    flutter clean
    rm -rf "$DIST_DIR"
    ;;
  *)
    printf 'Usage: ./build.sh {apk|apks1|linux|clean}\n'
    exit 1
    ;;
esac
