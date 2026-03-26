import Foundation

struct InstalledApp: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let bundleID: String
    let appURL: URL
}

struct AppRemnant: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let sizeInBytes: Int64

    var name: String { url.lastPathComponent }
}
