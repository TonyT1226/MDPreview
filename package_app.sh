#!/bin/bash
set -euo pipefail

# 打包 Markit.app 与 Markit-<版本号>.dmg
# 依赖：完整版 Xcode、xcodegen
#
# 说明：仓库通常放在 iCloud / 文件提供程序同步的目录里，构建产物会被打上
# com.apple.FinderInfo / com.apple.fileprovider.* 扩展属性，导致 codesign 报
# “resource fork, Finder information, or similar detritus not allowed”。
# 所以这里先不签名构建，再把产物 ditto 到 /tmp 下清干净、ad-hoc 签名、组 DMG。
#
# 签名：钥匙串里有「Developer ID Application」证书就用它（带时间戳），没有就 ad-hoc。
# 公证：用 Developer ID 签名、且存过 notarytool 凭据时自动提交并 staple。凭据只需存一次：
#     xcrun notarytool store-credentials MDPreview-notary --apple-id <Apple ID> --team-id <Team ID>
#   （会要求输入 App 专用密码，在 account.apple.com › 登录与安全 里生成）
#   凭据名可用环境变量 NOTARY_PROFILE 改。
#   ADHOC=1 ./package_app.sh 强制 ad-hoc 签名（本地试包用，不公证）。
# Mac App Store 的包走另一个脚本：archive_app_store.sh

APP_NAME="Markit"          # 产物名（.app / .dmg / .pkg）
PROJECT_NAME="MDPreview"   # 工程与 scheme 名，没有跟着改
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
  -project "$REPO_ROOT/${PROJECT_NAME}.xcodeproj" \
  -scheme "$PROJECT_NAME" \
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

NOTARY_PROFILE="${NOTARY_PROFILE:-MDPreview-notary}"
if [ "${ADHOC:-0}" = 1 ]; then
  IDENTITY=""
else
  IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
fi
if [ -n "$IDENTITY" ]; then
  echo "🔏 用 $IDENTITY 签名..."
  SIGN_ARGS=(--sign "$IDENTITY" --timestamp)
else
  echo "🔏 ad-hoc 签名（没有 Developer ID 证书，或设了 ADHOC=1）..."
  SIGN_ARGS=(--sign - --timestamp=none)
fi
# Quick Look 扩展必须带沙盒 entitlements 签名，否则系统不加载；--deep 不会带上 entitlements，
# 所以先逐个签扩展，再签外层 App（不用 --deep）。App 本身也开沙盒（v1.6 起，与 App Store 版同一份构建）。
PLUGINS="$STAGE/${APP_NAME}.app/Contents/PlugIns"
codesign --force "${SIGN_ARGS[@]}" --options runtime \
  --entitlements "$REPO_ROOT/Sources/QuickLookPreview/QuickLookPreview.entitlements" \
  "$PLUGINS/MDPreviewQuickLook.appex"
codesign --force "${SIGN_ARGS[@]}" --options runtime \
  --entitlements "$REPO_ROOT/Sources/QuickLookThumbnail/QuickLookThumbnail.entitlements" \
  "$PLUGINS/MDPreviewThumbnail.appex"
codesign --force "${SIGN_ARGS[@]}" --options runtime \
  --entitlements "$REPO_ROOT/Sources/App/MDPreview.entitlements" \
  "$STAGE/${APP_NAME}.app"
codesign --verify --deep --strict "$STAGE/${APP_NAME}.app"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$STAGE/${APP_NAME}.app/Contents/Info.plist")
echo "🔖 版本：$VERSION"

echo "💿 生成 DMG..."
DMG_SRC="$STAGE/dmg"
mkdir -p "$DMG_SRC"
ditto "$STAGE/${APP_NAME}.app" "$DMG_SRC/${APP_NAME}.app"
ln -s /Applications "$DMG_SRC/Applications"
DMG="$REPO_ROOT/${APP_NAME}-${VERSION}.dmg"
rm -f "$DMG"
hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "$DMG_SRC" -ov -format UDZO "$DMG"

if [ -n "$IDENTITY" ]; then
  codesign --force "${SIGN_ARGS[@]}" "$DMG"
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "📮 提交公证（一般几分钟）..."
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature -v "$DMG"
  else
    echo "⚠️  没有 notarytool 凭据「$NOTARY_PROFILE」，跳过公证（见脚本开头的说明）"
  fi
fi

echo
echo "✅ 完成：$DMG"
shasum -a 256 "$DMG"
echo "   （DMG 不进 git，作为 GitHub Release 附件分发）"
