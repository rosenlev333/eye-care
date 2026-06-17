#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

APP_NAME="Для глаз"
EXE="EyeCare"

echo "==> Building release binary…"
swift build -c release

BIN="$DIR/.build/release/$EXE"
if [[ ! -f "$BIN" ]]; then
  echo "Сборка не нашла бинарь: $BIN" >&2
  exit 1
fi

APP="$DIR/$APP_NAME.app"
echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXE"
cp "$DIR/Info.plist" "$APP/Contents/Info.plist"

# Иконка приложения (если положишь AppIcon.icns рядом — подхватится)
if [[ -f "$DIR/AppIcon.icns" ]]; then
  cp "$DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> Ad-hoc codesign…"
codesign --force --deep --sign - "$APP"

echo ""
echo "Готово: $APP"
echo "Запуск:  open \"$APP\""
echo "В /Applications:  cp -R \"$APP\" /Applications/ && xattr -dr com.apple.quarantine \"/Applications/$APP_NAME.app\""
