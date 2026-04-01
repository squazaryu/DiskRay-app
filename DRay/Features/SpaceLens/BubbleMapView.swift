import SwiftUI

enum BubbleTapMode: String, CaseIterable, Identifiable {
    case select
    case openFolders

    var id: String { rawValue }
    var title: String {
        switch self {
        case .select: return "Select"
        case .openFolders: return "Open folders"
        }
    }
}

struct BubbleMapView: View {
    let root: FileNode
    @Binding var hoveredPath: String?
    @Binding var selectedPaths: Set<String>
    @Binding var tapMode: BubbleTapMode
    let language: AppLanguage
    @Environment(\.colorScheme) private var colorScheme
    @State private var navigation: [FileNode] = []
    @State private var didInitialReset = false
    @State private var cachedLayout: [BubbleLayoutItem] = []
    @State private var cachedNodeID: FileNode.ID?
    @State private var cachedSize: CGSize = .zero
    @State private var cachedVisibleLimit: Int = 0
    @State private var overlayAvoidRect: CGRect = .zero
    @State private var cachedOverlayRect: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            let current = navigation.last ?? root
            let visibleLimit = visibleBubblesLimit(for: geo.size)
            let coreRadius = centerCoreRadius(for: geo.size)
            let center = coreCenter(for: geo.size, coreRadius: coreRadius, overlayRect: overlayAvoidRect)

            ZStack {
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onTapGesture {
                    selectedPaths.removeAll()
                    hoveredPath = nil
                }

                Circle()
                    .fill(surfaceColor.opacity(0.94))
                    .overlay(Circle().stroke(neutralStroke.opacity(0.65), lineWidth: 1))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.09), radius: 14, x: 0, y: 6)
                    .frame(width: coreRadius * 2, height: coreRadius * 2)
                    .position(x: center.x, y: center.y)
                VStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(primaryTextColor.opacity(0.74))
                    Text(current.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(primaryTextColor.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(current.formattedSize)
                        .font(.subheadline)
                        .foregroundStyle(secondaryTextColor)
                }
                .frame(maxWidth: 170)
                .position(x: center.x, y: center.y)

                ForEach(cachedLayout, id: \.node.url.path) { item in
                    bubbleView(for: item)
                }

                HStack(spacing: 8) {
                    Button {
                        resetToRoot()
                    } label: {
                        Label(t(.bubbleRoot), systemImage: "house")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)

                    Button {
                        goUp()
                    } label: {
                        Label(t(.bubbleBack), systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .disabled(navigation.isEmpty)

                    Menu {
                        ForEach(breadcrumbNodes(), id: \.url.path) { node in
                            Button(node.name == "/" ? t(.bubbleRootName) : node.name) {
                                jumpTo(node)
                            }
                        }
                    } label: {
                        Label(current.name == "/" ? t(.bubbleRootName) : current.name, systemImage: "folder")
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: 180, alignment: .leading)

                    Text(current.url.path)
                        .font(.caption)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 4)

                    Text(tapMode == .select ? t(.bubbleHintSelect) : t(.bubbleHintOpen))
                        .font(.caption2)
                        .foregroundStyle(secondaryTextColor.opacity(0.9))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: BubbleOverlayRectPreferenceKey.self,
                                value: proxy.frame(in: .named("bubble-map-space"))
                            )
                    }
                )
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .coordinateSpace(name: "bubble-map-space")
            .onChange(of: root.id) {
                navigation = []
                selectedPaths.removeAll()
                hoveredPath = nil
                cachedLayout = []
                cachedNodeID = nil
                recalcLayoutIfNeeded(current: root, size: geo.size, visibleLimit: visibleLimit, force: true)
            }
            .onAppear {
                if !didInitialReset {
                    selectedPaths.removeAll()
                    hoveredPath = nil
                    didInitialReset = true
                }
                sanitizeSelection(for: current, visibleLimit: visibleLimit)
                recalcLayoutIfNeeded(current: current, size: geo.size, visibleLimit: visibleLimit, force: true)
            }
            .onChange(of: current.id) {
                sanitizeSelection(for: current, visibleLimit: visibleLimit)
                recalcLayoutIfNeeded(current: current, size: geo.size, visibleLimit: visibleLimit, force: true)
            }
            .onChange(of: geo.size.width) {
                sanitizeSelection(for: current, visibleLimit: visibleLimit)
                recalcLayoutIfNeeded(current: current, size: geo.size, visibleLimit: visibleLimit, force: false)
            }
            .onChange(of: geo.size.height) {
                sanitizeSelection(for: current, visibleLimit: visibleLimit)
                recalcLayoutIfNeeded(current: current, size: geo.size, visibleLimit: visibleLimit, force: false)
            }
            .onPreferenceChange(BubbleOverlayRectPreferenceKey.self) { rect in
                if rectDistance(rect, overlayAvoidRect) > 1 {
                    overlayAvoidRect = rect
                    recalcLayoutIfNeeded(current: current, size: geo.size, visibleLimit: visibleLimit, force: true)
                }
            }
        }
    }

    private func bubbleView(for item: BubbleLayoutItem) -> some View {
        let isSelected = selectedPaths.contains(item.node.url.path)
        let isHovered = hoveredPath == item.node.url.path
        let fillColor = isSelected ? accentColor.opacity(0.24) : surfaceColor.opacity(0.86)
        let strokeColor: Color = {
            if isSelected { return accentColor.opacity(0.80) }
            if isHovered { return Color.black.opacity(0.30) }
            return neutralStroke
        }()

        return ZStack {
            Circle()
                .fill(fillColor)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.40), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .stroke(strokeColor, lineWidth: isSelected ? 2 : 1)
            VStack(spacing: 4) {
                Image(systemName: item.node.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(primaryTextColor.opacity(0.78))
                Text(item.node.name)
                    .font(.system(size: fontSize(for: item.radius), weight: .semibold))
                    .foregroundStyle(primaryTextColor.opacity(0.94))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: item.radius * 1.55)
                    .minimumScaleFactor(0.74)
                if item.radius > 50 {
                    Text(item.node.formattedSize)
                        .font(.system(size: max(10, fontSize(for: item.radius) - 2)))
                        .foregroundStyle(secondaryTextColor)
                }
            }
            .padding(.horizontal, item.radius * 0.12)
        }
        .shadow(color: .black.opacity(isSelected ? 0.16 : (colorScheme == .dark ? 0.2 : 0.06)), radius: isSelected ? 10 : 4, x: 0, y: 2)
        .frame(width: item.radius * 2, height: item.radius * 2)
        .contentShape(Circle())
        .position(x: item.center.x, y: item.center.y)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onTapGesture(perform: {
            handlePrimaryTap(on: item.node)
        })
        .onHover { inside in
            if inside {
                if hoveredPath != item.node.url.path {
                    hoveredPath = item.node.url.path
                }
            } else if hoveredPath == item.node.url.path {
                hoveredPath = nil
            }
        }
    }

    private func fontSize(for radius: CGFloat) -> CGFloat {
        min(30, max(11, radius * 0.2))
    }

    private func toggleSelection(for path: String) {
        withAnimation(.easeOut(duration: 0.12)) {
            if selectedPaths.contains(path) {
                selectedPaths.remove(path)
            } else {
                selectedPaths.insert(path)
            }
        }
    }

    private func handlePrimaryTap(on node: FileNode) {
        let path = node.url.path
        if tapMode == .openFolders {
            if node.isDirectory, !node.children.isEmpty {
                diveInto(node)
            } else {
                toggleSelection(for: path)
            }
            return
        }
        if selectedPaths.contains(path) {
            if node.isDirectory, !node.children.isEmpty {
                diveInto(node)
            } else {
                selectedPaths.remove(path)
            }
            return
        }
        toggleSelection(for: path)
    }

    private func diveInto(_ node: FileNode) {
        guard node.isDirectory, !node.children.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            navigation.append(node)
            selectedPaths.removeAll()
            hoveredPath = nil
        }
    }

    private func goUp() {
        guard !navigation.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            navigation.removeLast()
            selectedPaths.removeAll()
            hoveredPath = nil
        }
    }

    private func resetToRoot() {
        withAnimation(.easeInOut(duration: 0.18)) {
            navigation.removeAll()
            selectedPaths.removeAll()
            hoveredPath = nil
        }
    }

    private func breadcrumbNodes() -> [FileNode] {
        if navigation.isEmpty { return [root] }
        return [root] + navigation
    }

    private func jumpTo(_ node: FileNode) {
        if node.url.path == root.url.path {
            resetToRoot()
            return
        }
        if let idx = navigation.firstIndex(where: { $0.url.path == node.url.path }) {
            withAnimation(.easeInOut(duration: 0.18)) {
                navigation = Array(navigation.prefix(through: idx))
                selectedPaths.removeAll()
                hoveredPath = nil
            }
        }
    }

    private func packedLayout(
        for node: FileNode,
        in size: CGSize,
        maxItems: Int,
        overlayRect: CGRect
    ) -> [BubbleLayoutItem] {
        let items = Array(node.largestChildren.prefix(maxItems))
        guard !items.isEmpty else { return [] }

        let width = max(size.width, 320)
        let height = max(size.height, 260)
        let coreRadius = centerCoreRadius(for: size)
        let minCanvas = min(width, height)
        let bounds = CGRect(x: 12, y: 12, width: max(1, width - 24), height: max(1, height - 24))
        let avoidRect = normalizedAvoidRect(overlayRect: overlayRect, bounds: bounds)
        let center = coreCenter(for: size, coreRadius: coreRadius, overlayRect: avoidRect)

        let maxSize = Double(max(items.first?.sizeInBytes ?? 1, 1))
        let minR = max(20.0, minCanvas * (items.count > 14 ? 0.045 : 0.055))
        let maxR = min(120.0, minCanvas * 0.19)
        let initialRadii: [CGFloat] = items.map { child in
            let factor = sqrt(Double(max(child.sizeInBytes, 1)) / maxSize)
            return CGFloat(minR + (maxR - minR) * factor)
        }
        let scale = areaScaleFactor(
            for: initialRadii,
            coreRadius: coreRadius,
            bounds: bounds,
            itemCount: items.count
        )
        let radii = initialRadii.map { max(18, $0 * scale) }

        var output: [BubbleLayoutItem] = []
        output.reserveCapacity(items.count)
        for (index, node) in items.enumerated() {
            let radius = radii[index]
            let point = bestBubblePosition(
                radius: radius,
                index: index,
                center: center,
                coreRadius: coreRadius,
                bounds: bounds,
                avoidRect: avoidRect,
                placed: output
            )
            output.append(BubbleLayoutItem(node: node, center: point, radius: radius))
        }
        return relaxLayout(output, center: center, coreRadius: coreRadius, bounds: bounds, avoidRect: avoidRect)
    }

    private func bestBubblePosition(
        radius: CGFloat,
        index: Int,
        center: CGPoint,
        coreRadius: CGFloat,
        bounds: CGRect,
        avoidRect: CGRect,
        placed: [BubbleLayoutItem]
    ) -> CGPoint {
        let goldenAngle = Double.pi * (3 - sqrt(5))
        var bestPoint = CGPoint(x: center.x + coreRadius + radius + 18, y: center.y)
        var bestPenalty = CGFloat.greatestFiniteMagnitude
        let yScale: CGFloat = bounds.width > bounds.height ? 0.82 : 1.0

        for step in 0..<240 {
            let radialDistance = coreRadius + radius + 18 + CGFloat(step) * 4.8
            let angle = Double(index) * goldenAngle + Double(step) * 0.44
            var candidate = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radialDistance,
                y: center.y + CGFloat(sin(angle)) * radialDistance * yScale
            )
            candidate.x = min(max(candidate.x, bounds.minX + radius), bounds.maxX - radius)
            candidate.y = min(max(candidate.y, bounds.minY + radius), bounds.maxY - radius)

            let overlapPenalty = overlapAmount(for: candidate, radius: radius, placed: placed)
            let corePenalty = max(0, (coreRadius + radius + 12) - distance(candidate, center))
            let avoidPenalty = avoidRectPenalty(for: candidate, radius: radius, avoidRect: avoidRect)
            let centerPenalty = distance(candidate, center) * 0.008
            let penalty = overlapPenalty * 30 + corePenalty * 40 + avoidPenalty * 55 + centerPenalty

            if penalty < bestPenalty {
                bestPenalty = penalty
                bestPoint = candidate
            }
            if overlapPenalty <= 0.1 && corePenalty <= 0.1 && avoidPenalty <= 0.1 {
                break
            }
        }
        return bestPoint
    }

    private func overlapAmount(for point: CGPoint, radius: CGFloat, placed: [BubbleLayoutItem]) -> CGFloat {
        var overlap: CGFloat = 0
        for item in placed {
            let minDistance = item.radius + radius + 8
            let currentDistance = distance(point, item.center)
            if currentDistance < minDistance {
                overlap += (minDistance - currentDistance)
            }
        }
        return overlap
    }

    private func relaxLayout(
        _ items: [BubbleLayoutItem],
        center: CGPoint,
        coreRadius: CGFloat,
        bounds: CGRect,
        avoidRect: CGRect
    ) -> [BubbleLayoutItem] {
        guard items.count > 1 else { return items }
        var relaxed = items

        for _ in 0..<64 {
            var moved = false
            for i in relaxed.indices {
                for j in relaxed.indices where j > i {
                    let a = relaxed[i]
                    let b = relaxed[j]
                    let delta = CGPoint(x: b.center.x - a.center.x, y: b.center.y - a.center.y)
                    let dist = max(0.001, hypot(delta.x, delta.y))
                    let minDist = a.radius + b.radius + 8
                    guard dist < minDist else { continue }

                    let push = (minDist - dist) * 0.52
                    let nx = delta.x / dist
                    let ny = delta.y / dist
                    relaxed[i].center.x -= nx * push
                    relaxed[i].center.y -= ny * push
                    relaxed[j].center.x += nx * push
                    relaxed[j].center.y += ny * push
                    moved = true
                }
            }

            for idx in relaxed.indices {
                var item = relaxed[idx]

                // Keep bubbles outside center core.
                let dx = item.center.x - center.x
                let dy = item.center.y - center.y
                let dist = max(0.001, hypot(dx, dy))
                let minCoreDist = coreRadius + item.radius + 10
                if dist < minCoreDist {
                    let scale = minCoreDist / dist
                    item.center.x = center.x + dx * scale
                    item.center.y = center.y + dy * scale
                    moved = true
                }

                let avoidPenalty = avoidRectPenalty(for: item.center, radius: item.radius, avoidRect: avoidRect)
                if avoidPenalty > 0.01 {
                    item.center = projectedOutsideAvoidRect(
                        point: item.center,
                        radius: item.radius,
                        avoidRect: avoidRect,
                        bounds: bounds
                    )
                    moved = true
                }

                // Clamp to viewport bounds.
                let minX = bounds.minX + item.radius
                let maxX = bounds.maxX - item.radius
                let minY = bounds.minY + item.radius
                let maxY = bounds.maxY - item.radius
                let clampedX = min(max(item.center.x, minX), maxX)
                let clampedY = min(max(item.center.y, minY), maxY)
                if clampedX != item.center.x || clampedY != item.center.y {
                    item.center.x = clampedX
                    item.center.y = clampedY
                    moved = true
                }

                relaxed[idx] = item
            }

            if !moved { break }
        }

        return relaxed
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func recalcLayoutIfNeeded(current: FileNode, size: CGSize, visibleLimit: Int, force: Bool) {
        let nodeChanged = cachedNodeID != current.id
        let widthChanged = abs(size.width - cachedSize.width) > 24
        let heightChanged = abs(size.height - cachedSize.height) > 24
        let limitChanged = cachedVisibleLimit != visibleLimit
        let overlayChanged = rectDistance(overlayAvoidRect, cachedOverlayRect) > 6
        guard force || nodeChanged || widthChanged || heightChanged || limitChanged || overlayChanged else { return }
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.85, blendDuration: 0.2)) {
            cachedLayout = packedLayout(
                for: current,
                in: size,
                maxItems: visibleLimit,
                overlayRect: overlayAvoidRect
            )
        }
        cachedNodeID = current.id
        cachedSize = size
        cachedVisibleLimit = visibleLimit
        cachedOverlayRect = overlayAvoidRect
    }

    private func sanitizeSelection(for node: FileNode, visibleLimit: Int) {
        let visible = Set(node.largestChildren.prefix(visibleLimit).map { $0.url.path })
        selectedPaths = selectedPaths.filter { visible.contains($0) }
        if let hoveredPath, !visible.contains(hoveredPath) {
            self.hoveredPath = nil
        }
    }

    private func centerCoreRadius(for size: CGSize) -> CGFloat {
        let minSide = min(max(size.width, 320), max(size.height, 260))
        return min(122, max(72, minSide * 0.14))
    }

    private func visibleBubblesLimit(for size: CGSize) -> Int {
        let area = size.width * size.height
        if area < 190_000 { return 8 }
        if area < 300_000 { return 12 }
        if area < 430_000 { return 16 }
        return 20
    }

    private func coreCenter(for size: CGSize, coreRadius: CGFloat, overlayRect: CGRect) -> CGPoint {
        let width = max(size.width, 320)
        let height = max(size.height, 260)
        var center = CGPoint(x: width / 2, y: height / 2)
        guard !overlayRect.isEmpty else { return center }

        let minY = overlayRect.maxY + coreRadius + 16
        if center.y < minY {
            center.y = min(max(minY, coreRadius + 16), height - coreRadius - 16)
        }
        return center
    }

    private func normalizedAvoidRect(overlayRect: CGRect, bounds: CGRect) -> CGRect {
        guard !overlayRect.isEmpty else { return .zero }
        let expanded = overlayRect.insetBy(dx: -8, dy: -8)
        let clipped = bounds.intersection(expanded)
        return clipped.isNull ? .zero : clipped
    }

    private func areaScaleFactor(
        for radii: [CGFloat],
        coreRadius: CGFloat,
        bounds: CGRect,
        itemCount: Int
    ) -> CGFloat {
        let bubbleArea = radii.reduce(0.0) { partial, radius in
            partial + (.pi * radius * radius)
        }
        guard bubbleArea > 0 else { return 1.0 }

        let coreArea = .pi * (coreRadius + 10) * (coreRadius + 10)
        let fillRatio: CGFloat = itemCount > 14 ? 0.54 : 0.62
        let targetArea = max(1, (bounds.width * bounds.height * fillRatio) - coreArea)
        let rawScale = sqrt(targetArea / bubbleArea)
        return min(1.0, max(0.55, rawScale))
    }

    private func avoidRectPenalty(for point: CGPoint, radius: CGFloat, avoidRect: CGRect) -> CGFloat {
        guard !avoidRect.isEmpty else { return 0 }
        if avoidRect.contains(point) {
            return radius + min(avoidRect.width, avoidRect.height)
        }
        let closestX = min(max(point.x, avoidRect.minX), avoidRect.maxX)
        let closestY = min(max(point.y, avoidRect.minY), avoidRect.maxY)
        let dx = point.x - closestX
        let dy = point.y - closestY
        let distanceToRect = hypot(dx, dy)
        let minDistance = radius + 10
        if distanceToRect < minDistance {
            return minDistance - distanceToRect
        }
        return 0
    }

    private func projectedOutsideAvoidRect(
        point: CGPoint,
        radius: CGFloat,
        avoidRect: CGRect,
        bounds: CGRect
    ) -> CGPoint {
        guard !avoidRect.isEmpty else { return point }
        let pad = radius + 12
        let candidates = [
            CGPoint(x: avoidRect.minX - pad, y: point.y),
            CGPoint(x: avoidRect.maxX + pad, y: point.y),
            CGPoint(x: point.x, y: avoidRect.minY - pad),
            CGPoint(x: point.x, y: avoidRect.maxY + pad)
        ]
        var best = point
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for candidate in candidates {
            let clamped = CGPoint(
                x: min(max(candidate.x, bounds.minX + radius), bounds.maxX - radius),
                y: min(max(candidate.y, bounds.minY + radius), bounds.maxY - radius)
            )
            let d = distance(point, clamped)
            if d < bestDistance {
                bestDistance = d
                best = clamped
            }
        }
        return best
    }

    private func rectDistance(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let dx = lhs.origin.x - rhs.origin.x
        let dy = lhs.origin.y - rhs.origin.y
        let dw = lhs.size.width - rhs.size.width
        let dh = lhs.size.height - rhs.size.height
        return abs(dx) + abs(dy) + abs(dw) + abs(dh)
    }

    private func t(_ key: AppL10nKey) -> String {
        AppL10n.text(key, language: language)
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.08, green: 0.11, blue: 0.17), Color(red: 0.12, green: 0.15, blue: 0.21)]
        }
        return [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.93, green: 0.95, blue: 0.98)]
    }

    private var surfaceColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    private var accentColor: Color {
        colorScheme == .dark ? Color.cyan.opacity(0.75) : Color(red: 0.27, green: 0.53, blue: 0.93)
    }

    private var neutralStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.13)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.65)
    }
}

private struct BubbleLayoutItem {
    let node: FileNode
    var center: CGPoint
    let radius: CGFloat
}

private struct BubbleOverlayRectPreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty {
            value = next
        }
    }
}
