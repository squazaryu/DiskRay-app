import Foundation
import Testing
@testable import DRay

struct IncrementalTreeMergeUseCaseTests {
    @Test
    func mergeUpdatesExistingNodesAndAddsNewOnes() {
        let useCase = IncrementalTreeMergeUseCase()
        let base = node(
            "/",
            150,
            children: [
                node("/A", 100, children: [node("/A/a1", 100)]),
                node("/B", 50)
            ]
        )
        let delta = node(
            "/",
            0,
            children: [
                node("/", 999), // must be ignored as root self-path child
                node("/A", 200, children: [node("/A/a1", 120), node("/A/a2", 30)]),
                node("/C", 70)
            ]
        )

        let merged = useCase.merge(base: base, delta: delta)

        #expect(merged.children.count == 3)
        #expect(merged.children.map(\.url.path) == ["/A", "/C", "/B"])
        #expect(merged.sizeInBytes == 320)

        let a = merged.children.first { $0.url.path == "/A" }
        #expect(a?.sizeInBytes == 200)
        #expect(a?.children.map(\.url.path) == ["/A/a1", "/A/a2"])
        #expect(a?.children.first?.sizeInBytes == 120)
    }

    @Test
    func mergeKeepsExistingSizeWhenDeltaSizeIsZero() {
        let useCase = IncrementalTreeMergeUseCase()
        let base = node(
            "/",
            50,
            children: [
                node("/B", 50, children: [node("/B/b1", 10)])
            ]
        )
        let delta = node(
            "/",
            0,
            children: [
                node("/B", 0, children: [node("/B/b2", 5)])
            ]
        )

        let merged = useCase.merge(base: base, delta: delta)
        let b = merged.children.first

        #expect(merged.sizeInBytes == 50)
        #expect(b?.sizeInBytes == 50)
        #expect(b?.children.map(\.url.path) == ["/B/b1", "/B/b2"])
    }

    private func node(_ path: String, _ size: Int64, children: [FileNode] = []) -> FileNode {
        FileNode(
            url: URL(fileURLWithPath: path),
            name: URL(fileURLWithPath: path).lastPathComponent.isEmpty ? "root" : URL(fileURLWithPath: path).lastPathComponent,
            isDirectory: true,
            sizeInBytes: size,
            children: children
        )
    }
}
