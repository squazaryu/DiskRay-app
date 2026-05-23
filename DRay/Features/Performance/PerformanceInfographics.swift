import SwiftUI

struct DiagnosticBurdenBar: View {
    let value: Double
    let label: String
    let detail: String

    private var clampedValue: Double {
        min(max(value, 0), 100)
    }

    private var tint: Color {
        switch clampedValue {
        case 0..<45: return .green
        case 45..<75: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint.opacity(0.56))
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(Int(clampedValue))%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }
}

struct RankedShareBar: View {
    let title: String
    let subtitle: String
    let percentage: Double
    let accent: Color

    private var clampedPercentage: Double {
        min(max(percentage, 0), 100)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent.opacity(0.52))
                .frame(width: 3, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(Int(clampedPercentage))%")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)
                .monospacedDigit()
        }
        .padding(8)
        .calmGlass(.nestedCard, cornerRadius: 10)
    }
}

struct MiniSparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(tint.opacity(0.58), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, size.width > 0, size.height > 0 else { return [] }
        let maxValue = max(values.max() ?? 1, 1)
        let minValue = min(values.min() ?? 0, maxValue)
        let range = max(maxValue - minValue, 0.01)

        return values.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
            let normalized = (value - minValue) / range
            let y = size.height - (size.height * CGFloat(normalized))
            return CGPoint(x: x, y: y)
        }
    }
}

struct StatusChip: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.055), in: Capsule())
            .foregroundStyle(tint.opacity(0.78))
    }
}
