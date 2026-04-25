import SwiftUI

struct MenuBarStatusIcon: View {
    @ObservedObject var monitor: LiveSystemMetricsMonitor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 3) {
            if let percent = monitor.snapshot.batteryLevelPercent {
                Text("\(percent)%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text("BAT")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            if monitor.snapshot.batteryIsCharging == true {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .foregroundStyle(colorScheme == .dark ? .white : .black)
    }
}
