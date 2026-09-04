import SwiftUI
import XeneonWidgetsCore

struct ProcBox: View {
    @ObservedObject var processes: ProcessProvider
    @ObservedObject var state: DashboardState
    let wide: Bool
    var onHeaderTap: (() -> Void)?

    @State private var sort: ProcSort = .cpu
    @State private var filter: ProcFilter = .all

    @Environment(\.theme) private var theme

    init(
        processes: ProcessProvider,
        state: DashboardState,
        wide: Bool,
        onHeaderTap: (() -> Void)? = nil
    ) {
        self.processes = processes
        self.state = state
        self.wide = wide
        self.onHeaderTap = onHeaderTap
    }

    private var rowLimit: Int { wide ? 9 : 7 }
    private var rowHeight: CGFloat { wide ? 44 : 54 }
    private var rowFont: CGFloat { wide ? 16 : 17 }

    private var displayed: [ProcessSample] {
        let filtered = ProcessMath.filter(
            processes.processes,
            by: filter,
            currentUID: processes.currentUID
        )
        return Array(ProcessMath.sort(filtered, by: sort).prefix(rowLimit))
    }

    private var valueLabel: String {
        wide ? "\(rowLimit) · \(sort.rawValue) ↓" : "top 7 · cpu ↓"
    }

    var body: some View {
        BoxContainer(
            title: "proc",
            meta: "\(processes.processCount) processes · \(processes.threadCount) threads",
            value: valueLabel,
            gap: 12
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ChipRow(
                    titles: ProcFilter.allCases.map(\.rawValue),
                    selectedIndex: ProcFilter.allCases.firstIndex(of: filter) ?? 0,
                    height: 48,
                    onSelect: { filter = ProcFilter.allCases[$0] }
                )
                ProcHeader(wide: wide, sortKey: sort.rawValue) { key in
                    if let next = ProcSort(rawValue: key) {
                        sort = next
                    }
                }
                VStack(spacing: 0) {
                    ForEach(displayed) { sample in
                        ProcRow(
                            model: model(for: sample),
                            wide: wide,
                            selected: wide && state.selectedPID == sample.pid,
                            height: rowHeight,
                            fontSize: rowFont,
                            onTap: { select(sample) }
                        )
                    }
                }
                Spacer(minLength: 0)
                footer
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("tap row → details · long-press → sort")
                .font(Typography.pro(14))
                .foregroundStyle(theme.text3)
            Spacer(minLength: 8)
            Text("tap header → full list")
                .font(Typography.pro(14))
                .foregroundStyle(theme.text3)
                .contentShape(Rectangle())
                .onTapGesture { onHeaderTap?() }
        }
    }

    private func select(_ sample: ProcessSample) {
        state.selectedPID = sample.pid
        processes.watchedPID = sample.pid
        state.noteActivity()
    }

    private func model(for sample: ProcessSample) -> ProcRow.Model {
        let watched = wide && processes.watchedPID == sample.pid
        let detail = watched ? processes.detail : nil
        return ProcRow.Model(
            id: sample.pid,
            icon: processes.icon(for: sample),
            name: sample.name,
            pid: String(sample.pid),
            user: sample.user,
            threads: String(sample.threads),
            mem: ProcessMath.memLabel(sample.residentBytes),
            cpu: sample.cpuPercent,
            memHistory: detail?.memHistory.elements ?? [],
            cpuHistory: detail?.cpuHistory.elements ?? []
        )
    }
}
