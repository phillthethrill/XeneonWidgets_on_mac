import SwiftUI

struct ProcHeader: View {
    let wide: Bool
    let sortKey: String
    let onTap: (String) -> Void

    @Environment(\.theme) private var theme

    init(wide: Bool, sortKey: String, onTap: @escaping (String) -> Void) {
        self.wide = wide
        self.sortKey = sortKey
        self.onTap = onTap
    }

    var body: some View {
        Group {
            if wide {
                wideHeader
            } else {
                compactHeader
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
    }

    private var compactHeader: some View {
        HStack(spacing: 12) {
            Spacer().frame(width: 28)
            header("Name", key: "name")
                .frame(maxWidth: .infinity, alignment: .leading)
            header("PID", key: "pid")
                .frame(width: 60, alignment: .leading)
            staticHeader("User")
                .frame(width: 96, alignment: .leading)
            header("Mem", key: "mem", trailing: true)
                .frame(width: 92, alignment: .trailing)
            header("CPU", key: "cpu", trailing: true)
                .frame(width: 76, alignment: .trailing)
            staticHeader("Thr")
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var wideHeader: some View {
        HStack(spacing: 12) {
            Spacer().frame(width: 32)
            header("Name", key: "name")
                .frame(width: 480, alignment: .leading)
            header("PID", key: "pid")
                .frame(width: 80, alignment: .leading)
            staticHeader("User")
                .frame(width: 140, alignment: .leading)
            staticHeader("Thr")
                .frame(width: 60, alignment: .leading)
            Spacer().frame(width: 90)
            header("Mem", key: "mem", trailing: true)
                .frame(width: 110, alignment: .trailing)
            Spacer().frame(width: 90)
            header("CPU", key: "cpu", trailing: true)
                .frame(width: 90, alignment: .trailing)
            Spacer(minLength: 0)
        }
    }

    private func header(_ title: String, key: String, trailing: Bool = false) -> some View {
        let active = sortKey == key
        let arrow = active && (key == "cpu" || key == "mem") ? " ↓" : ""
        return Text(title + arrow)
            .font(Typography.colHead)
            .fontWeight(active ? .semibold : .regular)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(active ? theme.text : theme.text3)
            .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap(key) }
    }

    private func staticHeader(_ title: String) -> some View {
        Text(title)
            .font(Typography.colHead)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(theme.text3)
    }
}
