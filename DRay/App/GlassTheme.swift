import SwiftUI

enum DRaySurfaceLevel {
    case window
    case panelShell
    case moduleHeader
    case section
    case card
    case nestedCard
    case selected
    case critical
}

enum DRaySemanticTone {
    case neutral
    case accent
    case success
    case warning
    case danger
    case info
    case purple

    var foreground: Color {
        switch self {
        case .neutral: return .secondary
        case .accent: return .accentColor
        case .success: return .green
        case .warning: return .orange
        case .danger: return .red
        case .info: return .blue
        case .purple: return .purple
        }
    }

    var softFill: Color {
        switch self {
        case .neutral: return Color.primary.opacity(0.045)
        case .accent: return Color.accentColor.opacity(0.075)
        case .success: return Color.green.opacity(0.075)
        case .warning: return Color.orange.opacity(0.085)
        case .danger: return Color.red.opacity(0.085)
        case .info: return Color.blue.opacity(0.065)
        case .purple: return Color.purple.opacity(0.065)
        }
    }

    var softBorder: Color {
        foreground.opacity(0.18)
    }
}

enum PremiumTheme {
    static func appBackground(_ scheme: ColorScheme) -> [Color] {
        scheme == .dark
        ? [Color(red: 0.034, green: 0.038, blue: 0.046), Color(red: 0.052, green: 0.058, blue: 0.070)]
        : [Color(red: 0.972, green: 0.976, blue: 0.982), Color(red: 0.940, green: 0.950, blue: 0.962)]
    }

    static func sidebarBackground(_ scheme: ColorScheme) -> AnyShapeStyle {
        scheme == .dark
        ? AnyShapeStyle(Color.white.opacity(0.020))
        : AnyShapeStyle(Color.white.opacity(0.22))
    }

    static func contentBackground(_ scheme: ColorScheme) -> AnyShapeStyle {
        scheme == .dark
        ? AnyShapeStyle(Color.white.opacity(0.036))
        : AnyShapeStyle(.thinMaterial)
    }

    static func cardBackground(_ scheme: ColorScheme) -> AnyShapeStyle {
        scheme == .dark
        ? AnyShapeStyle(Color.white.opacity(0.038))
        : AnyShapeStyle(Color.white.opacity(0.30))
    }

    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.085) : Color.black.opacity(0.075)
    }

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.45, green: 0.63, blue: 0.82) : Color(red: 0.23, green: 0.42, blue: 0.66)
    }

    static func secondaryAccent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.42, green: 0.45, blue: 0.54) : Color(red: 0.48, green: 0.52, blue: 0.60)
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
                ? [Color.white.opacity(0.035), .clear]
                : [Color.white.opacity(0.48), Color(red: 0.88, green: 0.91, blue: 0.94).opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [drayAccentColor.opacity(colorScheme == .dark ? 0.045 : 0.030), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 560
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [PremiumTheme.secondaryAccent(colorScheme).opacity(colorScheme == .dark ? 0.030 : 0.022), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()
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
                            .stroke(borderColor.opacity(min(strokeOpacity, 0.075)), lineWidth: 0.6)
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.030 : 0.12), lineWidth: 0.45)
                            .allowsHitTesting(false)
                    )
                    .shadow(color: .black.opacity(calmedShadowOpacity), radius: shadowRadius, y: shadowY)
            )
    }

    private var baseFillStyle: AnyShapeStyle {
        if shadowOpacity <= 0.04 || cornerRadius <= 12 {
            return AnyShapeStyle(Color.primary.opacity(colorScheme == .dark ? 0.038 : 0.020))
        }
        if shadowOpacity >= 0.08 || cornerRadius >= 20 {
            return AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.040) : Color.white.opacity(0.26))
        }
        return AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.034) : Color.white.opacity(0.22))
    }

    private var surfaceOverlay: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.030 : 0.095),
                Color.white.opacity(colorScheme == .dark ? 0.006 : 0.020),
                Color.black.opacity(colorScheme == .dark ? 0.045 : 0.010)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }

    private var borderColor: Color {
        PremiumTheme.border(colorScheme)
    }

    private var effectivePadding: CGFloat {
        padding <= 0 ? 0 : max(4, padding * layoutMetrics.surfacePaddingScale)
    }

    private var calmedShadowOpacity: Double {
        min(shadowOpacity, colorScheme == .dark ? 0.055 : 0.026)
    }

    private var shadowRadius: CGFloat {
        shadowOpacity <= 0.04 ? 2 : (shadowOpacity >= 0.08 ? 7 : 4)
    }

    private var shadowY: CGFloat {
        shadowOpacity <= 0.04 ? 1 : (shadowOpacity >= 0.08 ? 3 : 2)
    }
}

struct DRayCalmGlassModifier: ViewModifier {
    let level: DRaySurfaceLevel
    var cornerRadius: CGFloat = 18
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(background)
            .overlay(border)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        switch level {
        case .window:
            Color.clear
        case .panelShell:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.040) : Color.white.opacity(0.27))
        case .moduleHeader:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.038) : Color.white.opacity(0.24))
        case .section:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.032) : Color.white.opacity(0.20))
        case .card:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.028) : Color.white.opacity(0.16))
        case .nestedCard:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.038 : 0.022))
        case .selected:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.080 : 0.052))
        case .critical:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.red.opacity(colorScheme == .dark ? 0.090 : 0.060))
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(borderColor, lineWidth: 0.8)
            .allowsHitTesting(false)
    }

    private var borderColor: Color {
        switch level {
        case .window:
            return .clear
        case .moduleHeader:
            return Color.white.opacity(colorScheme == .dark ? 0.075 : 0.17)
        case .panelShell, .section:
            return Color.primary.opacity(0.065)
        case .card:
            return Color.primary.opacity(0.052)
        case .nestedCard:
            return Color.primary.opacity(0.040)
        case .selected:
            return Color.accentColor.opacity(0.18)
        case .critical:
            return Color.red.opacity(0.20)
        }
    }

    private var shadowColor: Color {
        switch level {
        case .panelShell, .moduleHeader:
            return Color.black.opacity(colorScheme == .dark ? 0.070 : 0.028)
        case .section:
            return Color.black.opacity(colorScheme == .dark ? 0.050 : 0.020)
        case .card:
            return Color.black.opacity(colorScheme == .dark ? 0.030 : 0.012)
        case .nestedCard, .selected, .critical, .window:
            return .clear
        }
    }

    private var shadowRadius: CGFloat {
        switch level {
        case .panelShell, .moduleHeader: return 8
        case .section: return 5
        case .card: return 2
        default: return 0
        }
    }

    private var shadowY: CGFloat {
        switch level {
        case .panelShell, .moduleHeader: return 3
        case .section: return 2
        case .card: return 1
        default: return 0
        }
    }
}

extension View {
    func glassSurface(
        cornerRadius: CGFloat = 18,
        strokeOpacity: Double = 0.08,
        shadowOpacity: Double = 0.06,
        padding: CGFloat = 12
    ) -> some View {
        modifier(GlassSurfaceModifier(
            cornerRadius: cornerRadius,
            strokeOpacity: strokeOpacity,
            shadowOpacity: shadowOpacity,
            padding: padding
        ))
    }

    func calmGlass(_ level: DRaySurfaceLevel, cornerRadius: CGFloat = 18) -> some View {
        modifier(DRayCalmGlassModifier(level: level, cornerRadius: cornerRadius))
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
                dashboardTileMinHeight: 74,
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
                dashboardTileMinHeight: 84,
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
    @Environment(\.drayLayoutMetrics) private var layoutMetrics
    let title: String
    let subtitle: String
    @ViewBuilder let actions: Actions

    var body: some View {
        Group {
            if showFeatureHeader {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        headerText
                        Spacer(minLength: 12)
                        actions
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        headerText
                        HStack {
                            Spacer(minLength: 0)
                            actions
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(max(8, layoutMetrics.bottomStripVerticalPadding + 2))
                .calmGlass(.moduleHeader, cornerRadius: 18)
            } else {
                EmptyView()
            }
        }
    }

    private var headerText: some View {
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
                    .fill(Color.secondary.opacity(0.12))
                Capsule()
                    .fill(tint.opacity(0.46))
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
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint.opacity(colorScheme == .dark ? 0.58 : 0.46))
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, max(7, layoutMetrics.cardSpacing - 4))
        .calmGlass(.card, cornerRadius: 14)
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    statusItemView(item)
                        .padding(.horizontal, layoutMetrics.cardSpacing)
                    if index < items.count - 1 {
                        Divider()
                            .opacity(0.45)
                    }
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)],
                spacing: 8
            ) {
                ForEach(items) { item in
                    statusItemView(item)
                }
            }
            .padding(.horizontal, layoutMetrics.cardSpacing)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, layoutMetrics.bottomStripVerticalPadding)
        .calmGlass(.section, cornerRadius: 14)
    }

    private func statusItemView(_ item: Item) -> some View {
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
    }
}

struct DRayLiquidStatusRing: View {
    let icon: String
    var tint: Color = .blue
    var size: CGFloat = 132
    var progress: Double = 0.98

    private var clampedProgress: Double {
        min(max(progress, 0.08), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.055), lineWidth: 14)
            Circle()
                .trim(from: 0.005, to: 0.005 + (0.98 * clampedProgress))
                .stroke(
                    tint.opacity(0.48),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-120))
            Circle()
                .fill(Color.primary.opacity(0.026))
                .padding(22)
            Image(systemName: icon)
                .font(.system(size: size * 0.28, weight: .semibold))
                .foregroundStyle(tint.opacity(0.76))
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
                          ? AnyShapeStyle(drayAccentColor.opacity(colorScheme == .dark ? 0.095 : 0.055))
                          : PremiumTheme.sidebarBackground(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PremiumTheme.border(colorScheme).opacity(isSelected ? 0.22 : 0.10), lineWidth: 0.7)
                    )
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(drayAccentColor.opacity(colorScheme == .dark ? 0.62 : 0.52))
                        .frame(width: 3)
                        .padding(.vertical, 7)
                }
            }
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
            .background(tint.opacity(0.055), in: Capsule())
            .foregroundStyle(tint.opacity(0.78))
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.14), lineWidth: 0.7)
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
        HStack(alignment: .center, spacing: 9) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint.opacity(0.54))
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, layoutMetrics.cardSpacing)
        .padding(.vertical, max(7, layoutMetrics.cardSpacing - 4))
        .calmGlass(.nestedCard, cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.045), lineWidth: 0.7)
        )
    }
}

struct DRayQuietIconBadge: View {
    let systemName: String
    var tone: DRaySemanticTone = .neutral
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(tone.softFill)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .strokeBorder(tone.softBorder, lineWidth: 0.8)
                )

            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(tone.foreground)
        }
        .frame(width: size, height: size)
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
            .calmGlass(.nestedCard, cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.050), lineWidth: 0.7)
            )
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
                          ? AnyShapeStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.13 : 0.08))
                          : AnyShapeStyle(Color.primary.opacity(colorScheme == .dark ? 0.030 : 0.040)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(strokeColor.opacity(isActive ? 0.22 : 0.07), lineWidth: 0.7)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var strokeColor: Color {
        colorScheme == .dark ? Color.white : Color.accentColor
    }
}

struct DRayPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(metrics.font)
            .lineLimit(1)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.8)
            )
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }

    private func fillColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.primary.opacity(colorScheme == .dark ? 0.034 : 0.026)
        }
        return Color.accentColor.opacity((colorScheme == .dark ? 0.145 : 0.105) + (isPressed ? 0.035 : 0))
    }

    private var borderColor: Color {
        isEnabled
        ? Color.accentColor.opacity(colorScheme == .dark ? 0.26 : 0.22)
        : Color.primary.opacity(colorScheme == .dark ? 0.060 : 0.045)
    }

    private var metrics: DRayButtonMetrics {
        DRayButtonMetrics(controlSize: controlSize)
    }
}

struct DRaySecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(metrics.font)
            .lineLimit(1)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.8)
            )
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .opacity(configuration.isPressed ? 0.90 : 1)
    }

    private func fillColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.primary.opacity(colorScheme == .dark ? 0.030 : 0.022)
        }
        return Color.primary.opacity((colorScheme == .dark ? 0.050 : 0.038) + (isPressed ? 0.030 : 0))
    }

    private var borderColor: Color {
        isEnabled
        ? Color.primary.opacity(colorScheme == .dark ? 0.085 : 0.065)
        : Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.042)
    }

    private var metrics: DRayButtonMetrics {
        DRayButtonMetrics(controlSize: controlSize)
    }
}

struct DRayDangerButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(metrics.font)
            .lineLimit(1)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.8)
            )
            .foregroundStyle(isEnabled ? Color.red : Color.secondary)
            .opacity(configuration.isPressed ? 0.90 : 1)
    }

    private func fillColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.primary.opacity(colorScheme == .dark ? 0.030 : 0.022)
        }
        return Color.red.opacity((colorScheme == .dark ? 0.105 : 0.080) + (isPressed ? 0.035 : 0))
    }

    private var borderColor: Color {
        isEnabled
        ? Color.red.opacity(colorScheme == .dark ? 0.26 : 0.22)
        : Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.042)
    }

    private var metrics: DRayButtonMetrics {
        DRayButtonMetrics(controlSize: controlSize)
    }
}

private struct DRayButtonMetrics {
    let font: Font
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    init(controlSize: ControlSize) {
        switch controlSize {
        case .mini:
            font = .system(size: 10, weight: .semibold)
            horizontalPadding = 7
            verticalPadding = 3
        case .small:
            font = .system(size: 11, weight: .semibold)
            horizontalPadding = 9
            verticalPadding = 5
        case .regular:
            font = .caption.weight(.semibold)
            horizontalPadding = 12
            verticalPadding = 7
        case .large:
            font = .callout.weight(.semibold)
            horizontalPadding = 14
            verticalPadding = 8
        case .extraLarge:
            font = .callout.weight(.semibold)
            horizontalPadding = 16
            verticalPadding = 9
        @unknown default:
            font = .caption.weight(.semibold)
            horizontalPadding = 12
            verticalPadding = 7
        }
    }
}
