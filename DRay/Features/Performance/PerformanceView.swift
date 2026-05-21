import SwiftUI
import AppKit

struct PerformanceView: View {
    @StateObject var model: PerformanceViewModel
    @StateObject var monitor = LiveSystemMetricsMonitor()
    @StateObject var networkConnectionsMonitor = NetworkConnectionsMonitor()
    @StateObject var networkGeolocationMonitor = NetworkGeolocationMonitor()
    @StateObject var networkLatencyMonitor = NetworkLatencyMonitor()
    let networkPortScannerService = NetworkPortScannerService()
    let wakeOnLANService = WakeOnLANService()
    @Environment(\.drayLayoutMetrics) var layoutMetrics

    @State var selectedPaths = Set<String>()
    @State var showCleanupConfirm = false
    @State var pendingReliefAction: ReliefAction?
    @State var showReliefConfirm = false
    @State var reliefResultMessage: String?
    @State var workspaceTab: PerformanceWorkspaceTab = .overview

    @State var cpuTrend: [Double] = []
    @State var memoryTrend: [Double] = []
    @State var networkRateHistory: [NetworkRatePoint] = []
    @State var networkDataRepresentation: NetworkDataRepresentation = .bytes
    @State var networkHistory: [NetworkHistoryPoint] = []
    @State var networkSubscreen: NetworkWorkspaceSubscreen = .overview
    @AppStorage("dray.network.resolveLocations") var persistedNetworkResolveLocations = true
    @AppStorage("dray.network.dataRepresentation") var persistedNetworkDataRepresentation = NetworkDataRepresentation.bytes.rawValue
    @AppStorage("dray.network.portScanner.host") var persistedPortScannerHost = "127.0.0.1"
    @AppStorage("dray.network.portScanner.startPort") var persistedPortScannerStartPort = "1"
    @AppStorage("dray.network.portScanner.endPort") var persistedPortScannerEndPort = "1024"
    @State var didRestoreNetworkWorkspacePreferences = false
    @State var selectedNetworkHostID: String?
    @State var selectedNetworkServiceID: String?
    @State var selectedNetworkProgramID: String?
    @State var portScannerHost = "127.0.0.1"
    @State var portScannerStartPort = "1"
    @State var portScannerEndPort = "1024"
    @State var portScannerOpenPorts: [Int] = []
    @State var portScannerStatusMessage: String?
    @State var isPortScannerRunning = false
    @State var portScannerTask: Task<Void, Never>?
    @State var wakeOnLANMACAddress = "00:1A:2B:3C:4D:5E"
    @State var wakeOnLANBroadcastAddress = "255.255.255.255"
    @State var wakeOnLANPort = "9"
    @State var wakeOnLANStatusMessage: String?

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: PerformanceViewModel(root: rootModel))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: layoutMetrics.sectionSpacing) {
                header
                workspaceNavigation
                workspaceContent
                    .glassSurface(cornerRadius: 16, strokeOpacity: 0.10, shadowOpacity: 0.05, padding: 12)
            }
            .padding(.top, 6)
            .padding(layoutMetrics.cardSpacing)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            t("Отключить выбранные элементы автозапуска?", "Disable selected startup entries?"),
            isPresented: $showCleanupConfirm,
            titleVisibility: .visible
        ) {
            Button(t("Переместить в корзину", "Move to Trash"), role: .destructive) {
                model.cleanupStartupEntries(selectedEntries)
                selectedPaths.removeAll()
            }
            Button(t("Отмена", "Cancel"), role: .cancel) {}
        } message: {
            Text(t(
                "Выбранные элементы автозапуска будут перемещены в корзину.",
                "Selected startup entries will be moved to Trash."
            ))
        }
        .confirmationDialog(
            reliefDialogTitle,
            isPresented: $showReliefConfirm,
            titleVisibility: .visible
        ) {
            Button(reliefActionTitle) {
                executeReliefAction()
            }
            Button(t("Отмена", "Cancel"), role: .cancel) {
                pendingReliefAction = nil
            }
        }
        .alert(t("Изменение нагрузки", "Live Load Adjustment"), isPresented: Binding(
            get: { reliefResultMessage != nil },
            set: { if !$0 { reliefResultMessage = nil } }
        )) {
            Button(t("ОК", "OK"), role: .cancel) {}
        } message: {
            Text(reliefResultMessage ?? "")
        }
        .onAppear {
            restoreNetworkWorkspacePreferences()
            monitor.start()
            networkConnectionsMonitor.start()
            networkGeolocationMonitor.start()
            refreshNetworkToolsMonitoring()
            if model.performance.report == nil {
                model.runPerformanceScan()
            }
            if model.performance.batteryEnergyReport == nil {
                model.loadBatteryEnergyReport()
            }
        }
        .onDisappear {
            monitor.stop()
            networkConnectionsMonitor.stop()
            networkGeolocationMonitor.stop()
            networkLatencyMonitor.stop()
            portScannerTask?.cancel()
            portScannerTask = nil
        }
        .onReceive(monitor.$snapshot) { snapshot in
            appendTrend(value: snapshot.cpuLoadPercent, to: &cpuTrend)
            appendTrend(value: snapshot.memoryPressurePercent, to: &memoryTrend)
            appendNetworkRatePoint(from: snapshot)
        }
        .onReceive(networkConnectionsMonitor.$snapshot) { snapshot in
            let hosts = snapshot.topHosts.map(\.host)
            networkGeolocationMonitor.refreshEndpoints(hosts: hosts)

            let hostIDs = Set(snapshot.topHosts.map(\.id))
            if let selectedNetworkHostID, !hostIDs.contains(selectedNetworkHostID) {
                self.selectedNetworkHostID = nil
            }

            let serviceIDs = Set(snapshot.topServices.map(\.id))
            if let selectedNetworkServiceID, !serviceIDs.contains(selectedNetworkServiceID) {
                self.selectedNetworkServiceID = nil
            }

            let programIDs = Set(snapshot.topPrograms.map(\.id))
            if let selectedNetworkProgramID, !programIDs.contains(selectedNetworkProgramID) {
                self.selectedNetworkProgramID = nil
            }
        }
        .onChange(of: model.performance.networkSpeedTestResult?.measuredAt) {
            guard let result = model.performance.networkSpeedTestResult, result.isSuccess else { return }
            appendNetworkHistory(result)
        }
        .onChange(of: networkDataRepresentation) {
            persistedNetworkDataRepresentation = networkDataRepresentation.rawValue
            networkRateHistory.removeAll()
            appendNetworkRatePoint(from: monitor.snapshot)
        }
        .onChange(of: networkGeolocationMonitor.resolveEnabled) {
            persistedNetworkResolveLocations = networkGeolocationMonitor.resolveEnabled
        }
        .onChange(of: portScannerHost) {
            persistedPortScannerHost = portScannerHost
        }
        .onChange(of: portScannerStartPort) {
            persistedPortScannerStartPort = portScannerStartPort
        }
        .onChange(of: portScannerEndPort) {
            persistedPortScannerEndPort = portScannerEndPort
        }
        .onChange(of: workspaceTab) {
            refreshNetworkToolsMonitoring()
        }
        .onChange(of: networkSubscreen) {
            refreshNetworkToolsMonitoring()
        }
        .onChange(of: model.performance.report?.generatedAt) {
            let valid = Set(startupEntries.map { $0.url.path })
            selectedPaths = selectedPaths.intersection(valid)
        }
    }

    private func restoreNetworkWorkspacePreferences() {
        guard !didRestoreNetworkWorkspacePreferences else { return }
        didRestoreNetworkWorkspacePreferences = true

        if let representation = NetworkDataRepresentation(rawValue: persistedNetworkDataRepresentation) {
            networkDataRepresentation = representation
        } else {
            networkDataRepresentation = .bytes
            persistedNetworkDataRepresentation = NetworkDataRepresentation.bytes.rawValue
        }

        networkGeolocationMonitor.resolveEnabled = persistedNetworkResolveLocations

        let host = persistedPortScannerHost.trimmingCharacters(in: .whitespacesAndNewlines)
        portScannerHost = host.isEmpty ? "127.0.0.1" : persistedPortScannerHost

        let startPort = validatedPortScannerText(persistedPortScannerStartPort, fallback: "1")
        let endPort = validatedPortScannerText(persistedPortScannerEndPort, fallback: "1024")
        if let start = Int(startPort), let end = Int(endPort), start <= end {
            portScannerStartPort = startPort
            portScannerEndPort = endPort
        } else {
            portScannerStartPort = "1"
            portScannerEndPort = "1024"
        }

        persistedPortScannerHost = portScannerHost
        persistedPortScannerStartPort = portScannerStartPort
        persistedPortScannerEndPort = portScannerEndPort
    }

    private func validatedPortScannerText(_ rawValue: String, fallback: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmed), (1...65_535).contains(port) else {
            return fallback
        }
        return trimmed
    }

    private var header: some View {
        ModuleHeaderCard(
            title: t("Производительность", "Performance"),
            subtitle: t(
                "Командный центр диагностики: нагрузка, батарея, автозапуск и сеть.",
                "Diagnostics command center: load, battery, startup and network."
            )
        ) {
            globalCommandStrip
        }
    }

    private var globalCommandStrip: some View {
        HStack(spacing: 8) {
            Button(t("Запустить диагностику", "Run Diagnostics")) {
                model.runPerformanceScan()
            }
            .buttonStyle(DRayPrimaryButtonStyle())
            .controlSize(.small)
            .disabled(model.performance.isScanRunning)

            Button(t("Экспорт лога", "Export Ops Log")) {
                if let url = model.exportOperationLogReport() {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            .buttonStyle(DRaySecondaryButtonStyle())
            .controlSize(.small)

            Button(t("Показать crash log", "Reveal Crash Log")) {
                model.revealCrashTelemetry()
            }
            .buttonStyle(DRaySecondaryButtonStyle())
            .controlSize(.small)

            if model.performance.isScanRunning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(t("Диагностика выполняется", "Diagnostics running"))
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.045), in: Capsule())
            }
        }
    }

    private var workspaceNavigation: some View {
        Picker("", selection: $workspaceTab) {
            Text(t("Обзор", "Overview")).tag(PerformanceWorkspaceTab.overview)
            Text(t("Нагрузка", "System Load")).tag(PerformanceWorkspaceTab.systemLoad)
            Text(t("Батарея", "Battery & Energy")).tag(PerformanceWorkspaceTab.batteryEnergy)
            Text(t("Автозапуск", "Startup")).tag(PerformanceWorkspaceTab.startup)
            Text(t("Сеть", "Network")).tag(PerformanceWorkspaceTab.network)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 620)
        .padding(6)
        .calmGlass(.section, cornerRadius: 16)
    }

    @ViewBuilder
    private var workspaceContent: some View {
        switch workspaceTab {
        case .overview:
            overviewWorkspace
        case .systemLoad:
            systemLoadWorkspace
        case .batteryEnergy:
            batteryEnergyWorkspace
        case .startup:
            startupWorkspace
        case .network:
            networkWorkspace
        }
    }
}

extension PerformanceView {
    var isRussian: Bool { model.appLanguage.localeCode.lowercased().hasPrefix("ru") }

    func t(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }
}
