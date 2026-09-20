import SwiftUI

/// Race bib on navy. White cards with black race-number type, orange for the go signal, sky for fluid, lime for carbs.
enum Bib {
    static let navy = Color(red: 0.043, green: 0.071, blue: 0.125)      // #0B1220
    static let navy2 = Color(red: 0.08, green: 0.12, blue: 0.20)
    static let card = Color(red: 0.99, green: 0.99, blue: 0.98)
    static let ink = Color(red: 0.05, green: 0.07, blue: 0.12)
    static let ink2 = Color(red: 0.05, green: 0.07, blue: 0.12).opacity(0.6)
    static let ink3 = Color(red: 0.05, green: 0.07, blue: 0.12).opacity(0.35)
    static let onNavy = Color.white
    static let onNavy2 = Color.white.opacity(0.62)
    static let onNavy3 = Color.white.opacity(0.32)
    static let orange = Color(red: 1.0, green: 0.42, blue: 0.10)
    static let lime = Color(red: 0.64, green: 0.90, blue: 0.21)
    static let sky = Color(red: 0.13, green: 0.83, blue: 0.93)
    static let salt = Color(red: 0.98, green: 0.75, blue: 0.14)
    static let red = Color(red: 0.96, green: 0.25, blue: 0.37)
}

extension Font {
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded).monospacedDigit() }
    static func head(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func label(_ size: CGFloat, _ w: Font.Weight = .bold) -> Font { .system(size: size, weight: w, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .default) }
}

struct NavyBackground: View {
    var body: some View {
        ZStack {
            Bib.navy
            LinearGradient(colors: [Bib.navy2, .clear], startPoint: .top, endPoint: .center)
            // Course tape: diagonal stripes in the top right, very faint.
            Canvas { ctx, size in
                for i in 0..<14 {
                    var p = Path()
                    let x = size.width - 40 - CGFloat(i) * 22
                    p.move(to: CGPoint(x: x, y: -10))
                    p.addLine(to: CGPoint(x: x + 90, y: 150))
                    ctx.stroke(p, with: .color(Bib.orange.opacity(i % 2 == 0 ? 0.10 : 0.04)), lineWidth: 10)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// A race bib: white card, orange band, safety pins in the corners.
struct BibCard<Content: View>: View {
    var band: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let band {
                Text(band.uppercased()).font(.label(12, .black)).tracking(3).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 8).background(Bib.orange)
            }
            content.padding(16)
        }
        .background(Bib.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) { Pin().offset(x: 10, y: 6) }
        .overlay(alignment: .topTrailing) { Pin().offset(x: -10, y: 6) }
        .shadow(color: .black.opacity(0.45), radius: 20, y: 12)
    }
}

struct Pin: View {
    var body: some View {
        Capsule().fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.55)], startPoint: .top, endPoint: .bottom))
            .frame(width: 22, height: 8)
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.25), lineWidth: 0.5))
    }
}

/// A dark panel on the navy for secondary content.
extension View {
    func panel(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.10)))
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Bib.onNavy3
    init(_ t: String, color: Color = Bib.onNavy3) { text = t; self.color = color }
    var body: some View { Text(text.uppercased()).font(.label(11, .black)).tracking(2).foregroundStyle(color) }
}

/// Horizontal gauge: value against target, coloured by how close.
struct Gauge3: View {
    let label: String
    let value: Double
    let target: Double
    let unit: String
    let color: Color
    var decimals: Int = 0
    var body: some View {
        let r = target > 0 ? value / target : 0
        let state: Color = target == 0 ? Bib.ink3 : r < 0.85 ? Bib.salt : r > 1.2 ? Bib.red : color
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label.uppercased()).font(.label(10, .black)).tracking(1.2).foregroundStyle(Bib.ink3)
                Spacer()
                Text(String(format: "%.\(decimals)f", value) + unit).font(.number(13)).foregroundStyle(Bib.ink)
                Text("/ " + String(format: "%.\(decimals)f", target) + unit).font(.label(11, .semibold)).foregroundStyle(Bib.ink3)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Bib.ink.opacity(0.08))
                    Capsule().fill(state).frame(width: g.size.width * min(1, r / 1.4))
                    Rectangle().fill(Bib.ink.opacity(0.35)).frame(width: 2).offset(x: g.size.width / 1.4)
                }
            }
            .frame(height: 8)
        }
    }
}

struct GoButton: View {
    let title: String
    var icon: String? = nil
    var fill: Color = Bib.orange
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .black)) }
                Text(title.uppercased()).font(.label(14, .black)).tracking(1.5)
            }
            .foregroundStyle(fill == Bib.lime ? Bib.navy : .white)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill).shadow(color: fill.opacity(0.4), radius: 14, y: 6))
        }.buttonStyle(.plain)
    }
}

struct QuietButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title.uppercased()).font(.label(12, .black)).tracking(1.2)
            }
            .foregroundStyle(Bib.onNavy2).padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1.2))
        }.buttonStyle(.plain)
    }
}

struct BibTabBar: View {
    @Binding var selection: Tab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { withAnimation(.snappy(duration: 0.25)) { selection = t } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: t.icon).font(.system(size: 17, weight: selection == t ? .black : .medium))
                        Text(t.rawValue.uppercased()).font(.label(9, .black)).tracking(0.8)
                    }
                    .foregroundStyle(selection == t ? Bib.navy : Bib.onNavy3)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Group { if selection == t { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Bib.card) } })
                }.buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Bib.navy2).shadow(color: .black.opacity(0.6), radius: 20, y: 10))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
        .padding(.horizontal, 16)
    }
}

/// Dark-on-navy numeric field.
struct NumField: View {
    let label: String
    var hint: String = ""
    @Binding var value: Double
    var step: Double = 1
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.body(14)).foregroundStyle(Bib.onNavy)
                if !hint.isEmpty { Text(hint).font(.label(11, .medium)).foregroundStyle(Bib.onNavy3) }
            }
            Spacer()
            TextField("", value: $value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .font(.number(17)).foregroundStyle(Bib.lime).frame(width: 96, height: 36)
                .padding(.horizontal, 8).background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.3)))
        }
        .padding(.vertical, 6)
    }
}
