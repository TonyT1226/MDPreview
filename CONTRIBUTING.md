# 开发指南

## 环境要求

- **完整版 Xcode 16+**（不是 Command Line Tools）。首次请确认：
  ```bash
  xcode-select -p            # 应指向 /Applications/Xcode.app/Contents/Developer
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```
  > SwiftUI 预览、`swift test`、`xcodebuild` 都依赖完整 Xcode；只装 CLT 会出现
  > “no such module 'Testing'”、预览无法加载、`DocumentGroup` 不开窗等问题。
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`

## 工程结构

| 路径 | 说明 |
| :--- | :--- |
| `Sources/MDPreviewCore/` | 解析引擎 + 全部 UI 组件（SwiftPM 库，含 SwiftUI 预览） |
| `Sources/App/` | 极薄的 App 外壳：`@main` 入口、`Info.plist`、`Assets.xcassets` |
| `Tests/MDPreviewCoreTests/` | swift-testing 单测 |
| `project.yml` | XcodeGen 配置；`MDPreview.xcodeproj` 由它生成 |
| `Package.swift` | 依赖定义（`swift-markdown` 用 `revision:` 精确锁定；`Package.resolved` 不入库） |

## 常用命令

```bash
# 只编译解析核心 / 跑单测
swift build
swift test

# 生成并打开 App 工程（预览、运行、归档都在这里）
xcodegen generate
open MDPreview.xcodeproj

# 命令行构建 App
xcodebuild -project MDPreview.xcodeproj -scheme MDPreview -configuration Debug \
  -derivedDataPath .xcbuild CODE_SIGNING_ALLOWED=NO build

# 打包 DMG（Release）
./package_app.sh
```

修改了 `Sources/App/` 下的文件结构后需重新 `xcodegen generate`。生成的
`MDPreview.xcodeproj` 已提交仓库，普通开发无需装 XcodeGen 即可直接打开。

## 升级 swift-markdown

上游只发布开发快照 tag，没有 semver。升级步骤：

1. 修改 `Package.swift` 里的 `swiftMarkdownRevision`
2. `swift package update`
3. `swift test` 确认无回归

## 发布

DMG 不进 git，作为 GitHub Release 附件分发。正式分发需 Developer ID 签名 +
`xcrun notarytool` 公证，见 `package_app.sh` 顶部注释。
