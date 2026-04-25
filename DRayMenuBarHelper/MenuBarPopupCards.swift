import SwiftUI

struct MenuBarMetricCardView: View {
    let title: String
    let subtitle: String
    let value: String
    let actionTitle: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            HStack {
                Spacer()
                Button(actionTitle, action: action)
                    .controlSize(.small)
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MenuBarPopupCardSurface(colorScheme: colorScheme))
    }
}

struct MenuBarBatteryMetricCardView: View {
    let stateText: String
    let valueText: String
    let healthPercent: Int?
    let onDetails: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Battery")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            Text(stateText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(valueText)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            HStack {
                if let healthPercent {
                    Text("Health \(healthPercent)%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(healthPercent >= 80 ? .green : .orange)
                } else {
                    Text("Tap Details for diagnostics")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Details", action: onDetails)
                    .controlSize(.small)
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MenuBarPopupCardSurface(colorScheme: colorScheme))
    }
}

private struct MenuBarPopupCardSurface: View {
    let colorScheme: ColorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.26),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke((colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.72)).opacity(colorScheme == .dark ? 0.78 : 0.45), lineWidth: 0.65)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.08), radius: 10, y: 5)
            .shadow(color: .white.opacity(colorScheme == .dark ? 0.0 : 0.26), radius: 5, x: -1, y: -1)
    }
}
