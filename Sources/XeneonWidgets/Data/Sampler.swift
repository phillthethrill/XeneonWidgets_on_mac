import Foundation
import XeneonWidgetsCore

protocol SampledProvider: AnyObject {
    /// Called on the sampler's background queue every tick.
    func sample(at now: Date, interval: SamplingInterval)
    /// Called (background queue) when the interval changes; providers resize their ring buffers to `interval.historyCapacity`.
    func historyCapacityChanged(to capacity: Int)
}

final class Sampler {
    let queue = DispatchQueue(label: "com.local.xeneon.sampler", qos: .utility)
    private(set) var interval: SamplingInterval

    private var providers: [SampledProvider] = []
    private var timer: DispatchSourceTimer?

    init(interval: SamplingInterval) {
        self.interval = interval
    }

    deinit {
        stop()
    }

    func add(_ provider: SampledProvider) {
        providers.append(provider)
    }

    func start() {
        guard timer == nil else { return }
        scheduleTimer()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func setInterval(_ interval: SamplingInterval) {
        self.interval = interval
        let capacity = interval.historyCapacity
        let snapshot = providers
        queue.async {
            for provider in snapshot {
                provider.historyCapacityChanged(to: capacity)
            }
        }
        guard timer != nil else { return }
        timer?.cancel()
        timer = nil
        scheduleTimer()
    }

    private func scheduleTimer() {
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: interval.rawValue, leeway: .milliseconds(50))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let now = Date()
            let current = self.interval
            for provider in self.providers {
                provider.sample(at: now, interval: current)
            }
        }
        source.resume()
        timer = source
    }
}
