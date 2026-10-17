// Linux harness for the actual PanelExecutorStore orchestration.
// Combine observation and iOS device APIs are replaced by test doubles.
// This does not test SwiftUI, iOS signing or the real DevicePatchService.
import Foundation

protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
struct PatchRule { let bundleID: String; let relativePath: String }
struct PatchProject { let id: UUID; let rules: [PatchRule] }
struct PatchTransactionReceipt { let projectID: UUID }
struct PatchPackageSummary { let packageID: UUID; let isPasswordProtected: Bool }
struct DecodedPatchPackage { let project: PatchProject }
enum PatchPackageError: Error {
    case invalidPasswordOrCorruptedPackage, targetAppUnavailable(String), restoreFailed, applyFailed
}
struct Fixture: Codable { let id: UUID; let target: String }
enum PatchProjectLibrary {
    static func readPackage(at url: URL) throws -> Data { try Data(contentsOf: url) }
}
enum PatchPackageCodec {
    static func inspect(_ data: Data) throws -> PatchPackageSummary {
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        return PatchPackageSummary(packageID: fixture.id, isPasswordProtected: false)
    }
    static func decode(_ data: Data, password: String?) throws -> DecodedPatchPackage {
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        return DecodedPatchPackage(project: PatchProject(id: fixture.id, rules: [
            PatchRule(bundleID: "test.app", relativePath: fixture.target)
        ]))
    }
}

enum DevicePatchService {
    private static let lock = NSLock()
    private static var receipts: [UUID: PatchTransactionReceipt] = [:]
    private static var originals: [UUID: (URL, Data)] = [:]
    private static var failApply = false
    private static var failRestore = false
    private static var applyCalls = 0
    static let root = FileManager.default.temporaryDirectory.appendingPathComponent("rnzw-device-\(UUID().uuidString)")

    static func configureFailure(apply: Bool = false, restore: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        failApply = apply; failRestore = restore
    }
    static var applyCount: Int {
        lock.lock(); defer { lock.unlock() }; return applyCalls
    }
    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        lock.lock(); defer { lock.unlock() }; return receipts[projectID]
    }
    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        Thread.sleep(forTimeInterval: 0.03)
        lock.lock(); defer { lock.unlock() }
        applyCalls += 1
        if failApply { failApply = false; throw PatchPackageError.applyFailed }
        let target = root.appendingPathComponent(project.rules[0].relativePath)
        originals[project.id] = (target, try Data(contentsOf: target))
        try Data("patched:\(project.id)".utf8).write(to: target)
        let receipt = PatchTransactionReceipt(projectID: project.id)
        receipts[project.id] = receipt
        return receipt
    }
    static func restore(receipt: PatchTransactionReceipt) throws {
        lock.lock(); defer { lock.unlock() }
        if failRestore { failRestore = false; throw PatchPackageError.restoreFailed }
        guard let (target, data) = originals[receipt.projectID] else { throw PatchPackageError.restoreFailed }
        try data.write(to: target)
        originals[receipt.projectID] = nil
        receipts[receipt.projectID] = nil
    }
}

struct HarnessFailure: Error { let message: String }
@MainActor func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw HarnessFailure(message: message) }
}

@main struct ToggleTests {
    @MainActor static func wait(_ store: PanelExecutorStore) async throws {
        let deadline = Date().addingTimeInterval(5)
        while store.isBusy {
            if Date() > deadline { throw HarnessFailure(message: "Operation did not finish") }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }
    static var resources: URL {
        URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("PanelPackages")
    }
    static func fixture(_ feature: PanelFeature, target: String? = nil) throws {
        let data = try JSONEncoder().encode(Fixture(id: feature.packageID, target: target ?? feature.rawValue))
        try data.write(to: resources.appendingPathComponent(feature.rawValue + ".3105"))
    }
    @MainActor static func main() async throws {
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: DevicePatchService.root, withIntermediateDirectories: true)
        for feature in PanelFeature.allCases {
            try fixture(feature)
            try Data("original:\(feature.rawValue)".utf8)
                .write(to: DevicePatchService.root.appendingPathComponent(feature.rawValue))
        }
        let store = PanelExecutorStore()
        let original = try Data(contentsOf: DevicePatchService.root.appendingPathComponent("144-fps"))
        store.toggle(.fps)
        store.toggle(.fps) // rapid second tap must not write twice or lose the backup
        try expect(!store.active.contains(.fps), "Must not claim active before completion")
        try await wait(store)
        try expect(store.active.contains(.fps), "First tap must apply")
        try expect(DevicePatchService.applyCount == 1, "Repeated tap must be ignored while busy")
        try expect(try Data(contentsOf: DevicePatchService.root.appendingPathComponent("144-fps")) != original,
                   "Application must change the test file")
        print("PASS 1: first tap applies; double tap is serialized; no optimistic active state")

        store.toggle(.fps); try await wait(store)
        try expect(!store.active.contains(.fps), "Second completed tap must switch off")
        try expect(try Data(contentsOf: DevicePatchService.root.appendingPathComponent("144-fps")) == original,
                   "Second tap must restore original bytes")
        print("PASS 2: second tap restores original bytes")

        DevicePatchService.configureFailure(apply: true)
        store.toggle(.fps); try await wait(store)
        try expect(!store.active.contains(.fps) && store.notice != nil, "Failed apply must remain off and report error")
        print("PASS 3: apply failure does not claim success")

        store.notice = nil; store.toggle(.fps); try await wait(store)
        DevicePatchService.configureFailure(restore: true)
        store.toggle(.fps); try await wait(store)
        try expect(store.active.contains(.fps) && store.notice != nil, "Failed restore must remain on")
        store.notice = nil; store.toggle(.fps); try await wait(store)
        try expect(!store.active.contains(.fps), "Restore can be retried")
        print("PASS 4: restore failure preserves active state and allows retry")

        for feature in PanelFeature.allCases { store.toggle(feature); try await wait(store) }
        try expect(store.active.count == 3, "Three independent features may be active")
        let reopened = PanelExecutorStore(); reopened.refreshReceipts()
        try expect(reopened.active.count == 3, "State must recover from receipts on reopening")
        for feature in PanelFeature.allCases.reversed() { reopened.toggle(feature); try await wait(reopened) }
        for feature in PanelFeature.allCases {
            let data = try Data(contentsOf: DevicePatchService.root.appendingPathComponent(feature.rawValue))
            try expect(data == Data("original:\(feature.rawValue)".utf8), "Each original file must be restored")
        }
        print("PASS 5: independent features, reopened state, all original files restored")

        reopened.toggle(.fps); try await wait(reopened)
        try fixture(.aimhead, target: "144-fps")
        let before = DevicePatchService.applyCount
        reopened.toggle(.aimhead); try await wait(reopened)
        try expect(!reopened.active.contains(.aimhead) && reopened.active.contains(.fps), "Conflict must preserve the first feature")
        try expect(DevicePatchService.applyCount == before, "Conflicting feature must not write")
        try fixture(.aimhead)
        reopened.toggle(.fps); try await wait(reopened)
        print("PASS 6: a conflicting package is rejected before writing")

        try FileManager.default.removeItem(at: resources.appendingPathComponent("144-fps.3105"))
        reopened.notice = nil; reopened.toggle(.fps); try await wait(reopened)
        try expect(!reopened.active.contains(.fps) && reopened.notice != nil, "Missing package must remain off and report error")
        print("PASS 7: missing resource fails without a false active state")
        try fixture(.fps)
        reopened.notice = nil
        let callsBeforeBlockedTap = DevicePatchService.applyCount
        reopened.toggle(.fps, unavailableReason: "O acesso ainda está sendo preparado.")
        try expect(reopened.notice?.message == "O acesso ainda está sendo preparado.", "Blocked tap must explain the reason")
        try expect(!reopened.isBusy && !reopened.active.contains(.fps), "Blocked tap must not start a write")
        try expect(DevicePatchService.applyCount == callsBeforeBlockedTap, "Blocked tap must not call apply")
        print("PASS 8: unavailable access produces feedback instead of a silent button")
        print("8 controller scenarios passed. Device service is a test double; iOS integration is not tested here.")
    }
}
