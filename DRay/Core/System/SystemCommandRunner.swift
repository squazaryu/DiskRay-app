import Darwin
import Foundation

struct SystemCommandRequest: Sendable {
    let executablePath: String
    let arguments: [String]
    let timeoutSeconds: TimeInterval

    init(
        executablePath: String,
        arguments: [String],
        timeoutSeconds: TimeInterval
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.timeoutSeconds = max(0, timeoutSeconds)
    }
}

struct SystemCommandResult: Equatable, Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool
    let wasCancelled: Bool

    var succeeded: Bool {
        exitCode == 0 && !timedOut && !wasCancelled
    }
}

struct SystemCommandRunner: Sendable {
    let runRequest: @Sendable (SystemCommandRequest) async -> SystemCommandResult

    init(run: @escaping @Sendable (SystemCommandRequest) async -> SystemCommandResult) {
        self.runRequest = run
    }

    func run(
        executablePath: String,
        arguments: [String],
        timeoutSeconds: TimeInterval
    ) async -> SystemCommandResult {
        await runRequest(
            SystemCommandRequest(
                executablePath: executablePath,
                arguments: arguments,
                timeoutSeconds: timeoutSeconds
            )
        )
    }

    static let live = SystemCommandRunner { request in
        await SystemCommandProcess.run(request)
    }
}

private enum SystemCommandProcess {
    static func run(_ request: SystemCommandRequest) async -> SystemCommandResult {
        let box = SystemCommandProcessBox()

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                box.setContinuation(continuation)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: request.executablePath)
                process.arguments = request.arguments

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                box.setPipes(stdout: stdoutPipe, stderr: stderrPipe)
                box.setProcess(process)

                process.terminationHandler = { terminatedProcess in
                    box.finish(exitCode: terminatedProcess.terminationStatus)
                }

                do {
                    try process.run()
                } catch {
                    box.finish(
                        exitCode: 1,
                        fallbackStderr: error.localizedDescription
                    )
                    return
                }

                if request.timeoutSeconds > 0 {
                    Task {
                        let nanos = UInt64(request.timeoutSeconds * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: nanos)
                        box.terminate(timedOut: true, wasCancelled: false)
                    }
                }
            }
        } onCancel: {
            box.terminate(timedOut: false, wasCancelled: true)
        }
    }
}

private final class SystemCommandProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var continuation: CheckedContinuation<SystemCommandResult, Never>?
    private var completed = false
    private var timedOut = false
    private var wasCancelled = false

    func setContinuation(_ continuation: CheckedContinuation<SystemCommandResult, Never>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func setProcess(_ process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    func setPipes(stdout: Pipe, stderr: Pipe) {
        lock.lock()
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
        lock.unlock()
    }

    func terminate(timedOut: Bool, wasCancelled: Bool) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        self.timedOut = self.timedOut || timedOut
        self.wasCancelled = self.wasCancelled || wasCancelled
        let currentProcess = process
        lock.unlock()

        guard let currentProcess, currentProcess.isRunning else { return }
        currentProcess.terminate()

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if currentProcess.isRunning {
                kill(currentProcess.processIdentifier, SIGKILL)
            }
        }
    }

    func finish(exitCode: Int32, fallbackStderr: String? = nil) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        let continuation = self.continuation
        self.continuation = nil
        let stdoutPipe = self.stdoutPipe
        let stderrPipe = self.stderrPipe
        let timedOut = self.timedOut
        let wasCancelled = self.wasCancelled
        self.process = nil
        lock.unlock()

        let stdout = stdoutPipe
            .map { String(data: $0.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "" }
            ?? ""
        var stderr = stderrPipe
            .map { String(data: $0.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "" }
            ?? ""
        if stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let fallbackStderr {
            stderr = fallbackStderr
        }

        continuation?.resume(
            returning: SystemCommandResult(
                exitCode: exitCode,
                stdout: stdout,
                stderr: stderr,
                timedOut: timedOut,
                wasCancelled: wasCancelled
            )
        )
    }
}
