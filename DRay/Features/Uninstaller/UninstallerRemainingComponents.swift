import AppKit
import SwiftUI

struct UninstallerRemainingIssuePresentation: Identifiable {
    let issue: UninstallRemainingIssueRecord
    let categoryTitle: String
    let categoryTint: Color
    let nextStep: String

    var id: UUID { issue.id }
}

struct UninstallerRemainingRecordCard: View {
    let record: UninstallRemainingRecord
    let issues: [UninstallerRemainingIssuePresentation]
    let onCleanVerified: () -> Void
    let onRemoveRecord: () -> Void

    private var automaticIssueCount: Int {
        record.issues.filter(\.allowsAutomaticCleanup).count
    }

    private var reviewOnlyCount: Int {
        record.issues.count - automaticIssueCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.appName)
                        .font(.subheadline.bold())
                    Text("Updated \(record.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                GlassPillBadge(title: "\(record.remainingCount) remaining", tint: .orange)
                GlassPillBadge(
                    title: ByteCountFormatter.string(
                        fromByteCount: record.totalSizeInBytes,
                        countStyle: .file
                    ),
                    tint: .indigo
                )
                if reviewOnlyCount > 0 {
                    GlassPillBadge(title: "\(reviewOnlyCount) review", tint: .orange)
                }
            }

            VStack(spacing: 6) {
                ForEach(issues.prefix(10)) { presentation in
                    UninstallerRemainingIssueRow(presentation: presentation)
                }
                if issues.count > 10 {
                    Text("+\(issues.count - 10) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            HStack(spacing: 8) {
                Button(
                    reviewOnlyCount > 0 ? "Clean Verified" : "Clean Remaining",
                    role: .destructive,
                    action: onCleanVerified
                )
                .buttonStyle(DRayDangerButtonStyle())
                .disabled(automaticIssueCount == 0)

                Button("Remove Record", role: .destructive, action: onRemoveRecord)
                    .buttonStyle(DRayDangerButtonStyle())
            }

            if reviewOnlyCount > 0 {
                Text("Low and medium confidence Deep Sweep candidates are review-only and excluded from batch cleanup. Reveal the item to verify ownership before taking action.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .calmGlass(.nestedCard, cornerRadius: 12)
    }
}

private struct UninstallerRemainingIssueRow: View {
    let presentation: UninstallerRemainingIssuePresentation

    private var issue: UninstallRemainingIssueRecord {
        presentation.issue
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(riskTitle)
                .font(.caption2.bold())
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(riskTint.opacity(0.14), in: Capsule())
                .foregroundStyle(riskTint)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(issue.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(issue.reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(presentation.nextStep)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(presentation.categoryTint)
                    .lineLimit(2)
                if let confidence = issue.ownershipConfidence {
                    Text("Ownership confidence: \(confidence.rawValue.capitalized)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(confidenceTint(confidence))
                    ForEach(issue.ownershipEvidence, id: \.self) { evidence in
                        Text("• \(evidence.details)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(presentation.categoryTitle)
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(presentation.categoryTint.opacity(0.14), in: Capsule())
                    .foregroundStyle(presentation.categoryTint)
                Text(ByteCountFormatter.string(
                    fromByteCount: issue.sizeInBytes,
                    countStyle: .file
                ))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

                Button("Reveal") {
                    NSWorkspace.shared.activateFileViewerSelecting([issue.url])
                }
                .buttonStyle(DRaySecondaryButtonStyle())
                .controlSize(.mini)

                Button("Copy Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(issue.path, forType: .string)
                }
                .buttonStyle(.borderless)
                .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .calmGlass(.nestedCard, cornerRadius: 10)
    }

    private var riskTitle: String {
        switch issue.risk {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    private var riskTint: Color {
        switch issue.risk {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func confidenceTint(_ confidence: UninstallOwnershipConfidence) -> Color {
        switch confidence {
        case .low: return .orange
        case .medium: return .yellow
        case .high: return .green
        }
    }
}
