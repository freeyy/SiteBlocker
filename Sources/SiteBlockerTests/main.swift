import Foundation

// Test runner entry point. Each run* function registers and executes its tests against the
// shared `report`; `finishTests()` prints the summary and yields the exit code.

print("Running SiteBlocker test suite…")

runModelTests()
runDomainTests()
runScheduleEvaluatorTests()
runHostsFileTests()
runConfigStoreTests()
runScheduleSummaryTests()
runBlockPlanTests()
runSiteBlockStateTests()

exit(finishTests())
