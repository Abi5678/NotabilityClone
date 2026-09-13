//
//  ToolPaletteView.swift
//  NotabilityClone
//
//  Minimalist Monochrome tool palette
//

import SwiftUI

struct ToolPaletteView: View {
    @Binding var selectedTool: InkTool
    @Binding var selectedColor: Color
    @Binding var selectedWidth: CGFloat

    let widths: [CGFloat] = [2, 4, 8, 12, 20]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ToolButton(icon: "pencil.tip", label: "Pen", isSelected: selectedTool == .pen) {
                    selectedTool = .pen
                }

                MonochromeVerticalDivider(weight: MonochromeBorders.hairline)

                ToolButton(icon: "marker.fill", label: "Marker", isSelected: selectedTool == .marker) {
                    selectedTool = .marker
                }

                MonochromeVerticalDivider(weight: MonochromeBorders.hairline)

                ToolButton(icon: "eraser.fill", label: "Eraser", isSelected: selectedTool == .eraser) {
                    selectedTool = .eraser
                }
            }
            .overlay(
                Rectangle()
                    .stroke(MonochromeColors.border, lineWidth: MonochromeBorders.thin)
            )

            VStack(alignment: .leading, spacing: 8) {
                MonochromeLabel(title: "Stroke Weight")

                HStack(spacing: 12) {
                    ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                        Button(action: { selectedWidth = width }) {
                            Rectangle()
                                .fill(selectedWidth == width ? MonochromeColors.foreground : MonochromeColors.background)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Rectangle()
                                        .stroke(MonochromeColors.border, lineWidth: selectedWidth == width ? MonochromeBorders.medium : MonochromeBorders.thin)
                                )
                                .overlay(
                                    Rectangle()
                                        .fill(MonochromeColors.foreground)
                                        .frame(width: min(width, 20), height: min(width, 20))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                MonochromeLabel(title: "Color")

                HStack(spacing: 12) {
                    Button(action: { selectedColor = .black }) {
                        ZStack {
                            Rectangle()
                                .fill(selectedColor == .black ? MonochromeColors.foreground : MonochromeColors.background)
                            if selectedColor != .black {
                                Rectangle()
                                    .stroke(MonochromeColors.border, lineWidth: MonochromeBorders.thin)
                            }
                        }
                        .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    Text("Monochrome")
                        .font(MonochromeTypography.xs())
                        .foregroundColor(MonochromeColors.mutedForeground)
                        .italic()
                }
            }
        }
        .padding(20)
        .background(MonochromeColors.background)
    }
}

struct ToolButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(MonochromeTypography.xs())
                    .tracking(0.05)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(isSelected ? MonochromeColors.background : MonochromeColors.foreground)
            .background(isSelected ? MonochromeColors.foreground : MonochromeColors.background)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ToolPaletteView(
        selectedTool: .constant(.pen),
        selectedColor: .constant(.black),
        selectedWidth: .constant(4.0)
    )
    .padding()
}
