import Foundation

runCoreTests()
runRingBufferTests()
runGraphMathTests()
runFormattersTests()
runDashboardModelTests()
runLayoutSpecTests()
runAlertEngineTests()
runActivitySpikeTests()
runCPUMathTests()
runMemoryMathTests()
runDiskMathTests()
runNetworkMathTests()
runProcessMathTests()
runPowerMathTests()

if failures == 0 {
    print("All core logic tests passed.")
} else {
    fputs("\(failures) test(s) failed.\n", stderr)
    exit(1)
}
