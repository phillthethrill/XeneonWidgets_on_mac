import Foundation
import XeneonWidgetsCore

protocol SampledProvider: AnyObject {
    /// Called on the sampler's background queue every tick.
    func sample(at now: Date, interval: SamplingInterval)
    /// Called (background queue) when the interval changes; providers resize their ring buffers to `interval.historyCapacity`.
    func historyCapacityChanged(to capacity: Int)
}

final class Sampler {
    private static let queueKey = DispatchSpecificKey<Bool>()

    let queue = DispatchQueue(label: "com.local.xeneon.sampler", qos: .utility)
    private var storedInterval: SamplingInterval
    private var providers: [SampledProvider] = []
    private var timer: DispatchSourceTimer?

    var interval: SamplingInterval {
        syncOnQueue { storedInterval }
    }

    init(interval: SamplingInterval) {
        storedInterval = interval
        queue.setSpecific(key: Self.queueKey, value: true)
    }

    deinit {
        stop()
    }

    func add(_ provider: SampledProvider) {
        syncOnQueue { providers.append(provider) }
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
        syncOnQueue {
            storedInterval = interval
            let capacity = interval.historyCapacity
            for provider in providers {
                provider.historyCapacityChanged(to: capacity)
            }
        }
        guard timer != nil else { return }
        timer?.cancel()
        timer = nil
        scheduleTimer()
    }

    private func scheduleTimer() {
        let repeating = syncOnQueue { storedInterval.rawValue }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: repeating, leeway: .milliseconds(50))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let now = Date()
            let current = self.storedInterval
            for provider in self.providers {
                provider.sample(at: now, interval: current)
            }
        }
        source.resume()
        timer = source
    }

    private func syncOnQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: Self.queueKey) != nil {
            return work()
        }
        return queue.sync(execute: work)
    }
}
