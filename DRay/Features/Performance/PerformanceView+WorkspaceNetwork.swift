import SwiftUI
import MapKit
import AppKit

extension PerformanceView {
    var networkWorkspace: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("Сетевая наблюдаемость", "Network observability"))
                            .font(.headline)
                        Text(t(
                            "Онлайн-трафик, ключевые endpoint-ы и активность подключений по процессам.",
                            "Live traffic, top endpoints and process-level connection activity."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    networkToolbarControls
                }
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("Сетевая наблюдаемость", "Network observability"))
                            .font(.headline)
                        Text(t(
                            "Онлайн-трафик, ключевые endpoint-ы и активность подключений по процессам.",
                            "Live traffic, top endpoints and process-level connection activity."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    networkToolbarControls
                }
            }

            networkSubscreenPicker
            networkSubscreenContent

            if let error = networkConnectionsMonitor.snapshot.sampleError, !error.isEmpty {
                Text(t("Ошибка сетевого сэмпла: \(error)", "Network sample error: \(error)"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let error = networkGeolocationMonitor.lastErrorMessage, !error.isEmpty {
                Text(t("Ошибка геолокации: \(error)", "Geolocation error: \(error)"))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var networkSubscreenPicker: some View {
        Picker("", selection: $networkSubscreen) {
            Text(t("Обзор", "Overview")).tag(NetworkWorkspaceSubscreen.overview)
            Text(t("Карта", "Live Map")).tag(NetworkWorkspaceSubscreen.liveMap)
            Text(t("Инструменты", "Tools")).tag(NetworkWorkspaceSubscreen.tools)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 720)
        .padding(6)
        .calmGlass(.nestedCard, cornerRadius: 14)
    }

    @ViewBuilder
    private var networkSubscreenContent: some View {
        switch networkSubscreen {
        case .overview:
            networkObservabilityScreen
        case .liveMap:
            networkMapScreen
        case .tools:
            networkToolsScreen
        }
    }

    private var networkObservabilityScreen: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                    networkControlCard
                        .frame(minWidth: 240, idealWidth: 258, maxWidth: 272)
                    networkTrafficCard
                        .frame(minWidth: 420, maxWidth: .infinity)
                        .layoutPriority(1)
                }
                HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                    networkControlCard
                        .frame(minWidth: 220, idealWidth: 240, maxWidth: 250)
                    networkTrafficCard
                        .frame(minWidth: 360, maxWidth: .infinity)
                        .layoutPriority(1)
                }
                VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
                    networkTrafficCard
                    networkControlCard
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 230), spacing: layoutMetrics.cardSpacing, alignment: .top)
                ],
                spacing: layoutMetrics.cardSpacing
            ) {
                networkConnectionSummaryCard
                networkHostCard
                networkServiceCard
                networkProgramCard
            }
        }
    }

    private var networkMapScreen: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                networkMapCard
                    .frame(maxWidth: .infinity)
                networkMapSummaryCard
                    .frame(minWidth: 280, idealWidth: 300, maxWidth: 320)
            }
            HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                networkMapCard
                    .frame(maxWidth: .infinity)
                networkMapSummaryCard
                    .frame(minWidth: 250, idealWidth: 270, maxWidth: 290)
            }
            VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
                networkMapCard
                networkMapSummaryCard
            }
        }
    }

    private var networkToolsScreen: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                    VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
                        networkPublicIPCard
                        networkWakeOnLANCard
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
                        networkLatencyCard
                        networkPortScannerCard
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
                    networkPublicIPCard
                    networkLatencyCard
                    networkWakeOnLANCard
                    networkPortScannerCard
                }
            }

            networkToolsSupplementaryContent
        }
    }

    @ViewBuilder
    private var networkToolsSupplementaryContent: some View {
        if recentNetworkRows.isEmpty {
            networkSpeedTestToolsCard
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: layoutMetrics.cardSpacing) {
                    networkSpeedTestToolsCard
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    networkHistoryCard
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
                    networkSpeedTestToolsCard
                    networkHistoryCard
                }
            }
        }
    }

    private var networkToolbarControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Button(t("Обновить", "Refresh")) {
                    networkConnectionsMonitor.refreshNow()
                    networkGeolocationMonitor.refreshPublicProfile(force: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Toggle(
                    t("Локации", "Resolve locations"),
                    isOn: $networkGeolocationMonitor.resolveEnabled
                )
                .toggleStyle(.switch)
                .controlSize(.small)

                Button(t("Скорость", "Speed Test")) {
                    model.runNetworkSpeedTest()
                }
                .buttonStyle(DRayPrimaryButtonStyle())
                .controlSize(.small)
                .disabled(model.performance.isNetworkSpeedTestRunning)

                if selectedNetworkHostID != nil || selectedNetworkServiceID != nil || selectedNetworkProgramID != nil {
                    Button(t("Сбросить фокус", "Clear focus")) {
                        selectedNetworkHostID = nil
                        selectedNetworkServiceID = nil
                        selectedNetworkProgramID = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button(t("Обновить", "Refresh")) {
                        networkConnectionsMonitor.refreshNow()
                        networkGeolocationMonitor.refreshPublicProfile(force: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(t("Скорость", "Speed Test")) {
                        model.runNetworkSpeedTest()
                    }
                    .buttonStyle(DRayPrimaryButtonStyle())
                    .controlSize(.small)
                    .disabled(model.performance.isNetworkSpeedTestRunning)
                }

                Toggle(
                    t("Локации", "Resolve locations"),
                    isOn: $networkGeolocationMonitor.resolveEnabled
                )
                .toggleStyle(.switch)
                .controlSize(.small)

                if selectedNetworkHostID != nil || selectedNetworkServiceID != nil || selectedNetworkProgramID != nil {
                    Button(t("Сбросить фокус", "Clear focus")) {
                        selectedNetworkHostID = nil
                        selectedNetworkServiceID = nil
                        selectedNetworkProgramID = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var networkControlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Сетевой адаптер", "Network adapter"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(monitor.snapshot.networkPrimaryInterface ?? t("Неизвестно", "Unknown"))
                        .font(.headline)
                        .monospaced()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(t("Сессия", "Session"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(networkSessionDurationText)
                        .font(.headline)
                        .monospacedDigit()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(t("Представление данных", "Data representation"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $networkDataRepresentation) {
                    Text(t("биты", "bits")).tag(NetworkDataRepresentation.bits)
                    Text(t("байты", "bytes")).tag(NetworkDataRepresentation.bytes)
                    Text(t("пакеты", "packets")).tag(NetworkDataRepresentation.packets)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            DRayDonutChartView(
                segments: networkDonutSegments,
                centerTitle: networkTotalTitle,
                centerSubtitle: t("всего", "total"),
                lineWidth: 18
            )
            .frame(height: 140)

            VStack(alignment: .leading, spacing: 5) {
                networkLegendRow(
                    title: t("Входящий", "Incoming"),
                    value: networkLegendIncoming,
                    tint: .blue
                )
                networkLegendRow(
                    title: t("Исходящий", "Outgoing"),
                    value: networkLegendOutgoing,
                    tint: .green
                )
                networkLegendRow(
                    title: t("Потери", "Dropped"),
                    value: networkLegendDropped,
                    tint: .gray
                )
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var networkTrafficCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("Скорость трафика", "Traffic rate"))
                    .font(.headline)
                Spacer()
                performanceLegendDot(t("Входящий", "Incoming"), tint: .accentColor)
                performanceLegendDot(t("Исходящий", "Outgoing"), tint: .green)
            }

            NetworkTrafficDualChart(
                incoming: networkRateHistory.map(\.incoming),
                outgoing: networkRateHistory.map(\.outgoing),
                incomingTint: .accentColor,
                outgoingTint: .green
            )
            .frame(height: 240)
            .calmGlass(.nestedCard, cornerRadius: 14)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Входящий", "Incoming"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(currentIncomingRateLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor.opacity(0.76))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(t("Исходящий", "Outgoing"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(currentOutgoingRateLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.green)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var networkConnectionSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            performanceCardTitle(t("Сводка подключений", "Connection summary"), icon: "point.3.connected.trianglepath.dotted", tint: .teal)

            VStack(alignment: .leading, spacing: 4) {
                keyValueLine(
                    label: t("Подключения", "Connections"),
                    value: "\(networkConnectionsMonitor.snapshot.totalConnections)"
                )
                keyValueLine(
                    label: "TCP / UDP",
                    value: "\(networkConnectionsMonitor.snapshot.tcpConnections) / \(networkConnectionsMonitor.snapshot.udpConnections)"
                )
                keyValueLine(
                    label: t("Активные приложения", "Active apps"),
                    value: "\(networkConnectionsMonitor.snapshot.activePrograms)"
                )
            }

            if selectedNetworkHostID != nil || selectedNetworkServiceID != nil || selectedNetworkProgramID != nil {
                Divider()
                Text(t("Фокус применён: списки и карта фильтруются по выбранной сущности.", "Focus is active: lists and map are filtered by selected entity."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var networkMapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                performanceCardTitle(t("Карта в реальном времени", "Live map"), icon: "map", tint: .cyan)
                Spacer()
                Text(t("Обновлено \(relativeTime(networkConnectionsMonitor.snapshot.collectedAt))", "Updated \(relativeTime(networkConnectionsMonitor.snapshot.collectedAt))"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if hasNetworkMapData {
                Map(initialPosition: .region(networkMapRegion)) {
                    if let local = localNetworkHubCoordinate {
                        Annotation(t("Этот Mac", "This Mac"), coordinate: local) {
                            VStack(spacing: 4) {
                                Image(systemName: "laptopcomputer")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.accentColor.opacity(0.68))
                                    .padding(7)
                                    .background(Color.primary.opacity(0.045), in: Circle())
                                Text(t("Этот Mac", "This Mac"))
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.ultraThinMaterial, in: Capsule())
                            }
                        }
                    }

                    ForEach(geolocatedHostRows.prefix(12)) { row in
                        Annotation(row.host, coordinate: row.coordinate) {
                            Button {
                                selectedNetworkHostID = (selectedNetworkHostID == row.host) ? nil : row.host
                                selectedNetworkServiceID = nil
                                selectedNetworkProgramID = nil
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(endpointTint(for: row.host))
                                        .frame(
                                            width: row.host == selectedNetworkHostID ? 18 : 14,
                                            height: row.host == selectedNetworkHostID ? 18 : 14
                                        )
                                    Circle()
                                        .fill(Color.white.opacity(0.92))
                                        .frame(
                                            width: row.host == selectedNetworkHostID ? 6 : 4,
                                            height: row.host == selectedNetworkHostID ? 6 : 4
                                        )
                                }
                                .padding(4)
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help(row.host)
                        }
                    }

                    if let local = localNetworkHubCoordinate {
                        ForEach(geolocatedHostRows.prefix(12)) { row in
                            MapPolyline(coordinates: [local, row.coordinate])
                                .stroke(
                                    endpointTint(for: row.host).opacity(row.host == selectedNetworkHostID ? 0.42 : 0.16),
                                    lineWidth: row.host == selectedNetworkHostID ? 1.7 : 0.8
                                )
                        }
                    }
                }
                .id(networkMapIdentity)
                .mapStyle(.standard(elevation: .realistic))
                .frame(minHeight: 260, maxHeight: 340)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("Недостаточно данных для карты.", "Not enough data to render map."))
                        .font(.subheadline.weight(.semibold))
                    Text(t(
                        "Ожидаем внешний трафик и координаты публичного IP.",
                        "Waiting for remote traffic and public IP coordinates."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
                .padding(16)
                .calmGlass(.nestedCard, cornerRadius: 14)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    metricCard(
                        title: t("TCP-подключения", "TCP connections"),
                        value: "\(networkConnectionsMonitor.snapshot.tcpConnections)",
                        subtitle: t("Текущий сэмпл", "Live sample")
                    )
                    metricCard(
                        title: t("Геолокированные endpoint-ы", "Geolocated endpoints"),
                        value: "\(geolocatedHostRows.count)",
                        subtitle: t("Топ хостов", "Top host list")
                    )
                    metricCard(
                        title: t("Неразрешённые хосты", "Unresolved hosts"),
                        value: "\(networkGeolocationMonitor.unresolvedHosts.count)",
                        subtitle: t("DNS/geo недоступны", "DNS/geo unavailable")
                    )
                }
                VStack(alignment: .leading, spacing: 10) {
                    metricCard(
                        title: t("TCP-подключения", "TCP connections"),
                        value: "\(networkConnectionsMonitor.snapshot.tcpConnections)",
                        subtitle: t("Текущий сэмпл", "Live sample")
                    )
                    metricCard(
                        title: t("Геолокированные endpoint-ы", "Geolocated endpoints"),
                        value: "\(geolocatedHostRows.count)",
                        subtitle: t("Топ хостов", "Top host list")
                    )
                    metricCard(
                        title: t("Неразрешённые хосты", "Unresolved hosts"),
                        value: "\(networkGeolocationMonitor.unresolvedHosts.count)",
                        subtitle: t("DNS/geo недоступны", "DNS/geo unavailable")
                    )
                }
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var networkMapSummaryCard: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
            performanceCardTitle(t("Сводка", "Summary"), icon: "list.bullet.rectangle", tint: .blue)

            VStack(alignment: .leading, spacing: 4) {
                if let profile = networkGeolocationMonitor.publicProfile {
                    keyValueLine(label: t("Публичный IP", "Public IP"), value: profile.ip)
                    keyValueLine(label: t("Локация", "Location"), value: profile.locationLabel)
                    if let org = profile.organization, !org.isEmpty {
                        keyValueLine(label: t("Сеть", "Network"), value: org)
                    }
                    if let timezone = profile.timezone, !timezone.isEmpty {
                        keyValueLine(label: t("Часовой пояс", "Timezone"), value: timezone)
                    }
                } else if let error = networkGeolocationMonitor.lastErrorMessage, !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text(t("Профиль публичного IP загружается...", "Public IP profile is loading..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text(t("Топ удалённых хостов", "Top remote hosts"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if geolocatedHostRows.isEmpty {
                Text(t("Нет геолокированных endpoint-ов.", "No geolocated endpoints yet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(geolocatedHostRows.prefix(6)) { row in
                        Button {
                            selectedNetworkHostID = (selectedNetworkHostID == row.host) ? nil : row.host
                            selectedNetworkServiceID = nil
                            selectedNetworkProgramID = nil
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(endpointTint(for: row.host))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.host)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Text(row.location)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    if let processHint = hostProcessSummary(for: row.host) {
                                        Text(processHint)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 8)
                                Text(formatByteCount(row.totalBytes))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(row.host == selectedNetworkHostID ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.035))
                            )
                            .overlay(alignment: .leading) {
                                if row.host == selectedNetworkHostID {
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.70))
                                        .frame(width: 3)
                                        .padding(.vertical, 6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selectedNetworkHostID {
                Divider()

                Text(t("Активность выбранного endpoint-а", "Selected endpoint activity"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedNetworkHostID)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .textSelection(.enabled)
                    if let geo = networkGeolocationMonitor.endpointsByHost[selectedNetworkHostID] {
                        Text(geo.locationLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if selectedHostLinkedProgramIDs.isEmpty {
                        Text(t(
                            "Для этого endpoint-а в текущем сэмпле нет связанных имён процессов.",
                            "No linked process names available for this endpoint in current sample."
                        ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    } else {
                        Text(t("Процессы", "Processes"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(selectedHostLinkedProgramIDs.prefix(6)), id: \.self) { programID in
                                linkedProcessRow(programID: programID)
                            }
                        }
                    }

                    if !selectedHostLinkedServiceIDs.isEmpty {
                        Text(t("Сервисы", "Services"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(selectedHostLinkedServiceIDs
                            .prefix(4)
                            .map(serviceSummaryLabel(for:))
                            .joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }

            Divider()

            Text(t("Топ процессов", "Top processes"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(filteredProgramTrafficRows.prefix(5)) { row in
                    Button {
                        selectedNetworkProgramID = (selectedNetworkProgramID == row.id) ? nil : row.id
                        selectedNetworkHostID = nil
                        selectedNetworkServiceID = nil
                    } label: {
                        HStack(spacing: 8) {
                            Text(row.program)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            Text("\(row.connectionCount)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(row.id == selectedNetworkProgramID ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.035))
                        )
                        .overlay(alignment: .leading) {
                            if row.id == selectedNetworkProgramID {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.70))
                                    .frame(width: 3)
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

                Spacer(minLength: 0)
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .frame(minHeight: 240, idealHeight: 390, maxHeight: 560, alignment: .topLeading)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var networkHostCard: some View {
        networkListCard(
            title: t("Сетевой хост", "Network host"),
            icon: "globe",
            selectedRowID: selectedNetworkHostID,
            rows: filteredHostTrafficRows.map {
                NetworkListRow(
                    id: $0.id,
                    title: $0.host,
                    subtitle: "",
                    value: formatByteCount($0.totalBytes),
                    icon: "globe"
                )
            },
            onSelect: { row in
                selectedNetworkHostID = selectedNetworkHostID == row.id ? nil : row.id
                selectedNetworkServiceID = nil
                selectedNetworkProgramID = nil
            }
        )
    }

    private var networkServiceCard: some View {
        networkListCard(
            title: t("Сервис", "Service"),
            icon: "network",
            selectedRowID: selectedNetworkServiceID,
            rows: filteredServiceTrafficRows.map {
                NetworkListRow(
                    id: $0.id,
                    title: $0.label,
                    subtitle: "\($0.protocolLabel.uppercased()) · \($0.portLabel)",
                    value: formatByteCount($0.totalBytes),
                    icon: "point.3.connected.trianglepath.dotted"
                )
            },
            onSelect: { row in
                selectedNetworkServiceID = selectedNetworkServiceID == row.id ? nil : row.id
                selectedNetworkHostID = nil
                selectedNetworkProgramID = nil
            }
        )
    }

    private var networkProgramCard: some View {
        networkListCard(
            title: t("Программа", "Program"),
            icon: "app.badge",
            selectedRowID: selectedNetworkProgramID,
            rows: filteredProgramTrafficRows.map {
                NetworkListRow(
                    id: $0.id,
                    title: $0.program,
            subtitle: "\($0.connectionCount) соед. · TCP \($0.tcpConnections) / UDP \($0.udpConnections)",
                    value: formatByteCount($0.totalBytes),
                    icon: "app"
                )
            },
            onSelect: { row in
                selectedNetworkProgramID = selectedNetworkProgramID == row.id ? nil : row.id
                selectedNetworkHostID = nil
                selectedNetworkServiceID = nil
            }
        )
    }

    private var networkPublicIPCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                performanceCardTitle(t("Публичный IP и геолокация", "Public IP & geolocation"), icon: "globe.americas", tint: .cyan)
                Spacer()
                Button(t("Обновить", "Refresh")) {
                    networkGeolocationMonitor.refreshPublicProfile(force: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let profile = networkGeolocationMonitor.publicProfile {
                Text(profile.ip)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: 5) {
                    keyValueLine(label: t("Локация", "Location"), value: profile.locationLabel)
                    if let country = profile.countryName, !country.isEmpty {
                        keyValueLine(label: t("Страна", "Country"), value: country)
                    }
                    if let organization = profile.organization, !organization.isEmpty {
                        keyValueLine(label: t("Сеть", "Network"), value: organization)
                        if let asn = autonomousSystemCode(from: organization) {
                            keyValueLine(label: t("ASN", "ASN"), value: asn)
                        }
                    }
                    if let timezone = profile.timezone, !timezone.isEmpty {
                        keyValueLine(label: t("Часовой пояс", "Timezone"), value: timezone)
                    }
                }

                HStack {
                    Button(t("Копировать IP", "Copy IP")) {
                        copyPublicIPToClipboard(profile.ip)
                    }
                    .buttonStyle(DRayPrimaryButtonStyle())
                    .controlSize(.small)
                    Spacer()
                    Text(t("Обновлено \(relativeTime(profile.updatedAt))", "Updated \(relativeTime(profile.updatedAt))"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Публичный профиль загружается...", "Public profile is loading..."))
                        .font(.subheadline.weight(.semibold))
                    Text(t(
                        "DRay запрашивает текущий IP и геолокационный контекст для сетевой диагностики.",
                        "DRay requests current IP and geolocation context for network diagnostics."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var networkLatencyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                performanceCardTitle(t("Задержка до мировых узлов", "Latency to the world"), icon: "bolt.heart", tint: .green)
                Spacer()
                Button(networkLatencyMonitor.isPaused ? t("Продолжить", "Resume") : t("Пауза", "Pause")) {
                    if networkLatencyMonitor.isPaused {
                        networkLatencyMonitor.resume()
                    } else {
                        networkLatencyMonitor.pause()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button(t("Обновить", "Refresh")) {
                    networkLatencyMonitor.refreshNow()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if networkLatencyMonitor.samples.isEmpty && networkLatencyMonitor.isRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t("Собираем latency-пробы...", "Collecting latency probes..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(networkLatencyMonitor.samples) { sample in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(latencyTint(for: sample))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sample.target.label)
                                    .font(.subheadline.weight(.semibold))
                                Text(sample.target.host)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(latencyValueText(for: sample))
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(latencyTint(for: sample))
                                    .monospacedDigit()
                                Text(packetLossText(for: sample))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .calmGlass(.nestedCard, cornerRadius: 10)
                    }
                }
            }

            if let lastUpdatedAt = networkLatencyMonitor.lastUpdatedAt {
                Text(t("Обновлено \(relativeTime(lastUpdatedAt))", "Updated \(relativeTime(lastUpdatedAt))"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let error = networkLatencyMonitor.lastErrorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var networkPortScannerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            performanceCardTitle(t("TCP-сканер портов", "TCP port scanner"), icon: "magnifyingglass", tint: .blue)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Хост", "Host"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("127.0.0.1", text: $portScannerHost)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Начало", "Start"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("1", text: $portScannerStartPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 76)
                            .font(.system(.body, design: .monospaced))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Конец", "End"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("1024", text: $portScannerEndPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 82)
                            .font(.system(.body, design: .monospaced))
                    }
                    Button(t("Скан", "Scan")) {
                        startPortScan()
                    }
                    .buttonStyle(DRayPrimaryButtonStyle())
                    .controlSize(.small)
                    .disabled(isPortScannerRunning)
                }

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Хост", "Host"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("127.0.0.1", text: $portScannerHost)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("Начало", "Start"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("1", text: $portScannerStartPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 76)
                                .font(.system(.body, design: .monospaced))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("Конец", "End"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("1024", text: $portScannerEndPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 82)
                                .font(.system(.body, design: .monospaced))
                        }
                        Button(t("Скан", "Scan")) {
                            startPortScan()
                        }
                        .buttonStyle(DRayPrimaryButtonStyle())
                        .controlSize(.small)
                        .disabled(isPortScannerRunning)
                    }
                }
            }

            if isPortScannerRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t("Сканируем порты...", "Scanning ports..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let status = portScannerStatusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(t("Готово", "Ready"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !portScannerOpenPorts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Открытые порты", "Open ports"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(portScannerOpenPorts.map { ":\($0)" }.joined(separator: ", "))
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                }
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var networkWakeOnLANCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            performanceCardTitle(t("Wake-on-LAN", "Wake-on-LAN"), icon: "powerplug", tint: .teal)

            VStack(alignment: .leading, spacing: 4) {
                Text(t("MAC", "MAC"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField("00:1A:2B:3C:4D:5E", text: $wakeOnLANMACAddress)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Широковещательный адрес", "Broadcast"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("255.255.255.255", text: $wakeOnLANBroadcastAddress)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Port", "Port"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("9", text: $wakeOnLANPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 74)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Широковещательный адрес", "Broadcast"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("255.255.255.255", text: $wakeOnLANBroadcastAddress)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Port", "Port"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("9", text: $wakeOnLANPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 74)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }

            Button(t("Send magic packet", "Send magic packet")) {
                sendWakeOnLANPacket()
            }
            .buttonStyle(DRayPrimaryButtonStyle())
            .controlSize(.small)

            if let status = wakeOnLANStatusMessage, !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(t(
                    "Пробуждает LAN-устройство с включенным Wake-on-LAN в BIOS/EFI.",
                    "Wakes a LAN device that has Wake-on-LAN enabled in BIOS/EFI."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private var networkSpeedTestToolsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                performanceCardTitle(t("Тест скорости", "Speed test"), icon: "speedometer", tint: .indigo)
                Spacer()
                Button(t("Запустить тест скорости", "Run speed test")) {
                    model.runNetworkSpeedTest()
                }
                .buttonStyle(DRayPrimaryButtonStyle())
                .controlSize(.small)
                .disabled(model.performance.isNetworkSpeedTestRunning)
            }

            if model.performance.isNetworkSpeedTestRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t("Измеряем пропускную способность и отклик...", "Measuring throughput and responsiveness..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let speed = latestNetworkResult, speed.isSuccess {
                networkSpeedSummary(result: speed)
                    .padding(8)
                    .calmGlass(.nestedCard, cornerRadius: 12)
            } else {
                Text(t("Успешных тестов скорости пока нет.", "No successful speed test yet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private func latencyTint(for sample: NetworkLatencyProbeSample) -> Color {
        if !sample.isReachable {
            return .red
        }
        let loss = sample.packetLossPercent ?? 100
        if loss > 0 {
            return .orange
        }
        let latency = sample.averageLatencyMs ?? 0
        if latency <= 50 {
            return .green
        }
        if latency <= 100 {
            return .yellow
        }
        return .orange
    }

    private func latencyValueText(for sample: NetworkLatencyProbeSample) -> String {
        guard sample.isReachable else { return "n/a" }
        guard let latency = sample.averageLatencyMs else { return "n/a" }
        return "\(Int(latency.rounded())) ms"
    }

    private func packetLossText(for sample: NetworkLatencyProbeSample) -> String {
        if let loss = sample.packetLossPercent {
            return String(format: "%.0f%% loss", loss)
        }
        return sample.errorMessage ?? t("ошибка пробы", "probe error")
    }

    private func autonomousSystemCode(from organization: String) -> String? {
        guard let token = organization
            .split(whereSeparator: \.isWhitespace)
            .first else { return nil }
        let upper = token.uppercased()
        return upper.hasPrefix("AS") ? String(upper) : nil
    }

    func refreshNetworkToolsMonitoring() {
        let toolsVisible =
            workspaceTab == .network &&
            networkSubscreen == .tools
        if toolsVisible {
            if networkLatencyMonitor.isPaused {
                return
            }
            networkLatencyMonitor.start()
        } else {
            networkLatencyMonitor.stop()
            if isPortScannerRunning {
                portScannerTask?.cancel()
                portScannerTask = nil
                isPortScannerRunning = false
                portScannerStatusMessage = t("Скан портов приостановлен.", "Port scan paused.")
            }
        }
    }

    private func startPortScan() {
        guard !isPortScannerRunning else { return }

        let host = portScannerHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            portScannerStatusMessage = t("Сначала укажи хост.", "Enter host first.")
            return
        }
        guard let startPort = Int(portScannerStartPort),
              let endPort = Int(portScannerEndPort),
              (1...65_535).contains(startPort),
              (1...65_535).contains(endPort),
              startPort <= endPort else {
            portScannerStatusMessage = t("Некорректный диапазон портов.", "Invalid port range.")
            return
        }

        let rangeCount = endPort - startPort + 1
        guard rangeCount <= 2_048 else {
            portScannerStatusMessage = t(
                "Диапазон портов слишком широкий. Используй до 2048 портов за один скан.",
                "Port range is too wide. Use up to 2048 ports per scan."
            )
            return
        }

        portScannerTask?.cancel()
        portScannerOpenPorts = []
        portScannerStatusMessage = t("Сканируем \(rangeCount) портов...", "Scanning \(rangeCount) ports...")
        isPortScannerRunning = true

        portScannerTask = Task {
            let summary = await networkPortScannerService.scan(
                host: host,
                startPort: startPort,
                endPort: endPort,
                timeoutSeconds: 1,
                maxConcurrent: 32
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                isPortScannerRunning = false
                portScannerOpenPorts = summary.openPorts

                if let error = summary.errorMessage {
                    portScannerStatusMessage = t("Скан не удался: \(error)", "Scan failed: \(error)")
                } else {
                    portScannerStatusMessage = t(
                        "Просканировано \(summary.scannedCount) портов за \(String(format: "%.1f", summary.durationSeconds))с · открыто \(summary.openPorts.count)",
                        "Scanned \(summary.scannedCount) ports in \(String(format: "%.1f", summary.durationSeconds))s · open \(summary.openPorts.count)"
                    )
                }
            }
        }
    }

    private func sendWakeOnLANPacket() {
        let mac = wakeOnLANMACAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let broadcast = wakeOnLANBroadcastAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = UInt16(wakeOnLANPort), port > 0 else {
            wakeOnLANStatusMessage = t("Некорректный UDP-порт.", "Invalid UDP port.")
            return
        }

        wakeOnLANStatusMessage = t("Отправляем magic-пакет...", "Sending magic packet...")
        Task {
            do {
                let bytes = try await wakeOnLANService.sendMagicPacket(
                    macAddress: mac,
                    broadcastAddress: broadcast,
                    port: port
                )
                await MainActor.run {
                    wakeOnLANStatusMessage = t(
                        "Magic-пакет отправлен (\(bytes) байт).",
                        "Magic packet sent (\(bytes) bytes)."
                    )
                }
            } catch {
                await MainActor.run {
                    wakeOnLANStatusMessage = t(
                        "Не удалось отправить: \(error.localizedDescription)",
                        "Failed to send: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    private func copyPublicIPToClipboard(_ ip: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(ip, forType: .string)
    }

    private func networkSpeedSummary(result: NetworkSpeedTestResult) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: layoutMetrics.cardSpacing) {
                metricCard(
                    title: t("Скачивание", "Download"),
                    value: optionalMbps(result.downlinkMbps),
                    subtitle: t("Последний тест скорости", "Latest speed test")
                )
                metricCard(
                    title: t("Отдача", "Upload"),
                    value: optionalMbps(result.uplinkMbps),
                    subtitle: t("Последний тест скорости", "Latest speed test")
                )
                metricCard(
                    title: t("Отклик", "Responsiveness"),
                    value: optionalMilliseconds(result.responsivenessMs),
                    subtitle: t("Меньше — лучше", "Lower is better")
                )
                metricCard(
                    title: "Base RTT",
                    value: optionalMilliseconds(result.baseRTTMs),
                    subtitle: result.interfaceName ?? t("Интерфейс н/д", "Interface n/a")
                )
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 180), spacing: layoutMetrics.cardSpacing),
                    GridItem(.flexible(minimum: 180), spacing: layoutMetrics.cardSpacing)
                ],
                spacing: layoutMetrics.cardSpacing
            ) {
                metricCard(
                    title: t("Скачивание", "Download"),
                    value: optionalMbps(result.downlinkMbps),
                    subtitle: t("Последний тест скорости", "Latest speed test")
                )
                metricCard(
                    title: t("Отдача", "Upload"),
                    value: optionalMbps(result.uplinkMbps),
                    subtitle: t("Последний тест скорости", "Latest speed test")
                )
                metricCard(
                    title: t("Отклик", "Responsiveness"),
                    value: optionalMilliseconds(result.responsivenessMs),
                    subtitle: t("Меньше — лучше", "Lower is better")
                )
                metricCard(
                    title: "Base RTT",
                    value: optionalMilliseconds(result.baseRTTMs),
                    subtitle: result.interfaceName ?? t("Интерфейс н/д", "Interface n/a")
                )
            }

            VStack(alignment: .leading, spacing: layoutMetrics.cardSpacing) {
                metricCard(
                    title: t("Скачивание", "Download"),
                    value: optionalMbps(result.downlinkMbps),
                    subtitle: t("Последний тест скорости", "Latest speed test")
                )
                metricCard(
                    title: t("Отдача", "Upload"),
                    value: optionalMbps(result.uplinkMbps),
                    subtitle: t("Последний тест скорости", "Latest speed test")
                )
                metricCard(
                    title: t("Отклик", "Responsiveness"),
                    value: optionalMilliseconds(result.responsivenessMs),
                    subtitle: t("Меньше — лучше", "Lower is better")
                )
                metricCard(
                    title: "Base RTT",
                    value: optionalMilliseconds(result.baseRTTMs),
                    subtitle: result.interfaceName ?? t("Интерфейс н/д", "Interface n/a")
                )
            }
        }
    }

    private var networkHistoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            performanceCardTitle(t("Последние тесты скорости", "Recent speed tests"), icon: "clock.arrow.circlepath", tint: .blue)
            ForEach(recentNetworkRows.prefix(6)) { row in
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Text(relativeTime(row.measuredAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                        Spacer(minLength: 6)
                        Text("\(String(format: "%.1f", row.downMbps)) Mbps")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                            .monospacedDigit()
                            .frame(width: 92, alignment: .trailing)
                        Text("\(String(format: "%.1f", row.upMbps)) Mbps")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .monospacedDigit()
                            .frame(width: 92, alignment: .trailing)
                        Text("\(String(format: "%.1f", row.responsivenessMs)) ms")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                            .frame(width: 78, alignment: .trailing)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(relativeTime(row.measuredAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Text("↓ \(String(format: "%.1f", row.downMbps))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                                .monospacedDigit()
                            Text("↑ \(String(format: "%.1f", row.upMbps))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .monospacedDigit()
                            Text("\(String(format: "%.1f", row.responsivenessMs)) ms")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .calmGlass(.nestedCard, cornerRadius: 10)
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private func networkListCard(
        title: String,
        icon: String,
        selectedRowID: String?,
        rows: [NetworkListRow],
        onSelect: @escaping (NetworkListRow) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            performanceCardTitle(title, icon: icon, tint: .teal)

            if rows.isEmpty {
                Text(t("Пока нет данных для отображения.", "No data to display yet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(rows) { row in
                            Button {
                                onSelect(row)
                            } label: {
                                HStack(spacing: 10) {
                                    DRayIconBadge(icon: row.icon, tint: .blue, size: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.title)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        if !row.subtitle.isEmpty {
                                            Text(row.subtitle)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Text(row.value)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(row.id == selectedRowID ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(minHeight: 160, maxHeight: 260)
            }
        }
        .padding(layoutMetrics.cardSpacing)
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.09, shadowOpacity: 0.05, padding: 0)
    }

    private func networkLegendRow(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text("\(title):")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func keyValueLine(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
        }
    }

    private var hasNetworkMapData: Bool {
        localNetworkHubCoordinate != nil || !geolocatedHostRows.isEmpty
    }

    private var filteredHostTrafficRows: [NetworkHostTraffic] {
        var rows = networkConnectionsMonitor.snapshot.topHosts

        if let selectedNetworkHostID {
            rows = rows.filter { $0.id == selectedNetworkHostID }
        }
        if let selectedNetworkServiceID {
            let hostIDs = Set(networkConnectionsMonitor.snapshot.serviceToHosts[selectedNetworkServiceID] ?? [])
            rows = rows.filter { hostIDs.contains($0.id) }
        }
        if let selectedNetworkProgramID {
            let hostIDs = Set(networkConnectionsMonitor.snapshot.programToHosts[selectedNetworkProgramID] ?? [])
            rows = rows.filter { hostIDs.contains($0.id) }
        }
        return rows
    }

    private var filteredServiceTrafficRows: [NetworkServiceTraffic] {
        var rows = networkConnectionsMonitor.snapshot.topServices

        if let selectedNetworkServiceID {
            rows = rows.filter { $0.id == selectedNetworkServiceID }
        }
        if let selectedNetworkHostID {
            let serviceIDs = Set(networkConnectionsMonitor.snapshot.hostToServices[selectedNetworkHostID] ?? [])
            rows = rows.filter { serviceIDs.contains($0.id) }
        }
        if let selectedNetworkProgramID {
            let serviceIDs = Set(networkConnectionsMonitor.snapshot.programToServices[selectedNetworkProgramID] ?? [])
            rows = rows.filter { serviceIDs.contains($0.id) }
        }
        return rows
    }

    private var filteredProgramTrafficRows: [NetworkProgramTraffic] {
        var rows = networkConnectionsMonitor.snapshot.topPrograms

        if let selectedNetworkProgramID {
            rows = rows.filter { $0.id == selectedNetworkProgramID }
        }
        if let selectedNetworkHostID {
            let programIDs = Set(networkConnectionsMonitor.snapshot.hostToPrograms[selectedNetworkHostID] ?? [])
            rows = rows.filter { programIDs.contains($0.id) }
        }
        if let selectedNetworkServiceID {
            let programIDs = Set(networkConnectionsMonitor.snapshot.serviceToPrograms[selectedNetworkServiceID] ?? [])
            rows = rows.filter { programIDs.contains($0.id) }
        }
        return rows
    }

    private var programConnectionsByID: [String: Int] {
        Dictionary(uniqueKeysWithValues: networkConnectionsMonitor.snapshot.topPrograms.map { ($0.id, $0.connectionCount) })
    }

    private var serviceLabelsByID: [String: String] {
        Dictionary(uniqueKeysWithValues: networkConnectionsMonitor.snapshot.topServices.map { ($0.id, $0.label) })
    }

    private var selectedHostLinkedProgramIDs: [String] {
        guard let selectedNetworkHostID else { return [] }
        let ids = networkConnectionsMonitor.snapshot.hostToPrograms[selectedNetworkHostID] ?? []
        return ids.sorted { lhs, rhs in
            let left = programConnectionsByID[lhs] ?? 0
            let right = programConnectionsByID[rhs] ?? 0
            if left == right {
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            return left > right
        }
    }

    private var selectedHostLinkedServiceIDs: [String] {
        guard let selectedNetworkHostID else { return [] }
        let ids = networkConnectionsMonitor.snapshot.hostToServices[selectedNetworkHostID] ?? []
        return ids.sorted { lhs, rhs in
            serviceSummaryLabel(for: lhs).localizedCaseInsensitiveCompare(serviceSummaryLabel(for: rhs)) == .orderedAscending
        }
    }

    private func hostProcessSummary(for host: String) -> String? {
        let ids = networkConnectionsMonitor.snapshot.hostToPrograms[host] ?? []
        guard !ids.isEmpty else { return nil }
        let prioritized = ids.sorted { lhs, rhs in
            let left = programConnectionsByID[lhs] ?? 0
            let right = programConnectionsByID[rhs] ?? 0
            if left == right {
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            return left > right
        }
        let headline = prioritized.prefix(2).joined(separator: ", ")
        if ids.count > 2 {
            return "\(headline) +\(ids.count - 2)"
        }
        return headline
    }

    private func serviceSummaryLabel(for serviceID: String) -> String {
        let parts = serviceID.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let proto = parts.first.map { String($0).uppercased() } ?? ""
        let port = parts.count > 1 ? String(parts[1]) : ""
        if let label = serviceLabelsByID[serviceID], !label.isEmpty {
            return port.isEmpty ? label : "\(label) (\(proto) \(port))"
        }
        if proto.isEmpty {
            return serviceID
        }
        return port.isEmpty ? proto : "\(proto) \(port)"
    }

    @ViewBuilder
    private func linkedProcessRow(programID: String) -> some View {
        let isSelected = programID == selectedNetworkProgramID
        let connectionCount = programConnectionsByID[programID]

        Button {
            selectedNetworkProgramID = isSelected ? nil : programID
            selectedNetworkHostID = nil
            selectedNetworkServiceID = nil
        } label: {
            HStack(spacing: 8) {
                Text(programID)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if let connectionCount {
                    Text("\(connectionCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.035))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.70))
                        .frame(width: 3)
                        .padding(.vertical, 6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var geolocatedHostRows: [GeolocatedHostTrafficRow] {
        filteredHostTrafficRows.compactMap { host in
            guard let geo = networkGeolocationMonitor.endpointsByHost[host.host] else { return nil }
            return GeolocatedHostTrafficRow(
                host: host.host,
                location: geo.locationLabel,
                totalBytes: host.totalBytes,
                latitude: geo.latitude,
                longitude: geo.longitude
            )
        }
    }

    private var localNetworkHubCoordinate: CLLocationCoordinate2D? {
        guard let lat = networkGeolocationMonitor.publicProfile?.latitude,
              let lon = networkGeolocationMonitor.publicProfile?.longitude else {
            return nil
        }
        guard abs(lat) <= 90, abs(lon) <= 180 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var networkMapRegion: MKCoordinateRegion {
        var coordinates = geolocatedHostRows.map(\.coordinate)
        if let local = localNetworkHubCoordinate {
            coordinates.append(local)
        }
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 18, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180)
            )
        }

        var minLatitude = first.latitude
        var maxLatitude = first.latitude
        var minLongitude = first.longitude
        var maxLongitude = first.longitude

        for coordinate in coordinates.dropFirst() {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        let latitudeSpan = min(170, max(8, (maxLatitude - minLatitude) * 1.6))
        let longitudeSpan = min(340, max(12, (maxLongitude - minLongitude) * 1.6))
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(latitudeDelta: latitudeSpan, longitudeDelta: longitudeSpan)
        )
    }

    private var networkMapIdentity: String {
        var seed = geolocatedHostRows.map(\.host).joined(separator: "|")
        if let ip = networkGeolocationMonitor.publicProfile?.ip {
            seed += ":\(ip)"
        }
        if let selectedNetworkHostID {
            seed += ":focus=\(selectedNetworkHostID)"
        }
        return seed
    }

    private func endpointTint(for host: String) -> Color {
        let scalarSum = host.unicodeScalars.map(\.value).reduce(0, +)
        let hue = Double(scalarSum % 360) / 360.0
        return Color(hue: hue, saturation: 0.34, brightness: 0.72)
    }

    private var currentIncomingRate: Double {
        switch networkDataRepresentation {
        case .bits:
            return monitor.snapshot.networkDownBytesPerSecond * 8.0
        case .bytes:
            return monitor.snapshot.networkDownBytesPerSecond
        case .packets:
            return monitor.snapshot.networkDownPacketsPerSecond
        }
    }

    private var currentOutgoingRate: Double {
        switch networkDataRepresentation {
        case .bits:
            return monitor.snapshot.networkUpBytesPerSecond * 8.0
        case .bytes:
            return monitor.snapshot.networkUpBytesPerSecond
        case .packets:
            return monitor.snapshot.networkUpPacketsPerSecond
        }
    }

    private var currentIncomingRateLabel: String {
        formatRate(currentIncomingRate)
    }

    private var currentOutgoingRateLabel: String {
        formatRate(currentOutgoingRate)
    }

    private var networkSessionDurationText: String {
        guard let startedAt = networkRateHistory.first?.measuredAt else { return "0s" }
        let elapsed = max(0, Date().timeIntervalSince(startedAt))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: elapsed) ?? "0s"
    }

    private var networkDonutSegments: [DRayDonutSegment] {
        switch networkDataRepresentation {
        case .bits, .bytes:
            return [
                DRayDonutSegment(title: "incoming", value: Double(monitor.snapshot.networkInboundBytesTotal), color: .accentColor),
                DRayDonutSegment(title: "outgoing", value: Double(monitor.snapshot.networkOutboundBytesTotal), color: .green),
                DRayDonutSegment(title: "dropped", value: Double(monitor.snapshot.networkDroppedPacketsTotal), color: .gray)
            ]
        case .packets:
            return [
                DRayDonutSegment(title: "incoming", value: Double(monitor.snapshot.networkInboundPacketsTotal), color: .accentColor),
                DRayDonutSegment(title: "outgoing", value: Double(monitor.snapshot.networkOutboundPacketsTotal), color: .green),
                DRayDonutSegment(title: "dropped", value: Double(monitor.snapshot.networkDroppedPacketsTotal), color: .gray)
            ]
        }
    }

    private var networkTotalTitle: String {
        switch networkDataRepresentation {
        case .bits:
            let bits = Double(monitor.snapshot.networkInboundBytesTotal + monitor.snapshot.networkOutboundBytesTotal) * 8.0
            return formatBits(bits)
        case .bytes:
            let bytes = monitor.snapshot.networkInboundBytesTotal + monitor.snapshot.networkOutboundBytesTotal
            return formatByteCount(bytes)
        case .packets:
            let packets = monitor.snapshot.networkInboundPacketsTotal + monitor.snapshot.networkOutboundPacketsTotal
            return "\(packets) pkt"
        }
    }

    private var networkLegendIncoming: String {
        switch networkDataRepresentation {
        case .bits:
            return formatBits(Double(monitor.snapshot.networkInboundBytesTotal) * 8.0)
        case .bytes:
            return formatByteCount(monitor.snapshot.networkInboundBytesTotal)
        case .packets:
            return "\(monitor.snapshot.networkInboundPacketsTotal) pkt"
        }
    }

    private var networkLegendOutgoing: String {
        switch networkDataRepresentation {
        case .bits:
            return formatBits(Double(monitor.snapshot.networkOutboundBytesTotal) * 8.0)
        case .bytes:
            return formatByteCount(monitor.snapshot.networkOutboundBytesTotal)
        case .packets:
            return "\(monitor.snapshot.networkOutboundPacketsTotal) pkt"
        }
    }

    private var networkLegendDropped: String {
        "\(monitor.snapshot.networkDroppedPacketsTotal) pkt"
    }

    private func formatRate(_ value: Double) -> String {
        switch networkDataRepresentation {
        case .bits:
            return "\(formatBits(value))/s"
        case .bytes:
            return "\(formatBytes(value))/s"
        case .packets:
            return "\(Int(value.rounded())) pkt/s"
        }
    }

    private func formatByteCount(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .binary)
    }

    private func formatBytes(_ value: Double) -> String {
        let clamped = max(0, value)
        return ByteCountFormatter.string(fromByteCount: Int64(clamped), countStyle: .binary)
    }

    private func formatBits(_ value: Double) -> String {
        let clamped = max(0, value)
        if clamped >= 1_000_000_000 {
            return String(format: "%.1f Gb", clamped / 1_000_000_000)
        }
        if clamped >= 1_000_000 {
            return String(format: "%.1f Mb", clamped / 1_000_000)
        }
        if clamped >= 1_000 {
            return String(format: "%.1f Kb", clamped / 1_000)
        }
        return String(format: "%.0f b", clamped)
    }
}

private struct NetworkListRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let value: String
    let icon: String
}

private struct GeolocatedHostTrafficRow: Identifiable {
    let host: String
    let location: String
    let totalBytes: UInt64
    let latitude: Double
    let longitude: Double

    var id: String { host }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct NetworkTrafficDualChart: View {
    let incoming: [Double]
    let outgoing: [Double]
    let incomingTint: Color
    let outgoingTint: Color

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(1, (incoming + outgoing).max() ?? 1)
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.03))

                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)

                if incoming.count >= 2 {
                    NetworkAreaPath(values: incoming, maxValue: maxValue)
                        .fill(
                            LinearGradient(
                                colors: [incomingTint.opacity(0.11), incomingTint.opacity(0.018)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }

                if incoming.count >= 2 {
                    NetworkLinePath(values: incoming, maxValue: maxValue)
                        .stroke(incomingTint.opacity(0.58), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }

                if outgoing.count >= 2 {
                    NetworkLinePath(values: outgoing, maxValue: maxValue)
                        .stroke(outgoingTint.opacity(0.56), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }
            }
        }
    }
}

private struct NetworkLinePath: Shape {
    let values: [Double]
    let maxValue: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }
        if values.count == 1 {
            let y = rect.maxY - CGFloat(values[0] / maxValue) * rect.height
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            return path
        }

        let stepX = rect.width / CGFloat(max(values.count - 1, 1))
        let points = values.enumerated().map { index, value -> CGPoint in
            let normalized = max(0, min(1, value / maxValue))
            return CGPoint(
                x: rect.minX + CGFloat(index) * stepX,
                y: rect.maxY - CGFloat(normalized) * rect.height
            )
        }

        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct NetworkAreaPath: Shape {
    let values: [Double]
    let maxValue: Double

    func path(in rect: CGRect) -> Path {
        var line = NetworkLinePath(values: values, maxValue: maxValue).path(in: rect)
        line.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        line.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        line.closeSubpath()
        return line
    }
}
