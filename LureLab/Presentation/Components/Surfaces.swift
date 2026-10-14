import SwiftUI

/// surface_card: white card, 1 pt #E0EEF1 stroke, solid #D9ECF0 shadow 2 pt below, radius 20.
struct CardBackground: ViewModifier {
    var radius: CGFloat = Metrics.cardRadius
    var stroke: Color = Palette.cardStroke
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.cardShadow)
                    .offset(y: 2)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.panel)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(stroke, lineWidth: lineWidth)
            }
        )
    }
}

extension View {
    func lureCard(radius: CGFloat = Metrics.cardRadius, stroke: Color = Palette.cardStroke, lineWidth: CGFloat = 1) -> some View {
        modifier(CardBackground(radius: radius, stroke: stroke, lineWidth: lineWidth))
    }
}

/// field_normal / field_error container: 350 × 66, label 12 pt bold, value 17 pt demibold.
struct FieldBox<Content: View>: View {
    let label: String
    var isError: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 3.6) {
            Text(label)
                .font(.avenir(12, .bold))
                .foregroundColor(Palette.secondary)
                .accessibilityHidden(true)
            content()
                .font(.avenir(17, .demiBold))
                .foregroundColor(Palette.ink)
        }
        .padding(.top, 12)
        .padding(.bottom, 10.8)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous)
                .fill(isError ? Palette.fieldErrorFill : Palette.panel)
                .overlay(RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous)
                    .stroke(isError ? Palette.error : Palette.fieldStroke, lineWidth: isError ? 2 : 1))
                .padding(1)
        )
    }
}

/// Text field inside a FieldBox with a muted placeholder.
struct FieldTextInput: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isError: Bool = false
    var characterLimit: Int? = nil
    var submitLabel: SubmitLabel = .next

    var body: some View {
        FieldBox(label: label, isError: isError) {
            TextField("", text: $text)
                .keyboardType(keyboard)
                .submitLabel(submitLabel)
                .disableAutocorrection(keyboard != .default)
                .placeholder(placeholder, when: text.isEmpty)
                // UITextField reports ~1.5 pt more than a Text line; keep the 66 pt field of the mockup.
                .padding(.vertical, -0.8)
                .accessibilityLabel(Text(label.capitalized))
                .onChange(of: text) { newValue in
                    if let characterLimit, newValue.count > characterLimit {
                        text = String(newValue.prefix(characterLimit))
                    }
                }
        }
    }
}

extension View {
    func placeholder(_ text: String, when shown: Bool) -> some View {
        ZStack(alignment: .leading) {
            if shown {
                Text(text)
                    .foregroundColor(Palette.secondary.opacity(0.85))
                    .lineLimit(1)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            self
        }
    }
}

/// Inline validation message (color always paired with text).
struct ErrorText: View {
    let message: String
    var weight: AvenirWeight = .bold

    var body: some View {
        Text(message)
            .font(.avenir(13, weight))
            .foregroundColor(Palette.error)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text("Error: \(message)"))
    }
}

/// Filter / meta chip: 34 pt capsule, 13 pt bold.
struct ChipLabel: View {
    let title: String
    var selected: Bool = false
    var fillWidth: Bool = false
    var minWidth: CGFloat? = nil

    var body: some View {
        Text(title)
            .font(.avenir(13, .bold))
            .foregroundColor(selected ? .white : Palette.ink)
            .lineLimit(1)
            .offset(y: 1)
            .padding(.horizontal, 19)
            .frame(minWidth: minWidth, maxWidth: fillWidth ? .infinity : nil, minHeight: 34)
            .background(Capsule().fill(selected ? Palette.sea : Palette.chip))
    }
}

/// toggle_on / toggle_off.
struct LureToggle: View {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.lureReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Palette.sea : Palette.toggleOff)
                Circle().fill(Color.white).frame(width: 24, height: 24).padding(.horizontal, 3)
            }
            .frame(width: 52, height: 30)
            .frame(minWidth: 52, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement()
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Double tap to toggle"))
    }
}

/// Status pill under collection domes.
struct StatusPill: View {
    let title: String
    let good: Bool

    var body: some View {
        Text(title)
            .font(.avenir(12, .bold))
            .foregroundColor(good ? Palette.success : Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .frame(width: 130, height: 25)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(good ? Palette.statusGood : Palette.statusNeutral))
    }
}
