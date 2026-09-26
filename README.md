# MDPreview

<img src="Resources/AppIcon.png" alt="MDPreview" width="96" align="right">

English · [简体中文](README.zh-Hans.md)

A Markdown reader and light editor for macOS. Written with SwiftUI, AppKit and
`apple/swift-markdown`. No WebView.

Current version: v1.3.0 · Requires macOS 14+ · MIT license

---

## Features

- **Reading, editing and split view**, switched with `⌘R` / `⌘E` / `⇧⌘E`.
- **The reading view is one read-only text view.** You can select and copy across
  paragraphs and lists, search with `⌘F`, and use Look Up.
- **Rendering**: headings, bold / italic / strikethrough, inline code, `==highlight==`,
  links, block quotes, ordered / unordered / nested lists, task lists, tables,
  horizontal rules, images (local and remote).
- **Code highlighting** for Swift, Python, JavaScript / TypeScript, JSON, shell, Rust and Go.
- **Outline sidebar** built from H1–H6. Collapsible, click to jump, follows the scroll position.
- **Links**: `#heading` anchors jump within the document; relative `.md` links open in MDPreview.
- **Task lists**: tick a checkbox in the reading view and the source file is updated.
- **Editor** on TextKit 2 with line numbers. Markdown syntax coloring can be turned on in Settings.
- **Editing help**: `⌘B` / `⌘I` / `⌘K` / `⇧⌘K` for bold / italic / link / inline code; Return continues
  a list and exits it on an empty item; `Tab` / `⇧Tab` indent list items.
- **Images**: paste or drop an image and it is saved to an `assets/` folder next to the document, with a link inserted.
- **Settings** (`⌘,`): font, font size, line spacing, content width, light / dark / system theme.
  `⌘=` / `⌘-` / `⌘0` change the font size.
- **Export to PDF and print** (`⌥⌘P` / `⌘P`).
- **Reload on external change**: if another app changes the file, MDPreview reloads it.
  If you have unsaved edits, it asks first.
- **Finder previews**: Quick Look (space bar) and file thumbnails show the formatted document.
- **Languages**: English and Simplified Chinese, following the system setting.
- **Accessibility**: VoiceOver labels; stronger borders with Increase Contrast; no animations
  with Reduce Motion.
- **Document-based app**: multiple windows and tabs, `.md` file association, drag a file in to open it.
- Uses Liquid Glass on macOS 26+ and falls back to translucent materials on older systems.

## Versions

**v1.1**
Fixed Chinese input, task toggling, nested lists and `==` highlighting bugs; added unit tests and CI.

**v1.2**
PDF export and printing; reload on external change; all UI text moved to one place.

**v1.3 (current)**
1. The reading view is now a read-only `NSTextView`: selection works across blocks, `⌘F` works while reading.
2. Settings: font, size, line spacing, content width, theme, editor line numbers and syntax coloring.
3. UI, menus and messages use a String Catalog with `en` and `zh-Hans`.
4. Finder Quick Look preview and thumbnail extensions.
5. Accessibility: VoiceOver labels, Increase Contrast, Reduce Motion.
6. English and Chinese README.

The DMG is still ad-hoc signed and not notarized (that needs an Apple Developer account),
so the first launch needs right-click › Open.

**v1.4 (merged, not released) — editing**
Formatting shortcuts (`⌘B` / `⌘I` / `⌘K` / `⇧⌘K`); list continuation on Return and Tab indenting;
pasted or dropped images saved to `assets/`; bold no longer colored as italic in the source view.

**v1.5 (merged, not released) — performance, reload**
The reading view re-renders only the blocks that changed. On a 160 KB document, one edited character
takes about 30 ms instead of about 0.8 s. Reloading after an external change no longer marks the
document as edited, and a deleted file that comes back is watched again.

**Later**
Inline images, math, HTML blocks, more accurate code highlighting, more languages.

> Design notes and known gaps are in [PROJECT_SPEC.md](PROJECT_SPEC.md) (Chinese).

## Keyboard shortcuts

| Keys | Action |
| :-- | :-- |
| `⌘R` / `⌘E` / `⇧⌘E` | Reading / editing / split view |
| `⌘⌥S` | Show / hide outline |
| `⌘F` | Find (reading and editing view) |
| `⌘B` / `⌘I` / `⌘K` / `⇧⌘K` | Bold / italic / link / inline code (editing view) |
| `⌘=` / `⌘-` / `⌘0` | Larger / smaller / default font size |
| `⌘,` | Settings |
| `⌘P` / `⌥⌘P` | Print / export as PDF |
| `⌘N` / `⌘O` / `⌘S` / `⌘⇧S` | New / open / save / save as |
| `⌘W` / `⌘Q` | Close window / quit |

## Install

Download `MDPreview-<version>.dmg` (for example `MDPreview-1.3.0.dmg`) from [Releases](https://github.com/TonyT1226/MDPreview/releases)
and drag `MDPreview.app` into Applications. The first time, open it with right-click › Open
(the app is not notarized).

The Finder preview extensions become active after the app is in Applications and has been
opened once. If the space-bar preview still shows plain text, check that MDPreview is enabled
in System Settings › General › Login Items & Extensions › Quick Look.

## Build from source

You need full Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/TonyT1226/MDPreview.git
cd MDPreview

swift test                    # unit tests for the core library

brew install xcodegen
xcodegen generate
open MDPreview.xcodeproj       # run / preview / archive in Xcode

./package_app.sh              # or build the DMG from the command line
```

If `swift test` fails with `no such module 'Testing'`, SwiftUI previews don't load, or the app
starts without a window, `xcode-select` is probably pointing at the Command Line Tools:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for more.

## License

[MIT](LICENSE)
