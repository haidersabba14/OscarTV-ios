import XCTest
@testable import RemoteInteractionCore

final class InteractionTests: XCTestCase {
    @MainActor
    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Timed out waiting for command processing")
    }

    @MainActor
    func testQuickTapSendsOnceAndReleaseCancelsRepeat() async throws {
        let repeater = CommandRepeater(initialDelay: 50_000_000, repeatInterval: 10_000_000)
        var sent = 0
        repeater.begin { sent += 1; return true }
        try await eventually { sent == 1 }
        repeater.stop()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sent, 1)
    }

    @MainActor
    func testHoldRepeatsSequentiallyAndStopsOnRelease() async throws {
        let repeater = CommandRepeater(initialDelay: 5_000_000, repeatInterval: 5_000_000)
        var sent = 0
        var inFlight = 0
        var maximumInFlight = 0
        repeater.begin {
            inFlight += 1
            maximumInFlight = max(maximumInFlight, inFlight)
            try? await Task.sleep(nanoseconds: 15_000_000)
            sent += 1
            inFlight -= 1
            return true
        }
        // Repeated gesture updates must not start a second worker.
        repeater.begin { XCTFail("Duplicate worker"); return false }
        try await eventually { sent >= 3 }
        repeater.stop()
        try await eventually { inFlight == 0 }
        let releasedCount = sent
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertEqual(sent, releasedCount)
        XCTAssertEqual(maximumInFlight, 1)
    }

    @MainActor
    func testReleaseDoesNotCancelInFlightCommand() async throws {
        let repeater = CommandRepeater(initialDelay: 5_000_000, repeatInterval: 5_000_000)
        var continuation: CheckedContinuation<Void, Never>?
        var completed = false
        var wasCancelled = true
        var sent = 0
        repeater.begin {
            sent += 1
            await withCheckedContinuation { continuation = $0 }
            wasCancelled = Task.isCancelled
            completed = true
            return true
        }
        try await eventually { continuation != nil }
        repeater.stop()
        continuation?.resume()
        try await eventually { completed }
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertFalse(wasCancelled)
        XCTAssertEqual(sent, 1)
    }

    @MainActor
    func testReceiverFailureStopsHold() async throws {
        let repeater = CommandRepeater(initialDelay: 5_000_000, repeatInterval: 5_000_000)
        var sent = 0
        repeater.begin { sent += 1; return false }
        try await eventually { sent == 1 }
        try await Task.sleep(nanoseconds: 60_000_000)
        repeater.stop()
        XCTAssertEqual(sent, 1)
    }

    func testShortcutStorageRejectsUnknownAndDuplicateCommands() {
        let selection = ShortcutSelection(storage: "BOGUS,MUTE,MUTE,BACK,OTHER")
        XCTAssertEqual(selection.actions, [.mute, .back, .home])
        XCTAssertEqual(ShortcutSelection(storage: "").actions, ShortcutSelection.defaults)
        XCTAssertEqual(ShortcutSelection(storage: selection.storage), selection)
    }

    func testChoosingExistingShortcutSwapsSlotsAndPersists() {
        var selection = ShortcutSelection(storage: "HOME,MUTE,WAKE")
        selection.replace(slot: 0, with: .wake)
        XCTAssertEqual(selection.actions, [.wake, .mute, .home])
        selection.replace(slot: 1, with: .back)
        XCTAssertEqual(selection.actions, [.wake, .back, .home])
        XCTAssertEqual(ShortcutSelection(storage: selection.storage), selection)
        selection.replace(slot: 10, with: .powerMenu)
        XCTAssertEqual(selection.actions, [.wake, .back, .home])
    }
}
