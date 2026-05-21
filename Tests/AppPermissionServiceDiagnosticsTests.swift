import Foundation
import Testing
@testable import DRay

struct AppPermissionServiceDiagnosticsTests {
    @Test
    func fullDiskDiagnosticReportsLikelyGrantedWhenProbeIsReadable() throws {
        let file = try makeProbeFile(named: "readable.db")

        let report = AppPermissionService.evaluateFullDiskAccessDiagnostic(
            candidates: [file],
            readProbe: { _ in FullDiskAccessReadResult(readable: true) }
        )

        #expect(report.status == .likelyGranted)
        #expect(report.likelyGranted)
        #expect(report.probes[0].exists)
        #expect(report.probes[0].readable)
        #expect(!report.probes[0].denied)
    }

    @Test
    func fullDiskDiagnosticReportsLikelyMissingWhenExistingProbeIsDenied() throws {
        let file = try makeProbeFile(named: "denied.db")

        let report = AppPermissionService.evaluateFullDiskAccessDiagnostic(
            candidates: [file],
            readProbe: { _ in FullDiskAccessReadResult(readable: false, errorDescription: "Operation not permitted") }
        )

        #expect(report.status == .likelyMissing)
        #expect(!report.likelyGranted)
        #expect(report.probes[0].exists)
        #expect(!report.probes[0].readable)
        #expect(report.probes[0].denied)
        #expect(report.probes[0].errorDescription == "Operation not permitted")
    }

    @Test
    func fullDiskDiagnosticReportsPartialWhenSomeProbesReadAndSomeDeny() throws {
        let readable = try makeProbeFile(named: "readable.db")
        let denied = try makeProbeFile(named: "denied.db")

        let report = AppPermissionService.evaluateFullDiskAccessDiagnostic(
            candidates: [readable, denied],
            readProbe: { url in
                url.lastPathComponent == "readable.db"
                    ? FullDiskAccessReadResult(readable: true)
                    : FullDiskAccessReadResult(readable: false, errorDescription: "denied")
            }
        )

        #expect(report.status == .partial)
        #expect(report.likelyGranted)
        #expect(report.probes.filter(\.readable).count == 1)
        #expect(report.probes.filter(\.denied).count == 1)
    }

    @Test
    func fullDiskDiagnosticReportsUnknownWhenAllProbesAreMissing() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("dray-missing-probe-\(UUID().uuidString).db")

        let report = AppPermissionService.evaluateFullDiskAccessDiagnostic(
            candidates: [missing],
            readProbe: { _ in FullDiskAccessReadResult(readable: true) }
        )

        #expect(report.status == .unknown)
        #expect(!report.likelyGranted)
        #expect(report.probes[0].exists == false)
        #expect(report.probes[0].denied == false)
    }

    private func makeProbeFile(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dray-permission-probes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name)
        try Data("probe".utf8).write(to: file)
        return file
    }
}
