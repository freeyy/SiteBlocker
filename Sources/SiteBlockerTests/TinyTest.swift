import Foundation

// A minimal, zero-dependency test harness. We can't use XCTest here (no Xcode / no XCTest
// framework in the Command Line Tools), so this provides just enough: grouped tests, the common
// assertions, colored pass/fail output, and a non-zero exit code on failure for CI/TDD loops.

final class TestReport {
    var totalChecks = 0
    var failedChecks = 0
    var testCount = 0
    var failedTests = 0
    var currentTest = ""
    var currentTestFailed = false
    var failureLines: [String] = []
}

let report = TestReport()

private func recordFailure(_ message: String, file: StaticString, line: UInt) {
    report.failedChecks += 1
    if !report.currentTestFailed {
        report.currentTestFailed = true
    }
    let location = "\(file):\(line)"
    let text = "    ✗ \(message)  (\(location))"
    report.failureLines.append("[\(report.currentTest)] \(message) (\(location))")
    print(text)
}

private func recordPass() {
    report.totalChecks += 1
}

/// Run a named test. Any thrown error is reported as a failure.
func test(_ name: String, _ body: () throws -> Void) {
    report.testCount += 1
    report.currentTest = name
    report.currentTestFailed = false
    do {
        try body()
    } catch {
        recordFailure("unexpected error thrown: \(error)", file: #file, line: #line)
    }
    if report.currentTestFailed {
        report.failedTests += 1
        print("  ✗ \(name)")
    } else {
        print("  ✓ \(name)")
    }
}

func section(_ name: String) {
    print("\n\(name)")
}

// MARK: - Assertions

func expectTrue(_ value: Bool, _ message: String = "expected true", file: StaticString = #file, line: UInt = #line) {
    recordPass()
    if !value { recordFailure(message, file: file, line: line) }
}

func expectFalse(_ value: Bool, _ message: String = "expected false", file: StaticString = #file, line: UInt = #line) {
    recordPass()
    if value { recordFailure(message, file: file, line: line) }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    recordPass()
    if actual != expected {
        let detail = message.isEmpty ? "" : "\(message): "
        recordFailure("\(detail)expected \(expected), got \(actual)", file: file, line: line)
    }
}

func expectNil<T>(_ value: T?, _ message: String = "expected nil", file: StaticString = #file, line: UInt = #line) {
    recordPass()
    if let value { recordFailure("\(message), got \(value)", file: file, line: line) }
}

func expectNotNil<T>(_ value: T?, _ message: String = "expected non-nil", file: StaticString = #file, line: UInt = #line) {
    recordPass()
    if value == nil { recordFailure(message, file: file, line: line) }
}

func fail(_ message: String, file: StaticString = #file, line: UInt = #line) {
    recordPass()
    recordFailure(message, file: file, line: line)
}

/// Print the summary and return the process exit code (0 == success).
func finishTests() -> Int32 {
    print("\n" + String(repeating: "─", count: 48))
    let passedTests = report.testCount - report.failedTests
    if report.failedTests == 0 {
        print("✓ All \(report.testCount) tests passed (\(report.totalChecks) checks).")
        return 0
    } else {
        print("✗ \(report.failedTests) of \(report.testCount) tests failed (\(passedTests) passed).")
        print("\nFailures:")
        for line in report.failureLines { print("  • \(line)") }
        return 1
    }
}
