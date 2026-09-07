#!/bin/bash
set -euo pipefail

# 打包 MDPreview.app 与 MDPreview.dmg
# 依赖：完整版 Xcode、xcodegen
#
# 说明：仓库通常放在 iCloud / 文件提供程序同步的目录里，构建产物会被打上
# com.apple.FinderInfo / com.apple.fileprovider.* 扩展属性，导致 codesign 报
# “resource fork, Finder information, or similar detritus not allowed”。
# 所以这里先不签名构建，再把产物 ditto 到 /tmp 下清干净、ad-hoc 签名、组 DMG。
#
# 正式分发（需要 Apple Developer 账号）：
#   在 project.yml 设 DEVELOPMENT_TEAM，改用 Developer ID 签名后：
#     xcrun notarytool submit MDPreview.dmg --keychain-profile "AC_PASSWORD" --wait
#     xcrun stapler staple MDPreview.dmg

APP_NAME="MDPreview"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
DERIVED="$REPO_ROOT/.xcbuild"
STAGE="$(mktemp -d /tmp/mdp_pkg.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

command -v xcodegen >/dev/null || { echo "❌ 需要 xcodegen：brew install xcodegen"; exit 1; }

echo "🧩 生成 Xcode 工程..."
( cd "$REPO_ROOT" && xcodegen generate )

echo "📦 构建 Release（暂不签名）..."
rm -rf "$DERIVED"
xcodebuild \
  -project "$REPO_ROOT/${APP_NAME}.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build

BUILT="$DERIVED/Build/Products/Release/${APP_NAME}.app"
[ -d "$BUILT" ] || { echo "❌ 未找到构建产物 $BUILT"; exit 1; }

echo "🧹 转移到 $STAGE 并清理扩展属性..."
ditto "$BUILT" "$STAGE/${APP_NAME}.app"
xattr -cr "$STAGE/${APP_NAME}.app"
find "$STAGE/${APP_NAME}.app" -exec xattr -c {} \; 2>/dev/null || true

echo "🔏 ad-hoc 签名..."
codesign --force --deep --sign - --timestamp=none "$STAGE/${APP_NAME}.app"
codesign --verify --deep --strict "$STAGE/${APP_NAME}.app"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$STAGE/${APP_NAME}.app/Contents/Info.plist")
echo "🔖 版本：$VERSION"

echo "💿 生成 DMG..."
DMG_SRC="$STAGE/dmg"
mkdir -p "$DMG_SRC"
ditto "$STAGE/${APP_NAME}.app" "$DMG_SRC/${APP_NAME}.app"
ln -s /Applications "$DMG_SRC/Applications"
rm -f "$REPO_ROOT/${APP_NAME}.dmg"
hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "$DMG_SRC" -ov -format UDZO "$REPO_ROOT/${APP_NAME}.dmg"

echo
echo "✅ 完成：$REPO_ROOT/${APP_NAME}.dmg"
shasum -a 256 "$REPO_ROOT/${APP_NAME}.dmg"
echo "   （DMG 不进 git，作为 GitHub Release 附件分发）"
