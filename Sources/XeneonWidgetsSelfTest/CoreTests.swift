import Foundation
import XeneonWidgetsCore

func runCoreTests() {
    // MARK: - Display matching

    let displays = [
        DisplayCandidate(localizedName: "LG UltraWide", width: 2560, height: 720),
        DisplayCandidate(localizedName: "XENEON EDGE", width: 2560, height: 720),
    ]
    expectEqual(
        DisplayMatching.bestMatch(among: displays, preferredName: nil)?.localizedName,
        "XENEON EDGE",
        "prefers Xeneon Edge over resolution-only ultrawide"
    )

    expectNil(
        DisplayMatching.bestMatch(
            among: [DisplayCandidate(localizedName: "LG UltraWide", width: 2560, height: 720)],
            preferredName: nil
        ),
        "rejects resolution-only match"
    )

    expectEqual(
        DisplayMatching.bestMatch(
            among: [
                DisplayCandidate(localizedName: "XENEON EDGE", width: 2560, height: 720),
                DisplayCandidate(localizedName: "XENEON EDGE 2", width: 2560, height: 720),
            ],
            preferredName: "XENEON EDGE 2"
        )?.localizedName,
        "XENEON EDGE 2",
        "uses preferred display when available"
    )

    let withResolution = DisplayCandidate(localizedName: "Xeneon Edge", width: 2560, height: 720)
    let nameOnly = DisplayCandidate(localizedName: "Xeneon Edge", width: 1920, height: 1080)
    expect(
        DisplayMatching.matchScore(for: withResolution) > DisplayMatching.matchScore(for: nameOnly),
        "scores name and resolution higher than name alone"
    )

    // MARK: - Stats math

    let previousCPU = [
        StatsMath.CPUTicks(user: 100, system: 50, idle: 800, nice: 50),
    ]
    let currentCPU = [
        StatsMath.CPUTicks(user: 120, system: 60, idle: 860, nice: 60),
    ]
    if let usage = StatsMath.cpuUsagePercent(current: currentCPU, previous: previousCPU) {
        expect(abs(usage - 40) < 0.001, "computes CPU usage from tick deltas")
    } else {
        expect(false, "CPU usage should be available with matching baselines")
    }

    expectNil(
        StatsMath.cpuUsagePercent(
            current: [StatsMath.CPUTicks(user: 100, system: 50, idle: 800, nice: 50)],
            previous: []
        ),
        "CPU usage waits for baseline"
    )

    let ramUsage = StatsMath.ramUsagePercent(
        activePages: 100,
        wiredPages: 50,
        compressedPages: 25,
        pageSize: 4096,
        totalBytes: 16_000_000
    )
    expect(abs(ramUsage - 4.48) < 0.001, "RAM usage includes compressed pages")

    expectNil(
        StatsMath.networkRates(
            currentIn: 1_000,
            currentOut: 500,
            previousIn: 0,
            previousOut: 0,
            interval: 2
        ),
        "network rates require warmup sample"
    )

    if let rates = StatsMath.networkRates(
        currentIn: 3_000,
        currentOut: 1_500,
        previousIn: 1_000,
        previousOut: 500,
        interval: 2
    ) {
        expectEqual(rates.download, 1000, "download rate")
        expectEqual(rates.upload, 500, "upload rate")
    } else {
        expect(false, "network rates should be available after warmup")
    }

    if let wrap = StatsMath.networkRates(
        currentIn: 0x1000,
        currentOut: 0x1000,
        previousIn: 0xFFFF0000,
        previousOut: 0xFFFF0000,
        interval: 1
    ) {
        expectEqual(wrap.download, Double(0x11000), "networkRates 32-bit wrap matches NetworkMath")
        expectEqual(wrap.upload, Double(0x11000), "networkRates 32-bit wrap up")
    } else {
        expect(false, "networkRates should handle 32-bit wrap")
    }

    expect(StatsMath.isDataInterface("en0"), "en0 is a data interface")
    expect(!StatsMath.isDataInterface("lo0"), "lo0 is not a data interface")
    expect(!StatsMath.isDataInterface("utun4"), "utun4 is not a data interface")
    expect(!StatsMath.isDataInterface("awdl0"), "awdl0 is not a data interface")
}
