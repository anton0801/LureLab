import SwiftUI

/// 60 pt navigation/info row: icon 28 at x 11, title 16 demibold at x 51, trailing value 15 demibold.
struct ListRow<Trailing: View>: View {
    var icon: String?
    let title: String
    var titleColor: Color = Palette.ink
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 0) {
            if let icon {
                UIIcon(name: icon, size: 28)
                    .padding(.leading, 11)
                    .padding(.trailing, 12)
                    .offset(y: -1)
            }
            Text(title)
                .font(.avenir(16, .demiBold))
                .foregroundColor(titleColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, icon == nil ? 15 : 0)
            Spacer(minLength: 10)
            trailing()
                .padding(.trailing, 20)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 60)
        .lureCard()
    }
}

extension ListRow where Trailing == RowValue {
    init(icon: String?, title: String, value: String = "", chevron: Bool = false) {
        self.icon = icon
        self.title = title
        self.trailing = { RowValue(text: value, chevron: chevron) }
    }
}

struct RowValue: View {
    let text: String
    var chevron: Bool = false

    var body: some View {
        let shown = chevron ? (text.isEmpty ? "›" : "\(text) ›") : text
        Text(shown)
            .font(.avenir(15, .demiBold))
            .foregroundColor(Palette.secondary)
            .multilineTextAlignment(.trailing)
            .lineLimit(2)
    }
}

/// Tappable 60 pt row.
struct NavRow: View {
    let icon: String?
    let title: String
    var value: String = ""
    var titleColor: Color = Palette.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ListRow(icon: icon, title: title, titleColor: titleColor) {
                RowValue(text: value, chevron: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(value.isEmpty ? title : "\(title), \(value)"))
        .accessibilityAddTraits(.isButton)
    }
}

/// User photo (aspect fill) or the placeholder_photo component. Never shows invented imagery.
struct PhotoThumb: View {
    let path: String?
    let size: CGFloat
    @EnvironmentObject private var photos: PhotoLibrary

    var body: some View {
        Group {
            if let path, let image = photos.image(for: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 118 / 120, height: size * 118 / 120)
                    .clipShape(RoundedRectangle(cornerRadius: size * 18 / 120, style: .continuous))
                    .frame(width: size, height: size)
            } else {
                Image("placeholder_photo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 100 pt lure card used by My Lures, Choose Lure and Archived Lures.
struct LureCardRow<Accessory: View>: View {
    let lure: Lure
    let meta: String
    let status: String
    var highlighted: Bool = false
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            PhotoThumb(path: lure.photoPath, size: 72)
                .padding(.leading, 10)
                .padding(.top, 15)
            VStack(alignment: .leading, spacing: 0) {
                Text(lure.name)
                    .font(.avenir(18, .heavy))
                    .foregroundColor(Palette.ink)
                    .lineLimit(2)
                    .padding(.top, 13)
                Text(meta)
                    .font(.avenir(13, .demiBold))
                    .foregroundColor(Palette.secondary)
                    .padding(.top, 6.4)
                Text(status)
                    .font(.avenir(13, .bold))
                    .foregroundColor(Palette.sea)
                    .padding(.top, 7.2)
                    .padding(.bottom, 13)
            }
            .padding(.leading, 13)
            Spacer(minLength: 8)
            accessory()
                .padding(.trailing, 12)
                .padding(.top, 35)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .lureCard(stroke: highlighted ? Palette.sea : Palette.cardStroke, lineWidth: highlighted ? 2 : 1)
        .accessibilityElement(children: .combine)
    }
}

/// Journal row (94 pt): place 21 heavy, lure · retrieve, duration · counts.
struct TestRow: View {
    let test: TestEntry
    let lureName: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(test.placeName)
                    .font(.avenir(21, .heavy))
                    .foregroundColor(Palette.ink)
                    .lineLimit(2)
                    .padding(.top, 11)
                Text(Format.lureAndRetrieve(lureName: lureName, retrieve: test.retrieve))
                    .font(.avenir(14, .demiBold))
                    .foregroundColor(Palette.secondary)
                    .padding(.top, 3.3)
                Text(Format.durationAndCounts(test))
                    .font(.avenir(14, .demiBold))
                    .foregroundColor(Palette.ink)
                    .padding(.top, 4.9)
                    .padding(.bottom, 8)
            }
            .padding(.leading, 18)
            Spacer(minLength: 8)
            UIIcon(name: "icon_chevron", size: 25)
                .padding(.top, 26)
                .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
        .lureCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(test.placeName), \(Format.mediumDate(test.occurredAt)), \(lureName). \(Format.durationAndCounts(test))"))
        .accessibilityAddTraits(.isButton)
    }
}

/// Bites / Catches stepper row (53 pt). Tapping the value opens numeric input.
struct CountStepperRow: View {
    let metric: CountMetric
    let value: Int?
    var isError: Bool = false
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    let onEditValue: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(metric.title)
                .font(.avenir(17, .demiBold))
                .foregroundColor(Palette.ink)
                .padding(.leading, 16)
            Spacer(minLength: 8)
            circle("−", label: "Decrease \(metric.plural)", action: onDecrement)
            Button(action: onEditValue) {
                Text(value.map(String.init) ?? "—")
                    .font(.avenir(23, .heavy))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 48, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(metric.title): \(value.map(String.init) ?? "not recorded")"))
            .accessibilityHint(Text("Double tap to type a value or mark it not recorded"))
            circle("+", label: "Increase \(metric.plural)", action: onIncrement)
                .padding(.trailing, 19)
        }
        .frame(maxWidth: .infinity, minHeight: 53)
        .lureCard(stroke: isError ? Palette.error : Palette.cardStroke, lineWidth: isError ? 2 : 1)
        .accessibilityElement(children: .contain)
    }

    private func circle(_ glyph: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.avenirFixed(24, .bold))
                .foregroundColor(.white)
                .offset(y: 1)
                .frame(width: 41, height: 41)
                .background(Circle().fill(Palette.ink))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, -1.5)
        .accessibilityLabel(Text(label))
    }
}
