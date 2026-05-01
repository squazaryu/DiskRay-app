import SwiftUI

enum PremiumTheme {
    static func appBackground(_ scheme: ColorScheme) -> [Color] {
        scheme == .dark
        ? [Color(red: 0.03, green: 0.05, blue: 0.09), Color(red: 0.06, green: 0.10, blue: 0.16)]
        : [Color(red: 0.94, green: 0.96, blue: 1.00), Color(red: 0.88, green: 0.92, blue: 0.97)]
    }

    static func sidebarBackground(_ scheme: ColorScheme) -> AnyShapeStyle {
        scheme == .dark
        ? AnyShapeStyle(Color.white.opacity(0.025))
        : AnyShapeStyle(Color.white.opacity(0.30))
    }

    static func contentBackground(_ scheme: ColorScheme) -> AnyShapeStyle {
        scheme == .dark
        ? AnyShapeStyle(Color.white.opacity(0.045))
        : AnyShapeStyle(.regularMaterial)
    }

    static func cardBackground(_ scheme: ColorScheme) -> AnyShapeStyle {
        scheme == .dark
        ? AnyShapeStyle(Color.white.opacity(0.05))
        : AnyShapeStyle(Color.white.opacity(0.40))
    }

    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.11) : Color.black.opacity(0.10)
    }

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.cyan : Color.blue
    }

    static func secondaryAccent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.indigo.opacity(0.8) : Color.indigo.opacity(0.7)
    }

    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
}

struct GlassShellBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.drayAccentColor) private var drayAccentColor

    var body: some View {
        ZStack {
            LinearGradient(
                colors: PremiumTheme.appBackground(colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: colorScheme == .dark
                ? [Color(red: 0.08, green: 0.12, blue: 0.20).opacity(0.55), .clear]
                : [Color.white.opacity(0.75), Color(red: 0.82, green: 0.90, blue: 1.0).opacity(0.20)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [drayAccentColor.opacity(colorScheme == .dark ? 0.26 : 0.18), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 560
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [PremiumTheme.secondaryAccent(colorScheme).opacity(colorScheme == .dark ? 0.14 : 0.11), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()

            if colorScheme == .light {
                RadialGradient(
                    colors: [Color.cyan.opacity(0.10), .clear],
                    center: .bottomLeading,
                    startRadius: 30,
                    endRadius: 440
                )
                .ignoresSafeArea()
            }
        }
    }

}

struct GlassSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.drayAccentColor) private var drayAccentColor
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    let cornerRadius: CGFloat
    let strokeOpacity: Double
    let shadowOpacity: Double
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(effectivePadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseFillStyle)
                    .overlay(
                        surfaceOverlay
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor.opacity(strokeOpacity), lineWidth: 0.7)
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.40), lineWidth: 0.6)
                            .blur(radius: 0.3)
                            .allowsHitTesting(false)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? shadowOpacity : shadowOpacity * 0.7), radius: colorScheme == .dark ? 24 : 16, y: 10)
                    .shadow(color: .white.opacity(colorScheme == .dark ? 0.0 : 0.06), radius: 8, x: -1, y: -1)
            )
    }

    private var baseFillStyle: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.white.opacity(0.04))
        }
        return AnyShapeStyle(.regularMaterial)
    }

    private var surfaceOverlay: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.55),
                Color.white.opacity(colorScheme == .dark ? 0.01 : 0.08),
                Color.black.opacity(colorScheme == .dark ? 0.30 : 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RadialGradient(
                colors: [
                    (colorScheme == .dark ? Color.cyan : Color.blue).opacity(colorScheme == .dark ? 0.09 : 0.08),
                    drayAccentColor.opacity(colorScheme == .dark ? 0.08 : 0.07),
                    .clear
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 340
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
        )
        .allowsHitTesting(false)
    }

    private var borderColor: Color {
        PremiumTheme.border(colorScheme)
    }

    private var effectivePadding: CGFloat {
        padding <= 0 ? 0 : max(4, padding * layoutMetrics.surfacePaddingScale)
    }
}

extension View {
    func glassSurface(
        cornerRadius: CGFloat = 18,
        strokeOpacity: Double = 0.14,
        shadowOpacity: Double = 0.15,
        padding: CGFloat = 12
    ) -> some View {
        modifier(GlassSurfaceModifier(
            cornerRadius: cornerRadius,
            strokeOpacity: strokeOpacity,
            shadowOpacity: shadowOpacity,
            padding: padding
        ))
    }
}

private struct DRayAccentColorKey: EnvironmentKey {
    static let defaultValue = Color.blue
}

extension EnvironmentValues {
    var drayAccentColor: Color {
        get { self[DRayAccentColorKey.self] }
        set { self[DRayAccentColorKey.self] = newValue }
    }
}

struct DRayLayoutMetrics {
    let surfacePaddingScale: CGFloat
    let rootSpacing: CGFloat
    let rootPadding: CGFloat
    let sectionSpacing: CGFloat
    let cardSpacing: CGFloat
    let dashboardTileMinHeight: CGFloat
    let metricTileMinHeight: CGFloat
    let bottomStripVerticalPadding: CGFloat
    let controlStripHeight: CGFloat

    static func metrics(for density: AppInterfaceDensity) -> DRayLayoutMetrics {
        switch density {
        case .compact:
            return DRayLayoutMetrics(
                surfacePaddingScale: 0.78,
                rootSpacing: 10,
                rootPadding: 8,
                sectionSpacing: 10,
                cardSpacing: 9,
                dashboardTileMinHeight: 96,
                metricTileMinHeight: 92,
                bottomStripVerticalPadding: 6,
                controlStripHeight: 34
            )
        case .adaptive, .comfortable:
            return DRayLayoutMetrics(
                surfacePaddingScale: 1.0,
                rootSpacing: 14,
                rootPadding: 10,
                sectionSpacing: 14,
                cardSpacing: 12,
                dashboardTileMinHeight: 118,
                metricTileMinHeight: 116,
                bottomStripVerticalPadding: 9,
                controlStripHeight: 40
            )
        }
    }
}

private struct DRayInterfaceDensityKey: EnvironmentKey {
    static let defaultValue: AppInterfaceDensity = .comfortable
}

private struct DRayLayoutMetricsKey: EnvironmentKey {
    static let defaultValue = DRayLayoutMetrics.metrics(for: .comfortable)
}

extension EnvironmentValues {
    var drayInterfaceDensity: AppInterfaceDensity {
        get { self[DRayInterfaceDensityKey.self] }
        set { self[DRayInterfaceDensityKey.self] = newValue }
    }

    var drayLayoutMetrics: DRayLayoutMetrics {
        get { self[DRayLayoutMetricsKey.self] }
        set { self[DRayLayoutMetricsKey.self] = newValue }
    }
}

private struct ShowFeatureHeaderKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var showFeatureHeader: Bool {
        get { self[ShowFeatureHeaderKey.self] }
        set { self[ShowFeatureHeaderKey.self] = newValue }
    }
}

struct ModuleHeaderCard<Actions: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.showFeatureHeader) private var showFeatureHeader
    @Environment(\.drayInterfaceDensity) private var density
    let title: String
    let subtitle: String
    @ViewBuilder let actions: Actions

    var body: some View {
        Group {
            if showFeatureHeader {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font((density == .compact ? Font.headline : Font.title3).weight(.semibold))
                            .lineLimit(1)
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    actions
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            } else {
                EmptyView()
            }
        }
    }
}

struct DRayLogoMark: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.drayAccentColor) private var drayAccentColor
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: logoGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.58), lineWidth: 0.8)
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.30))
                        .frame(width: size * 0.42, height: size * 0.15)
                        .blur(radius: size * 0.12)
                        .offset(x: size * 0.12, y: size * 0.08)
                }
                .shadow(color: drayAccentColor.opacity(colorScheme == .dark ? 0.24 : 0.18), radius: size * 0.22, y: size * 0.10)

            Text("D")
                .font(.system(size: size * 0.60, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var logoGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.08, green: 0.78, blue: 1.00),
                drayAccentColor.opacity(0.96),
                Color.indigo.opacity(0.92)
            ]
        }

        return [
            Color(red: 0.30, green: 0.88, blue: 1.00),
            drayAccentColor.opacity(0.94),
            Color.indigo.opacity(0.88)
        ]
    }
}

struct DRayProgressBar: View {
    let value: Double
    var tint: Color = .blue
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(1, max(0, value))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.14))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, proxy.size.width * clamped))
            }
        }
        .frame(height: height)
    }
}

struct DRayMetricTile: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    var tint: Color = .blue
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing - 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(colorScheme == .dark ? 0.18 : 0.13), in: Circle())
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let progress {
                DRayProgressBar(value: progress, tint: tint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: layoutMetrics.metricTileMinHeight, alignment: .topLeading)
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.08, shadowOpacity: 0.05, padding: 0)
    }
}

struct DRayBottomStatusStrip: View {
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    let items: [Item]

    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let icon: String
        var tint: Color = .blue
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 9) {
                    Image(systemName: item.icon)
                        .foregroundStyle(item.tint)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 6)
                }
                .padding(.horizontal, layoutMetrics.cardSpacing)
                if index < items.count - 1 {
                    Divider()
                        .opacity(0.45)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.08, shadowOpacity: 0.04, padding: 0)
    }
}

struct DRayLiquidStatusRing: View {
    let icon: String
    var tint: Color = .blue
    var size: CGFloat = 132

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.24), lineWidth: 18)
            Circle()
                .trim(from: 0.08, to: 0.88)
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.95), Color.cyan.opacity(0.78), tint.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-120))
            Circle()
                .fill(.ultraThinMaterial)
                .padding(22)
                .shadow(color: tint.opacity(0.20), radius: 18)
            Image(systemName: icon)
                .font(.system(size: size * 0.28, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

struct PremiumSidebarItem: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.drayAccentColor) private var drayAccentColor
    let icon: String
    let title: String
    let isSelected: Bool
    var isCollapsed: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: isCollapsed ? 0 : 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 20)
                if !isCollapsed {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 0 : 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected
                          ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    drayAccentColor.opacity(colorScheme == .dark ? 0.32 : 0.22),
                                    PremiumTheme.secondaryAccent(colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                          )
                          : PremiumTheme.sidebarBackground(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PremiumTheme.border(colorScheme).opacity(isSelected ? 0.4 : 0.18), lineWidth: 0.8)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

struct WorkspaceSegmentBar<Selection: Hashable>: View {
    let title: String
    @Binding var selection: Selection
    let segments: [(Selection, String)]

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.headline)
            Spacer(minLength: 8)
            Picker("", selection: $selection) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Text(segment.1).tag(segment.0)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 560)
        }
    }
}

struct GlassPillBadge: View {
    let title: String
    var tint: Color = .blue

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.28), lineWidth: 0.8)
            )
    }
}

struct DRayCompactInfoTile: View {
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    var tint: Color = .blue
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                DRayIconBadge(icon: icon, tint: tint, size: 24)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: layoutMetrics.dashboardTileMinHeight < 110 ? 18 : 21, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let progress {
                DRayProgressBar(value: progress, tint: tint, height: 5)
            }
        }
        .frame(maxWidth: .infinity, minHeight: layoutMetrics.dashboardTileMinHeight < 110 ? 72 : 84, alignment: .topLeading)
        .padding(layoutMetrics.cardSpacing)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 0.7)
        )
    }
}

struct DRayActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var tint: Color = .blue
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                DRayIconBadge(icon: icon, tint: tint, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(actionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.65))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MinimalGlassButtonStyle: ButtonStyle {
    let isActive: Bool
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive
                          ? AnyShapeStyle(
                            LinearGradient(
                                colors: colorScheme == .dark
                                ? [Color.cyan.opacity(0.30), Color.blue.opacity(0.22)]
                                : [Color.white.opacity(0.92), Color.blue.opacity(0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                          )
                          : AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.02 : 0.10)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(strokeColor.opacity(isActive ? 0.26 : 0.08), lineWidth: 0.7)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var strokeColor: Color {
        colorScheme == .dark ? Color.white : Color.blue
    }
}
