#!/bin/bash
set -e

echo "🚀 开始打包 MDPreview.app 与 MDPreview.dmg (v1.0.0)..."

# 1. 编译 Release 优化版本
echo "📦 正在编译 Release 二进制文件..."
swift build -c release

# 2. 准备 App Bundle 目录结构
APP_NAME="MDPreview"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 3. 复制可执行文件与资源
echo "📄 复制二进制文件与图标资源..."
cp ".build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
cp "Resources/AppIcon.png" "${RESOURCES_DIR}/AppIcon.png"

# 4. 生成 Info.plist (包含 Finder .md 文件类型关联与 UTType 配置)
echo "📝 生成 Info.plist 配置..."
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MDPreview</string>
    <key>CFBundleDisplayName</key>
    <string>MDPreview</string>
    <key>CFBundleIdentifier</key>
    <string>com.mdpreview.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleExecutable</key>
    <string>MDPreview</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
                <string>public.markdown</string>
                <string>public.plain-text</string>
                <string>public.text</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
                <string>markdown</string>
                <string>mdown</string>
                <string>mkdn</string>
                <string>txt</string>
            </array>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>net.daringfireball.markdown</string>
            <key>UTTypeDescription</key>
            <string>Markdown Document</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>md</string>
                    <string>markdown</string>
                    <string>mdown</string>
                    <string>mkdn</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

# 5. 本地代码签名 (Ad-hoc Code Signing)
echo "🔏 进行本地代码签名..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# 6. 生成标准 DMG 安装包
echo "💿 正在生成 MDPreview.dmg 安装包..."
DMG_STAGING=$(mktemp -d)
cp -R "${APP_BUNDLE}" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
rm -f "${APP_NAME}.dmg"
hdiutil create -volname "${APP_NAME}" -srcfolder "$DMG_STAGING" -ov -format UDZO "${APP_NAME}.dmg"
rm -rf "$DMG_STAGING"

# 7. 刷新 LaunchServices 注册
if [ -f "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP_BUNDLE}" || true
fi

echo "✅ 打包完成！"
echo "📂 生成的应用程序: $(pwd)/${APP_BUNDLE}"
echo "💿 生成的 DMG 安装包: $(pwd)/${APP_NAME}.dmg"
