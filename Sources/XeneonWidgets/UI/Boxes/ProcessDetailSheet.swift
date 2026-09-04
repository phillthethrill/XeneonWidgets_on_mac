import AppKit
import SwiftUI
import XeneonWidgetsCore

struct ProcessDetailSheet: View {
    let process: ProcessSample
    let icon: NSImage?
    let detail: ProcessDetail?
    @ObservedObject var state: DashboardState
    let onTerminate: () -> Void
    let onForceQuit: () -> Void
    let onClose: () -> Void

    @Environment(\.theme) private var theme

    init(
        process: ProcessSample,
        icon: NSImage?,
        detail: ProcessDetail?,
        state: DashboardState,
        onTerminate: @escaping () -> Void,
        onForceQuit: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.process = process
        self.icon = icon
        self.detail = detail
        self.state = state
        self.onTerminate = onTerminate
        self.onForceQuit = onForceQuit
        self.onClose = onClose
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.sheetRadius)
        VStack(alignment: .leading, spacing: 20) {
            header
            commandBox
            statTiles
            graphs
            Spacer(minLength: 0)
            bottom
        }
        .padding(28)
        .frame(width: 780)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.sheet, in: shape)
        .overlay(shape.stroke(theme.hairline, lineWidth: Metrics.hairline))
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.55), radius: 90, x: -30, y: 0)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            AppIconView(image: icon, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(process.name)
                    .font(Typography.pro(30, .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(metaLine)
                    .font(Typography.smallMono)
                    .monoDigits()
                    .foregroundStyle(theme.text3)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onClose) {
                Text("×")
                    .font(Typography.pro(24))
                    .foregroundStyle(theme.text2)
                    .frame(width: 56, height: 56)
                    .background(theme.surface2, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var metaLine: String {
        let since = process.startTime.map { Formatters.clockHM($0) } ?? "—"
        return "PID \(process.pid) · \(process.user) · Running · since \(since)"
    }

    private var commandBox: some View {
        Text(process.path.isEmpty ? "—" : process.path)
            .font(Typography.mono(14))
            .monoDigits()
            .foregroundStyle(theme.text2)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(theme.surface2, in: RoundedRectangle(cornerRadius: 12))
    }

    private var statTiles: some View {
        HStack(spacing: 12) {
            tile(
                label: "CPU",
                value: Formatters.percent1(process.cpuPercent),
                color: theme.stateColor(process.cpuPercent, .process)
            )
            tile(
                label: "Memory",
                value: ProcessMath.memLabel(process.residentBytes),
                color: theme.text
            )
            tile(
                label: "Threads",
                value: String(process.threads),
                color: theme.text
            )
            tile(
                label: "Files",
                value: process.openFiles.map(String.init) ?? "—",
                color: theme.text
            )
        }
    }

    private func tile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typography.microSans)
                .foregroundStyle(theme.text3)
            Text(value)
                .font(Typography.mono(28, .semibold))
                .monoDigits()
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(theme.surface2, in: RoundedRectangle(cornerRadius: 14))
    }

    private var graphs: some View {
        let cpuValues = detail?.cpuHistory.elements ?? []
        let memValues = detail?.memHistory.elements ?? []
        let memMax = max(memValues.max() ?? 1, 1)
        return HStack(spacing: 16) {
            graphColumn(title: "CPU · last 60 s") {
                HistoryGraph(values: cpuValues, style: .ramp)
            }
            graphColumn(title: "Memory · last 60 s") {
                HistoryGraph(
                    values: memValues,
                    max: memMax,
                    style: .solid(theme.accent),
                    thresholds: []
                )
            }
        }
    }

    private func graphColumn<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typography.microSans)
                .foregroundStyle(theme.text3)
            content()
                .frame(width: 354, height: 96)
        }
    }

    @ViewBuilder
    private var bottom: some View {
        if let confirm = state.confirm {
            ForceQuitConfirmCard(
                processName: process.name,
                action: confirm,
                onCancel: { state.confirm = nil },
                onConfirm: {
                    switch confirm {
                    case .terminate:
                        onTerminate()
                    case .forceQuit:
                        onForceQuit()
                    }
                    state.confirm = nil
                }
            )
        } else {
            HStack(spacing: 12) {
                DashButton("Terminate", kind: .secondary) {
                    state.confirm = .terminate(process.pid)
                }
                DashButton("Force Quit…", kind: .destructiveTinted) {
                    state.confirm = .forceQuit(process.pid)
                }
            }
        }
    }
}
