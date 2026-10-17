// Test doubles for iOS observations and native functions; no device access is attempted.
import Foundation
protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
enum AppInfo {
    static var versionTuple = (major: 26, minor: 5, patch: 1)
    static var osBuild = "23F81"
    static var osVersion: String { "\(versionTuple.major).\(versionTuple.minor).\(versionTuple.patch)" }
}
private var kernelCalls = 0
func kexploit_opa334() -> Int32 { kernelCalls += 1; return -1 }
func proc_self() -> UInt64 { 0 }
func sandbox_escape(_ process: UInt64) -> Int32 { -1 }
func sandbox_access_is_active() -> Int32 { 0 }
func log(_ message: String) {}
struct AccessTestFailure: Error { let message: String }
func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw AccessTestFailure(message: message) }
}
func reason(supported: Bool = true, required: Bool = false, running: Bool = false,
            succeeded: Bool = false, failed: Bool = false,
            identifier: String? = PanelAccessPolicy.requiredBundleIdentifier) -> String? {
    PanelAccessPolicy.blockReason(systemSupported: supported, kernelRequired: required,
        kernelRunning: running, kernelSucceeded: succeeded, kernelFailed: failed,
        hostBundleIdentifier: identifier, osVersion: "26.5.1")
}

@main struct AccessTests {
    static func main() throws {
        // Actual AppState, KernelExploit and SupportPolicy implementations are compiled into this harness.
        let state = AppState()
        state.detectSupport()
        try expect(state.isSupported && !state.kernelExploitApplicable, "iOS 26.5.1 must use the existing container route")
        try expect(!state.kernelExploitRunning && kernelCalls == 0, "Detection must not invoke the incompatible kernel implementation")
        state.runKernelExploitIfNeeded()
        try expect(!state.kernelExploitRunning && kernelCalls == 0, "Manual kernel entry must also respect applicability")
        print("PASS 1: actual AppState routes iOS 26.5.1 without starting the kernel stage")

        let versions: [(Int, Int, Int, Bool)] = [
            (17, 0, 0, true), (17, 7, 9, true), (17, 8, 0, false),
            (18, 0, 0, true), (18, 7, 1, true), (18, 7, 2, false),
            (18, 8, 0, false), (26, 0, 0, false), (26, 5, 1, false),
            (26, 6, 1, false), (27, 0, 0, false)
        ]
        for (major, minor, patch, expected) in versions {
            try expect(KernelExploit.isApplicable(major: major, minor: minor, patch: patch, build: "test") == expected,
                       "Incorrect kernel applicability for \(major).\(minor).\(patch)")
        }
        try expect(ExploitSupportPolicy.isSupported(major: 26, minor: 5, patch: 1, build: "23F81"),
                   "Routing correction must not falsely mark all iOS 26 app functions unsupported")
        print("PASS 2: eleven kernel applicability boundaries remain distinct from app support")

        try expect(reason(failed: true) == nil, "An irrelevant kernel failure must not block the container route")
        print("PASS 3: the iOS 26 route does not require a kernel success")
        try expect(reason(required: true, failed: true) != nil, "A required failed kernel stage remains blocked")
        try expect(reason(required: true, succeeded: true) == nil, "A completed required kernel stage is accepted")
        print("PASS 4: legacy kernel requirement is preserved")
        try expect(reason(running: true)?.contains("preparado") == true, "Preparation must have a readable explanation")
        print("PASS 5: preparation status explains a blocked tap")
        try expect(reason(identifier: "renamed.app")?.contains("identificador") == true, "Changed bundle identity must be explained")
        try expect(reason(identifier: nil) != nil, "Unknown bundle identity must not pass")
        print("PASS 6: signing identity mismatches are explained")
        try expect(reason(supported: false, succeeded: true) != nil, "Unsupported system must remain blocked")
        print("PASS 7: unsupported system is not enabled by stale success")
        print("7 access-routing scenarios passed with native API stubs; no physical-device access was tested.")
    }
}
