import Foundation
import Observation

enum LegKind: String, Codable, CaseIterable, Identifiable {
    case swim = "Swim", transition = "Transition", bike = "Bike", run = "Run"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .swim: return "figure.open.water.swim"
        case .transition: return "arrow.triangle.swap"
        case .bike: return "figure.outdoor.cycle"
        case .run: return "figure.run"
        }
    }
}

enum ProductKind: String, Codable, CaseIterable, Identifiable {
    case gel = "Gel", chew = "Chews", drink = "Drink", salt = "Salt", food = "Food"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .gel: return "drop.fill"
        case .chew: return "circle.grid.2x2.fill"
        case .drink: return "waterbottle.fill"
        case .salt: return "capsule.fill"
        case .food: return "fork.knife"
        }
    }
}

struct Product: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: ProductKind
    var carb: Double
    var sodium: Double
    var ml: Double
    var caffeine: Double
}

struct Item: Codable, Identifiable, Hashable {
    var id = UUID()
    var productID: UUID
    var count: Double
}

struct Leg: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: LegKind
    var hours: Double
    var items: [Item] = []
}

struct Targets { var carb: Double; var fluid: Double; var sodium: Double }

struct Athlete: Codable {
    var weight: Double = 74
    var gut: Double = 90            // g/h trained
    var sweatSodium: Double = 900    // mg/L
    var caffeinePerKg: Double = 3
    var testBefore: Double = 74.2
    var testAfter: Double = 73.1
    var testDrank: Double = 600
    var testMinutes: Double = 60
    var testFactor: Double = 1.0     // race-day adjustment
    var sweatRate: Double { max(0.2, ((testBefore - testAfter) * 1000 + testDrank) / (testMinutes / 60) / 1000 * testFactor) }
}

struct Race: Codable {
    var name: String = "Half iron"
    var preset: String = "70.3"
    var start: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
    var temp: Double = 24
    var legs: [Leg] = []
}

struct Event: Identifiable {
    var id: String { "\(hours)-\(what)" }
    let hours: Double
    let what: String
    let legName: String
    let isTransition: Bool
}

@Observable
final class Store {
    var athlete = Athlete()
    var race = Race()
    var products: [Product] = []
    var armed: Date? = nil           // race day: notifications scheduled from this start
    private var saveTask: Task<Void, Never>?
    private let url = URL.documentsDirectory.appending(path: "racefuel.json")
    struct Disk: Codable { var athlete: Athlete; var race: Race; var products: [Product]; var armed: Date? }

    static let presets: [(String, String, [(String, LegKind, Double)])] = [
        ("sprint", "Sprint triathlon", [("Swim", .swim, 0.3), ("T1", .transition, 0.05), ("Bike", .bike, 0.75), ("T2", .transition, 0.03), ("Run", .run, 0.45)]),
        ("oly", "Olympic triathlon", [("Swim", .swim, 0.5), ("T1", .transition, 0.07), ("Bike", .bike, 1.25), ("T2", .transition, 0.04), ("Run", .run, 0.9)]),
        ("70.3", "Half iron (70.3)", [("Swim", .swim, 0.6), ("T1", .transition, 0.1), ("Bike", .bike, 2.9), ("T2", .transition, 0.07), ("Run", .run, 1.95)]),
        ("140.6", "Full iron (140.6)", [("Swim", .swim, 1.25), ("T1", .transition, 0.15), ("Bike", .bike, 6.0), ("T2", .transition, 0.1), ("Run", .run, 4.3)]),
        ("marathon", "Marathon", [("Run", .run, 3.9)]),
        ("half", "Half marathon", [("Run", .run, 1.8)]),
        ("century", "Century ride", [("Bike", .bike, 5.5)]),
        ("fondo", "Gran fondo", [("Bike", .bike, 4.5)]),
        ("ultra", "50 km trail", [("Run", .run, 6.0)]),
    ]

    static let starterProducts: [Product] = [
        Product(name: "Gel", kind: .gel, carb: 25, sodium: 40, ml: 0, caffeine: 0),
        Product(name: "Caffeine gel", kind: .gel, carb: 25, sodium: 40, ml: 0, caffeine: 100),
        Product(name: "High-carb gel", kind: .gel, carb: 40, sodium: 60, ml: 0, caffeine: 0),
        Product(name: "Chews, one pack", kind: .chew, carb: 24, sodium: 60, ml: 0, caffeine: 0),
        Product(name: "Bottle, 1 scoop", kind: .drink, carb: 20, sodium: 300, ml: 750, caffeine: 0),
        Product(name: "Bottle, 2 scoops", kind: .drink, carb: 40, sodium: 400, ml: 750, caffeine: 0),
        Product(name: "Bottle, plain water", kind: .drink, carb: 0, sodium: 0, ml: 750, caffeine: 0),
        Product(name: "Salt capsule", kind: .salt, carb: 0, sodium: 200, ml: 0, caffeine: 0),
        Product(name: "Bar", kind: .food, carb: 40, sodium: 100, ml: 0, caffeine: 0),
        Product(name: "Banana", kind: .food, carb: 27, sodium: 1, ml: 0, caffeine: 0),
        Product(name: "Cola, 330 ml", kind: .drink, carb: 35, sodium: 15, ml: 330, caffeine: 32),
        Product(name: "Aid station cup", kind: .drink, carb: 9, sodium: 60, ml: 150, caffeine: 0),
    ]

    init(demo: Bool) {
        if demo { products = Store.starterProducts; applyPreset("70.3"); autoFill(); return }
        if let d = try? Data(contentsOf: url), let disk = try? JSONDecoder().decode(Disk.self, from: d) {
            athlete = disk.athlete; race = disk.race; products = disk.products; armed = disk.armed
        } else {
            products = Store.starterProducts; applyPreset("70.3")
        }
    }

    func save() {
        saveTask?.cancel()
        let disk = Disk(athlete: athlete, race: race, products: products, armed: armed); let u = url
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(250)); if Task.isCancelled { return }
            if let d = try? JSONEncoder().encode(disk) { try? d.write(to: u, options: .atomic) }
        }
    }

    // MARK: targets

    func targets(_ kind: LegKind) -> Targets {
        let heat = 1 + max(0, race.temp - 20) * 0.02
        let carb: Double = kind == .bike ? athlete.gut : kind == .run ? (athlete.gut * 0.8).rounded() : 0
        let fluid: Double = kind == .swim ? 0 : min(1.2, max(0.4, athlete.sweatRate * heat * 0.8))
        let sodium: Double = kind == .swim ? 0 : (fluid * athlete.sweatSodium * 0.9 / 50).rounded() * 50
        return Targets(carb: carb, fluid: fluid, sodium: sodium)
    }

    func product(_ id: UUID) -> Product? { products.first { $0.id == id } }

    func totals(_ leg: Leg) -> (carb: Double, sodium: Double, ml: Double, caffeine: Double) {
        var t = (carb: 0.0, sodium: 0.0, ml: 0.0, caffeine: 0.0)
        for it in leg.items { if let p = product(it.productID) { t.carb += p.carb * it.count; t.sodium += p.sodium * it.count; t.ml += p.ml * it.count; t.caffeine += p.caffeine * it.count } }
        return t
    }

    var totalHours: Double { race.legs.reduce(0) { $0 + $1.hours } }
    var planned: (carb: Double, sodium: Double, ml: Double, caffeine: Double) {
        var t = (carb: 0.0, sodium: 0.0, ml: 0.0, caffeine: 0.0)
        for l in race.legs { let x = totals(l); t.carb += x.carb; t.sodium += x.sodium; t.ml += x.ml; t.caffeine += x.caffeine }
        return t
    }
    var needed: (carb: Double, fluid: Double, sodium: Double) {
        race.legs.reduce((carb: 0.0, fluid: 0.0, sodium: 0.0)) { acc, l in
            let t = targets(l.kind); return (acc.carb + t.carb * l.hours, acc.fluid + t.fluid * l.hours, acc.sodium + t.sodium * l.hours)
        }
    }

    func applyPreset(_ key: String) {
        guard let p = Store.presets.first(where: { $0.0 == key }) else { return }
        race.preset = key; race.name = p.1
        race.legs = p.2.map { Leg(name: $0.0, kind: $0.1, hours: $0.2) }
        save()
    }

    /// Greedy: a drink to the fluid target, gels for the carbs, salt caps for the rest, a caffeine gel late in the run.
    func autoFill() {
        for i in race.legs.indices {
            let l = race.legs[i]; race.legs[i].items = []
            let t = targets(l.kind)
            if l.kind == .swim { continue }
            if l.kind == .transition { if let g = products.first(where: { $0.kind == .gel && $0.caffeine == 0 }) { race.legs[i].items = [Item(productID: g.id, count: 1)] }; continue }
            guard let drink = products.first(where: { $0.kind == .drink && $0.carb >= 20 && $0.carb <= 45 }) ?? products.first(where: { $0.kind == .drink }) else { continue }
            let gel = products.first(where: { $0.kind == .gel && $0.caffeine == 0 }) ?? products.first(where: { $0.kind == .gel })
            let salt = products.first(where: { $0.kind == .salt })
            let caf = products.first(where: { $0.kind == .gel && $0.caffeine > 0 })
            let bottles = (t.fluid * 1000 / max(1, drink.ml) * l.hours * 10).rounded() / 10
            race.legs[i].items.append(Item(productID: drink.id, count: bottles))
            let carbSoFar = drink.carb * bottles
            let needC = t.carb * l.hours
            if let gel { let n = max(0, ((needC - carbSoFar) / gel.carb).rounded()); if n > 0 { race.legs[i].items.append(Item(productID: gel.id, count: n)) }
                if let caf, l.kind == .run, n >= 2 { race.legs[i].items[race.legs[i].items.count - 1].count = n - 1; race.legs[i].items.append(Item(productID: caf.id, count: 1)) } }
            let naSoFar = drink.sodium * bottles; let needNa = t.sodium * l.hours
            if let salt, needNa - naSoFar > 150 { race.legs[i].items.append(Item(productID: salt.id, count: ((needNa - naSoFar) / salt.sodium).rounded())) }
        }
        save()
    }

    /// Every planned intake, spread evenly through its leg.
    var events: [Event] {
        var out: [Event] = []; var t0 = 0.0
        for l in race.legs {
            if l.kind == .transition {
                let what = l.items.compactMap { it in product(it.productID).map { "\(Int(it.count)) × \($0.name)" } }.joined(separator: ", ")
                out.append(Event(hours: t0, what: "\(l.name): " + (what.isEmpty ? "drink up" : what), legName: l.name, isTransition: true))
            } else {
                for it in l.items {
                    guard let p = product(it.productID), it.count > 0 else { continue }
                    let n = max(1, Int(it.count.rounded())); let gap = l.hours / Double(n)
                    for k in 0..<n { out.append(Event(hours: t0 + gap * (Double(k) + 0.5), what: (p.kind == .drink ? "Finish " : "Take ") + p.name, legName: l.name, isTransition: false)) }
                }
            }
            t0 += l.hours
        }
        return out.sorted { $0.hours < $1.hours }
    }

    func clock(_ hours: Double) -> String {
        let d = race.start.addingTimeInterval(hours * 3600)
        return d.formatted(date: .omitted, time: .shortened)
    }
    func legStart(_ index: Int) -> Double { race.legs.prefix(index).reduce(0) { $0 + $1.hours } }
}

func hm(_ h: Double) -> String { let m = Int((h * 60).rounded()); return "\(m / 60):" + String(format: "%02d", m % 60) }
