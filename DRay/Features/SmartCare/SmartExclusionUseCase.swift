import Foundation

struct SmartExclusionState {
    let excludedPaths: [String]
    let excludedAnalyzerKeys: [String]
}

struct SmartExclusionUseCase {
    private let userDefaults: UserDefaults
    private let pathsKey: String
    private let analyzerKeysKey: String

    init(
        userDefaults: UserDefaults = .standard,
        pathsKey: String = "dray.smart.exclusions",
        analyzerKeysKey: String = "dray.smart.analyzer.exclusions"
    ) {
        self.userDefaults = userDefaults
        self.pathsKey = pathsKey
        self.analyzerKeysKey = analyzerKeysKey
    }

    func loadState() -> SmartExclusionState {
        SmartExclusionState(
            excludedPaths: userDefaults.stringArray(forKey: pathsKey) ?? [],
            excludedAnalyzerKeys: userDefaults.stringArray(forKey: analyzerKeysKey) ?? []
        )
    }

    func addPath(_ path: String, to currentPaths: [String]) -> [String] {
        let normalized = normalize(path)
        guard !normalized.isEmpty else { return currentPaths }
        guard !currentPaths.contains(normalized) else { return currentPaths }
        var updated = currentPaths
        updated.append(normalized)
        updated.sort()
        persistPaths(updated)
        return updated
    }

    func removePath(_ path: String, from currentPaths: [String]) -> [String] {
        let normalized = normalize(path)
        guard !normalized.isEmpty else { return currentPaths }
        let updated = currentPaths.filter { $0 != normalized }
        persistPaths(updated)
        return updated
    }

    func togglePath(_ path: String, currentPaths: [String]) -> [String] {
        let normalized = normalize(path)
        guard !normalized.isEmpty else { return currentPaths }
        if currentPaths.contains(normalized) {
            return removePath(normalized, from: currentPaths)
        }
        return addPath(normalized, to: currentPaths)
    }

    func toggleAnalyzer(_ analyzerKey: String, currentAnalyzerKeys: [String]) -> [String] {
        guard !analyzerKey.isEmpty else { return currentAnalyzerKeys }
        let updated: [String]
        if currentAnalyzerKeys.contains(analyzerKey) {
            updated = currentAnalyzerKeys.filter { $0 != analyzerKey }
        } else {
            updated = (currentAnalyzerKeys + [analyzerKey]).sorted()
        }
        userDefaults.set(updated, forKey: analyzerKeysKey)
        return updated
    }

    private func normalize(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func persistPaths(_ paths: [String]) {
        userDefaults.set(paths, forKey: pathsKey)
    }
}
