import SwiftUI
import AppKit

struct PerformanceView: View {
    @StateObject var model: PerformanceViewModel
    @StateObject var monitor = LiveSystemMetricsMonitor()

    @State var selectedPaths = Set<String>()
    @State var showCleanupConfirm = false
    @State var pendingReliefAction: ReliefAction?
    @State var showReliefConfirm = false
    @State var reliefResultMessage: String?
    @State var workspaceTab: PerformanceWorkspaceTab = .overview

    @State var cpuTrend: [Double] = []
    @State var memoryTrend: [Double] = []
    @State var networkHistory: [NetworkHistoryPoint] = []

    init(rootModel: RootViewModel) {
        _model = StateObject(wrappedValue: PerformanceViewModel(root: rootModel))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
                header
                globalCommandStrip
                workspaceNavigation
                workspaceContent
                    .glassSurface(cornerRadius: 16, strokeOpacity: 0.10, shadowOpacity: 0.05, padding: 12)
            }
            .padding(.top, 6)
            .padding(12)
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
            monitor.start()
            if model.performance.report == nil {
                model.runPerformanceScan()
            }
            if model.performance.batteryEnergyReport == nil {
                model.loadBatteryEnergyReport()
            }
        }
        .onDisappear {
            monitor.stop()
        }
        .onReceive(monitor.$snapshot) { snapshot in
            appendTrend(value: snapshot.cpuLoadPercent, to: &cpuTrend)
            appendTrend(value: snapshot.memoryPressurePercent, to: &memoryTrend)
        }
        .onChange(of: model.performance.networkSpeedTestResult?.measuredAt) {
            guard let result = model.performance.networkSpeedTestResult, result.isSuccess else { return }
            appendNetworkHistory(result)
        }
        .onChange(of: model.performance.report?.generatedAt) {
            let valid = Set(startupEntries.map { $0.url.path })
            selectedPaths = selectedPaths.intersection(valid)
        }
    }

    private var header: some View {
        ModuleHeaderCard(
            title: t("Производительность", "Performance"),
            subtitle: t(
                "Командный центр диагностики: нагрузка, батарея, автозапуск и сеть.",
                "Diagnostics command center: load, battery, startup and network."
            )
        ) {
            EmptyView()
        }
    }

    private var globalCommandStrip: some View {
        HStack(spacing: 8) {
            Button(t("Запустить диагностику", "Run Diagnostics")) {
                model.runPerformanceScan()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(model.performance.isScanRunning)

            Button(t("Экспорт лога", "Export Ops Log")) {
                if let url = model.exportOperationLogReport() {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(t("Показать crash log", "Reveal Crash Log")) {
                model.revealCrashTelemetry()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer(minLength: 10)

            if model.performance.isScanRunning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(t("Диагностика выполняется", "Diagnostics running"))
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 14, strokeOpacity: 0.08, shadowOpacity: 0.03, padding: 0)
    }

    private var workspaceNavigation: some View {
        HStack(spacing: 10) {
            Picker("", selection: $workspaceTab) {
                Text(t("Обзор", "Overview")).tag(PerformanceWorkspaceTab.overview)
                Text(t("Нагрузка", "System Load")).tag(PerformanceWorkspaceTab.systemLoad)
                Text(t("Батарея", "Battery & Energy")).tag(PerformanceWorkspaceTab.batteryEnergy)
                Text(t("Автозапуск", "Startup")).tag(PerformanceWorkspaceTab.startup)
                Text(t("Сеть", "Network")).tag(PerformanceWorkspaceTab.network)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 2)
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
