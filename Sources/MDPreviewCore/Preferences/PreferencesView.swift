import SwiftUI

/// 偏好设置窗口（App 的 `Settings` 场景）
public struct PreferencesView: View {
    @AppStorage(PrefKey.fontSize) private var fontSize = Double(ReaderStyle.default.fontSize)
    @AppStorage(PrefKey.lineHeight) private var lineHeight = Double(ReaderStyle.default.lineHeight)
    @AppStorage(PrefKey.contentWidth) private var contentWidth = Double(ReaderStyle.default.contentWidth)
    @AppStorage(PrefKey.fontFamily) private var fontFamily = ReaderStyle.default.fontFamily.rawValue
    @AppStorage(PrefKey.theme) private var theme = AppTheme.system.rawValue
    @AppStorage(PrefKey.editorHighlighting) private var editorHighlighting = false

    public init() {}

    public var body: some View {
        Form {
            Section(L.prefsReading) {
                Picker(L.prefsFont, selection: $fontFamily) {
                    ForEach(ReaderFontFamily.allCases) { Text($0.title).tag($0.rawValue) }
                }

                LabeledContent(L.prefsFontSize) {
                    HStack {
                        Slider(value: $fontSize,
                               in: Double(ReaderStyle.fontSizeRange.lowerBound)...Double(ReaderStyle.fontSizeRange.upperBound),
                               step: 1)
                        Text(L.pointValue(Int(fontSize)))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                .accessibilityValue(L.pointValue(Int(fontSize)))

                LabeledContent(L.prefsLineHeight) {
                    HStack {
                        Slider(value: $lineHeight,
                               in: Double(ReaderStyle.lineHeightRange.lowerBound)...Double(ReaderStyle.lineHeightRange.upperBound),
                               step: 0.05)
                        Text(String(format: "%.2f", lineHeight))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                LabeledContent(L.prefsContentWidth) {
                    HStack {
                        Slider(value: $contentWidth,
                               in: Double(ReaderStyle.contentWidthRange.lowerBound)...Double(ReaderStyle.contentWidthRange.upperBound),
                               step: 20)
                        Text(L.pointValue(Int(contentWidth)))
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }

            Section(L.prefsAppearance) {
                Picker(L.prefsTheme, selection: $theme) {
                    ForEach(AppTheme.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section(L.prefsEditor) {
                Toggle(L.prefsSourceHighlighting, isOn: $editorHighlighting)
                Text(L.prefsSourceHighlightingHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button(L.prefsRestoreDefaults) { restoreDefaults() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func restoreDefaults() {
        let d = ReaderStyle.default
        fontSize = Double(d.fontSize)
        lineHeight = Double(d.lineHeight)
        contentWidth = Double(d.contentWidth)
        fontFamily = d.fontFamily.rawValue
        theme = AppTheme.system.rawValue
        editorHighlighting = false
    }
}
