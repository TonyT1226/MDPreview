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
| `Sources/MDPreviewCore/` | 解析、排版、全部 UI 组件（SwiftPM 库） |
| `Sources/MDPreviewCore/Resources/` | `Strings.swift`（界面文字入口 `L`）+ `Localizable.xcstrings` |
| `Sources/App/` | 很薄的 App 外壳：`@main` 入口、`Info.plist`、`InfoPlist.xcstrings`、`Assets.xcassets` |
| `Sources/QuickLookPreview/` | Finder 空格预览扩展 |
| `Sources/QuickLookThumbnail/` | Finder 缩略图扩展 |
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

如果仓库放在 iCloud 同步的目录里，`swift test` 会因为扩展属性签不了测试包，
把构建目录放到别处即可：`swift test --scratch-path /tmp/mdp-spm`。

修改了 `Sources/` 下的文件结构后需重新 `xcodegen generate`。生成的
`MDPreview.xcodeproj` 已提交仓库，普通开发无需装 XcodeGen 即可直接打开。

## 界面文字与翻译

- 代码里只用 `L.xxx`，不要写字面量。`Strings.swift` 里每个属性的键就是属性名，英文写在 `defaultValue`。
- 新增一条：在 `Strings.swift` 加属性，再在 `Localizable.xcstrings` 里补 `en` 和 `zh-Hans`
  （Xcode 里直接编辑，或手改 JSON）。
- 测试会检查：catalog 里每个键都有两种语言；`Sources/` 里没有含中日韩字符的字符串字面量。

## 手动检查用的测试

两组测试平时跳过，设置环境变量才运行：

```bash
# 把示例文档的阅读区（浅色 / 深色）、编辑器行号、Quick Look 缩略图渲染成 PNG
MDP_SNAPSHOT_DIR=/tmp/snap swift test --filter SnapshotTests

# 大文档解析 / 排版耗时
MDP_PERF=1 swift test -c release --filter PerfProbe
```

## 升级 swift-markdown

上游只发布开发快照 tag，没有 semver。升级步骤：

1. 修改 `Package.swift` 里的 `swiftMarkdownRevision`
2. `swift package update`
3. `swift test` 确认无回归

## 发布

DMG 不进 git，作为 GitHub Release 附件分发。`package_app.sh` 先给两个 Quick Look 扩展
带 entitlements 签名（沙盒是扩展加载的前提），再签外层 App。正式分发需 Developer ID 签名 +
`xcrun notarytool` 公证，见 `package_app.sh` 顶部注释。
