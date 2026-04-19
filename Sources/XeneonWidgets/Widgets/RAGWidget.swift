import SwiftUI

struct RAGWidgetView: View {
    @ObservedObject var ragStatus: RAGStatusProvider

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
            HStack(spacing: 0) {
                ForEach(components) { component in
                    RAGComponentView(component: component)
                    if component.id != components.last?.id {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 1)
                            .padding(.vertical, 16)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var components: [RAGComponentState] {
        [ragStatus.ollama, ragStatus.docling, ragStatus.openWebUI, ragStatus.watcher]
    }
}

// MARK: - Per-component cell

private struct RAGComponentView: View {
    let component: RAGComponentState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: component.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(component.name)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: dotColor.opacity(0.7), radius: dotColor == .yellow ? 0 : 4)
                Text(detailText)
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dotColor: Color {
        switch component.status {
        case .checking:   return .yellow
        case .up:         return .green
        case .down:       return .red
        }
    }

    private var detailText: String {
        switch component.status {
        case .checking:            return "checking…"
        case .up(let detail):      return detail
        case .down(let detail):    return detail
        }
    }
}
