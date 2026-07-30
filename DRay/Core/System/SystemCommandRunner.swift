import Darwin
import Foundation

struct SystemCommandRequest: Sendable {
    static let defaultMaxOutputBytes = 8 * 1_024 * 1_024

    let executablePath: String
    let arguments: [String]
    let timeoutSeconds: TimeInterval
    let maxOutputBytes: Int

    init(
        executablePath: String,
        arguments: [String],
        timeoutSeconds: TimeInterval,
        maxOutputBytes: Int = Self.defaultMaxOutputBytes
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.timeoutSeconds = max(0, timeoutSeconds)
        self.maxOutputBytes = max(1_024, maxOutputBytes)
    }
}

struct SystemCommandResult: Equatable, Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool
    let wasCancelled: Bool
    let outputTruncated: Bool

    init(
        exitCode: Int32,
        stdout: String,
        stderr: String,
        timedOut: Bool,
        wasCancelled: Bool,
        outputTruncated: Bool = false
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.timedOut = timedOut
        self.wasCancelled = wasCancelled
        self.outputTruncated = outputTruncated
    }

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
        timeoutSeconds: TimeInterval,
        maxOutputBytes: Int = SystemCommandRequest.defaultMaxOutputBytes
    ) async -> SystemCommandResult {
        await runRequest(
            SystemCommandRequest(
                executablePath: executablePath,
                arguments: arguments,
                timeoutSeconds: timeoutSeconds,
                maxOutputBytes: maxOutputBytes
            )
        )
    }

    static let live = SystemCommandRunner { request in
        await SystemCommandProcess.run(request)
    }
}

private enum SystemCommandProcess {
    static func run(_ request: SystemCommandRequest) async -> SystemCommandResult {
        let box = SystemCommandProcessBox(maxOutputBytes: request.maxOutputBytes)

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
                box.prepare(
                    process: process,
                    stdoutHandle: stdoutPipe.fileHandleForReading,
                    stderrHandle: stderrPipe.fileHandleForReading
                )

                if Task.isCancelled {
                    box.requestTermination(timedOut: false, wasCancelled: true)
                }
                guard !box.shouldSkipLaunch else {
                    box.finishWithoutProcess(exitCode: SIGTERM)
                    return
                }

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty {
                        handle.readabilityHandler = nil
                        box.markStreamEnded(.stdout)
                    } else {
                        box.append(data, to: .stdout)
                    }
                }
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty {
                        handle.readabilityHandler = nil
                        box.markStreamEnded(.stderr)
                    } else {
                        box.append(data, to: .stderr)
                    }
                }

                process.terminationHandler = { terminatedProcess in
                    box.processDidTerminate(exitCode: terminatedProcess.terminationStatus)
                }

                do {
                    try process.run()
                    box.processDidLaunch()
                } catch {
                    box.launchFailed(error.localizedDescription)
                    return
                }

                guard request.timeoutSeconds > 0 else { return }
                let timeoutTask = Task {
                    let nanos = UInt64(request.timeoutSeconds * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: nanos)
                    guard !Task.isCancelled else { return }
                    box.requestTermination(timedOut: true, wasCancelled: false)
                }
                box.setTimeoutTask(timeoutTask)
            }
        } onCancel: {
            box.requestTermination(timedOut: false, wasCancelled: true)
        }
    }
}

private enum SystemCommandStream {
    case stdout
    case stderr
}

private final class SystemCommandProcessBox: @unchecked Sendable {
    private struct Completion {
        let continuation: CheckedContinuation<SystemCommandResult, Never>
        let result: SystemCommandResult
        let stdoutHandle: FileHandle?
        let stderrHandle: FileHandle?
        let timeoutTask: Task<Void, Never>?
        let drainGraceTask: Task<Void, Never>?
    }

    private let lock = NSLock()
    private let maxOutputBytes: Int
    private var process: Process?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var stdoutData = Data()
    private var stderrData = Data()
    private var stdoutEnded = false
    private var stderrEnded = false
    private var stdoutTruncated = false
    private var stderrTruncated = false
    private var continuation: CheckedContinuation<SystemCommandResult, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var drainGraceTask: Task<Void, Never>?
    private var terminatedExitCode: Int32?
    private var fallbackStderr: String?
    private var completed = false
    private var launched = false
    private var timedOut = false
    private var wasCancelled = false

    init(maxOutputBytes: Int) {
        self.maxOutputBytes = maxOutputBytes
    }

    var shouldSkipLaunch: Bool {
        lock.lock()
        defer { lock.unlock() }
        return completed || wasCancelled
    }

    func setContinuation(_ continuation: CheckedContinuation<SystemCommandResult, Never>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func prepare(process: Process, stdoutHandle: FileHandle, stderrHandle: FileHandle) {
        lock.lock()
        self.process = process
        self.stdoutHandle = stdoutHandle
        self.stderrHandle = stderrHandle
        lock.unlock()
    }

    func setTimeoutTask(_ task: Task<Void, Never>) {
        lock.lock()
        if completed || terminatedExitCode != nil {
            lock.unlock()
            task.cancel()
            return
        }
        timeoutTask = task
        lock.unlock()
    }

    func processDidLaunch() {
        lock.lock()
        launched = true
        let shouldTerminate = timedOut || wasCancelled
        let currentProcess = process
        lock.unlock()

        if shouldTerminate {
            terminate(currentProcess)
        }
    }

    func append(_ data: Data, to stream: SystemCommandStream) {
        guard !data.isEmpty else { return }

        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }

        switch stream {
        case .stdout:
            appendBounded(data, to: &stdoutData, truncated: &stdoutTruncated)
        case .stderr:
            appendBounded(data, to: &stderrData, truncated: &stderrTruncated)
        }
        lock.unlock()
    }

    func markStreamEnded(_ stream: SystemCommandStream) {
        lock.lock()
        switch stream {
        case .stdout:
            stdoutEnded = true
        case .stderr:
            stderrEnded = true
        }
        let completion = takeCompletionIfReadyLocked(force: false)
        lock.unlock()
        resume(completion)
    }

    func processDidTerminate(exitCode: Int32) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        terminatedExitCode = exitCode
        process = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        let completion = takeCompletionIfReadyLocked(force: false)
        let needsDrainGrace = completion == nil && drainGraceTask == nil
        lock.unlock()

        resume(completion)

        guard needsDrainGrace else { return }
        let task = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self.forceFinishAfterDrainGrace()
        }
        setDrainGraceTask(task)
    }

    func requestTermination(timedOut: Bool, wasCancelled: Bool) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        self.timedOut = self.timedOut || timedOut
        self.wasCancelled = self.wasCancelled || wasCancelled
        let currentProcess = process
        let processWasLaunched = launched
        lock.unlock()

        if processWasLaunched || currentProcess?.isRunning == true {
            terminate(currentProcess)
        }
    }

    func finishWithoutProcess(exitCode: Int32) {
        lock.lock()
        terminatedExitCode = exitCode
        stdoutEnded = true
        stderrEnded = true
        process = nil
        let completion = takeCompletionIfReadyLocked(force: true)
        lock.unlock()
        resume(completion)
    }

    func launchFailed(_ message: String) {
        lock.lock()
        fallbackStderr = message
        terminatedExitCode = 1
        stdoutEnded = true
        stderrEnded = true
        process = nil
        let completion = takeCompletionIfReadyLocked(force: true)
        lock.unlock()
        resume(completion)
    }

    private func appendBounded(_ data: Data, to buffer: inout Data, truncated: inout Bool) {
        let remainingBytes = maxOutputBytes - buffer.count
        guard remainingBytes > 0 else {
            truncated = true
            return
        }
        if data.count > remainingBytes {
            buffer.append(data.prefix(remainingBytes))
            truncated = true
        } else {
            buffer.append(data)
        }
    }

    private func setDrainGraceTask(_ task: Task<Void, Never>) {
        lock.lock()
        if completed {
            lock.unlock()
            task.cancel()
            return
        }
        if drainGraceTask == nil {
            drainGraceTask = task
            lock.unlock()
        } else {
            lock.unlock()
            task.cancel()
        }
    }

    private func forceFinishAfterDrainGrace() {
        lock.lock()
        let completion = takeCompletionIfReadyLocked(force: true)
        lock.unlock()
        resume(completion)
    }

    private func takeCompletionIfReadyLocked(force: Bool) -> Completion? {
        guard !completed,
              let continuation,
              let exitCode = terminatedExitCode,
              force || (stdoutEnded && stderrEnded)
        else {
            return nil
        }

        completed = true
        self.continuation = nil

        var stderr = String(decoding: stderrData, as: UTF8.self)
        if stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let fallbackStderr {
            stderr = fallbackStderr
        }

        let result = SystemCommandResult(
            exitCode: exitCode,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: stderr,
            timedOut: timedOut,
            wasCancelled: wasCancelled,
            outputTruncated: stdoutTruncated || stderrTruncated
        )

        let completion = Completion(
            continuation: continuation,
            result: result,
            stdoutHandle: stdoutHandle,
            stderrHandle: stderrHandle,
            timeoutTask: timeoutTask,
            drainGraceTask: drainGraceTask
        )
        stdoutHandle = nil
        stderrHandle = nil
        timeoutTask = nil
        drainGraceTask = nil
        process = nil
        return completion
    }

    private func resume(_ completion: Completion?) {
        guard let completion else { return }
        completion.timeoutTask?.cancel()
        completion.drainGraceTask?.cancel()
        completion.stdoutHandle?.readabilityHandler = nil
        completion.stderrHandle?.readabilityHandler = nil
        completion.continuation.resume(returning: completion.result)
    }

    private func terminate(_ process: Process?) {
        guard let process, process.isRunning else { return }
        process.terminate()

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard process.isRunning else { return }
            kill(process.processIdentifier, SIGKILL)
        }
    }
}
