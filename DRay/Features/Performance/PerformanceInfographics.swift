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
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(clampedValue))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.10))
                    Capsule()
                        .fill(tint.opacity(0.78))
                        .frame(width: max(8, geo.size.width * (clampedValue / 100)))
                }
            }
            .frame(height: 8)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(Int(clampedPercentage))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
            }
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(accent.opacity(0.75))
                        .frame(width: max(6, geo.size.width * (clampedPercentage / 100)))
                }
            }
            .frame(height: 7)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
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
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}
