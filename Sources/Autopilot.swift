import SwiftUI

/// Drives the real screens for the App Review recording (-demoAutoplay).
@Observable
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    private var running = false
    @MainActor private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    @MainActor
    func run(_ store: Store, _ router: Router) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(3)
            router.tab = .athlete; await wait(3)
            store.athlete.gut = 105; await wait(1.5)
            router.tab = .race; await wait(2.5)
            store.applyPreset("140.6"); store.autoFill(); await wait(2.5)
            router.tab = .products; await wait(2.5)
            router.tab = .plan; await wait(1.5)
            store.autoFill(); await wait(3)
            router.tab = .timeline; await wait(3)
            store.armed = .now; store.save(); await wait(3)
            store.armed = nil; store.save(); await wait(1)
            try? Data("ok".utf8).write(to: URL.documentsDirectory.appending(path: "demo_done"))
        }
    }
}
