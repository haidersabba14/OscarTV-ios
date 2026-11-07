import Foundation

/// Repeats only after the preceding command has completed. Releasing a press
/// stops future sends without cancelling a command already on the wire.
@MainActor
public final class CommandRepeater {
    private final class Press {
        var active = true
        var sleeping = false
        var worker: Task<Void, Never>?
    }

    private var press: Press?
    private let initialDelay: UInt64
    private let repeatInterval: UInt64

    public init(initialDelay: UInt64 = 400_000_000, repeatInterval: UInt64 = 220_000_000) {
        self.initialDelay = max(initialDelay, 1_000_000)
        self.repeatInterval = max(repeatInterval, 1_000_000)
    }

    public func begin(action: @escaping @MainActor () async -> Bool) {
        guard press?.active != true else { return }
        let current = Press()
        press = current
        let delay = initialDelay
        let interval = repeatInterval
        current.worker = Task {
            defer {
                current.active = false
                current.worker = nil
            }
            guard await action(), current.active else { return }
            var wait = delay
            while current.active {
                current.sleeping = true
                do { try await Task.sleep(nanoseconds: wait) }
                catch { return }
                current.sleeping = false
                guard current.active, !Task.isCancelled else { return }
                guard await action() else { return }
                wait = interval
            }
        }
    }

    public func stop() {
        guard let current = press else { return }
        current.active = false
        // Avoid turning a normal touch release into a cancelled HTTP request.
        if current.sleeping { current.worker?.cancel() }
        press = nil
    }
}
