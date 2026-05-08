import SwiftUI

struct RootSidebarView: View {
    @ObservedObject var model: RootViewModel
    let sections: [RootSectionItem]
    let isCollapsed: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            if !isCollapsed {
                HStack(spacing: 8) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [PremiumTheme.secondaryAccent(colorScheme), PremiumTheme.secondaryAccent(colorScheme).opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text("D")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.95))
                        )
                        .frame(width: 20, height: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("DRay")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("Workspace")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sections) { item in
                        PremiumSidebarItem(
                            icon: item.icon,
                            title: model.localizedSectionTitle(for: item.id),
                            isSelected: model.selectedSection == item.id,
                            isCollapsed: isCollapsed
                        ) {
                            withAnimation(.snappy(duration: 0.18)) {
                                model.selectedSection = item.id
                            }
                        }
                        .accessibilityIdentifier("section-tab-\(item.id.rawValue)")
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 6)
            }

            Divider()

            VStack(spacing: 6) {
                if isCollapsed {
                    Text(compactSidebarVersionText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text(model.appVersionDisplay)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                HStack(spacing: 6) {
                    Image(systemName: model.permissions.hasFullDiskAccess ? "checkmark.shield.fill" : "exclamationmark.shield")
                        .foregroundStyle(model.permissions.hasFullDiskAccess ? PremiumTheme.success : PremiumTheme.warning)
                    if !isCollapsed {
                        Text(model.permissions.hasFullDiskAccess ? "Full Disk Access On" : "Full Disk Access Required")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 0 : 8)
            .padding(.bottom, 4)
            .help(model.permissions.hasFullDiskAccess ? "Full Disk Access: On" : "Full Disk Access: Required")
        }
    }

    private var compactSidebarVersionText: String {
        model.appVersionDisplay
            .split(separator: " ")
            .first
            .map(String.init) ?? model.appVersionDisplay
    }
}

struct RootSectionItem: Identifiable {
    let id: AppSection
    let icon: String
}
