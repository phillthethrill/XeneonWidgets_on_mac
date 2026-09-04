import AppKit
import SwiftUI
import XeneonWidgetsCore

struct ProcRow: View {
    struct Model: Identifiable, Equatable {
        let id: pid_t
        let icon: NSImage?
        let name: String
        let pid: String
        let user: String
        let threads: String
        let mem: String
        let cpu: Double
        let memHistory: [Double]
        let cpuHistory: [Double]

        static func == (lhs: Model, rhs: Model) -> Bool {
            lhs.id == rhs.id
                && lhs.icon === rhs.icon
                && lhs.name == rhs.name
                && lhs.pid == rhs.pid
                && lhs.user == rhs.user
                && lhs.threads == rhs.threads
                && lhs.mem == rhs.mem
                && lhs.cpu == rhs.cpu
                && lhs.memHistory == rhs.memHistory
                && lhs.cpuHistory == rhs.cpuHistory
        }
    }

    let model: Model
    let wide: Bool
    let selected: Bool
    let height: CGFloat
    let fontSize: CGFloat
    let onTap: () -> Void

    @Environment(\.theme) private var theme

    init(model: Model, wide: Bool, selected: Bool, height: CGFloat, fontSize: CGFloat, onTap: @escaping () -> Void) {
        self.model = model
        self.wide = wide
        self.selected = selected
        self.height = height
        self.fontSize = fontSize
        self.onTap = onTap
    }

    var body: some View {
        Group {
            if wide {
                wideRow
            } else {
                compactRow
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.surface2)
            }
        }
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.accent, lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onTap)
    }

    private var cpuColor: Color {
        theme.stateColor(model.cpu, .process)
    }

    private var compactRow: some View {
        HStack(spacing: 12) {
            AppIconView(image: model.icon, size: 28)
                .frame(width: 28)
            nameText
                .frame(maxWidth: .infinity, alignment: .leading)
            pidText
                .frame(width: 60, alignment: .leading)
            userText
                .frame(width: 96, alignment: .leading)
            memText
                .frame(width: 92, alignment: .trailing)
            cpuText
                .frame(width: 76, alignment: .trailing)
            threadsText
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var wideRow: some View {
        HStack(spacing: 12) {
            AppIconView(image: model.icon, size: 32)
                .frame(width: 32)
            nameText
                .frame(width: 480, alignment: .leading)
            pidText
                .frame(width: 80, alignment: .leading)
            userText
                .frame(width: 140, alignment: .leading)
            threadsText
                .frame(width: 60, alignment: .leading)
            Sparkline(values: model.memHistory, color: theme.text3, max: 8)
                .frame(width: 80, height: 22)
                .frame(width: 90)
            memText
                .frame(width: 110, alignment: .trailing)
            Sparkline(values: model.cpuHistory, color: cpuColor, max: 100)
                .frame(width: 80, height: 22)
                .frame(width: 90)
            cpuText
                .frame(width: 90, alignment: .trailing)
            Spacer(minLength: 0)
        }
    }

    private var nameText: some View {
        Text(model.name)
            .font(Typography.pro(fontSize, .medium))
            .foregroundStyle(theme.text)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var pidText: some View {
        Text(model.pid)
            .font(Typography.mono(fontSize - 2))
            .monoDigits()
            .foregroundStyle(theme.text3)
            .lineLimit(1)
    }

    private var userText: some View {
        Text(model.user)
            .font(Typography.pro(fontSize - 2))
            .foregroundStyle(theme.text3)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var threadsText: some View {
        Text(model.threads)
            .font(Typography.mono(fontSize - 2))
            .monoDigits()
            .foregroundStyle(theme.text3)
            .lineLimit(1)
    }

    private var memText: some View {
        Text(model.mem)
            .font(Typography.mono(fontSize))
            .monoDigits()
            .foregroundStyle(theme.text2)
            .lineLimit(1)
    }

    private var cpuText: some View {
        Text(Formatters.percent1(model.cpu))
            .font(Typography.mono(fontSize, .semibold))
            .monoDigits()
            .foregroundStyle(cpuColor)
            .lineLimit(1)
    }
}
