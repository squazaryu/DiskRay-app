import SwiftUI

struct MenuBarMiniRing: View {
    let icon: String
    var tint: Color
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 12)
            Circle()
                .trim(from: 0.08, to: 0.88)
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.95), Color.cyan.opacity(0.75), tint.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-125))
            Circle()
                .fill(.ultraThinMaterial)
                .padding(14)
            Image(systemName: icon)
                .font(.system(size: size * 0.28, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

struct MenuBarSparklineView: View {
    let values: [Double]
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(size: proxy.size)
            ZStack {
                fillPath(points: points, size: proxy.size)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.18), tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                linePath(points: points)
                    .stroke(tint.opacity(0.82), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func normalizedPoints(size: CGSize) -> [CGPoint] {
        let series = values.count > 1 ? values : [0.2, 0.45, 0.34, 0.62, 0.49, 0.72, 0.58]
        let minValue = series.min() ?? 0
        let maxValue = series.max() ?? 1
        let range = max(maxValue - minValue, 0.01)
        let step = size.width / CGFloat(max(series.count - 1, 1))
        return series.enumerated().map { index, value in
            let normalized = (value - minValue) / range
            return CGPoint(
                x: CGFloat(index) * step,
                y: size.height - CGFloat(normalized) * size.height * 0.72 - size.height * 0.14
            )
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in points.indices.dropFirst() {
            let previous = points[index - 1]
            let current = points[index]
            let midX = (previous.x + current.x) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: midX, y: previous.y),
                control2: CGPoint(x: midX, y: current.y)
            )
        }
        return path
    }

    private func fillPath(points: [CGPoint], size: CGSize) -> Path {
        var path = linePath(points: points)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}

struct MenuBarMetricTileCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    var tint: Color
    var progress: Double?
    var sparkline: [Double] = []
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 21, height: 21)
                    .background(tint.opacity(colorScheme == .dark ? 0.20 : 0.13), in: Circle())
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

            if !sparkline.isEmpty {
                MenuBarSparklineView(values: sparkline, tint: tint)
                    .frame(height: 19)
            } else if let progress {
                MenuBarProgressBar(value: progress, tint: tint, height: 5)
            }

            if let actionTitle, let action {
                HStack {
                    Spacer()
                    Button(actionTitle, action: action)
                        .font(.system(size: 11, weight: .semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(8)
        .background(MenuBarCompactRowSurface(colorScheme: colorScheme, accent: tint, cornerRadius: 14))
    }
}

struct MenuBarProgressBar: View {
    let value: Double
    var tint: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(1, max(0, value))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.16))
                Capsule()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.45)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, proxy.size.width * clamped))
            }
        }
        .frame(height: height)
    }
}

struct MenuBarRankedConsumerRow: View {
    let name: String
    let detail: String
    let value: String
    let progress: Double
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            MenuBarProgressBar(value: progress, tint: tint, height: 4)
            Text(detail)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
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
                .fill(accent.opacity(colorScheme == .dark ? 0.72 : 0.55))
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
                .font(.system(size: 12, weight: .semibold))
                .controlSize(.small)
                .buttonStyle(.bordered)
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
                .fill(accent.opacity(colorScheme == .dark ? 0.72 : 0.55))
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
                .font(.system(size: 12, weight: .semibold))
                .controlSize(.small)
                .buttonStyle(.bordered)
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

private struct MenuBarCompactRowSurface: View {
    let colorScheme: ColorScheme
    let accent: Color
    var cornerRadius: CGFloat = 9

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(colorScheme == .dark ? 0.14 : 0.09),
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.14),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.17) : Color.white.opacity(0.48), lineWidth: 0.65)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.black.opacity(0.20) : Color.black.opacity(0.04), lineWidth: 0.45)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.06), radius: 6, y: 2)
            .shadow(color: .white.opacity(colorScheme == .dark ? 0.0 : 0.14), radius: 2, x: -1, y: -1)
    }
}
