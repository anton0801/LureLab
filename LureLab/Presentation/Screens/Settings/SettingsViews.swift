import SwiftUI

/// Screen 29. No account, server or sound switch (audio is not part of this build).
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        LightScreen {
            ScreenHeader(title: "Settings", subtitle: "Make the workshop feel right for you.", onBack: { router.pop() })
            VStack(spacing: 17) {
                ListRow(icon: "icon_haptic", title: "Haptics") {
                    LureToggle(title: "Haptics", isOn: Binding(get: { model.settings.hapticsEnabled },
                                                               set: { value in model.updateSettings { $0.hapticsEnabled = value } }))
                        .padding(.trailing, -1)
                }
                ListRow(icon: "icon_motion", title: systemReduceMotion ? "Reduce Motion (on in iOS)" : "Reduce Motion") {
                    LureToggle(title: "Reduce Motion", isOn: Binding(get: { model.settings.reduceMotion || systemReduceMotion },
                                                                     set: { value in model.updateSettings { $0.reduceMotion = value } }))
                        .padding(.trailing, -1)
                        .disabled(systemReduceMotion)
                        .opacity(systemReduceMotion ? 0.6 : 1)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 37.5)

            VStack(spacing: 17) {
                NavRow(icon: "icon_lure", title: "Units", value: model.settings.units.title) { router.push(.units) }
                NavRow(icon: "icon_archive", title: "Data & Backup") { router.push(.data) }
                NavRow(icon: "icon_help", title: "Workshop Guide") { router.push(.workshopGuide) }
                NavRow(icon: "icon_retry", title: "Replay Onboarding") {
                    NotificationCenter.default.post(name: .replayOnboarding, object: nil)
                }
                NavRow(icon: "icon_info", title: "About Lure Lab") { router.push(.about) }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 31)

            Text("Your journal stays on this device.")
                .font(.avenir(14, .medium))
                .foregroundColor(Palette.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 41)
        }
    }
}

/// Screen 45. Canonical storage stays cm / g; only display and input change.
struct UnitsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router

    private let sampleLength = Decimal(9)
    private let sampleWeight = Decimal(12)

    var body: some View {
        let units = model.settings.units
        LightScreen {
            ScreenHeader(title: "Units", subtitle: "Choose how measurements are displayed.", onBack: { router.pop() })
            VStack(spacing: 16) {
                ForEach(UnitSystem.allCases) { option in
                    Button { model.updateSettings { $0.units = option } } label: {
                        ListRow(icon: units == option ? "icon_check" : "icon_lure", title: option.title,
                                value: units == option ? "Selected" : "")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityAddTraits(units == option ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 42.5)

            VStack(alignment: .leading, spacing: 0) {
                Text("Measurement preview")
                    .font(.avenir(22, .heavy))
                    .foregroundColor(Palette.ink)
                    .padding(.top, 16)
                Text("Length: \(Format.length(sampleLength, units: units))")
                    .font(.avenir(18, .demiBold))
                    .foregroundColor(Palette.ink)
                    .padding(.top, 15)
                Text("Weight: \(Format.weight(sampleWeight, units: units))")
                    .font(.avenir(18, .demiBold))
                    .foregroundColor(Palette.ink)
                    .padding(.top, 11.4)
                    .padding(.bottom, 25)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 159, alignment: .topLeading)
            .lureCard()
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 39)
            .accessibilityElement(children: .combine)
        } bottom: {
            GoldButton(title: "Done") { router.pop() }
        }
    }
}

/// Screen 46: local information only — no invented developer, email or links.
struct AboutView: View {
    @EnvironmentObject private var router: Router

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "Version \(short)"
    }

    var body: some View {
        LightScreen(bottomPadding: 18) {
            ScreenHeader(title: "About Lure Lab", onBack: { router.pop() })
            ArtImage(art: .i01)
                .frame(width: 92, height: 92)
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
            Text("Lure Lab")
                .font(.avenir(28, .heavy))
                .foregroundColor(Palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.top, 13)
            Text(version)
                .font(.avenir(15, .medium))
                .foregroundColor(Palette.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 6.8)
            VStack(alignment: .leading, spacing: 0) {
                Text("Your personal fishing journal")
                    .font(.avenir(21, .heavy))
                    .foregroundColor(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
                Text("Your lures, photos and test notes are stored on this device. No account is required.")
                    .font(.avenir(16, .medium))
                    .foregroundColor(Palette.secondary)
                    .lineSpacing(1.1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 255, alignment: .leading)
                    .padding(.top, 13.3)
                Text("Use Data & Backup to export your records before changing devices.")
                    .font(.avenir(16, .medium))
                    .foregroundColor(Palette.secondary)
                    .lineSpacing(1.1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 255, alignment: .leading)
                    .padding(.top, 26.1)
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 244, alignment: .topLeading)
            .lureCard()
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 38.3)
        } bottom: {
            GoldButton(title: "Data & Backup") { router.push(.data) }
            SurfaceButton(title: "Done") { router.pop() }
                .padding(.top, 17)
        }
    }
}
