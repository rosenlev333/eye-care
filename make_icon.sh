#!/bin/bash
# Полная регенерация иконки приложения: render master PNG → iconset → AppIcon.icns
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "==> Render master PNG…"
swift make_icon.swift   # создаёт icon_1024.png (фактически 2048² на Retina)

echo "==> Build iconset…"
rm -rf AppIcon.iconset
mkdir AppIcon.iconset
specs=("16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" \
       "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" "512:icon_256x256@2x" \
       "512:icon_512x512" "1024:icon_512x512@2x")
for s in "${specs[@]}"; do
  px="${s%%:*}"; name="${s##*:}"
  sips -z "$px" "$px" icon_1024.png --out "AppIcon.iconset/$name.png" >/dev/null
done

echo "==> Pack AppIcon.icns…"
iconutil -c icns AppIcon.iconset -o AppIcon.icns
rm -rf AppIcon.iconset icon_1024.png

echo "Готово: $DIR/AppIcon.icns"
echo "Пересобери приложение: ./build_app.sh"
