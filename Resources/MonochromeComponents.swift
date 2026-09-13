//
//  MonochromeComponents.swift
//  NotabilityClone
//
//  Reusable Minimalist Monochrome UI components
//

import SwiftUI

// MARK: - Buttons

public struct MonochromeButton: View {
    let title: String
    var variant: ButtonVariant = .primary
    var icon: String? = nil
    let action: () -> Void
    
    enum ButtonVariant {
        case primary
        case outline
        case ghost
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(0.1)
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(background_color)
            .foregroundColor(foreground_color)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(border_color, lineWidth: border_width)
            )
        }
        .buttonStyle(.plain)
        .focusable()
        .focusEffectDisabled()
    }
    
    private var background_color: Color {
        switch variant {
        case .primary:
            return MonochromeColors.foreground
        case .outline, .ghost:
            return MonochromeColors.background
        }
    }
    
    private var foreground_color: Color {
        switch variant {
        case .primary:
            return MonochromeColors.background
        case .outline, .ghost:
            return MonochromeColors.foreground
        }
    }
    
    private var border_color: Color {
        switch variant {
        case .primary:
            return Color.clear
        case .outline:
            return MonochromeColors.foreground
        case .ghost:
            return Color.clear
        }
    }
    
    private var border_width: CGFloat {
        switch variant {
        case .primary, .ghost:
            return 0
        case .outline:
            return MonochromeBorders.medium
        }
    }
}

// MARK: - Cards

public struct MonochromeCard<Content: View>: View {
    let content: Content
    var inverted: Bool = false
    var borderless: Bool = false
    
    init(inverted: Bool = false, borderless: Bool = false, @ViewBuilder content: () -> Content) {
        self.inverted = inverted
        self.borderless = borderless
        self.content = content()
    }
    
    public var body: some View {
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

// MARK: - Text Fields

public struct MonochromeTextField: View {
    @Binding var text: String
    var placeholder: String
    var onSubmit: (() -> Void)? = nil
    
    public var body: some View {
        TextField(placeholder, text: $text)
            .font(MonochromeTypography.base())
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(MonochromeColors.background)
            .overlay(
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(MonochromeColors.border)
                        .frame(height: MonochromeBorders.medium)
                }
            )
            .onSubmit {
                onSubmit?()
            }
    }
}

struct MonochromeSecureField: View {
    @Binding var text: String
    var placeholder: String
    
    public var body: some View {
        SecureField(placeholder, text: $text)
            .font(MonochromeTypography.base())
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(MonochromeColors.background)
            .overlay(
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(MonochromeColors.border)
                        .frame(height: MonochromeBorders.medium)
                }
            )
    }
}

// MARK: - Dividers

public struct MonochromeDivider: View {
    var weight: CGFloat = MonochromeBorders.thick
    
    public var body: some View {
        Rectangle()
            .fill(MonochromeColors.foreground)
            .frame(height: weight)
    }
}

struct MonochromeVerticalDivider: View {
    var weight: CGFloat = MonochromeBorders.thin
    
    public var body: some View {
        Rectangle()
            .fill(MonochromeColors.border)
            .frame(width: weight)
    }
}

// MARK: - Labels & Headings

public struct MonochromeHeading: View {
    let title: String
    var level: HeadingLevel = .h1
    
    enum HeadingLevel {
        case h1, h2, h3, h4, h5, h6
    }
    
    public var body: some View {
        Text(title)
            .font(fontForLevel)
            .tracking(trackingForLevel)
            .fontWeight(weightForLevel)
    }
    
    private var fontForLevel: Font {
        switch level {
        case .h1: return MonochromeTypography.xl9()
        case .h2: return MonochromeTypography.xl7()
        case .h3: return MonochromeTypography.xl5()
        case .h4: return MonochromeTypography.xl4()
        case .h5: return MonochromeTypography.xl3()
        case .h6: return MonochromeTypography.xl2()
        }
    }
    
    private var trackingForLevel: CGFloat {
        switch level {
        case .h1, .h2, .h3: return MonochromeTypography.trackingTight
        default: return MonochromeTypography.trackingNormal
        }
    }
    
    private var weightForLevel: Font.Weight {
        switch level {
        case .h1, .h2, .h3: return .bold
        default: return .medium
        }
    }
}

public struct MonochromeLabel: View {
    let title: String
    var uppercase: Bool = true
    
    public var body: some View {
        Text(uppercase ? title.uppercased() : title)
            .font(MonochromeTypography.sm())
            .tracking(MonochromeTypography.trackingWide)
            .foregroundColor(MonochromeColors.mutedForeground)
    }
}

// MARK: - Lists

public struct MonochromeListItem<Content: View>: View {
    let content: Content
    var showBorder: Bool = true
    
    init(showBorder: Bool = true, @ViewBuilder content: () -> Content) {
        self.showBorder = showBorder
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .overlay(
                showBorder ?
                Divider()
                    .background(MonochromeColors.borderLight)
                : nil,
                alignment: .bottom
            )
    }
}

// MARK: - Previews

#Preview("Primary Button") {
    MonochromeButton(title: "Get Started", variant: .primary, icon: "arrow.right") {
        print("Clicked")
    }
    .padding()
}

#Preview("Outline Button") {
    MonochromeButton(title: "Learn More", variant: .outline) {
        print("Clicked")
    }
    .padding()
}

#Preview("Card") {
    MonochromeCard {
        Text("Card Content")
            .font(.title)
    }
    .padding()
}

#Preview("Inverted Card") {
    MonochromeCard(inverted: true) {
        Text("Inverted Card")
            .font(.title)
    }
    .padding()
}

#Preview("Divider") {
    VStack(spacing: 24) {
        Text("Section 1")
        MonochromeDivider()
        Text("Section 2")
    }
    .padding()
}