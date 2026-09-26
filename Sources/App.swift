import SwiftUI
import UserNotifications

@main
struct RaceFuelApp: App {
    @State private var store: Store
    @State private var router = Router()
    @State private var pro: Pro
    init() {
        let a = ProcessInfo.processInfo.arguments
        let demo = a.contains("-shot") || a.contains("-demoAutoplay")
        _store = State(initialValue: Store(demo: demo))
        // Screenshots and the review recording never touch StoreKit. The paywall shot shows the free app.
        let paywallShot = a.firstIndex(of: "-shot").map { $0 + 1 < a.count && a[$0 + 1] == "paywall" } ?? false
        let p = demo ? Pro(forced: !paywallShot) : Pro()
        if paywallShot { p.paywall = .raceDay }
        _pro = State(initialValue: p)
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(router).environment(pro).preferredColorScheme(.dark).tint(Bib.orange)
                .onAppear { router.applyShotArgs(store); Autopilot.shared.run(store, router) }
        }
    }
}

enum Tab: String, CaseIterable {
    case plan = "Plan", athlete = "Athlete", race = "Race", products = "Products", timeline = "Timeline"
    var icon: String {
        switch self {
        case .plan: return "bolt.fill"
        case .athlete: return "figure.run"
        case .race: return "flag.checkered"
        case .products: return "drop.fill"
        case .timeline: return "clock.fill"
        }
    }
}

@Observable
final class Router {
    var tab: Tab = .plan
    var raceDay = false
    func applyShotArgs(_ s: Store) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return }
        switch a[i + 1] {
        case "athlete": tab = .athlete
        case "race": tab = .race
        case "products": tab = .products
        case "timeline": tab = .timeline
        case "paywall": tab = .timeline
        case "raceday": tab = .timeline; s.armed = Date.now.addingTimeInterval(-47 * 60); raceDay = true
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    var body: some View {
        @Bindable var router = router
        @Bindable var pro = pro
        ZStack(alignment: .bottom) {
            NavyBackground()
            Group {
                switch router.tab {
                case .plan: PlanView()
                case .athlete: AthleteView()
                case .race: RaceView()
                case .products: ProductsView()
                case .timeline: TimelineView()
                }
            }
            BibTabBar(selection: $router.tab).padding(.bottom, 2)
        }
        .sheet(item: $pro.paywall) { r in PaywallView(reason: r).presentationBackground(Bib.navy) }
    }
}

struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) { content }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 110)
        }
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(eyebrow, color: Bib.orange)
            Text(title).font(.head(34)).foregroundStyle(Bib.onNavy)
        }.padding(.top, 10)
    }
}

enum Notify {
    static func schedule(_ store: Store) async -> Int {
        let c = UNUserNotificationCenter.current()
        let ok = (try? await c.requestAuthorization(options: [.alert, .sound])) ?? false
        guard ok else { return 0 }
        c.removeAllPendingNotificationRequests()
        let start = store.armed ?? .now
        var n = 0
        for e in store.events {
            let fire = start.addingTimeInterval(e.hours * 3600)
            guard fire > .now else { continue }
            let content = UNMutableNotificationContent()
            content.title = e.isTransition ? e.legName : e.what
            content.body = e.isTransition ? e.what : "\(e.legName) · " + hm(e.hours) + " in"
            content.sound = .default
            let trig = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSinceNow), repeats: false)
            try? await c.add(UNNotificationRequest(identifier: "rf-\(n)", content: content, trigger: trig))
            n += 1
        }
        return n
    }
    static func cancel() { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }
}
