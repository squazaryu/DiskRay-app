import Foundation

extension PerformanceView {
    func optionalPercent(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value)%"
    }

    func optionalWatts(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f W", value)
    }

    func optionalTemperature(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f °C", value)
    }

    func optionalVolts(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f", value)
    }

    func optionalAmps(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.2f", value)
    }

    func optionalMbps(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f Mbps", value)
    }

    func optionalMilliseconds(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.1f ms", value)
    }

    func batteryStateText(_ snapshot: BatteryEnergySnapshot) -> String {
        guard let isCharging = snapshot.isCharging else {
            return t("Статус n/a", "Status n/a")
        }
        return isCharging ? t("Заряжается", "Charging") : t("Разряжается", "Discharging")
    }

    func timeEstimateText(_ snapshot: BatteryEnergySnapshot) -> String {
        if snapshot.isCharging == true {
            guard let minutes = snapshot.minutesToFull else { return t("До 100% n/a", "To full n/a") }
            let hours = minutes / 60
            let mins = minutes % 60
            return t("До 100% \(hours)ч \(mins)м", "To full \(hours)h \(mins)m")
        }
        guard let minutes = snapshot.minutesToEmpty else { return t("До разрядки n/a", "To empty n/a") }
        let hours = minutes / 60
        let mins = minutes % 60
        return t("До разрядки \(hours)ч \(mins)м", "To empty \(hours)h \(mins)m")
    }

    func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
