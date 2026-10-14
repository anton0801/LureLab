import SwiftUI

/// Screen 34: transparent description of capsules and rewards.
struct WorkshopGuideView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router

    private var steps: [(String, String)] {
        let hours = model.rules.capsuleCooldownSeconds / 3600
        return [
            ("1. Save a test", "Earn 1 capsule when the \(hours)-hour timer is ready (max \(model.rules.maxCapsules)). Zero catches is fine."),
            ("2. Open Lucky Cast", "Use 1 free capsule. Every opening gives at least \(model.rules.reward.defaultParts) Part."),
            ("3. Make a collectible", "Choose a lure. Each costs \(model.rules.craftCostParts) Parts and is yours once crafted."),
            ("No real-world value", "Capsules and Parts cannot be bought, sold or exchanged for money.")
        ]
    }

    var body: some View {
        LightScreen {
            ScreenHeader(title: "Workshop Guide", subtitle: "A free extra for your fishing journal.", onBack: { router.pop() })
            VStack(spacing: 14) {
                ForEach(steps, id: \.0) { step in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(step.0)
                            .font(.avenir(19, .heavy))
                            .foregroundColor(Palette.ink)
                            .padding(.top, 15)
                            .accessibilityAddTraits(.isHeader)
                        Text(step.1)
                            .font(.avenir(15, .medium))
                            .foregroundColor(Palette.secondary)
                            .lineSpacing(0.5)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 268, alignment: .leading)
                            .padding(.top, 7)
                            .padding(.bottom, 18)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 119, alignment: .topLeading)
                    .lureCard()
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 30.5)
            LinkButton(title: "Reward details ›", size: 16) { router.push(.rewardDetails) }
                .frame(maxWidth: .infinity)
                .padding(.top, 9)
        } bottom: {
            GoldButton(title: "Done") { router.pop() }
        }
    }
}

/// Screen 43: exact odds computed by enumerating all 7776 middle rows.
struct RewardDetailsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router

    private var distribution: [Int: Int] { CastEngine(rules: model.rules).exhaustiveDistribution() }

    var body: some View {
        let counts = distribution
        let total = counts.values.reduce(0, +)
        let rewards = [model.rules.reward.defaultParts, model.rules.reward.longestRun3or4Parts, model.rules.reward.longestRun5Parts]
        LightScreen {
            ScreenHeader(title: "Reward Details", subtitle: "Every opening gives workshop Parts.", onBack: { router.pop() })
            VStack(alignment: .leading, spacing: 0) {
                Text("One row counts")
                    .font(.avenir(23, .heavy))
                    .foregroundColor(Palette.ink)
                    .padding(.top, 14)
                    .accessibilityAddTraits(.isHeader)
                Text("Only the middle row is evaluated. Each of the six symbols has the same chance in every cell.")
                    .font(.avenir(16, .medium))
                    .foregroundColor(Palette.secondary)
                    .lineSpacing(1.1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 255, alignment: .leading)
                    .padding(.top, 12.6)
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .lureCard()
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 34.5)

            VStack(spacing: 17) {
                ForEach(rewards, id: \.self) { parts in
                    let count = counts[parts] ?? 0
                    ListRow(icon: "icon_parts", title: Format.parts(parts), value: percent(count, of: total))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("\(Format.parts(parts)): \(percent(count, of: total)), \(count) of \(total) rows"))
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 30)

            Text("3 or 4 adjacent matching symbols: \(Format.parts(model.rules.reward.longestRun3or4Parts)). All 5 matching: \(Format.parts(model.rules.reward.longestRun5Parts)). Otherwise: \(Format.parts(model.rules.reward.defaultParts)).")
                .font(.avenir(16, .medium))
                .foregroundColor(Palette.secondary)
                .lineSpacing(1.1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 280, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 39)
        } bottom: {
            GoldButton(title: "Done") { router.pop() }
        }
    }

    private func percent(_ count: Int, of total: Int) -> String {
        guard total > 0 else { return "—" }
        return String(format: "%.4f%%", locale: Locale(identifier: "en_US_POSIX"), Double(count) / Double(total) * 100)
    }
}
