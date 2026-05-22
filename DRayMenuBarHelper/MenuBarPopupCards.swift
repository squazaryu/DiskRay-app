import SwiftUI

struct MenuBarMiniRing: View {
    let icon: String
    var tint: Color
    var size: CGFloat = 76
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07), lineWidth: 12)
            Circle()
                .trim(from: 0.08, to: 0.88)
                .stroke(
                    tint.opacity(colorScheme == .dark ? 0.58 : 0.48),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-125))
            Circle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035))
                .overlay(
                    Circle()
                        .strokeBorder(tint.opacity(colorScheme == .dark ? 0.16 : 0.12), lineWidth: 0.8)
                )
                .padding(14)
            Image(systemName: icon)
                .font(.system(size: size * 0.28, weight: .semibold))
                .foregroundStyle(tint.opacity(colorScheme == .dark ? 0.86 : 0.78))
        }
        .frame(width: size, height: size)
    }
}

struct MenuBarMetricTileCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    var tint: Color
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint.opacity(colorScheme == .dark ? 0.74 : 0.64))
                    .frame(width: 21, height: 21)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.030))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.070 : 0.055), lineWidth: 0.7)
                    )
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)

            if let actionTitle, let action {
                HStack {
                    Spacer()
                    Button(actionTitle, action: action)
                        .buttonStyle(MenuBarSoftButtonStyle())
                        .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .topLeading)
        .padding(8)
        .background(MenuBarCompactRowSurface(colorScheme: colorScheme, accent: tint, cornerRadius: 14))
    }
}

struct MenuBarRankedConsumerRow: View {
    let name: String
    let detail: String
    let value: String
    let progress: Double
    var tint: Color = .blue

    var body: some View {
        HStack(spacing: 8) {
            MenuBarConsumerLoadMarker(value: progress, tint: tint)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(MenuBarCompactRowSurface(colorScheme: colorScheme, accent: tint, cornerRadius: 9))
    }

    @Environment(\.colorScheme) private var colorScheme
}

private struct MenuBarConsumerLoadMarker: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(1, max(0, value))

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                Capsule()
                    .fill(tint.opacity(0.44))
                    .frame(height: max(4, proxy.size.height * clamped))
            }
        }
        .frame(height: 26)
    }
}

struct MenuBarMetricLineView: View {
    let title: String
    let subtitle: String
    let value: String
    let actionTitle: String
    let accent: Color
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(colorScheme == .dark ? 0.50 : 0.38))
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(1)
                    .allowsTightening(false)
                    .layoutPriority(1)
                    .monospacedDigit()
            }

            Spacer(minLength: 6)

            Button(actionTitle, action: action)
                .controlSize(.small)
                .buttonStyle(MenuBarSoftButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MenuBarCompactRowSurface(colorScheme: colorScheme, accent: accent))
    }
}

struct MenuBarBatteryLineView: View {
    let stateText: String
    let valueText: String
    let healthPercent: Int?
    let accent: Color
    let onDetails: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(colorScheme == .dark ? 0.50 : 0.38))
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Battery")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(stateText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(valueText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(1)
                        .allowsTightening(false)
                        .layoutPriority(1)
                        .monospacedDigit()
                    Text(healthLabelText)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(healthLabelColor)
                        .lineLimit(1)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 6)

            Button("Details", action: onDetails)
                .controlSize(.small)
                .buttonStyle(MenuBarSoftButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MenuBarCompactRowSurface(colorScheme: colorScheme, accent: accent))
    }

    private var healthLabelText: String {
        if let healthPercent {
            return "Health \(healthPercent)%"
        }
        return "Health --"
    }

    private var healthLabelColor: Color {
        guard let healthPercent else { return .secondary }
        return healthPercent >= 80 ? .green : .orange
    }
}

struct MenuBarCompactRowSurface: View {
    let colorScheme: ColorScheme
    let accent: Color
    var cornerRadius: CGFloat = 9

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.040) : Color.white.opacity(0.30))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.018 : 0.034),
                                accent.opacity(colorScheme == .dark ? 0.014 : 0.006),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.060 : 0.050), lineWidth: 0.65)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.black.opacity(0.08) : Color.white.opacity(0.08), lineWidth: 0.30)
            )
    }
}

struct MenuBarSoftButtonStyle: ButtonStyle {
    enum Tone {
        case primary
        case secondary
        case danger
    }

    var tone: Tone = .secondary

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(foreground)
            .background(
                Capsule(style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.7)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.84 : 1) : 0.50)
    }

    private var foreground: Color {
        guard isEnabled else { return .secondary }
        switch tone {
        case .primary:
            return .primary
        case .secondary:
            return .primary
        case .danger:
            return Color(red: 0.68, green: 0.28, blue: 0.25)
        }
    }

    private func fillColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.primary.opacity(colorScheme == .dark ? 0.034 : 0.026)
        }

        let pressedBoost = isPressed ? 0.035 : 0
        switch tone {
        case .primary:
            return Color.accentColor.opacity((colorScheme == .dark ? 0.145 : 0.105) + pressedBoost)
        case .secondary:
            return Color.primary.opacity((colorScheme == .dark ? 0.052 : 0.040) + pressedBoost)
        case .danger:
            return Color.red.opacity((colorScheme == .dark ? 0.105 : 0.080) + pressedBoost)
        }
    }

    private var borderColor: Color {
        guard isEnabled else {
            return Color.primary.opacity(colorScheme == .dark ? 0.060 : 0.045)
        }

        switch tone {
        case .primary:
            return Color.accentColor.opacity(colorScheme == .dark ? 0.26 : 0.22)
        case .secondary:
            return Color.primary.opacity(colorScheme == .dark ? 0.085 : 0.065)
        case .danger:
            return Color.red.opacity(colorScheme == .dark ? 0.24 : 0.20)
        }
    }
}
