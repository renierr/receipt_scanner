#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ReceiptScanner"
EXE_NAME="receipt_scanner"
SRC="dist/${APP_NAME}-linux"
DEST="$HOME/.local/share/$APP_NAME"
BIN="$HOME/.local/bin/receipt-scanner"
DESKTOP="$HOME/.local/share/applications/receipt-scanner.desktop"

if [ "${1:-}" = "--uninstall" ]; then
  rm -rf "$DEST"
  rm -f "$BIN" "$DESKTOP"
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  exit 0
fi

[ -x "$SRC/$EXE_NAME" ] || { printf 'Build missing: %s\n' "$SRC/$EXE_NAME"; exit 1; }
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")" "$(dirname "$BIN")" "$(dirname "$DESKTOP")"
cp -r "$SRC" "$DEST"
ln -sf "$DEST/$EXE_NAME" "$BIN"
cat > "$DESKTOP" <<EOF
[Desktop Entry]
Name=Receipt Scanner
Comment=Scan receipts and extract text
Exec=$DEST/$EXE_NAME
Icon=accessories-text-editor
Terminal=false
Type=Application
Categories=Utility;
EOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
