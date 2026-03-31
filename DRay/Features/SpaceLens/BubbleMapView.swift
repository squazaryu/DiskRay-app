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
    @Environment(\.colorScheme) private var colorScheme
    @State private var navigation: [FileNode] = []
    @State private var didInitialReset = false
    @State private var cachedLayout: [BubbleLayoutItem] = []
    @State private var cachedNodeID: FileNode.ID?
    @State private var cachedSize: CGSize = .zero
    private let maxVisibleBubbles = 20

    var body: some View {
        GeometryReader { geo in
            let current = navigation.last ?? root
            let coreRadius = centerCoreRadius(for: geo.size)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

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

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            resetToRoot()
                        } label: {
                            Label("Root", systemImage: "house")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)

                        Button {
                            goUp()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        .disabled(navigation.isEmpty)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(breadcrumbNodes(), id: \.url.path) { node in
                                Button {
                                    jumpTo(node)
                                } label: {
                                    Text(node.name == "/" ? "Root" : node.name)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Text(current.url.path)
                        .font(.caption2)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                    Text(tapMode == .select ? "Tap bubble: select item" : "Tap folder bubble: open level")
                        .font(.caption2)
                        .foregroundStyle(secondaryTextColor.opacity(0.9))
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .onChange(of: root.id) {
                navigation = []
                selectedPaths.removeAll()
                hoveredPath = nil
                cachedLayout = []
                cachedNodeID = nil
                recalcLayoutIfNeeded(current: root, size: geo.size, force: true)
            }
            .onAppear {
                if !didInitialReset {
                    selectedPaths.removeAll()
                    hoveredPath = nil
                    didInitialReset = true
                }
                sanitizeSelection(for: current)
                recalcLayoutIfNeeded(current: current, size: geo.size, force: true)
            }
            .onChange(of: current.id) {
                sanitizeSelection(for: current)
                recalcLayoutIfNeeded(current: current, size: geo.size, force: true)
            }
            .onChange(of: geo.size.width) {
                recalcLayoutIfNeeded(current: current, size: geo.size, force: false)
            }
            .onChange(of: geo.size.height) {
                recalcLayoutIfNeeded(current: current, size: geo.size, force: false)
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

    private func packedLayout(for node: FileNode, in size: CGSize, maxItems: Int) -> [BubbleLayoutItem] {
        let items = Array(node.largestChildren.prefix(maxItems))
        guard !items.isEmpty else { return [] }

        let width = max(size.width, 520)
        let height = max(size.height, 360)
        let center = CGPoint(x: width / 2, y: height / 2)
        let coreRadius = centerCoreRadius(for: size)
        let minCanvas = min(width, height)
        let bounds = CGRect(x: 12, y: 12, width: width - 24, height: height - 24)

        let maxSize = Double(max(items.first?.sizeInBytes ?? 1, 1))
        let minR = max(26.0, minCanvas * 0.055)
        let maxR = min(100.0, minCanvas * 0.18)
        let baseRadii: [CGFloat] = items.map { child in
            let factor = sqrt(Double(max(child.sizeInBytes, 1)) / maxSize)
            return CGFloat(minR + (maxR - minR) * factor)
        }

        var output: [BubbleLayoutItem] = []
        output.reserveCapacity(items.count)
        for (index, node) in items.enumerated() {
            let radius = baseRadii[index]
            let point = bestBubblePosition(
                radius: radius,
                index: index,
                center: center,
                coreRadius: coreRadius,
                bounds: bounds,
                placed: output
            )
            output.append(BubbleLayoutItem(node: node, center: point, radius: radius))
        }
        return relaxLayout(output, center: center, coreRadius: coreRadius, bounds: bounds)
    }

    private func bestBubblePosition(
        radius: CGFloat,
        index: Int,
        center: CGPoint,
        coreRadius: CGFloat,
        bounds: CGRect,
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
            let centerPenalty = distance(candidate, center) * 0.01
            let penalty = overlapPenalty * 30 + corePenalty * 40 + centerPenalty

            if penalty < bestPenalty {
                bestPenalty = penalty
                bestPoint = candidate
            }
            if overlapPenalty <= 0.1 && corePenalty <= 0.1 {
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
        bounds: CGRect
    ) -> [BubbleLayoutItem] {
        guard items.count > 1 else { return items }
        var relaxed = items

        for _ in 0..<48 {
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

    private func recalcLayoutIfNeeded(current: FileNode, size: CGSize, force: Bool) {
        let nodeChanged = cachedNodeID != current.id
        let widthChanged = abs(size.width - cachedSize.width) > 24
        let heightChanged = abs(size.height - cachedSize.height) > 24
        guard force || nodeChanged || widthChanged || heightChanged else { return }
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.85, blendDuration: 0.2)) {
            cachedLayout = packedLayout(for: current, in: size, maxItems: maxVisibleBubbles)
        }
        cachedNodeID = current.id
        cachedSize = size
    }

    private func sanitizeSelection(for node: FileNode) {
        let visible = Set(node.largestChildren.prefix(maxVisibleBubbles).map { $0.url.path })
        selectedPaths = selectedPaths.filter { visible.contains($0) }
        if let hoveredPath, !visible.contains(hoveredPath) {
            self.hoveredPath = nil
        }
    }

    private func centerCoreRadius(for size: CGSize) -> CGFloat {
        let minSide = min(max(size.width, 400), max(size.height, 320))
        return min(118, max(84, minSide * 0.15))
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
