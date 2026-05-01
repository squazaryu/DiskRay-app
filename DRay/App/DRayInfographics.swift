import SwiftUI

struct DRaySparklineView: View {
    let values: [Double]
    var tint: Color = .blue
    var lineWidth: CGFloat = 2
    var fill: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let normalized = normalizedValues
            ZStack {
                if fill {
                    sparklineFillPath(values: normalized, in: proxy.size)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.22), tint.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                sparklinePath(values: normalized, in: proxy.size)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }

    private var normalizedValues: [Double] {
        guard values.count > 1 else { return [0.35, 0.55, 0.42, 0.62, 0.58, 0.76, 0.50] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 0.01)
        return values.map { ($0 - minValue) / range }
    }

    private func sparklinePath(values: [Double], in size: CGSize) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }
        let step = size.width / CGFloat(max(values.count - 1, 1))
        let points = values.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * step,
                y: size.height - CGFloat(value) * (size.height * 0.78) - size.height * 0.10
            )
        }
        path.move(to: points[0])
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

    private func sparklineFillPath(values: [Double], in size: CGSize) -> Path {
        var path = sparklinePath(values: values, in: size)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}

struct DRayDashboardMetricTile: View {
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    var tint: Color
    var progress: Double?
    var sparkline: [Double] = []
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: max(6, layoutMetrics.cardSpacing - 3)) {
            HStack(alignment: .top, spacing: 8) {
                DRayIconBadge(icon: icon, tint: tint, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font((layoutMetrics.dashboardTileMinHeight < 110 ? Font.title3 : Font.title2).weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 0)
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !sparkline.isEmpty {
                DRaySparklineView(values: sparkline, tint: tint, lineWidth: 1.7)
                    .frame(height: layoutMetrics.dashboardTileMinHeight < 110 ? 24 : 34)
            }

            if let progress {
                DRayProgressBar(value: progress, tint: tint, height: 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: layoutMetrics.dashboardTileMinHeight, alignment: .topLeading)
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 18, strokeOpacity: 0.09, shadowOpacity: 0.06, padding: 0)
    }
}

struct DRayRankedBarRow: View {
    let rank: Int
    let title: String
    let subtitle: String
    let value: String
    let progress: Double
    var tint: Color = .blue
    var icon: String = "app"

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.13), in: Circle())

            DRayIconBadge(icon: icon, tint: tint, size: 26)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                DRayProgressBar(value: progress, tint: tint, height: 5)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct DRayActivityTimelineRow: View {
    let title: String
    let subtitle: String
    let time: String
    let icon: String
    var tint: Color = .blue

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            DRayIconBadge(icon: icon, tint: tint, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(time)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct DRayIconBadge: View {
    let icon: String
    var tint: Color = .blue
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(tint.opacity(0.14))
                    .overlay(Circle().stroke(tint.opacity(0.18), lineWidth: 0.7))
            )
            .shadow(color: tint.opacity(0.12), radius: 6, y: 3)
    }
}

struct DRayDonutSegment: Identifiable {
    let id = UUID()
    let title: String
    let value: Double
    let color: Color
}

struct DRayDonutChartView: View {
    let segments: [DRayDonutSegment]
    let centerTitle: String
    let centerSubtitle: String
    var lineWidth: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.12), lineWidth: lineWidth)

            ForEach(segmentAngles) { item in
                DRayDonutArc(startAngle: item.start, endAngle: item.end)
                    .stroke(
                        LinearGradient(
                            colors: [item.segment.color.opacity(0.95), item.segment.color.opacity(0.48)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .shadow(color: item.segment.color.opacity(0.14), radius: 7, y: 3)
            }

            VStack(spacing: 2) {
                Text(centerTitle)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(centerSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(18)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var segmentAngles: [DRayDonutArcItem] {
        let positive = segments.filter { $0.value > 0 }
        let total = positive.reduce(0) { $0 + $1.value }
        guard total > 0 else { return [] }

        var cursor = -90.0
        return positive.map { segment in
            let sweep = max(1.0, segment.value / total * 354.0)
            let item = DRayDonutArcItem(
                segment: segment,
                start: .degrees(cursor),
                end: .degrees(cursor + sweep)
            )
            cursor += sweep + 2.0
            return item
        }
    }
}

private struct DRayDonutArcItem: Identifiable {
    let id = UUID()
    let segment: DRayDonutSegment
    let start: Angle
    let end: Angle
}

private struct DRayDonutArc: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
