import SwiftUI

/// 统一适配 macOS 26+ Liquid Glass 及 macOS 14/15 Material 材质的修饰器
public struct AdaptiveGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var isInteractive: Bool
    public var tint: Color?

    public init(cornerRadius: CGFloat = 12, isInteractive: Bool = false, tint: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        #if compiler(>=6.0)
        if #available(macOS 26, *) {
            // Liquid Glass 规范：优先使用系统原生 glassEffect 材质
            if let tint = tint {
                if isInteractive {
                    content.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    content.glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
                }
            } else {
                if isInteractive {
                    content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                } else {
                    content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                }
            }
        } else {
            fallbackGlass(content: content)
        }
        #else
        fallbackGlass(content: content)
        #endif
    }

    @ViewBuilder
    private func fallbackGlass(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

public extension View {
    func adaptiveGlass(cornerRadius: CGFloat = 12, isInteractive: Bool = false, tint: Color? = nil) -> some View {
        self.modifier(AdaptiveGlassModifier(cornerRadius: cornerRadius, isInteractive: isInteractive, tint: tint))
    }

    func glassPill() -> some View {
        self.adaptiveGlass(cornerRadius: 100, isInteractive: false)
    }
}
