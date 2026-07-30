import Foundation
import Testing
@testable import DRay

@Suite("SystemCommandRunnerTests")
struct SystemCommandRunnerTests {
    @Test
    func drainsLargeStdoutWithoutPipeDeadlock() async {
        let result = await SystemCommandRunner.live.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "/usr/bin/yes 0123456789 | /usr/bin/head -c 1048576"],
            timeoutSeconds: 5,
            maxOutputBytes: 2 * 1_024 * 1_024
        )

        #expect(result.succeeded)
        #expect(result.stdout.utf8.count == 1_048_576)
        #expect(!result.outputTruncated)
    }

    @Test
    func boundsCapturedOutputAndReportsTruncation() async {
        let result = await SystemCommandRunner.live.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "/usr/bin/yes output | /usr/bin/head -c 131072"],
            timeoutSeconds: 5,
            maxOutputBytes: 4_096
        )

        #expect(result.succeeded)
        #expect(result.stdout.utf8.count == 4_096)
        #expect(result.outputTruncated)
    }

    @Test
    func timeoutTerminatesCommand() async {
        let clock = ContinuousClock()
        let startedAt = clock.now
        let result = await SystemCommandRunner.live.run(
            executablePath: "/bin/sleep",
            arguments: ["5"],
            timeoutSeconds: 0.05
        )
        let elapsed = startedAt.duration(to: clock.now)

        #expect(result.timedOut)
        #expect(!result.wasCancelled)
        #expect(elapsed < .seconds(2))
    }

    @Test
    func cancellationTerminatesCommand() async {
        let task = Task {
            await SystemCommandRunner.live.run(
                executablePath: "/bin/sleep",
                arguments: ["5"],
                timeoutSeconds: 10
            )
        }
        try? await Task.sleep(for: .milliseconds(40))
        task.cancel()

        let result = await task.value
        #expect(result.wasCancelled)
        #expect(!result.timedOut)
    }

    @Test
    func cancellationBeforeLaunchReturnsWithoutRunningCommand() async {
        let task = Task {
            await SystemCommandRunner.live.run(
                executablePath: "/bin/sleep",
                arguments: ["5"],
                timeoutSeconds: 10
            )
        }
        task.cancel()

        let result = await task.value
        #expect(result.wasCancelled)
        #expect(!result.timedOut)
    }
}
