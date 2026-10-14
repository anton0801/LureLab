import SwiftUI

/// Press feedback from the design system: scale 0.98 and 1 pt down, 90 ms.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

/// Primary CTA: F03 gold master + live label. Disabled uses the button_disabled surface.
struct GoldButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.haptics) private var haptics

    var body: some View {
        Button {
            haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Palette.ink))
                }
                Text(title)
                    .font(.avenir(18, .heavy))
                    .foregroundColor(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(Text(title))
    }

    @ViewBuilder
    private var surface: some View {
        if isEnabled {
            ArtImage(art: .f03, mode: .stretch)
        } else {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .fill(Palette.disabledButton)
                    .overlay(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                        .stroke(Palette.disabledButtonStroke, lineWidth: 1))
                    .padding(1)
                Spacer(minLength: 4)
            }
        }
    }
}

enum SurfaceButtonKind {
    case secondary, danger, disabled
}

/// 58 pt secondary / danger surfaces from assets/ui (native geometry).
struct SurfaceButton: View {
    let title: String
    var kind: SurfaceButtonKind = .secondary
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.haptics) private var haptics

    private var fill: Color {
        switch kind {
        case .secondary: return Palette.secondaryButton
        case .danger: return Palette.error
        case .disabled: return Palette.disabledButton
        }
    }

    private var stroke: Color? {
        switch kind {
        case .secondary: return Palette.secondaryButtonStroke
        case .danger: return nil
        case .disabled: return Palette.disabledButtonStroke
        }
    }

    var body: some View {
        Button {
            haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: kind == .danger ? .white : Palette.ink))
                }
                Text(title)
                    .font(.avenir(18, .heavy))
                    .foregroundColor(kind == .danger ? .white : Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .fill(fill)
                    .overlay(stroke.map { RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous).stroke($0, lineWidth: 1) })
                    .padding(1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(kind == .disabled || isLoading)
    }
}

/// Inline text action with a 44 pt touch area.
struct LinkButton: View {
    let title: String
    var size: CGFloat = 17
    var weight: AvenirWeight = .bold
    var color: Color = Palette.sea
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.avenir(size, weight))
                .foregroundColor(color)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Small blue pill ("Open").
struct PillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.avenir(14, .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(minWidth: 66, minHeight: 35)
                .background(Capsule().fill(Palette.sea))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Icon-only button with a 44 × 44 touch target.
struct IconButton: View {
    let icon: String
    var size: CGFloat = 30
    var color: Color = Palette.ink
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            UIIcon(name: icon, size: size, color: color)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(label))
    }
}
