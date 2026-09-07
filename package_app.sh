#!/bin/bash
set -euo pipefail

# 打包 MDPreview.app 与 MDPreview.dmg
# 依赖：Xcode（完整版）、xcodegen
#
# 发布签名/公证（需要 Apple Developer 账号，本脚本默认走 ad-hoc 签名）：
#   1. 在 project.yml 里把 DEVELOPMENT_TEAM 设为你的 Team ID，CODE_SIGN_STYLE 设为 Manual/Automatic
#   2. 归档后执行：
#        xcrun notarytool submit MDPreview.dmg --keychain-profile "AC_PASSWORD" --wait
#        xcrun stapler staple MDPreview.dmg

APP_NAME="MDPreview"
BUILD_DIR=".xcbuild"
EXPORT_DIR="dist"

echo "🧩 生成 Xcode 工程..."
command -v xcodegen >/dev/null || { echo "❌ 需要 xcodegen：brew install xcodegen"; exit 1; }
xcodegen generate

echo "📦 归档 Release 版本..."
rm -rf "$BUILD_DIR" "$EXPORT_DIR"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -archivePath "$BUILD_DIR/${APP_NAME}.xcarchive" \
  archive

APP_PATH="$BUILD_DIR/${APP_NAME}.xcarchive/Products/Applications/${APP_NAME}.app"
[ -d "$APP_PATH" ] || { echo "❌ 未找到归档产物 $APP_PATH"; exit 1; }

mkdir -p "$EXPORT_DIR"
cp -R "$APP_PATH" "$EXPORT_DIR/"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$EXPORT_DIR/${APP_NAME}.app/Contents/Info.plist")
echo "🔖 版本：$VERSION"

echo "💿 生成 DMG..."
DMG_STAGING=$(mktemp -d)
cp -R "$EXPORT_DIR/${APP_NAME}.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
rm -f "${APP_NAME}.dmg"
hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "$DMG_STAGING" -ov -format UDZO "${APP_NAME}.dmg"
rm -rf "$DMG_STAGING"

echo "✅ 完成：$(pwd)/${APP_NAME}.dmg"
echo "   （DMG 不进 git，作为 GitHub Release 附件分发）"
