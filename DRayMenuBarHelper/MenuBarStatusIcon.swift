import SwiftUI

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case appIcon
    case appIconAndBattery
    case batteryOnly

    var id: String { rawValue }
}

struct MenuBarStatusLabel: View {
    @ObservedObject var monitor: LiveSystemMetricsMonitor
    let mode: MenuBarDisplayMode

    init(monitor: LiveSystemMetricsMonitor, mode: MenuBarDisplayMode = .appIconAndBattery) {
        self.monitor = monitor
        self.mode = mode
    }

    var body: some View {
        HStack(spacing: 4) {
            switch mode {
            case .appIcon:
                DRayMenuBarMark()
            case .appIconAndBattery:
                DRayMenuBarMark()
                batteryState
            case .batteryOnly:
                batteryState
            }
        }
        .padding(.horizontal, mode == .appIcon ? 4 : 6)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var batteryState: some View {
        if let percent = monitor.snapshot.batteryLevelPercent {
            HStack(spacing: 2) {
                if monitor.snapshot.batteryIsCharging == true {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.yellow.opacity(0.82))
                        .accessibilityHidden(true)
                }

                Text("\(percent)%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(batteryTint(for: percent))
            }
        } else if mode == .batteryOnly {
            Text("BAT")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilityLabel: String {
        guard let percent = monitor.snapshot.batteryLevelPercent else {
            return mode == .batteryOnly ? "DRay battery unavailable" : "DRay"
        }
        if monitor.snapshot.batteryIsCharging == true {
            return "DRay, charging, battery \(percent) percent"
        }
        return "DRay, battery \(percent) percent"
    }

    private func batteryTint(for percent: Int) -> Color {
        if monitor.snapshot.batteryIsCharging == true {
            return .primary
        }
        if percent < 20 {
            return Color(red: 0.78, green: 0.24, blue: 0.22)
        }
        return .primary
    }
}

struct DRayMenuBarMark: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(markFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(markStroke, lineWidth: 0.7)
                )

            Text("D")
                .font(.system(size: 8.5, weight: .black, design: .rounded))
                .foregroundStyle(markText)
                .offset(y: -0.2)
        }
        .frame(width: 13, height: 13)
        .accessibilityHidden(true)
    }

    private var markFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.46, green: 0.92, blue: 0.96),
                Color(red: 0.05, green: 0.62, blue: 0.65)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var markStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.45)
            : Color.black.opacity(0.28)
    }

    private var markText: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.82)
            : Color.white.opacity(0.95)
    }
}

typealias MenuBarStatusIcon = MenuBarStatusLabel
