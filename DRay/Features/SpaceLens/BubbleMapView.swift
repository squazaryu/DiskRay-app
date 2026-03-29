import SwiftUI

struct BubbleMapView: View {
    let root: FileNode
    @Binding var hoveredPath: String?
    @Binding var selectedPaths: Set<String>
    @State private var navigation: [FileNode] = []
    @State private var zoomPulse = false
    @State private var didInitialReset = false
    @State private var cachedLayout: [BubbleLayoutItem] = []
    @State private var cachedNodeID: FileNode.ID?
    @State private var cachedSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let current = navigation.last ?? root

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.96, blue: 0.98), Color(red: 0.90, green: 0.92, blue: 0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onTapGesture(count: 2) { goUp() }
                .onTapGesture { selectedPaths.removeAll() }

                Circle()
                    .fill(Color.white.opacity(0.90))
                    .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 1))
                    .frame(width: 196, height: 196)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .overlay(alignment: .center) {
                        VStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.black.opacity(0.75))
                            Text(current.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.black.opacity(0.9))
                                .lineLimit(1)
                            Text(current.formattedSize)
                                .font(.subheadline)
                                .foregroundStyle(.black.opacity(0.65))
                        }
                        .frame(maxWidth: 170)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    .scaleEffect(zoomPulse ? 1.0 : 0.94)
                    .opacity(zoomPulse ? 1.0 : 0.82)
                    .animation(.spring(response: 0.42, dampingFraction: 0.82), value: zoomPulse)

                ForEach(cachedLayout, id: \.node.id) { item in
                    let isSelected = selectedPaths.contains(item.node.url.path)
                    let isHovered = hoveredPath == item.node.url.path
                    let fillColor = isSelected ? Color(red: 0.82, green: 0.88, blue: 1.0) : Color.white.opacity(0.84)
                    let strokeColor: Color = {
                        if isSelected { return Color.blue.opacity(0.6) }
                        if isHovered { return Color.black.opacity(0.28) }
                        return Color.black.opacity(0.12)
                    }()
                    let strokeWidth: CGFloat = isSelected ? 2 : 1
                    Circle()
                        .fill(fillColor)
                        .overlay(Circle().stroke(strokeColor, lineWidth: strokeWidth))
                        .frame(width: item.radius * 2, height: item.radius * 2)
                        .position(x: item.center.x, y: item.center.y)
                        .overlay(alignment: .center) {
                            VStack(spacing: 4) {
                                Image(systemName: item.node.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundStyle(.black.opacity(0.75))
                                Text(item.node.name)
                                    .font(.system(size: fontSize(for: item.radius), weight: .semibold))
                                    .foregroundStyle(.black.opacity(0.92))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: item.radius * 1.55)
                                if item.radius > 48 {
                                    Text(item.node.formattedSize)
                                        .font(.system(size: max(10, fontSize(for: item.radius) - 2)))
                                        .foregroundStyle(.black.opacity(0.70))
                                }
                            }
                            .position(x: item.center.x, y: item.center.y)
                        }
                        .onTapGesture {
                            handlePrimaryTap(on: item.node)
                        }
                        .onHover { inside in
                            hoveredPath = inside ? item.node.url.path : nil
                        }
                        .scaleEffect(zoomPulse ? 1.0 : 0.94)
                        .opacity(zoomPulse ? 1.0 : 0.82)
                        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: zoomPulse)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            resetToRoot()
                        } label: {
                            Label("Root", systemImage: "house")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.black.opacity(0.08))

                        Button {
                            goUp()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        .disabled(navigation.isEmpty)
                    }

                    Text(current.url.path)
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.7))
                        .lineLimit(1)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .onChange(of: root.id) {
                navigation = []
                selectedPaths.removeAll()
                hoveredPath = nil
                cachedLayout = []
                cachedNodeID = nil
                animateZoom()
            }
            .onAppear {
                if !didInitialReset {
                    selectedPaths.removeAll()
                    hoveredPath = nil
                    didInitialReset = true
                }
                recalcLayoutIfNeeded(current: current, size: geo.size, force: true)
            }
            .onChange(of: current.id) {
                recalcLayoutIfNeeded(current: current, size: geo.size, force: true)
                animateZoom()
            }
            .onChange(of: geo.size.width) {
                recalcLayoutIfNeeded(current: current, size: geo.size, force: false)
            }
            .onChange(of: geo.size.height) {
                recalcLayoutIfNeeded(current: current, size: geo.size, force: false)
            }
        }
    }

    private func fontSize(for radius: CGFloat) -> CGFloat {
        min(30, max(11, radius * 0.2))
    }

    private func toggleSelection(for path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            // Prevent accidental multi-select from rapid click streams.
            if selectedPaths.count > 6 {
                selectedPaths.removeAll()
            }
            selectedPaths.insert(path)
        }
    }

    private func handlePrimaryTap(on node: FileNode) {
        if node.isDirectory, !node.children.isEmpty {
            diveInto(node)
            return
        }
        toggleSelection(for: node.url.path)
    }

    private func diveInto(_ node: FileNode) {
        guard node.isDirectory, !node.children.isEmpty else { return }
        navigation.append(node)
        selectedPaths.removeAll()
        hoveredPath = nil
    }

    private func goUp() {
        guard !navigation.isEmpty else { return }
        navigation.removeLast()
        selectedPaths.removeAll()
        hoveredPath = nil
    }

    private func resetToRoot() {
        navigation.removeAll()
        selectedPaths.removeAll()
        hoveredPath = nil
    }

    private func packedLayout(for node: FileNode, in size: CGSize, maxItems: Int) -> [BubbleLayoutItem] {
        let items = Array(node.largestChildren.prefix(maxItems))
        guard !items.isEmpty else { return [] }

        let width = max(size.width, 400)
        let height = max(size.height, 320)
        let center = CGPoint(x: width / 2, y: height / 2)
        let coreRadius: CGFloat = 112
        let minCanvas = min(width, height)

        let maxSize = Double(max(items.first?.sizeInBytes ?? 1, 1))
        let radii: [CGFloat] = items.map { child in
            let factor = sqrt(Double(max(child.sizeInBytes, 1)) / maxSize)
            return CGFloat(22 + factor * 84)
        }

        var placed: [BubbleLayoutItem] = []

        for (idx, node) in items.enumerated() {
            let radius = radii[idx]
            var placedPoint: CGPoint?

            let baseDistance = coreRadius + radius + 20
            var ring = 0
            while ring < 14 && placedPoint == nil {
                let ringDistance = baseDistance + CGFloat(ring) * (radius * 1.2 + 18)
                let attempts = max(24, 20 + ring * 14)

                for i in 0..<attempts {
                    let angle = (2 * Double.pi * Double(i) / Double(attempts)) + Double(ring) * 0.23
                    let x = center.x + CGFloat(cos(angle)) * ringDistance
                    let y = center.y + CGFloat(sin(angle)) * ringDistance
                    let candidate = CGPoint(x: x, y: y)

                    if !isInside(candidate: candidate, radius: radius, width: width, height: height) {
                        continue
                    }
                    if intersectsCore(candidate: candidate, radius: radius, center: center, coreRadius: coreRadius) {
                        continue
                    }
                    if intersectsPlaced(candidate: candidate, radius: radius, placed: placed) {
                        continue
                    }

                    placedPoint = candidate
                    break
                }
                ring += 1
            }

            let fallback = placedPoint ?? spiralFallback(
                center: center,
                radius: radius,
                coreRadius: coreRadius,
                width: width,
                height: height,
                placed: placed,
                maxRadius: minCanvas * 0.55
            )

            placed.append(BubbleLayoutItem(node: node, center: fallback, radius: radius))
        }

        return relaxLayout(placed, center: center, coreRadius: coreRadius, width: width, height: height, iterations: 14)
    }

    private func animateZoom() {
        zoomPulse = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            zoomPulse = true
        }
    }

    private func recalcLayoutIfNeeded(current: FileNode, size: CGSize, force: Bool) {
        let nodeChanged = cachedNodeID != current.id
        let widthChanged = abs(size.width - cachedSize.width) > 24
        let heightChanged = abs(size.height - cachedSize.height) > 24
        guard force || nodeChanged || widthChanged || heightChanged else { return }
        cachedLayout = packedLayout(for: current, in: size, maxItems: 24)
        cachedNodeID = current.id
        cachedSize = size
    }

    private func relaxLayout(
        _ seed: [BubbleLayoutItem],
        center: CGPoint,
        coreRadius: CGFloat,
        width: CGFloat,
        height: CGFloat,
        iterations: Int
    ) -> [BubbleLayoutItem] {
        var items = seed
        guard !items.isEmpty else { return items }

        for _ in 0..<iterations {
            var deltas = Array(repeating: CGVector(dx: 0, dy: 0), count: items.count)

            for i in items.indices {
                for j in items.indices where j > i {
                    let a = items[i]
                    let b = items[j]
                    let dx = b.center.x - a.center.x
                    let dy = b.center.y - a.center.y
                    let dist = max(0.001, hypot(dx, dy))
                    let minDist = a.radius + b.radius + 8

                    if dist < minDist {
                        let push = (minDist - dist) * 0.52
                        let nx = dx / dist
                        let ny = dy / dist
                        deltas[i].dx -= nx * push
                        deltas[i].dy -= ny * push
                        deltas[j].dx += nx * push
                        deltas[j].dy += ny * push
                    }
                }
            }

            for i in items.indices {
                let p = items[i].center
                let toCenterX = p.x - center.x
                let toCenterY = p.y - center.y
                let radial = max(1, hypot(toCenterX, toCenterY))
                let coreMin = coreRadius + items[i].radius + 10
                if radial < coreMin {
                    let nx = toCenterX / radial
                    let ny = toCenterY / radial
                    let push = (coreMin - radial) * 0.7
                    deltas[i].dx += nx * push
                    deltas[i].dy += ny * push
                }
            }

            for i in items.indices {
                var x = items[i].center.x + deltas[i].dx * 0.6
                var y = items[i].center.y + deltas[i].dy * 0.6

                let r = items[i].radius
                x = min(max(x, r + 10), width - r - 10)
                y = min(max(y, r + 10), height - r - 10)
                items[i] = BubbleLayoutItem(node: items[i].node, center: CGPoint(x: x, y: y), radius: r)
            }
        }

        return items
    }

    private func intersectsCore(candidate: CGPoint, radius: CGFloat, center: CGPoint, coreRadius: CGFloat) -> Bool {
        let distance = hypot(candidate.x - center.x, candidate.y - center.y)
        return distance < (radius + coreRadius + 10)
    }

    private func intersectsPlaced(candidate: CGPoint, radius: CGFloat, placed: [BubbleLayoutItem]) -> Bool {
        placed.contains { existing in
            let d = hypot(candidate.x - existing.center.x, candidate.y - existing.center.y)
            return d < (radius + existing.radius + 8)
        }
    }

    private func isInside(candidate: CGPoint, radius: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
        let margin: CGFloat = 10
        return candidate.x - radius > margin &&
               candidate.y - radius > margin &&
               candidate.x + radius < width - margin &&
               candidate.y + radius < height - margin
    }

    private func spiralFallback(
        center: CGPoint,
        radius: CGFloat,
        coreRadius: CGFloat,
        width: CGFloat,
        height: CGFloat,
        placed: [BubbleLayoutItem],
        maxRadius: CGFloat
    ) -> CGPoint {
        var angle: Double = 0
        var distance: CGFloat = coreRadius + radius + 16

        while distance < maxRadius {
            let p = CGPoint(
                x: center.x + CGFloat(cos(angle)) * distance,
                y: center.y + CGFloat(sin(angle)) * distance
            )

            if isInside(candidate: p, radius: radius, width: width, height: height) &&
                !intersectsCore(candidate: p, radius: radius, center: center, coreRadius: coreRadius) &&
                !intersectsPlaced(candidate: p, radius: radius, placed: placed) {
                return p
            }

            angle += 0.4
            distance += 2.6
        }

        return CGPoint(x: center.x + coreRadius + radius + 24, y: center.y)
    }
}

private struct BubbleLayoutItem {
    let node: FileNode
    let center: CGPoint
    let radius: CGFloat
}
