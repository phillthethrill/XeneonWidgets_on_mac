import Foundation
import XeneonWidgetsCore

func runNetworkMathTests() {
    runNetworkSelectionTests()
    runAggregateTests()
    runRatesTests()
    runKindTests()
    runRateScaleLabelTests()
}

private func runNetworkSelectionTests() {
    expectEqual(NetworkSelection(rawValue: "auto"), .auto, "rawValue auto")
    expectEqual(NetworkSelection(rawValue: "en0"), .interface("en0"), "rawValue interface name")
    expectEqual(NetworkSelection.auto.rawValue, "auto", "auto rawValue")
    expectEqual(NetworkSelection.interface("en1").rawValue, "en1", "interface rawValue")
    expectEqual(NetworkSelection.auto.chipLabel, "Auto", "auto chipLabel")
    expectEqual(NetworkSelection.interface("en0").chipLabel, "en0", "interface chipLabel is the name; kind label is supplied by the view")
}

private func runAggregateTests() {
    let counters: [String: InterfaceCounters] = [
        "en0": InterfaceCounters(inBytes: 1_000, outBytes: 100),
        "en1": InterfaceCounters(inBytes: 400, outBytes: 40),
        "lo0": InterfaceCounters(inBytes: 9_000, outBytes: 9_000),
        "awdl0": InterfaceCounters(inBytes: 50, outBytes: 50),
    ]

    let autoActiveEn0 = NetworkMath.aggregate(
        counters,
        selection: .auto,
        activeNames: ["en0", "lo0", "awdl0"]
    )
    expectEqual(autoActiveEn0, InterfaceCounters(inBytes: 1_000, outBytes: 100), "auto sums only active en*")

    let autoBoth = NetworkMath.aggregate(
        counters,
        selection: .auto,
        activeNames: ["en0", "en1"]
    )
    expectEqual(autoBoth, InterfaceCounters(inBytes: 1_400, outBytes: 140), "auto sums every active en*")

    let autoNone = NetworkMath.aggregate(
        counters,
        selection: .auto,
        activeNames: ["lo0"]
    )
    expectEqual(autoNone, InterfaceCounters(inBytes: 0, outBytes: 0), "auto with no active en* is zero")

    let specific = NetworkMath.aggregate(
        counters,
        selection: .interface("en1"),
        activeNames: ["en0"]
    )
    expectEqual(specific, InterfaceCounters(inBytes: 400, outBytes: 40), "selection specific picks one even if inactive")

    let missing = NetworkMath.aggregate(
        counters,
        selection: .interface("en9"),
        activeNames: ["en0"]
    )
    expectEqual(missing, InterfaceCounters(inBytes: 0, outBytes: 0), "unknown interface is zero")
}

private func runRatesTests() {
    let current = InterfaceCounters(inBytes: 2_000, outBytes: 500)
    let previous = InterfaceCounters(inBytes: 1_000, outBytes: 100)
    let zero = InterfaceCounters(inBytes: 0, outBytes: 0)

    expectNil(
        NetworkMath.rates(current: current, previous: zero, interval: 1),
        "rates warm-up nil when previous is zero"
    )
    expectNil(
        NetworkMath.rates(current: current, previous: previous, interval: 0),
        "rates nil when interval is 0"
    )
    expectNil(
        NetworkMath.rates(current: current, previous: previous, interval: -0.5),
        "rates nil when interval is negative"
    )

    let rates = NetworkMath.rates(current: current, previous: previous, interval: 2)
    expectNotNil(rates, "rates after warm-up")
    if let rates {
        expectClose(rates.down, 500, "down bytes/s")
        expectClose(rates.up, 200, "up bytes/s")
    }

    let wrap = NetworkMath.rates(
        current: InterfaceCounters(inBytes: 0x1000, outBytes: 0x1000),
        previous: InterfaceCounters(inBytes: 0xFFFF0000, outBytes: 0xFFFF0000),
        interval: 1
    )
    expectNotNil(wrap, "32-bit wrap still produces a rate")
    if let wrap {
        expectClose(wrap.down, Double(0x11000), "32-bit wrap down delta")
        expectClose(wrap.up, Double(0x11000), "32-bit wrap up delta")
    }

    let reset = NetworkMath.rates(
        current: InterfaceCounters(inBytes: 100, outBytes: 100),
        previous: InterfaceCounters(inBytes: UInt64(UInt32.max) + 50, outBytes: UInt64(UInt32.max) + 50),
        interval: 1
    )
    expectNotNil(reset, "64-bit backwards jump still returns a rate")
    if let reset {
        expectClose(reset.down, 0, "64-bit backwards jump is not a 32-bit wrap")
        expectClose(reset.up, 0, "64-bit backwards jump up is 0")
    }
}

private func runKindTests() {
    expectEqual(
        NetworkMath.kind(forSCInterfaceType: "IEEE80211", bsdName: "en0"),
        .wifi,
        "IEEE80211 → wifi"
    )
    expectEqual(
        NetworkMath.kind(forSCInterfaceType: "Ethernet", bsdName: "en1"),
        .ethernet,
        "Ethernet → ethernet"
    )
    expectEqual(
        NetworkMath.kind(forSCInterfaceType: "Ethernet", bsdName: "en2", localizedName: "USB 10/100/1000 LAN"),
        .usb,
        "Ethernet + USB in localized name → usb"
    )
    expectEqual(
        NetworkMath.kind(forSCInterfaceType: "Ethernet", bsdName: "usb0"),
        .usb,
        "Ethernet + USB in bsdName → usb"
    )
    expectEqual(
        NetworkMath.kind(forSCInterfaceType: nil, bsdName: "en0"),
        .other,
        "nil type → other"
    )
    expectEqual(
        NetworkMath.kind(forSCInterfaceType: "PPP", bsdName: "ppp0"),
        .other,
        "unknown SC type → other"
    )
    expectEqual(InterfaceKind.wifi.rawValue, "Wi-Fi", "wifi label")
    expectEqual(InterfaceKind.ethernet.rawValue, "Ethernet", "ethernet label")
    expectEqual(InterfaceKind.usb.rawValue, "USB", "usb label")
    expectEqual(InterfaceKind.other.rawValue, "Other", "other label")
}

private func runRateScaleLabelTests() {
    expectEqual(
        NetworkMath.rateScaleLabel(bytesPerSecond: 48_200_000, arrow: "↓"),
        "↓ 50 MB/s",
        "niceScale of 48.2 MB → 50"
    )
    expectEqual(
        NetworkMath.rateScaleLabel(bytesPerSecond: 12_000_000, arrow: "↑"),
        "↑ 20 MB/s",
        "niceScale of 12 MB → 20"
    )
}
