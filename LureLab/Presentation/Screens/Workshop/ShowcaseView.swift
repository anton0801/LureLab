import SwiftUI

/// Collection tile: F05 dome, the L-art behind it, status pill and gold label (collection_label).
struct CollectionTile: View {
    let definition: CollectibleDefinition
    let crafted: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            ArtImage(art: .f05).mockupFrame(x: 5, y: 0, width: 160, height: 176)
            ArtImage(art: Art.collectible(definition.id))
                .opacity(crafted ? 1 : 0.7)
                .mockupFrame(x: 23, y: 27, width: 124, height: 99)
            StatusPill(title: crafted ? "Crafted" : Format.parts(definition.costParts), good: crafted)
                .mockupFrame(x: 21, y: 143, width: 130, height: 25)
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(hex: 0x78461F))
                    .frame(width: 168, height: 34)
                    .offset(y: 1)
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Palette.goldGradient)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color(hex: 0xBB782C), lineWidth: 1))
                    .frame(width: 168, height: 33)
                    .offset(y: -1)
                Text(definition.name)
                    .font(.avenir(14, .heavy))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 8)
            }
            .mockupFrame(x: 0, y: 177, width: 170, height: 36)
        }
        .frame(width: 170, height: 213, alignment: .topLeading)
        // Art layers ignore hit testing; the whole tile is the tap target.
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(definition.name), \(crafted ? "crafted" : "costs \(Format.parts(definition.costParts))")"))
        .accessibilityAddTraits(.isButton)
    }
}

/// Screens 24 (My Showcase), 25 (Showcase Empty), 42 (Collection Complete).
struct ShowcaseView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let crafted = model.craftedIDs
            let complete = crafted.count == model.rules.collectibles.count
            ZStack(alignment: .top) {
                ArtImage(art: .bg02, mode: .fill).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            Palette.background.frame(width: width, height: 55)
                            ScreenHeader(title: "My Showcase", onBack: { router.pop() })
                            ArtImage(art: .c03)
                                .frame(width: 101, height: 109)
                                .offset(x: width - 138, y: 66)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Your collection")
                                    .font(.avenir(27, .heavy))
                                    .foregroundColor(Palette.ink)
                                    .accessibilityAddTraits(.isHeader)
                                Text(subtitle(crafted: crafted.count, complete: complete))
                                    .font(.avenir(17, .demiBold))
                                    .foregroundColor(Palette.ink)
                                    .padding(.top, 6.1)
                            }
                            .offset(x: 22, y: 79)
                        }
                        .frame(width: width, height: 192, alignment: .topLeading)

                        // Large text: one column so names stay readable.
                        let columns = sizeCategory.isAccessibilityCategory
                            ? [GridItem(.fixed(170))]
                            : [GridItem(.fixed(170), spacing: 10), GridItem(.fixed(170), spacing: 10)]
                        LazyVGrid(columns: columns, spacing: 19) {
                            ForEach(model.rules.collectibles) { definition in
                                Button { router.push(.collectible(definition.id)) } label: {
                                    CollectionTile(definition: definition, crafted: crafted.contains(definition.id))
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity)

                        GoldButton(title: "Open Workshop") { router.popToRoot() }
                            .padding(.horizontal, Metrics.margin)
                            .padding(.top, 53)
                            .padding(.bottom, 16)
                    }
                }
                StatusBarCover()
            }
        }
    }

    private func subtitle(crafted: Int, complete: Bool) -> String {
        let base = "\(crafted) of \(model.rules.collectibles.count) crafted"
        return complete ? "\(base) · \(Format.parts(model.capsuleState.parts)) saved" : base
    }
}

/// Screens 26 (Craft Lure), 27 (Need More Parts), 28 (Lure Crafted). Result is known before crafting.
struct CollectibleDetailView: View {
    let collectibleID: String
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @Environment(\.lureReduceMotion) private var reduceMotion
    @Environment(\.haptics) private var haptics
    @State private var justCrafted = false
    @State private var lureScale: CGFloat = 1
    @State private var burstOpacity: Double = 0
    @State private var isCrafting = false
    @State private var errorMessage: String?

    private var definition: CollectibleDefinition {
        model.rules.collectible(collectibleID) ?? model.rules.collectibles[0]
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let record = model.crafted(definition.id)
            let parts = model.capsuleState.parts
            ZStack(alignment: .top) {
                ArtImage(art: .bg03, mode: .fill).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            Palette.background.frame(width: width, height: 60)
                            ScreenHeader(title: definition.name, onBack: { router.pop() })
                        }
                        .frame(width: width, height: 60, alignment: .topLeading)

                        Text("WORKSHOP COLLECTION")
                            .font(.avenir(12, .heavy))
                            .foregroundColor(Palette.collectionCaption)
                            .padding(.top, 32)

                        ZStack(alignment: .topLeading) {
                            if justCrafted && !reduceMotion {
                                ArtImage(art: .fx02)
                                    .mockupFrame(x: -31, y: 9, width: 338, height: 326)
                                    .opacity(burstOpacity)
                            }
                            ArtImage(art: .f05).mockupFrame(x: 0, y: 0, width: 276, height: 321)
                            ArtImage(art: Art.collectible(definition.id))
                                .scaleEffect(lureScale)
                                .mockupFrame(x: 35, y: 59, width: 210, height: 167)
                        }
                        .frame(width: 276, height: 321)
                        .padding(.top, 22.6)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("\(definition.name) under a glass display dome"))

                        ZStack {
                            ArtImage(art: .f04, mode: .stretch)
                            Text(definition.name)
                                .font(.avenir(22, .heavy))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 30)
                        }
                        .frame(width: 312, height: 47)
                        .padding(.top, 16)

                        Text(record == nil || justCrafted ? "Collectible only · For your showcase" : "Crafted \(Format.mediumDate(record!.craftedAt)) · For your showcase")
                            .font(.avenir(14, .medium))
                            .foregroundColor(Palette.collectionSubtitle)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Metrics.margin)
                            .padding(.top, 16)

                        if justCrafted {
                            Text("Made it yours!")
                                .font(.avenir(28, .heavy))
                                .foregroundColor(Palette.madeItYours)
                                .padding(.top, 25.9)
                            GoldButton(title: "View Collection") { router.pop() }
                                .padding(.horizontal, Metrics.margin)
                                .padding(.top, 75.8)
                        } else if record != nil {
                            partsCard(text: "Crafted")
                                .padding(.horizontal, Metrics.margin)
                                .padding(.top, 30.9)
                            GoldButton(title: "View Collection") { router.pop() }
                                .padding(.horizontal, Metrics.margin)
                                .padding(.top, 33)
                        } else {
                            partsCard(text: "\(min(parts, definition.costParts)) / \(definition.costParts)")
                                .padding(.horizontal, Metrics.margin)
                                .padding(.top, 30.9)
                            if parts >= definition.costParts {
                                GoldButton(title: "Craft for \(Format.parts(definition.costParts))", isLoading: isCrafting, action: craft)
                                    .padding(.horizontal, Metrics.margin)
                                    .padding(.top, 33)
                            } else {
                                GoldButton(title: "Need \(definition.costParts - parts) More \(definition.costParts - parts == 1 ? "Part" : "Parts")", isEnabled: false) {}
                                    .padding(.horizontal, Metrics.margin)
                                    .padding(.top, 33)
                                LinkButton(title: "Open Lucky Cast ›", size: 17, weight: .bold, color: Palette.luckyLink) {
                                    router.setStack([.luckyCast])
                                }
                                .shadow(color: Color.black.opacity(0.55), radius: 2, x: 0, y: 1)
                                .padding(.top, -8)
                            }
                        }
                        Spacer(minLength: 16)
                    }
                    .frame(width: width)
                }
                StatusBarCover()
            }
        }
        .onAppear {
            #if DEBUG
            if DebugScenario.name == "28" { craft() }
            #endif
        }
        .alert(item: Binding(get: { errorMessage.map(AlertText.init) }, set: { errorMessage = $0?.text })) { message in
            Alert(title: Text("Could not craft"), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
    }

    private func partsCard(text: String) -> some View {
        HStack(spacing: 0) {
            ArtImage(art: .p03).frame(width: 43, height: 39).padding(.leading, 15)
            Text("Parts")
                .font(.avenir(18, .bold))
                .foregroundColor(Palette.ink)
                .padding(.leading, 13)
            Spacer()
            Text(text)
                .font(.avenir(22, .heavy))
                .foregroundColor(Palette.ink)
                .padding(.trailing, 21)
        }
        .frame(maxWidth: .infinity, minHeight: 69)
        .lureCard()
        .accessibilityElement(children: .combine)
    }

    private func craft() {
        guard !isCrafting else { return }
        isCrafting = true
        defer { isCrafting = false }
        do {
            let result = try model.craft(definition.id)
            guard case .crafted = result else { return }
            haptics.success()
            justCrafted = true
            Accessibility.announce("\(definition.name) crafted for your showcase")
            if reduceMotion { return }
            lureScale = 0.92
            burstOpacity = 0
            withAnimation(.easeOut(duration: 0.28)) {
                lureScale = 1
                burstOpacity = 1
            }
        } catch {
            haptics.warning()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Nothing was spent. Try again."
        }
    }
}
