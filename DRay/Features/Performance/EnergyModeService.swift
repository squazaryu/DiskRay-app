import Foundation

protocol EnergyModeManaging: Sendable {
    func loadEnergyModeSettings() async -> MacEnergyModeSettings
    func setEnergyMode(_ mode: MacEnergyMode, for source: MacEnergyPowerSource) async -> MacEnergyModeUpdateResult
}

actor EnergyModeService: EnergyModeManaging {
    typealias ElevatedCommandRunner = @Sendable (_ mode: MacEnergyMode, _ source: MacEnergyPowerSource) -> SystemCommandResult

    private let commandRunner: SystemCommandRunner
    private let elevatedCommandRunner: ElevatedCommandRunner
    private let pmsetPath = "/usr/bin/pmset"

    init(
        commandRunner: SystemCommandRunner = .live,
        elevatedCommandRunner: @escaping ElevatedCommandRunner = EnergyModeService.runPmsetWithAdministratorAuthorization
    ) {
        self.commandRunner = commandRunner
        self.elevatedCommandRunner = elevatedCommandRunner
    }

    func loadEnergyModeSettings() async -> MacEnergyModeSettings {
        async let customResult = commandRunner.run(
            executablePath: pmsetPath,
            arguments: ["-g", "custom"],
            timeoutSeconds: 3
        )
        async let capabilityResult = commandRunner.run(
            executablePath: pmsetPath,
            arguments: ["-g", "cap"],
            timeoutSeconds: 3
        )
        async let batteryResult = commandRunner.run(
            executablePath: pmsetPath,
            arguments: ["-g", "batt"],
            timeoutSeconds: 3
        )

        let (custom, capabilities, battery) = await (customResult, capabilityResult, batteryResult)
        let parsedModes = Self.parseCustomSettings(custom.stdout)
        let parsedCapabilities = Self.parseCapabilities(capabilities.stdout)
        let currentPowerSource = Self.parseCurrentPowerSource(battery.stdout)

        let errorMessage: String? = custom.succeeded
            ? nil
            : commandFailureMessage(prefix: "Unable to read energy mode settings", result: custom)

        return MacEnergyModeSettings(
            generatedAt: Date(),
            batteryMode: parsedModes.battery,
            chargerMode: parsedModes.charger,
            supportsLowPowerMode: parsedCapabilities.lowPower,
            supportsHighPowerMode: parsedCapabilities.highPower,
            currentPowerSource: currentPowerSource,
            errorMessage: errorMessage
        )
    }

    func setEnergyMode(_ mode: MacEnergyMode, for source: MacEnergyPowerSource) async -> MacEnergyModeUpdateResult {
        let directResult = await commandRunner.run(
            executablePath: pmsetPath,
            arguments: [source.pmsetArgument, "powermode", String(mode.rawValue)],
            timeoutSeconds: 5
        )
        let result = shouldRetryWithAdministratorAuthorization(directResult)
            ? elevatedCommandRunner(mode, source)
            : directResult
        let settings = await loadEnergyModeSettings()
        let errorMessage = result.succeeded
            ? nil
            : commandFailureMessage(prefix: "Unable to apply energy mode", result: result)
        return MacEnergyModeUpdateResult(
            source: source,
            requestedMode: mode,
            settings: settings,
            errorMessage: errorMessage
        )
    }

    static func parseCustomSettings(_ output: String) -> (battery: MacEnergyMode?, charger: MacEnergyMode?) {
        var currentSource: MacEnergyPowerSource?
        var batteryMode: MacEnergyMode?
        var chargerMode: MacEnergyMode?

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = line.lowercased()
            if lower == "battery power:" {
                currentSource = .battery
                continue
            }
            if lower == "ac power:" {
                currentSource = .charger
                continue
            }

            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard parts.count >= 2,
                  parts[0].lowercased() == "powermode",
                  let value = Int(parts[1]),
                  let mode = MacEnergyMode(rawValue: value),
                  let currentSource else {
                continue
            }

            switch currentSource {
            case .battery:
                batteryMode = mode
            case .charger:
                chargerMode = mode
            }
        }

        return (batteryMode, chargerMode)
    }

    static func parseCapabilities(_ output: String) -> (lowPower: Bool, highPower: Bool) {
        let lower = output.lowercased()
        return (
            lowPower: lower.contains("lowpowermode"),
            highPower: lower.contains("highpowermode")
        )
    }

    static func parseCurrentPowerSource(_ output: String) -> MacEnergyPowerSource? {
        let lower = output.lowercased()
        if lower.contains("now drawing from 'ac power'") {
            return .charger
        }
        if lower.contains("now drawing from 'battery power'") {
            return .battery
        }
        return nil
    }

    private func commandFailureMessage(prefix: String, result: SystemCommandResult) -> String {
        if result.timedOut {
            return "\(prefix): command timed out."
        }
        if result.wasCancelled {
            return "\(prefix): command was cancelled."
        }
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            return "\(prefix): \(stderr)"
        }
        if !stdout.isEmpty {
            return "\(prefix): \(stdout)"
        }
        return "\(prefix): pmset exited with code \(result.exitCode)."
    }

    private func shouldRetryWithAdministratorAuthorization(_ result: SystemCommandResult) -> Bool {
        guard !result.succeeded, !result.timedOut, !result.wasCancelled else { return false }
        let text = "\(result.stdout)\n\(result.stderr)".lowercased()
        return text.contains("must be run as root")
            || text.contains("operation not permitted")
            || text.contains("not privileged")
            || text.contains("authorization")
    }

    private nonisolated static func runPmsetWithAdministratorAuthorization(
        mode: MacEnergyMode,
        source: MacEnergyPowerSource
    ) -> SystemCommandResult {
        let script = """
        do shell script "/usr/bin/pmset \(source.pmsetArgument) powermode \(mode.rawValue)" with administrator privileges
        return "ok"
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return SystemCommandResult(
                exitCode: process.terminationStatus,
                stdout: output,
                stderr: error,
                timedOut: false,
                wasCancelled: false
            )
        } catch {
            return SystemCommandResult(
                exitCode: 1,
                stdout: "",
                stderr: error.localizedDescription,
                timedOut: false,
                wasCancelled: false
            )
        }
    }
}
