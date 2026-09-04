import Foundation
import XeneonWidgetsCore

func runDiskMathTests() {
    expectEqual(
        DiskMath.kindLabel(format: "APFS", isInternal: true, isRemovable: false, isLocal: true),
        "APFS · internal",
        "kindLabel internal APFS"
    )
    expectEqual(
        DiskMath.kindLabel(format: "APFS", isInternal: false, isRemovable: true, isLocal: true),
        "APFS · external",
        "kindLabel external APFS"
    )
    expectEqual(
        DiskMath.kindLabel(format: "SMB", isInternal: false, isRemovable: false, isLocal: false),
        "SMB · network",
        "kindLabel network SMB"
    )
    expectEqual(
        DiskMath.kindLabel(format: "ExFAT", isInternal: false, isRemovable: false, isLocal: true),
        "ExFAT · external",
        "kindLabel local non-internal is external"
    )
    expectEqual(
        DiskMath.kindLabel(format: nil, isInternal: true, isRemovable: false, isLocal: true),
        "unknown · internal",
        "kindLabel nil format"
    )

    expectEqual(DiskMath.wholeDisk(fromBSDName: "disk3s1"), "disk3", "wholeDisk strips slice")
    expectEqual(DiskMath.wholeDisk(fromBSDName: "disk0"), "disk0", "wholeDisk keeps whole disk")
    expectEqual(DiskMath.wholeDisk(fromBSDName: "disk11s2"), "disk11", "wholeDisk keeps multi-digit index")
    expectEqual(DiskMath.wholeDisk(fromBSDName: "disk3s1s1"), "disk3", "wholeDisk strips APFS nested slices")

    let previous = DiskIOSample(readBytes: 1_000_000, writeBytes: 500_000)
    let current = DiskIOSample(readBytes: 3_000_000, writeBytes: 1_500_000)
    if let rates = DiskMath.rates(current: current, previous: previous, interval: 2) {
        expectClose(rates.read, 1_000_000, "read bytes/s")
        expectClose(rates.write, 500_000, "write bytes/s")
    } else {
        expect(false, "rates should exist when interval is positive")
    }
    expectNil(
        DiskMath.rates(current: current, previous: previous, interval: 0),
        "rates nil when interval is 0"
    )
    expectNil(
        DiskMath.rates(current: current, previous: previous, interval: -1),
        "rates nil when interval is negative"
    )

    let gb = UInt64(1_073_741_824)
    expectEqual(
        DiskMath.capacityLabel(used: 612 * gb, total: 926 * gb),
        "612 GB / 926 GB",
        "capacityLabel under 1 TB"
    )
    let usedTB = UInt64((1.86 * 1024 * 1024 * 1024 * 1024).rounded())
    let totalTB = UInt64((2.00 * 1024 * 1024 * 1024 * 1024).rounded())
    expectEqual(
        DiskMath.capacityLabel(used: usedTB, total: totalTB),
        "1.86 TB / 2.00 TB",
        "capacityLabel in TB"
    )
}
