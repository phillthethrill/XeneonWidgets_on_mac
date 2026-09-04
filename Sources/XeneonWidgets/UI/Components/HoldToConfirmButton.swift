import SwiftUI

struct HoldToConfirmButton: View {
    let title: String
    let holdSeconds: Double
    let action: () -> Void

    @Environment(\.theme) private var theme
    @StateObject private var hold = HoldModel()

    init(title: String, holdSeconds: Double, action: @escaping () -> Void) {
        self.title = title
        self.holdSeconds = holdSeconds
        self.action = action
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                theme.crit
                Color.black.opacity(0.25)
                    .frame(width: geo.size.width * hold.progress)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                HStack {
                    Text(title)
                        .font(Typography.button)
                    Spacer(minLength: 8)
                    Text(progressLabel)
                        .font(Typography.mono(14))
                        .monoDigits()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
            }
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius))
        .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    hold.start(holdSeconds: holdSeconds, action: action)
                }
                .onEnded { _ in
                    hold.cancel()
                }
        )
    }

    private var progressLabel: String {
        let elapsed = hold.progress * holdSeconds
        return String(format: "%.1f / %.1f s", elapsed, holdSeconds)
    }
}

private final class HoldModel: ObservableObject {
    @Published var progress: Double = 0

    private var timer: Timer?
    private var didFire = false
    private var sessionActive = false

    func start(holdSeconds: Double, action: @escaping () -> Void) {
        guard !sessionActive else { return }
        sessionActive = true
        didFire = false
        progress = 0
        let started = Date()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self else { return }
            let next = min(1, Date().timeIntervalSince(started) / holdSeconds)
            self.progress = next
            if next >= 1 {
                t.invalidate()
                self.timer = nil
                if !self.didFire {
                    self.didFire = true
                    action()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        progress = 0
        didFire = false
        sessionActive = false
    }

    deinit {
        timer?.invalidate()
    }
}
