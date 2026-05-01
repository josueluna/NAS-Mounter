#!/bin/bash
# ─────────────────────────────────────────────────────────────
# NAS-Mountie — DMG creator script
# Run this from the root of your project after archiving the app.
#
# Requirements:
#   brew install create-dmg
#
# Usage:
#   chmod +x create-dmg.sh
#   ./create-dmg.sh
# ─────────────────────────────────────────────────────────────

set -e

APP_NAME="NAS-Mountie"
VERSION="0.2.0"
DMG_NAME="${APP_NAME}-${VERSION}-beta"
APP_PATH="./NAS-Mountie/NAS-Mountie/NAS-Mountie 2026-04-17 16-26-57/NAS-Mountie.app"
DMG_DIR="./dmg-output"
BACKGROUND="./dmg-assets/dmg-background.png"
ICON_SIZE=128
WINDOW_W=660
WINDOW_H=400

mkdir -p "$DMG_DIR"

echo "→ Creating DMG: ${DMG_NAME}.dmg"

create-dmg \
  --volname "$APP_NAME" \
  --volicon "./dmg-assets/nas-mountie.icns" \
  --background "$BACKGROUND" \
  --window-pos 200 120 \
  --window-size $WINDOW_W $WINDOW_H \
  --icon-size $ICON_SIZE \
  --icon "${APP_NAME}.app" 185 195 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 475 195 \
  --no-internet-enable \
  "${DMG_DIR}/${DMG_NAME}.dmg" \
  "$APP_PATH"

echo "✓ Done: ${DMG_DIR}/${DMG_NAME}.dmg"
