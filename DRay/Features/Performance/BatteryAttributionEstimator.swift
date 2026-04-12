import Foundation

protocol BatteryAttributionEstimating: Sendable {
    func applyEstimate(
        consumers: [EnergyConsumerSnapshot],
        battery: BatteryEnergySnapshot
    ) -> [EnergyConsumerSnapshot]
}

struct BatteryAttributionEstimator: BatteryAttributionEstimating, Sendable {
    func applyEstimate(
        consumers: [EnergyConsumerSnapshot],
        battery: BatteryEnergySnapshot
    ) -> [EnergyConsumerSnapshot] {
        guard !consumers.isEmpty else { return [] }

        let weightedConsumers = consumers.map { consumer in
            // Estimated model: blend current/average energy impact and add a small
            // penalty for active sleep prevention to reflect persistence.
            let weight = max(
                0,
                consumer.currentEnergyImpact * 0.7
                + consumer.averageEnergyImpact * 0.3
                + (consumer.preventingSleep ? 6 : 0)
            )
            return (consumer, weight)
        }

        let totalWeight = weightedConsumers.reduce(0.0) { $0 + $1.1 }
        let dischargingPower = battery.isCharging == false ? abs(battery.powerDrawWatts ?? 0) : 0

        let estimated: [EnergyConsumerSnapshot] = weightedConsumers.map { tuple in
            let consumer = tuple.0
            let share: Double
            if totalWeight > 0 {
                share = (tuple.1 / totalWeight) * 100.0
            } else {
                share = 0
            }

            let estimated12hWh: Double?
            if dischargingPower > 0, share > 0 {
                estimated12hWh = dischargingPower * 12.0 * (share / 100.0)
            } else {
                estimated12hWh = nil
            }

            return EnergyConsumerSnapshot(
                id: consumer.id,
                pid: consumer.pid,
                displayName: consumer.displayName,
                currentEnergyImpact: consumer.currentEnergyImpact,
                averageEnergyImpact: consumer.averageEnergyImpact,
                estimatedDrainShare: share,
                estimatedPower12hWh: estimated12hWh,
                preventingSleep: consumer.preventingSleep,
                highPowerGPUUsage: consumer.highPowerGPUUsage,
                appNapStatus: consumer.appNapStatus,
                cpuPercent: consumer.cpuPercent,
                memoryMB: consumer.memoryMB
            )
        }

        return estimated.sorted { lhs, rhs in
            if lhs.estimatedDrainShare != rhs.estimatedDrainShare {
                return lhs.estimatedDrainShare > rhs.estimatedDrainShare
            }
            return lhs.currentEnergyImpact > rhs.currentEnergyImpact
        }
    }
}

