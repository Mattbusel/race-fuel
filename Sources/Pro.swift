import SwiftUI
import StoreKit

/// Race Fuel Pro: one non-consumable. Planning is free: the sweat test, the targets, every race
/// preset, auto-fill, the timeline and the shopping list. Pro is race day and the long tail:
/// the race clock with a reminder for every intake, more than a few products of your own,
/// and sharing the plan.
///
/// Anyone whose first download was a build before firstFreemiumBuild paid for the app and keeps
/// everything. AppTransaction's originalAppVersion is that build number. Only trusted in
/// production: sandbox and Xcode report made-up values, and App Review must see the paywall.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.racefuel.pro"
    /// The first build with Pro in it. Anything earlier was the paid app.
    static let firstFreemiumBuild = 2
    /// Products you can add on top of the starter list before Pro.
    static let freeOwnProducts = 3

    enum Reason: String, Identifiable { case raceDay, products, share, general; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var grandfathered = false
    private(set) var product: StoreKit.Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

    private var updates: Task<Void, Never>?
    private let key = "racefuel.pro.unlocked"
    private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$4.99" }

    /// True when the feature may run; otherwise opens the paywall.
    @discardableResult
    func allow(_ why: Reason) -> Bool {
        if unlocked { return true }
        paywall = why
        return false
    }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await StoreKit.Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
        if case .verified(let app)? = try? await AppTransaction.shared,
           app.environment == .production, (Int(app.originalAppVersion) ?? Int.max) < Pro.firstFreemiumBuild {
            grandfathered = true
            grant()
        }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await StoreKit.Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else if !grandfathered { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

// MARK: - Paywall: a race bib with PRO as the number

struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var shown = false

    var body: some View {
        ZStack {
            NavyBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Eyebrow("Race Fuel Pro", color: Bib.orange)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Bib.onNavy2)
                                .frame(width: 38, height: 38).overlay(Circle().strokeBorder(Color.white.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                    Text(headline).font(.head(34)).foregroundStyle(Bib.onNavy).fixedSize(horizontal: false, vertical: true)
                    Text("Planning stays free. Pro is for the day you pin the number on.")
                        .font(.body(15)).foregroundStyle(Bib.onNavy2)

                    BibCard(band: "Race day") {
                        VStack(spacing: 4) {
                            Text("PRO").font(.number(92)).foregroundStyle(Bib.ink).tracking(4)
                                .scaleEffect(shown ? 1 : 0.7).opacity(shown ? 1 : 0)
                            Text("ONE PAYMENT · YOURS FOR GOOD").font(.label(11, .black)).tracking(2).foregroundStyle(Bib.ink3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .rotationEffect(.degrees(shown ? -1.5 : 0))

                    VStack(alignment: .leading, spacing: 14) {
                        feature("flag.checkered", "Race clock and reminders", "Start the race on the line and your phone buzzes for every gel, bottle and salt cap, on time.")
                        feature("drop.fill", "All your own products", "The free plan takes \(Pro.freeOwnProducts) of your own on top of the starter list. Pro takes every gel you own.")
                        feature("square.and.arrow.up", "Share the plan", "Send the timeline and shopping list to your coach, your crew or your notes.")
                    }
                    .panel()

                    if let m = pro.message {
                        Text(m).font(.label(13, .semibold)).foregroundStyle(Bib.salt).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                    GoButton(title: pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill", fill: Bib.lime) {
                        Task { await pro.buy() }
                    }
                    .disabled(pro.busy)
                    HStack(spacing: 10) {
                        QuietButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        Spacer()
                        QuietButton(title: "Not now") { dismiss() }
                    }
                    Text("No subscription. Family Sharing works. Your plan, products and numbers stay yours, Pro or not.")
                        .font(.label(11.5, .medium)).foregroundStyle(Bib.onNavy3).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15)) { shown = true } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .raceDay: return "Let the phone call your gels."
        case .products: return "Race with what you actually carry."
        case .share: return "Hand the plan to your crew."
        case .general: return "Fuel the whole race."
        }
    }

    func feature(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .black)).foregroundStyle(Bib.orange)
                .frame(width: 34, height: 34).background(Circle().fill(Bib.card))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.head(15)).foregroundStyle(Bib.onNavy)
                Text(body).font(.body(13)).foregroundStyle(Bib.onNavy2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The Pro card at the foot of the Athlete tab: unlock, or proof of it, and Restore either way.
struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow("Race Fuel Pro", color: pro.unlocked ? Bib.lime : Bib.orange)
                Spacer()
                if pro.unlocked { Image(systemName: "checkmark.seal.fill").foregroundStyle(Bib.lime) }
            }
            Text(pro.unlocked ? "Unlocked. Race clock, reminders, every product, sharing." : "Race clock with intake reminders, all your own products, and sharing the plan. One payment of \(pro.price).")
                .font(.body(13)).foregroundStyle(Bib.onNavy2).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if !pro.unlocked { GoButton(title: "See Pro", icon: "flag.checkered") { pro.paywall = .general } }
                QuietButton(title: "Restore", icon: "arrow.clockwise") { Task { await pro.restore() } }
            }
            if let m = pro.message, pro.paywall == nil {
                Text(m).font(.label(12, .semibold)).foregroundStyle(Bib.salt)
            }
        }
        .panel()
    }
}

extension Store {
    /// The plan as plain text, for the share sheet.
    var planText: String {
        var s = "\(race.name), Race Fuel plan\n\n"
        for e in events { s += "\(clock(e.hours))  +\(hm(e.hours))  \(e.what)  (\(e.legName))\n" }
        let shop = Dictionary(grouping: race.legs.flatMap { $0.items }, by: { $0.productID })
            .compactMap { k, v -> (String, Double)? in product(k).map { ($0.name, v.reduce(0) { $0 + $1.count }) } }
            .sorted { $0.1 > $1.1 }
        if !shop.isEmpty {
            s += "\nShopping list\n"
            for x in shop { s += "\(Int(x.1.rounded(.up))) x \(x.0)\n" }
        }
        return s
    }
}
