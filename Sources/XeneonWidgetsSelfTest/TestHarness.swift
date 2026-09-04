import Foundation

var failures = 0

func expect(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition {
        let name = (file as NSString).lastPathComponent
        fputs("FAIL [\(name):\(line)] \(message)\n", stderr)
        failures += 1
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    expect(actual == expected, "\(message) (expected \(expected), got \(actual))")
}

func expectNil<T>(_ value: T?, _ message: String) {
    expect(value == nil, message)
}

func expectNotNil<T>(_ value: T?, _ message: String) {
    expect(value != nil, message)
}

func expectClose(_ a: Double, _ b: Double, tol: Double = 0.001, _ message: String) {
    expect(abs(a - b) <= tol, "\(message) (expected \(b) ± \(tol), got \(a))")
}
