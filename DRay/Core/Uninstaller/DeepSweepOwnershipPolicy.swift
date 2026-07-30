import Foundation

struct DeepSweepOwnershipDecision: Sendable {
    let bundleID: String
    let confidence: UninstallOwnershipConfidence
    let evidence: [UninstallOwnershipEvidence]

    var allowsAutomaticCleanup: Bool {
        confidence == .high
    }
}

enum DeepSweepOwnershipPolicy {
    static func evaluate(
        path rawPath: String,
        candidateBundleIDs: [String],
        installedIdentityBundleIDs: Set<String>,
        receiptBundleIDs: Set<String>
    ) -> DeepSweepOwnershipDecision? {
        let path = URL(fileURLWithPath: rawPath).standardizedFileURL.path
        let normalizedInstalled = Set(installedIdentityBundleIDs.map(normalizedIdentifier))
        let normalizedReceipts = Set(receiptBundleIDs.map(normalizedIdentifier))
        let candidates = Array(Set(candidateBundleIDs.map(normalizedIdentifier)))
            .filter { isEligibleIdentifier($0, installedIdentityBundleIDs: normalizedInstalled) }
        guard !candidates.isEmpty else { return nil }

        let ranked = candidates.map { candidate in
            (
                bundleID: candidate,
                exact: hasExactIdentityComponent(path: path, bundleID: candidate),
                receipt: normalizedReceipts.contains(candidate)
            )
        }
        .sorted { lhs, rhs in
            let leftScore = (lhs.exact ? 2 : 0) + (lhs.receipt ? 1 : 0)
            let rightScore = (rhs.exact ? 2 : 0) + (rhs.receipt ? 1 : 0)
            if leftScore == rightScore {
                return lhs.bundleID < rhs.bundleID
            }
            return leftScore > rightScore
        }

        guard let selected = ranked.first else { return nil }
        let isShared = isSharedOwnershipPath(path)
        let isAmbiguous = candidates.count > 1
        var evidence = [
            UninstallOwnershipEvidence(
                kind: .identifierPattern,
                details: "Path contains identifier \(selected.bundleID)."
            )
        ]
        if selected.exact {
            evidence.append(UninstallOwnershipEvidence(
                kind: .exactPathIdentity,
                details: "A complete path component matches \(selected.bundleID)."
            ))
        }
        if selected.receipt {
            evidence.append(UninstallOwnershipEvidence(
                kind: .packageReceipt,
                details: "A package receipt matches \(selected.bundleID)."
            ))
        }
        if isShared {
            evidence.append(UninstallOwnershipEvidence(
                kind: .sharedContainer,
                details: "The path is in a shared or group-container location."
            ))
        }
        if isAmbiguous {
            evidence.append(UninstallOwnershipEvidence(
                kind: .ambiguousIdentifiers,
                details: "The path contains multiple possible application identities."
            ))
        }

        let confidence: UninstallOwnershipConfidence
        if isShared || isAmbiguous {
            confidence = .low
        } else if selected.exact && selected.receipt {
            confidence = .high
        } else if selected.exact {
            confidence = .medium
        } else {
            confidence = .low
        }

        return DeepSweepOwnershipDecision(
            bundleID: selected.bundleID,
            confidence: confidence,
            evidence: evidence
        )
    }

    private static func isEligibleIdentifier(
        _ bundleID: String,
        installedIdentityBundleIDs: Set<String>
    ) -> Bool {
        guard !installedIdentityBundleIDs.contains(bundleID) else { return false }
        guard !bundleID.hasPrefix("com.apple."),
              !bundleID.hasPrefix("apple."),
              !bundleID.hasPrefix("group.com.apple.") else {
            return false
        }
        return true
    }

    private static func normalizedIdentifier(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .removingPrefix("group.")
    }

    private static func hasExactIdentityComponent(path: String, bundleID: String) -> Bool {
        path.split(separator: "/").contains { rawComponent in
            var component = String(rawComponent).lowercased()
            for suffix in [".plist", ".savedstate", ".cache", ".log"] where component.hasSuffix(suffix) {
                component.removeLast(suffix.count)
                break
            }
            return normalizedIdentifier(component) == bundleID
        }
    }

    private static func isSharedOwnershipPath(_ path: String) -> Bool {
        let lowerPath = path.lowercased()
        return lowerPath.contains("/library/group containers/")
            || lowerPath.contains("/shared/")
            || lowerPath.contains("/shared data/")
    }
}

private extension String {
    func removingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
