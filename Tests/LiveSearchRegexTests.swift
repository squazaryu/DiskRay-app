import Foundation
import Testing
@testable import DRay

struct LiveSearchRegexTests {
    @Test
    func invalidRegexThrowsValidationError() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Data("payload".utf8).write(to: tempDir.appendingPathComponent("sample.txt"))

        let service = LiveSearchService(commandRunner: SystemCommandRunner { _ in
            SystemCommandResult(exitCode: 0, stdout: "", stderr: "", timedOut: false, wasCancelled: false)
        })

        do {
            _ = try await service.search(request(rootURL: tempDir, query: "[", useRegex: true))
            #expect(Bool(false), "Invalid regex should throw")
        } catch let error as LiveSearchValidationError {
            #expect(error == .invalidRegularExpression)
        }
    }

    @Test
    func validRegexStillMatchesEnumeratorResults() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Data("payload".utf8).write(to: tempDir.appendingPathComponent("dray-target-file.txt"))

        let service = LiveSearchService(commandRunner: SystemCommandRunner { _ in
            SystemCommandResult(exitCode: 0, stdout: "", stderr: "", timedOut: false, wasCancelled: false)
        })

        let results = try await service.search(
            request(rootURL: tempDir, query: #"dray-target-.*\.txt"#, useRegex: true)
        )

        #expect(results.map(\.name).contains("dray-target-file.txt"))
    }

    @MainActor
    @Test
    func controllerShowsInvalidRegexMessageWithoutSubstringFallback() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Data("payload".utf8).write(to: tempDir.appendingPathComponent("sample.txt"))

        let controller = SearchFeatureController(
            selectedTargetURL: tempDir,
            liveSearchService: LiveSearchService(),
            searchPresetUseCase: SearchPresetUseCase(
                store: SearchPresetStore(
                    historyStore: OperationalHistoryStore(directoryURL: tempDir)
                )
            )
        )

        controller.update(\.query, value: "[")
        controller.update(\.useRegex, value: true)
        controller.update(\.scopeMode, value: .selectedTarget)
        controller.runSearch()

        let timeout = Date().addingTimeInterval(3)
        while controller.state.isLiveRunning, Date() < timeout {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(controller.state.validationMessage == "Invalid regular expression")
        #expect(controller.state.results.isEmpty)
    }

    private func request(rootURL: URL, query: String, useRegex: Bool) -> LiveSearchRequest {
        LiveSearchRequest(
            rootURL: rootURL,
            query: query,
            mode: .deep,
            useRegex: useRegex,
            pathContains: "",
            ownerContains: "",
            minSizeBytes: 0,
            depthMin: 0,
            depthMax: 64,
            modifiedWithinDays: nil,
            nodeType: .any,
            onlyDirectories: false,
            onlyFiles: false,
            excludeTrash: true,
            includeHidden: true,
            includePackageContents: true,
            limit: 100
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dray-live-search-regex-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
