import EventKit
import Foundation

struct CalendarEvent: Equatable {
    var title: String
    var start: Date
}

final class ClockProvider: ObservableObject {
    @Published private(set) var now: Date
    @Published private(set) var uptime: TimeInterval
    @Published private(set) var nextEvent: CalendarEvent? = nil

    let hostName: String
    let osVersion: String

    private var store: EKEventStore?
    private let eventsQueue = DispatchQueue(label: "com.local.xeneon.calendar", qos: .utility)
    private var clockTimer: Timer?
    private var eventTimer: Timer?
    private var didRequestAccess = false

    init() {
        now = Date()
        uptime = ProcessInfo.processInfo.systemUptime
        hostName = Host.current().localizedName ?? "Mac"
        osVersion = Self.formattedOSVersion()
    }

    deinit {
        let clock = clockTimer
        let events = eventTimer
        DispatchQueue.main.async {
            clock?.invalidate()
            events?.invalidate()
        }
    }

    func start() {
        if Thread.isMainThread {
            startOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.startOnMain()
            }
        }
    }

    func stop() {
        if Thread.isMainThread {
            stopOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.stopOnMain()
            }
        }
    }

    private func startOnMain() {
        if clockTimer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                self?.publishClock()
            }
            RunLoop.main.add(timer, forMode: .common)
            clockTimer = timer
            publishClock()
        }
        requestCalendarAccessIfNeeded()
    }

    private func stopOnMain() {
        clockTimer?.invalidate()
        clockTimer = nil
        eventTimer?.invalidate()
        eventTimer = nil
    }

    private func publishClock() {
        now = Date()
        uptime = ProcessInfo.processInfo.systemUptime
    }

    private func requestCalendarAccessIfNeeded() {
        if Self.isAuthorized {
            startEventRefresh()
            return
        }
        guard !didRequestAccess else { return }
        didRequestAccess = true
        guard Self.authorizationStatus() == .notDetermined else { return }

        eventsQueue.async { [weak self] in
            self?.requestAccessOnQueue()
        }
    }

    private func requestAccessOnQueue() {
        let store = eventStore()
        let handler: (Bool, Error?) -> Void = { [weak self] granted, _ in
            guard granted else { return }
            self?.eventsQueue.async {
                guard let self else { return }
                self.refreshNextEventOnQueue()
                DispatchQueue.main.async { [weak self] in
                    self?.ensureEventTimer()
                }
            }
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: handler)
        } else {
            store.requestAccess(to: .event, completion: handler)
        }
    }

    private func startEventRefresh() {
        refreshNextEvent()
        ensureEventTimer()
    }

    private func ensureEventTimer() {
        guard eventTimer == nil else { return }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshNextEvent()
        }
        RunLoop.main.add(timer, forMode: .common)
        eventTimer = timer
    }

    /// Lazily creates the store. Call only on `eventsQueue`.
    private func eventStore() -> EKEventStore {
        if let store { return store }
        let created = EKEventStore()
        store = created
        return created
    }

    private func refreshNextEvent() {
        eventsQueue.async { [weak self] in
            self?.refreshNextEventOnQueue()
        }
    }

    private func refreshNextEventOnQueue() {
        guard Self.isAuthorized else {
            DispatchQueue.main.async { [weak self] in
                self?.nextEvent = nil
            }
            return
        }
        let store = eventStore()
        let now = Date()
        let end = now.addingTimeInterval(24 * 60 * 60)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)
        let next = events
            .filter { !$0.isAllDay && $0.startDate > now }
            .min(by: { $0.startDate < $1.startDate })
        let mapped = next.map { CalendarEvent(title: $0.title ?? "", start: $0.startDate) }
        DispatchQueue.main.async { [weak self] in
            self?.nextEvent = mapped
        }
    }

    private static func formattedOSVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        if v.patchVersion == 0 {
            return "macOS \(v.majorVersion).\(v.minorVersion)"
        }
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private static func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    private static var isAuthorized: Bool {
        if #available(macOS 14.0, *) {
            return authorizationStatus() == .fullAccess
        } else {
            return authorizationStatus() == .authorized
        }
    }
}
