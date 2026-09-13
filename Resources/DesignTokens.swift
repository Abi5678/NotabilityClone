//
//  DesignTokens.swift
//  NotabilityClone
//
//  Minimalist Monochrome Design System
//  Pure black & white, sharp corners, dramatic typography
//

import SwiftUI

// MARK: - Color Palette

public struct MonochromeColors {
    // Core
    static let background = Color(hex: "#FFFFFF")
    static let foreground = Color(hex: "#000000")
    
    // Muted
    static let muted = Color(hex: "#F5F5F5")
    static let mutedForeground = Color(hex: "#525252")
    
    // Borders
    static let border = Color(hex: "#000000")
    static let borderLight = Color(hex: "#E5E5E5")
    
    // Cards
    static let card = Color(hex: "#FFFFFF")
    static let cardForeground = Color(hex: "#000000")
    
    // Focus
    static let ring = Color(hex: "#000000")
}

// MARK: - Typography

public struct MonochromeTypography {
    // Font families - simplified for macOS
    // Note: Custom fonts would need to be loaded separately
    // Using system fonts for now
    
    // Type scale (dramatic range)
    static func xs() -> Font { .system(size: 12, weight: .regular) }
    static func sm() -> Font { .system(size: 14, weight: .regular) }
    static func `base`() -> Font { .system(size: 16, weight: .regular) }
    static func lg() -> Font { .system(size: 18, weight: .regular) }
    static func xl() -> Font { .system(size: 20, weight: .regular) }
    static func xl2() -> Font { .system(size: 24, weight: .regular) }
    static func xl3() -> Font { .system(size: 32, weight: .medium) }
    static func xl4() -> Font { .system(size: 40, weight: .medium) }
    static func xl5() -> Font { .system(size: 56, weight: .bold) }
    static func xl6() -> Font { .system(size: 72, weight: .bold) }
    static func xl7() -> Font { .system(size: 96, weight: .bold) }
    static func xl8() -> Font { .system(size: 128, weight: .bold) }
    static func xl9() -> Font { .system(size: 160, weight: .bold) }
    
    // Mono for time displays
    static func mono() -> Font { .system(size: 14, weight: .medium, design: .monospaced) }
    
    // Tracking
    static let trackingTighter: CGFloat = -0.05
    static let trackingTight: CGFloat = -0.025
    static let trackingNormal: CGFloat = 0
    static let trackingWide: CGFloat = 0.1
}

struct FontFamily {
    let name: String
    let fallback: Font
    
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .custom(name, fixedSize: size)
    }
}

// MARK: - Border Weights

public struct MonochromeBorders {
    static let hairline = 1.0
    static let thin = 1.0
    static let medium = 2.0
    static let thick = 4.0
    static let ultra = 8.0
}

// MARK: - Spacing

public struct MonochromeSpacing {
    static let sectionVertical: CGFloat = 160  // py-40
    static let containerPadding: CGFloat = 48  // px-12
    static let cardPadding: CGFloat = 32       // p-8
}

// MARK: - View Modifiers

struct MonochromeCardStyle: ViewModifier {
    var inverted: Bool = false
    var borderless: Bool = false
    
    func body(content: Content) -> some View {
        content
            .padding(MonochromeSpacing.cardPadding)
            .background(inverted ? MonochromeColors.foreground : MonochromeColors.card)
            .foregroundColor(inverted ? MonochromeColors.background : MonochromeColors.cardForeground)
            .overlay(
                !borderless ?
                RoundedRectangle(cornerRadius: 0)
                    .stroke(MonochromeColors.border, lineWidth: MonochromeBorders.thin)
                : nil
            )
    }
}

struct HorizontalRule: View {
    var weight: CGFloat = MonochromeBorders.thick
    
    var body: some View {
        Rectangle()
            .fill(MonochromeColors.foreground)
            .frame(height: weight)
    }
}

struct TexturedBackground: ViewModifier {
    var pattern: TexturePattern = .horizontalLines
    var inverted: Bool = false
    
    enum TexturePattern {
        case horizontalLines
        case grid
        case diagonal
        case noise
        case verticalLines
        case radial
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if inverted {
                        MonochromeColors.foreground
                    } else {
                        MonochromeColors.background
                    }
                    
                    // Texture overlay
                    TextureView(pattern: pattern, inverted: inverted)
                        .opacity(inverted ? 0.03 : 0.015)
                        .allowsHitTesting(false)
                }
            )
    }
}

struct TextureView: View {
    var pattern: TexturedBackground.TexturePattern
    var inverted: Bool
    
    var body: some View {
        switch pattern {
        case .horizontalLines:
            HorizontalLinesTexture(inverted: inverted)
        case .grid:
            GridTexture(inverted: inverted)
        case .diagonal:
            DiagonalTexture(inverted: inverted)
        case .verticalLines:
            VerticalLinesTexture(inverted: inverted)
        case .radial:
            RadialTexture(inverted: inverted)
        case .noise:
            NoiseTexture()
        }
    }
}

struct HorizontalLinesTexture: View {
    var inverted: Bool = false
    
    var body: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 4
            let lineHeight: CGFloat = 1
            let color = inverted ? Color.white : Color.black
            
            var y: CGFloat = 0
            while y < size.height {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(color.opacity(0.015)), lineWidth: lineHeight)
                y += lineSpacing
            }
        }
    }
}

struct VerticalLinesTexture: View {
    var inverted: Bool = false
    
    var body: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 4
            let lineHeight: CGFloat = 1
            let color = inverted ? Color.white : Color.black
            
            var x: CGFloat = 0
            while x < size.width {
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(color.opacity(0.03)), lineWidth: lineHeight)
                x += lineSpacing
            }
        }
    }
}

struct GridTexture: View {
    var inverted: Bool = false
    
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40
            let lineWidth: CGFloat = 1
            let color = inverted ? Color.white : Color.black
            
            // Horizontal lines
            var y: CGFloat = 0
            while y < size.height {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(color.opacity(0.015)), lineWidth: lineWidth)
                y += gridSize
            }
            
            // Vertical lines
            var x: CGFloat = 0
            while x < size.width {
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(color.opacity(0.015)), lineWidth: lineWidth)
                x += gridSize
            }
        }
    }
}

struct DiagonalTexture: View {
    var inverted: Bool = false
    
    var body: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 42
            let lineWidth: CGFloat = 2
            let color = inverted ? Color.white : Color.black
            
            let diagonalLength = sqrt(size.width * size.width + size.height * size.height)
            
            for i in stride(from: -diagonalLength, to: diagonalLength * 2, by: lineSpacing) {
                let path = Path { p in
                    p.move(to: CGPoint(x: i, y: 0))
                    p.addLine(to: CGPoint(x: i + diagonalLength * 0.707, y: diagonalLength * 0.707))
                }
                context.stroke(path, with: .color(color.opacity(0.01)), lineWidth: lineWidth)
            }
        }
    }
}

struct RadialTexture: View {
    var inverted: Bool = false
    
    var body: some View {
        RadialGradient(
            colors: [
                (inverted ? Color.white : Color.black).opacity(0.05),
                Color.clear
            ],
            center: .top,
            startRadius: 0,
            endRadius: 1000
        )
    }
}

struct NoiseTexture: View {
    var body: some View {
        // Simplified noise - in production would use image asset
        Rectangle()
            .fill(Color.black.opacity(0.02))
    }
}

// MARK: - View Extensions

extension View {
    func monochromeCard(inverted: Bool = false, borderless: Bool = false) -> some View {
        modifier(MonochromeCardStyle(inverted: inverted, borderless: borderless))
    }
    
    func texturedBackground(pattern: TexturedBackground.TexturePattern = .horizontalLines, inverted: Bool = false) -> some View {
        modifier(TexturedBackground(pattern: pattern, inverted: inverted))
    }
}

// MARK: - Helper Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}