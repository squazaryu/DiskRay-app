import SwiftUI

struct BatteryDetailsSheetView: View {
    let snapshot: BatteryDiagnosticsSnapshot?
    let isLoading: Bool
    let errorText: String?
    let onRefresh: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Battery Details")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Refresh") { onRefresh() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Close") { onClose() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if let snapshot {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.deviceName)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                        Text("Identifier: \(snapshot.machineIdentifier)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    BatteryProgressCard(
                        title: "Battery Charge",
                        valueText: formattedMAh(snapshot.currentCapacityMAh),
                        percentText: percentString(snapshot.chargePercent),
                        percentValue: normalizedPercent(snapshot.chargePercent),
                        tint: .green
                    )

                    BatteryProgressCard(
                        title: "Battery Health",
                        valueText: formattedMAh(snapshot.fullChargeCapacityMAh),
                        percentText: percentString(snapshot.healthPercent),
                        percentValue: normalizedPercent(snapshot.healthPercent),
                        tint: (snapshot.healthPercent ?? 0) >= 80 ? .green : .orange
                    )

                    primaryDurationCard(snapshot)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10, alignment: .leading),
                            GridItem(.flexible(), spacing: 10, alignment: .leading)
                        ],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(secondaryDetails(snapshot), id: \.0) { row in
                            detailMetricCell(title: row.0, value: row.1)
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else if isLoading {
                VStack(spacing: 10) {
                    ProgressView("Loading battery diagnostics...")
                    Text("Reading AppleSmartBattery telemetry")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorText ?? "No battery diagnostics available yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") { onRefresh() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(12)
        .frame(width: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.9)
        )
    }

    private func detailMetricCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryDurationCard(_ snapshot: BatteryDiagnosticsSnapshot) -> some View {
        let row = primaryDurationRow(snapshot)
        return VStack(spacing: 4) {
            Text(row.0)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(row.1)
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func secondaryDetails(_ snapshot: BatteryDiagnosticsSnapshot) -> [(String, String)] {
        [
            ("Power", formattedPower(snapshot.powerWatts)),
            ("Temperature", formattedTemperature(snapshot.temperatureCelsius)),
            ("Charge Cycles", formattedInt(snapshot.cycleCount)),
            ("Voltage", formattedVoltage(snapshot.voltageVolts)),
            ("Amperage", formattedAmperage(snapshot.amperageAmps)),
            ("Updated", snapshot.updatedAt.formatted(date: .omitted, time: .shortened))
        ]
    }

    private func primaryDurationRow(_ snapshot: BatteryDiagnosticsSnapshot) -> (String, String) {
        if snapshot.isCharging == true {
            return ("Time to Full", formattedDuration(snapshot.minutesToFull))
        }
        if snapshot.isCharging == false {
            return ("Time to Empty", formattedDuration(snapshot.minutesToEmpty))
        }
        if snapshot.minutesToFull != nil {
            return ("Time to Full", formattedDuration(snapshot.minutesToFull))
        }
        if snapshot.minutesToEmpty != nil {
            return ("Time to Empty", formattedDuration(snapshot.minutesToEmpty))
        }
        return ("Time", "n/a")
    }

    private func formattedInt(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value)"
    }

    private func formattedMAh(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value.formatted(.number.grouping(.automatic))) mAh"
    }

    private func formattedTemperature(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f °C", value)
    }

    private func formattedVoltage(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f V", value)
    }

    private func formattedAmperage(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f A", value)
    }

    private func formattedPower(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        if value < 0 {
            return String(format: "Discharging %.1f W", abs(value))
        }
        if value > 0 {
            return String(format: "Charging %.1f W", value)
        }
        return "0 W"
    }

    private func percentString(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value)%"
    }

    private func formattedDuration(_ minutes: Int?) -> String {
        guard let minutes, minutes >= 0 else { return "n/a" }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    private func normalizedPercent(_ value: Int?) -> Double {
        guard let value else { return 0 }
        return min(1, max(0, Double(value) / 100.0))
    }
}

struct BatteryProgressCard: View {
    let title: String
    let valueText: String
    let percentText: String
    let percentValue: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.secondary.opacity(0.16))
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.88), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, proxy.size.width * percentValue))
                    Text(percentText)
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(height: 18)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
