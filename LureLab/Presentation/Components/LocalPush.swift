import SwiftUI

/// Pushes a sub-screen that edits the presenting form's state (More Details, Conditions, Choose Lure).
/// It looks like a navigation push but keeps the parent form alive and bound.
struct LocalPushModifier<Pushed: View>: ViewModifier {
    let isPresented: Bool
    @ViewBuilder let pushed: () -> Pushed
    @Environment(\.lureReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
                .allowsHitTesting(!isPresented)
                .accessibilityHidden(isPresented)
            if isPresented {
                pushed()
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                    .zIndex(1)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.3), value: isPresented)
    }
}

/// Dialog overlay with a fade (dialogs 32–41).
struct DialogModifier<Dialog: View>: ViewModifier {
    let isPresented: Bool
    @ViewBuilder let dialog: () -> Dialog

    func body(content: Content) -> some View {
        ZStack {
            content
                .accessibilityHidden(isPresented)
            if isPresented {
                dialog()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isPresented)
    }
}

/// Native progress over the current content while an operation runs; content stays visible.
struct BusyOverlayModifier: ViewModifier {
    let isBusy: Bool
    var label: String = "Working…"

    func body(content: Content) -> some View {
        ZStack {
            content
                .allowsHitTesting(!isBusy)
            if isBusy {
                Color.black.opacity(0.08).ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Palette.ink))
                        .scaleEffect(1.2)
                    Text(label)
                        .font(.avenir(15, .demiBold))
                        .foregroundColor(Palette.ink)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 20)
                .lureCard()
                .accessibilityElement(children: .combine)
                .zIndex(3)
            }
        }
    }
}

extension View {
    func localPush<Pushed: View>(isPresented: Bool, @ViewBuilder content: @escaping () -> Pushed) -> some View {
        modifier(LocalPushModifier(isPresented: isPresented, pushed: content))
    }

    func dialog<Dialog: View>(isPresented: Bool, @ViewBuilder content: @escaping () -> Dialog) -> some View {
        modifier(DialogModifier(isPresented: isPresented, dialog: content))
    }

    func busyOverlay(_ isBusy: Bool, label: String = "Working…") -> some View {
        modifier(BusyOverlayModifier(isBusy: isBusy, label: label))
    }
}

/// Simple dialog with up to three stacked actions (gold first, then secondary surfaces).
struct DialogAction: Identifiable {
    enum Style { case primary, secondary, danger, disabled }
    let id = UUID()
    let title: String
    var style: Style = .secondary
    let action: () -> Void
}

struct ActionDialog: View {
    let icon: String
    let title: String
    let message: String
    let actions: [DialogAction]
    var messageToActions: CGFloat = 22
    var bottomPadding: CGFloat = 29

    var body: some View {
        ModalDialog(icon: icon, title: title, message: message, messageToActions: messageToActions, bottomPadding: bottomPadding) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, item in
                Group {
                    switch item.style {
                    case .primary:
                        GoldButton(title: item.title, action: item.action)
                    case .secondary:
                        SurfaceButton(title: item.title, kind: .secondary, action: item.action)
                    case .danger:
                        SurfaceButton(title: item.title, kind: .danger, action: item.action)
                    case .disabled:
                        SurfaceButton(title: item.title, kind: .disabled, action: item.action)
                    }
                }
                .padding(.top, index == 0 ? 0 : (actions[index - 1].style == .primary ? 2 : 6))
            }
        }
    }
}
