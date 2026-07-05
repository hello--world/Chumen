import Foundation

// Centralizes periodic UI data refreshes.
//
// Intent: Chumen shows several status surfaces at once: header pills, dashboard cards, status bar
// menu data, and settings rows. Keeping timers beside individual features made refresh behavior
// uneven, for example controller telemetry refreshed periodically while system proxy status only
// refreshed after explicit events. This coordinator keeps the refresh cadence explicit and grouped
// by data ownership: app-level state can run while the core is stopped, while core-level snapshots
// are started and stopped with the controller streams.
@MainActor
final class AppUpdateCoordinator {
    struct Item: Sendable {
        let id: String
        let interval: Duration
        let runImmediately: Bool
        let update: @MainActor @Sendable () async -> Void
    }

    private var tasks: [String: Task<Void, Never>] = [:]

    func start(_ item: Item) {
        stop(item.id)
        tasks[item.id] = Task { @MainActor [weak self] in
            if item.runImmediately {
                await item.update()
            }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: item.interval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await item.update()
            }
            self?.tasks[item.id] = nil
        }
    }

    func stop(_ id: String) {
        tasks.removeValue(forKey: id)?.cancel()
    }

    func stopAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
    }

    deinit {
        for task in tasks.values {
            task.cancel()
        }
    }
}
