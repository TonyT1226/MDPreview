#!/bin/bash
set -euo pipefail

# 归档并导出 Mac App Store 用的安装包（.pkg）；加 --upload 时直接上传到 App Store Connect。
# 依赖：完整版 Xcode、xcodegen；Xcode › Settings › Accounts 里登录了开发者账号（自动签名要用）。
#
#   ./archive_app_store.sh              只导出，产物在仓库根目录的 Markit-<版本号>-<构建号>.pkg
#   ./archive_app_store.sh --upload     导出后上传
#   BUILD_NUMBER=2 ./archive_app_store.sh --upload    同一版本号再传一次时，构建号要比上次大
#
# 归档和中间产物都放在 /tmp：仓库在 iCloud 同步目录里，产物带扩展属性会让 codesign 失败（见 package_app.sh）。

APP_NAME="Markit"          # 产物名（.app / .dmg / .pkg）
PROJECT_NAME="MDPreview"   # 工程与 scheme 名，没有跟着改
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
STAGE="$(mktemp -d /tmp/mdp_archive.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

UPLOAD=0
[ "${1:-}" = "--upload" ] && UPLOAD=1

command -v xcodegen >/dev/null || { echo "❌ 需要 xcodegen：brew install xcodegen"; exit 1; }

echo "🧩 生成 Xcode 工程..."
( cd "$REPO_ROOT" && xcodegen generate )

TEAM_ID=$(xcodebuild -project "$REPO_ROOT/${PROJECT_NAME}.xcodeproj" -scheme "$PROJECT_NAME" -showBuildSettings 2>/dev/null \
  | awk '$1 == "DEVELOPMENT_TEAM" { print $3; exit }')
[ -n "$TEAM_ID" ] || { echo "❌ project.yml 里没有 DEVELOPMENT_TEAM"; exit 1; }

BUILD_ARGS=()
[ -n "${BUILD_NUMBER:-}" ] && BUILD_ARGS+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")

echo "📦 归档（Release，自动签名）..."
ARCHIVE="$STAGE/${APP_NAME}.xcarchive"
xcodebuild \
  -project "$REPO_ROOT/${PROJECT_NAME}.xcodeproj" \
  -scheme "$PROJECT_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$STAGE/derived" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -quiet \
  ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"} \
  archive

INFO="$ARCHIVE/Products/Applications/${APP_NAME}.app/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO")
echo "🔖 版本：${VERSION}（${BUILD}）"

cat > "$STAGE/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
PLIST

echo "📤 导出 .pkg..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$STAGE/export" \
  -exportOptionsPlist "$STAGE/ExportOptions.plist" \
  -allowProvisioningUpdates

PKG="$REPO_ROOT/${APP_NAME}-${VERSION}-${BUILD}.pkg"
cp "$STAGE/export/${APP_NAME}.pkg" "$PKG"
echo "✅ 导出：$PKG"

if [ "$UPLOAD" = 1 ]; then
  echo "🚀 上传到 App Store Connect..."
  /usr/libexec/PlistBuddy -c "Set :destination upload" "$STAGE/ExportOptions.plist"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$STAGE/upload" \
    -exportOptionsPlist "$STAGE/ExportOptions.plist" \
    -allowProvisioningUpdates
  echo "✅ 已上传。几分钟后在 App Store Connect › TestFlight 里能看到这个构建。"
else
  echo "   （.pkg 不进 git。上传：./archive_app_store.sh --upload，或用 Transporter 拖入这个文件）"
fi
