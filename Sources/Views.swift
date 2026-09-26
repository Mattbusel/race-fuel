import SwiftUI

// MARK: Plan

struct PlanView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    var body: some View {
        let p = store.planned, need = store.needed
        Page {
            PageHeader(eyebrow: store.race.name, title: "Your fuel plan.")
            BibCard(band: "Per hour on the bike") {
                let t = store.targets(.bike)
                HStack(alignment: .top, spacing: 0) {
                    bigStat(String(Int(t.carb)), "g carbs", Bib.ink)
                    Divider().frame(height: 60)
                    bigStat(String(format: "%.1f", t.fluid), "L fluid", Bib.ink)
                    Divider().frame(height: 60)
                    bigStat(String(Int(t.sodium)), "mg sodium", Bib.ink)
                }
                Text("Run gets \(Int(store.targets(.run).carb)) g/h. From your sweat test, gut training and \(Int(store.race.temp))° on the day.").font(.body(12.5)).foregroundStyle(Bib.ink2).padding(.top, 8)
                SourcesLink(light: true).padding(.top, 4)
            }
            HStack(spacing: 10) {
                miniStat(String(Int(p.carb)), "g carbs", "of \(Int(need.carb))", Bib.lime)
                miniStat(String(format: "%.1f", p.ml / 1000), "L fluid", "of " + String(format: "%.1f", need.fluid), Bib.sky)
                miniStat(String(Int(p.sodium)), "mg Na", "of \(Int(need.sodium))", Bib.salt)
            }
            HStack(spacing: 8) {
                GoButton(title: "Auto-fill", icon: "wand.and.stars") { withAnimation { store.autoFill() } }
                QuietButton(title: "Clear") { for i in store.race.legs.indices { store.race.legs[i].items = [] }; store.save() }
            }
            ForEach(Array(store.race.legs.enumerated()), id: \.element.id) { i, leg in
                LegCard(index: i, leg: leg)
            }
            Text("Caffeine planned: \(Int(p.caffeine)) mg of \(Int(store.athlete.caffeinePerKg * store.athlete.weight)) mg allowed. Test every product in training first. A planning tool, not medical advice.").font(.body(12.5)).foregroundStyle(Bib.onNavy3)
            SourcesLink()
        }
    }
    func bigStat(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) { Text(v).font(.number(38)).foregroundStyle(c); Text(l.uppercased()).font(.label(10, .black)).tracking(1.2).foregroundStyle(Bib.ink3) }.frame(maxWidth: .infinity)
    }
    func miniStat(_ v: String, _ l: String, _ sub: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.number(22)).foregroundStyle(c)
            Text(l.uppercased()).font(.label(9.5, .black)).tracking(1).foregroundStyle(Bib.onNavy2)
            Text(sub).font(.label(10, .semibold)).foregroundStyle(Bib.onNavy3)
        }.frame(maxWidth: .infinity, alignment: .leading).panel(padding: 12)
    }
}

struct LegCard: View {
    @Environment(Store.self) private var store
    let index: Int
    let leg: Leg
    @State private var adding = false
    var body: some View {
        let t = store.targets(leg.kind), tot = store.totals(leg)
        let per: (Double) -> Double = { leg.hours > 0 ? $0 / leg.hours : 0 }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: leg.kind.icon).font(.system(size: 16, weight: .black)).foregroundStyle(Bib.orange)
                Text(leg.name).font(.head(18)).foregroundStyle(Bib.onNavy)
                Text(hm(leg.hours)).font(.number(13)).foregroundStyle(Bib.onNavy3)
                Spacer()
                Text(store.clock(store.legStart(index))).font(.number(12)).foregroundStyle(Bib.onNavy3)
                Button { adding = true } label: { Image(systemName: "plus").font(.system(size: 13, weight: .black)).foregroundStyle(Bib.onNavy).frame(width: 30, height: 30).background(Circle().fill(Color.white.opacity(0.1))) }.buttonStyle(.plain)
            }
            if leg.kind == .swim {
                Text("Nothing during the swim. A gel and 300 ml in the 15 minutes before the start.").font(.body(13)).foregroundStyle(Bib.onNavy2)
            } else if leg.kind == .transition {
                Text("A gel and a long drink. No hourly targets.").font(.body(13)).foregroundStyle(Bib.onNavy2)
            } else {
                VStack(spacing: 8) {
                    Gauge3(label: "Carbs / h", value: per(tot.carb), target: t.carb, unit: " g", color: Bib.lime)
                    Gauge3(label: "Fluid / h", value: per(tot.ml) / 1000, target: t.fluid, unit: " L", color: Bib.sky, decimals: 2)
                    Gauge3(label: "Sodium / h", value: per(tot.sodium), target: t.sodium, unit: " mg", color: Bib.salt)
                }
                .padding(12).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Bib.card))
            }
            ForEach(leg.items) { it in
                if let p = store.product(it.productID) {
                    HStack(spacing: 10) {
                        Image(systemName: p.kind.icon).font(.system(size: 12, weight: .bold)).foregroundStyle(Bib.orange).frame(width: 18)
                        Text(p.name).font(.body(14)).foregroundStyle(Bib.onNavy)
                        Spacer()
                        Stepper("", value: Binding(get: { it.count }, set: { v in set(it.id, max(0, v)) }), in: 0...30, step: 0.5).labelsHidden().scaleEffect(0.85)
                        Text(fmt(it.count)).font(.number(15)).foregroundStyle(Bib.lime).frame(width: 34, alignment: .trailing)
                        Button { store.race.legs[index].items.removeAll { $0.id == it.id }; store.save() } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Bib.onNavy3) }.buttonStyle(.plain)
                    }
                }
            }
        }
        .panel()
        .confirmationDialog("Add to \(leg.name)", isPresented: $adding, titleVisibility: .visible) {
            ForEach(store.products) { p in Button(p.name) { store.race.legs[index].items.append(Item(productID: p.id, count: 1)); store.save() } }
        }
    }
    func set(_ id: UUID, _ v: Double) { if let j = store.race.legs[index].items.firstIndex(where: { $0.id == id }) { store.race.legs[index].items[j].count = v; store.save() } }
    func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
}

// MARK: Athlete

struct AthleteView: View {
    @Environment(Store.self) private var store
    var body: some View {
        @Bindable var store = store
        Page {
            PageHeader(eyebrow: "Athlete", title: "Your numbers.")
            BibCard(band: "Sweat rate") {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(format: "%.2f", store.athlete.sweatRate)).font(.number(44)).foregroundStyle(Bib.ink)
                    Text("L / hour").font(.label(13, .black)).foregroundStyle(Bib.ink3)
                }
                Text("Losing about \(Int(store.athlete.sweatRate * store.athlete.sweatSodium)) mg of sodium an hour. The plan replaces 80% of the fluid, capped at what a gut absorbs, and most of the sodium.").font(.body(12.5)).foregroundStyle(Bib.ink2).padding(.top, 6)
                SourcesLink(light: true).padding(.top, 4)
            }
            VStack(spacing: 0) {
                Eyebrow("Sweat test").frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 6)
                NumField(label: "Weight before", hint: "kg, nude, after peeing", value: $store.athlete.testBefore)
                NumField(label: "Weight after", hint: "kg, towelled off", value: $store.athlete.testAfter)
                NumField(label: "Drank during", hint: "ml", value: $store.athlete.testDrank)
                NumField(label: "Duration", hint: "minutes", value: $store.athlete.testMinutes)
                Picker("Conditions", selection: $store.athlete.testFactor) {
                    Text("Like race day").tag(1.0); Text("Cooler than race day").tag(1.25); Text("Hotter than race day").tag(0.8)
                }.pickerStyle(.segmented).padding(.top, 6)
            }.panel()
            VStack(spacing: 0) {
                Eyebrow("Gut and salt").frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 6)
                NumField(label: "Body weight", hint: "kg", value: $store.athlete.weight)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Carbs your gut can take").font(.body(14)).foregroundStyle(Bib.onNavy)
                    Picker("Gut", selection: $store.athlete.gut) {
                        Text("60").tag(60.0); Text("75").tag(75.0); Text("90").tag(90.0); Text("105").tag(105.0); Text("120").tag(120.0)
                    }.pickerStyle(.segmented)
                    Text("g per hour, what you have practised in training. The gut adapts in about four weeks.").font(.label(11, .medium)).foregroundStyle(Bib.onNavy3)
                }.padding(.vertical, 6)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sweat saltiness").font(.body(14)).foregroundStyle(Bib.onNavy)
                    Picker("Salt", selection: $store.athlete.sweatSodium) {
                        Text("Low").tag(500.0); Text("Average").tag(900.0); Text("Salty").tag(1300.0); Text("Very").tag(1800.0)
                    }.pickerStyle(.segmented)
                    Text("White streaks on your kit means salty. A sweat patch test gives the real mg/L; type it below.").font(.label(11, .medium)).foregroundStyle(Bib.onNavy3)
                }.padding(.vertical, 6)
                NumField(label: "Measured sodium", hint: "mg/L, optional", value: $store.athlete.sweatSodium)
                NumField(label: "Caffeine", hint: "mg per kg, 0 to 6", value: $store.athlete.caffeinePerKg, step: 0.5)
                SourcesLink().frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            }.panel()
            ProCard()
        }
        .onChange(of: store.athlete.weight) { store.save() }.onChange(of: store.athlete.gut) { store.save() }.onChange(of: store.athlete.sweatSodium) { store.save() }
        .onChange(of: store.athlete.testBefore) { store.save() }.onChange(of: store.athlete.testAfter) { store.save() }.onChange(of: store.athlete.testDrank) { store.save() }
        .onChange(of: store.athlete.testMinutes) { store.save() }.onChange(of: store.athlete.testFactor) { store.save() }.onChange(of: store.athlete.caffeinePerKg) { store.save() }
    }
}

// MARK: Race

struct RaceView: View {
    @Environment(Store.self) private var store
    var body: some View {
        @Bindable var store = store
        Page {
            PageHeader(eyebrow: "Race", title: store.race.name + ".")
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Preset")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Store.presets, id: \.0) { p in
                            Button { store.applyPreset(p.0); store.autoFill() } label: {
                                Text(p.1).font(.label(12, .black)).foregroundStyle(store.race.preset == p.0 ? Bib.navy : Bib.onNavy2).padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(Capsule().fill(store.race.preset == p.0 ? Bib.card : Color.white.opacity(0.08)))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                HStack {
                    Text("Start").font(.body(14)).foregroundStyle(Bib.onNavy); Spacer()
                    DatePicker("", selection: $store.race.start, displayedComponents: [.date, .hourAndMinute]).labelsHidden().colorScheme(.dark)
                }.padding(.vertical, 4)
                NumField(label: "Expected temperature", hint: "°C, raises the fluid target", value: $store.race.temp)
            }.panel()
            VStack(alignment: .leading, spacing: 10) {
                HStack { Eyebrow("Legs"); Spacer(); QuietButton(title: "Add leg", icon: "plus") { store.race.legs.append(Leg(name: "Leg", kind: .bike, hours: 1)); store.save() } }
                ForEach($store.race.legs) { $leg in
                    HStack(spacing: 8) {
                        Picker("", selection: $leg.kind) { ForEach(LegKind.allCases) { k in Image(systemName: k.icon).tag(k) } }.labelsHidden().tint(Bib.orange).frame(width: 60)
                        TextField("Name", text: $leg.name).font(.body(14)).foregroundStyle(Bib.onNavy)
                        TextField("h", value: $leg.hours, format: .number.precision(.fractionLength(0...2))).keyboardType(.decimalPad).multilineTextAlignment(.trailing).font(.number(15)).foregroundStyle(Bib.lime).frame(width: 60)
                        Text("h").font(.label(11, .bold)).foregroundStyle(Bib.onNavy3)
                        Button { store.race.legs.removeAll { $0.id == leg.id }; store.save() } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Bib.onNavy3) }.buttonStyle(.plain)
                    }
                    .padding(.vertical, 8).overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
                }
                HStack(spacing: 14) {
                    stat(hm(store.totalHours), "total time")
                    stat(store.clock(store.totalHours), "expected finish")
                    stat("\(Int(store.needed.carb)) g", "carbs needed")
                }.padding(.top, 6)
            }.panel()
            .onChange(of: store.race.temp) { store.save() }.onChange(of: store.race.start) { store.save() }.onChange(of: store.race.legs) { store.save() }
        }
    }
    func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(v).font(.number(16)).foregroundStyle(Bib.onNavy); Text(l.uppercased()).font(.label(9.5, .black)).tracking(1).foregroundStyle(Bib.onNavy3) }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Products

struct ProductsView: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @State private var editing: Product? = nil
    var body: some View {
        Page {
            PageHeader(eyebrow: "Products", title: "What you carry.")
            HStack(spacing: 8) {
                GoButton(title: "Add product", icon: "plus") {
                    guard store.products.count < Store.starterProducts.count + Pro.freeOwnProducts || pro.allow(.products) else { return }
                    let p = Product(name: "New product", kind: .gel, carb: 25, sodium: 50, ml: 0, caffeine: 0); store.products.append(p); store.save(); editing = p }
                QuietButton(title: "Defaults") { store.products = Store.starterProducts; store.autoFill() }
            }
            ForEach(store.products) { p in
                Button { editing = p } label: {
                    HStack(spacing: 12) {
                        Image(systemName: p.kind.icon).font(.system(size: 16, weight: .black)).foregroundStyle(Bib.orange).frame(width: 34, height: 34).background(Circle().fill(Bib.card))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.head(15)).foregroundStyle(Bib.onNavy)
                            Text("\(Int(p.carb)) g · \(Int(p.sodium)) mg Na" + (p.ml > 0 ? " · \(Int(p.ml)) ml" : "") + (p.caffeine > 0 ? " · \(Int(p.caffeine)) mg caf" : "")).font(.label(11.5, .semibold)).foregroundStyle(Bib.onNavy3)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .black)).foregroundStyle(Bib.onNavy3)
                    }.panel(padding: 12)
                }.buttonStyle(.plain)
            }
            Text("Read the label of what you actually race with and fix the numbers. A bottle is what you mix, so two scoops is a different product from one.").font(.body(12.5)).foregroundStyle(Bib.onNavy3)
        }
        .sheet(item: $editing) { p in ProductEditor(product: p).presentationBackground(Bib.navy).presentationDetents([.medium, .large]) }
    }
}

struct ProductEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var product: Product
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $product.name).font(.head(24)).foregroundStyle(Bib.onNavy).padding(.top, 20)
            Picker("Kind", selection: $product.kind) { ForEach(ProductKind.allCases) { k in Text(k.rawValue).tag(k) } }.pickerStyle(.segmented)
            NumField(label: "Carbs", hint: "grams", value: $product.carb)
            NumField(label: "Sodium", hint: "mg", value: $product.sodium)
            NumField(label: "Fluid", hint: "ml, drinks only", value: $product.ml)
            NumField(label: "Caffeine", hint: "mg", value: $product.caffeine)
            Spacer()
            HStack(spacing: 8) {
                QuietButton(title: "Delete", icon: "trash") { store.products.removeAll { $0.id == product.id }; for i in store.race.legs.indices { store.race.legs[i].items.removeAll { $0.productID == product.id } }; store.save(); dismiss() }
                GoButton(title: "Save") { if let i = store.products.firstIndex(where: { $0.id == product.id }) { store.products[i] = product }; store.save(); dismiss() }
            }
        }.padding(20)
    }
}

// MARK: Timeline / race day

struct TimelineView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @State private var now = Date.now
    @State private var scheduled: Int? = nil
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        let ev = store.events
        Page {
            PageHeader(eyebrow: "Timeline", title: store.armed == nil ? "Every intake." : "Race day.")
            if let armed = store.armed {
                let elapsed = now.timeIntervalSince(armed) / 3600
                let next = ev.first { $0.hours > elapsed }
                BibCard(band: "Race clock") {
                    HStack(alignment: .lastTextBaseline) {
                        Text(hm(max(0, elapsed))).font(.number(46)).foregroundStyle(Bib.ink)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("NEXT").font(.label(10, .black)).tracking(1.5).foregroundStyle(Bib.ink3)
                            if let next { Text(next.what).font(.head(15)).foregroundStyle(Bib.orange).multilineTextAlignment(.trailing); Text("in " + hm(next.hours - elapsed)).font(.number(14)).foregroundStyle(Bib.ink2) } else { Text("Finish line").font(.head(15)).foregroundStyle(Bib.ink2) }
                        }
                    }
                }
                HStack(spacing: 8) {
                    QuietButton(title: "Stop race", icon: "stop.fill") { store.armed = nil; store.save(); Notify.cancel(); scheduled = nil }
                    if let scheduled { Text("\(scheduled) reminders set").font(.label(12, .bold)).foregroundStyle(Bib.lime) }
                }
            } else {
                GoButton(title: "Start the race", icon: "flag.checkered", fill: Bib.lime) {
                    guard pro.allow(.raceDay) else { return }
                    store.armed = .now; store.save()
                    Task { scheduled = await Notify.schedule(store) }
                }
                Text("Starts the race clock now and sets a notification for every intake below. Do it on the start line." + (pro.unlocked ? "" : " Race Fuel Pro.")).font(.body(12.5)).foregroundStyle(Bib.onNavy3)
            }
            if pro.unlocked {
                ShareLink(item: store.planText, subject: Text("Race Fuel plan")) {
                    HStack(spacing: 6) { Image(systemName: "square.and.arrow.up").font(.system(size: 13, weight: .bold)); Text("SHARE THE PLAN").font(.label(12, .black)).tracking(1.2) }
                        .foregroundStyle(Bib.onNavy2).padding(.horizontal, 14).padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1.2))
                }
            } else {
                QuietButton(title: "Share the plan", icon: "square.and.arrow.up") { pro.allow(.share) }
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ev) { e in
                    let passed = store.armed.map { now.timeIntervalSince($0) / 3600 > e.hours } ?? false
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle().fill(e.isTransition ? Bib.orange : passed ? Bib.onNavy3 : Bib.lime).frame(width: 10, height: 10)
                            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 2).frame(maxHeight: .infinity)
                        }.frame(width: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text(store.clock(e.hours)).font(.number(13)).foregroundStyle(passed ? Bib.onNavy3 : Bib.onNavy); Text("+" + hm(e.hours)).font(.label(11, .semibold)).foregroundStyle(Bib.onNavy3) }
                            Text(e.what).font(.body(14)).foregroundStyle(passed ? Bib.onNavy3 : Bib.onNavy).strikethrough(passed)
                            Text(e.legName).font(.label(10.5, .bold)).foregroundStyle(Bib.onNavy3)
                        }.padding(.bottom, 14)
                        Spacer(minLength: 0)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).panel()
            let shop = Dictionary(grouping: store.race.legs.flatMap { $0.items }, by: { $0.productID }).compactMap { k, v -> (String, Double)? in store.product(k).map { ($0.name, v.reduce(0) { $0 + $1.count }) } }.sorted { $0.1 > $1.1 }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Shopping list")
                ForEach(shop, id: \.0) { s in HStack { Text(s.0).font(.body(14)).foregroundStyle(Bib.onNavy); Spacer(); Text("\(Int(s.1.rounded(.up)))").font(.number(15)).foregroundStyle(Bib.lime) } }
            }.panel()
        }
        .onReceive(clock) { now = $0 }
        .onAppear { if router.raceDay { scheduled = ev.count } }
    }
}
