import SwiftUI

/// Where every number in the plan comes from. App Review (guideline 1.4.1) asks for these to be
/// easy to find, so each block of figures carries a "Sources" link that opens this list.
struct Citation: Identifiable {
    let id: String
    let backs: String
    let authors: String
    let title: String
    let journal: String
    let doi: String
    var url: URL { URL(string: "https://doi.org/\(doi)")! }

    static let all: [Citation] = [
        Citation(id: "acsm-nutrition",
                 backs: "Carbohydrate, fluid and sodium during endurance exercise, in general.",
                 authors: "Thomas DT, Erdman KA, Burke LM",
                 title: "American College of Sports Medicine Joint Position Statement: Nutrition and Athletic Performance",
                 journal: "Medicine & Science in Sports & Exercise, 2016; 48(3): 543-568",
                 doi: "10.1249/MSS.0000000000000852"),
        Citation(id: "acsm-fluid",
                 backs: "The sweat test (weight before and after, plus what you drank) and replacing part of the fluid rather than all of it.",
                 authors: "Sawka MN, Burke LM, Eichner ER, et al.",
                 title: "American College of Sports Medicine Position Stand: Exercise and Fluid Replacement",
                 journal: "Medicine & Science in Sports & Exercise, 2007; 39(2): 377-390",
                 doi: "10.1249/mss.0b013e31802ca597"),
        Citation(id: "jeukendrup-carbs",
                 backs: "Carbohydrate per hour, from 60 up to 90 g and more with mixed sugars, set by race length.",
                 authors: "Jeukendrup A",
                 title: "A Step Towards Personalized Sports Nutrition: Carbohydrate Intake During Exercise",
                 journal: "Sports Medicine, 2014; 44(Suppl 1): S25-S33",
                 doi: "10.1007/s40279-014-0148-z"),
        Citation(id: "jeukendrup-gut",
                 backs: "Carbs your gut can take, and training the gut to take more.",
                 authors: "Jeukendrup AE",
                 title: "Training the Gut for Athletes",
                 journal: "Sports Medicine, 2017; 47(Suppl 1): 101-110",
                 doi: "10.1007/s40279-017-0690-6"),
        Citation(id: "baker-sweat",
                 backs: "Sweat rate and how salty sweat is, and how much both vary from person to person.",
                 authors: "Baker LB",
                 title: "Sweating Rate and Sweat Sodium Concentration in Athletes: A Review of Methodology and Intra/Interindividual Variability",
                 journal: "Sports Medicine, 2017; 47(Suppl 1): 111-128",
                 doi: "10.1007/s40279-017-0691-5"),
        Citation(id: "mccubbin-heat",
                 backs: "Drinking and sodium on hot race days.",
                 authors: "McCubbin AJ, Allanson BA, Caldwell Odgers JN, et al.",
                 title: "Sports Dietitians Australia Position Statement: Nutrition for Exercise in Hot Environments",
                 journal: "International Journal of Sport Nutrition and Exercise Metabolism, 2020; 30(1): 83-98",
                 doi: "10.1123/ijsnem.2019-0300"),
        Citation(id: "issn-caffeine",
                 backs: "The caffeine limit, 3 to 6 mg per kg of body weight.",
                 authors: "Guest NS, VanDusseldorp TA, Nelson MT, et al.",
                 title: "International Society of Sports Nutrition Position Stand: Caffeine and Exercise Performance",
                 journal: "Journal of the International Society of Sports Nutrition, 2021; 18(1): 1",
                 doi: "10.1186/s12970-020-00383-4"),
    ]
}

/// The small "Sources" link under a block of figures.
struct SourcesLink: View {
    var light = false
    @State private var open = false
    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "book.closed.fill").font(.system(size: 11, weight: .bold))
                Text("SOURCES").font(.label(11, .black)).tracking(1.2)
            }
            .foregroundStyle(light ? Bib.ink2 : Bib.onNavy2)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sources for these numbers")
        .sheet(isPresented: $open) { SourcesView().presentationBackground(Bib.navy) }
    }
}

struct SourcesView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Eyebrow("Sources")
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .black)).foregroundStyle(Bib.onNavy)
                            .frame(width: 32, height: 32).background(Circle().fill(Color.white.opacity(0.1)))
                    }.accessibilityLabel("Close")
                }
                Text("Where the numbers come from.").font(.number(30)).foregroundStyle(Bib.onNavy)
                Text("Race Fuel does arithmetic on your own figures using the published sports nutrition guidance below. Tap any source to read it.").font(.body(14)).foregroundStyle(Bib.onNavy2)
                ForEach(Citation.all) { c in
                    Link(destination: c.url) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(c.backs).font(.label(12, .black)).foregroundStyle(Bib.orange)
                            Text(c.title).font(.body(15)).foregroundStyle(Bib.onNavy).multilineTextAlignment(.leading)
                            Text("\(c.authors). \(c.journal).").font(.body(12.5)).foregroundStyle(Bib.onNavy3).multilineTextAlignment(.leading)
                            HStack(spacing: 4) {
                                Text("doi.org/\(c.doi)").font(.label(11, .semibold))
                                Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold))
                            }.foregroundStyle(Bib.sky)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .panel()
                    }
                }
                Text("Race Fuel is a planning tool, not medical advice. Everyone's needs differ: try your plan in training before you race, and talk to a doctor or sports dietitian if you have a medical condition, or before using caffeine or salt capsules.")
                    .font(.body(12.5)).foregroundStyle(Bib.onNavy3).padding(.top, 4)
            }
            .padding(20)
        }
        .background(Bib.navy.ignoresSafeArea())
    }
}
