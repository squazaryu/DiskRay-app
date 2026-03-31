import Foundation

struct CrashSessionState: Codable {
    let launchID: UUID
    let pid: Int32
    let startedAt: Date
    let mode: String
}

struct CrashEvent: Codable {
    let detectedAt: Date
    let previousLaunchID: UUID
    let previousPID: Int32
    let previousStartedAt: Date
    let previousMode: String
    let reason: String
}

@MainActor
final class CrashTelemetryService {
    static let shared = CrashTelemetryService()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private var currentSession: CrashSessionState?
    private var isSessionOpen = false

    private lazy var telemetryRoot: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let root = appSupport.appendingPathComponent("DRay/Telemetry", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }()

    private var sessionFileURL: URL {
        telemetryRoot.appendingPathComponent("session_state.json")
    }

    private var crashLogFileURL: URL {
        telemetryRoot.appendingPathComponent("crash_events.ndjson")
    }

    func beginSession(mode: AppRunMode) {
        guard !isSessionOpen else { return }
        isSessionOpen = true

        if let previous = readPreviousSession() {
            appendCrashEvent(
                CrashEvent(
                    detectedAt: Date(),
                    previousLaunchID: previous.launchID,
                    previousPID: previous.pid,
                    previousStartedAt: previous.startedAt,
                    previousMode: previous.mode,
                    reason: "Previous DRay process did not close cleanly."
                )
            )
        }

        let state = CrashSessionState(
            launchID: UUID(),
            pid: ProcessInfo.processInfo.processIdentifier,
            startedAt: Date(),
            mode: mode.rawValue
        )
        currentSession = state
        writeSession(state)
    }

    func endSession() {
        guard isSessionOpen else { return }
        isSessionOpen = false
        currentSession = nil
        try? FileManager.default.removeItem(at: sessionFileURL)
    }

    func crashEventsURL() -> URL? {
        let url = crashLogFileURL
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func readPreviousSession() -> CrashSessionState? {
        guard let data = try? Data(contentsOf: sessionFileURL) else { return nil }
        return try? decoder.decode(CrashSessionState.self, from: data)
    }

    private func writeSession(_ session: CrashSessionState) {
        guard let data = try? encoder.encode(session) else { return }
        try? data.write(to: sessionFileURL, options: [.atomic])
    }

    private func appendCrashEvent(_ event: CrashEvent) {
        guard let data = try? encoder.encode(event) else { return }
        var line = data
        line.append(0x0A)
        if FileManager.default.fileExists(atPath: crashLogFileURL.path),
           let handle = try? FileHandle(forWritingTo: crashLogFileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: crashLogFileURL, options: [.atomic])
        }
    }
}
