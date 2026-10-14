import SwiftUI

/// Gold lettering on the wooden sign: brown drop shadow, pale outline, gold gradient fill.
struct SignLettering: View {
    let text: String
    let size: CGFloat

    var body: some View {
        let font = Font.avenirFixed(size, .heavy)
        ZStack {
            Text(text).font(font).foregroundColor(Palette.signShadow).offset(x: 1, y: 3)
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * .pi / 4
                Text(text).font(font).foregroundColor(Palette.signStroke)
                    .offset(x: CGFloat(cos(angle)) * 0.4, y: CGFloat(sin(angle)) * 0.4)
            }
            Text(text).font(font).foregroundColor(.clear)
                .overlay(Palette.goldGradient.mask(Text(text).font(font)))
        }
        .fixedSize()
        .accessibilityHidden(true)
    }
}

/// Screens 20 (Ready), 21 (Motion), 22 (Result), 23 (No Capsules), 44 (Cooldown).
/// The receipt (matrix, Parts, balance) is committed before the reels move; animation is never the source of truth.
struct LuckyCastView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.lureReduceMotion) private var reduceMotion
    @Environment(\.haptics) private var haptics

    enum Phase { case idle, spinning, result }

    @State private var phase: Phase = .idle
    @State private var receipt: CastReceipt?
    @State private var strips: [[CastSymbol]] = []
    @State private var offsets: [CGFloat] = Array(repeating: 0, count: 5)
    @State private var stopped: [Bool] = Array(repeating: true, count: 5)
    @State private var ringsVisible = false
    @State private var plaqueLift: CGFloat = 0
    @State private var generation = 0
    @State private var prepared = false
    @State private var errorMessage: String?

    private let pitch: CGFloat = 70
    private var engine: CastEngine { CastEngine(rules: model.rules) }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let scale = width / 390
            ZStack(alignment: .top) {
                ArtImage(art: .bg02, mode: .fill)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header(width: width)
                        canvas
                            .frame(width: 390, height: 547, alignment: .topLeading)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: width, height: 547 * scale, alignment: .topLeading)
                        controls
                            .padding(.horizontal, Metrics.margin)
                            .padding(.top, 32)
                            .padding(.bottom, 16)
                    }
                }
                StatusBarCover()
            }
        }
        .onDisappear {
            // Back / swipe during the reels: cancel callbacks so the committed result stays pending
            // and is shown (not silently marked presented) on the next visit.
            generation += 1
        }
        .onAppear {
            prepare()
            #if DEBUG
            if DebugScenario.name == "21" { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { cast() } }
            #endif
        }
        .alert(item: Binding(get: { errorMessage.map(AlertText.init) }, set: { errorMessage = $0?.text })) { message in
            Alert(title: Text("Lucky Cast"), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: State

    private var capsules: Int { model.capsuleState.capsules }

    private var cooldownUntil: Date? {
        guard let next = model.capsuleState.nextEligibleAt, next > model.now else { return nil }
        return next
    }

    private var evaluation: CastEngine.Evaluation? {
        receipt.map { engine.evaluate(matrix: $0.matrix) }
    }

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        if let pending = model.workshop.pendingReceipt {
            // Relaunch / return during animation: show the same committed outcome, nothing is granted again.
            receipt = pending
            strips = columns(of: pending.matrix)
            phase = .result
            ringsVisible = true
            model.markPresented(pending.id)
            Accessibility.announce(resultAnnouncement(parts: pending.parts))
        } else {
            strips = columns(of: engine.idleBoard())
        }
    }

    private func columns(of matrix: [[CastSymbol]]) -> [[CastSymbol]] {
        (0..<5).map { column in (0..<3).map { row in matrix[row][column] } }
    }

    // MARK: Header (native size)

    private func header(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Palette.background.frame(width: width, height: 56)
            IconButton(icon: "icon_back", size: 28, label: "Back") { router.pop() }
                .offset(x: 5, y: 9)
            ArtImage(art: .s02)
                .frame(width: 35, height: 27)
                .offset(x: 46, y: 13)
            Text("Lure Lab")
                .font(.avenir(23, .heavy))
                .foregroundColor(Palette.ink)
                .lineLimit(1)
                .offset(x: 86, y: 12)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 4) {
                ArtImage(art: .s03).frame(width: 30, height: 26)
                Text(Format.capsules(capsules))
                    .font(.avenirFixed(12, .heavy))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .frame(minWidth: 62)
            }
            .padding(.leading, 7)
            .padding(.trailing, 8)
            .frame(height: 36)
            .background(Capsule().fill(Palette.background))
            .offset(x: width - 125, y: 11)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(Format.capsules(capsules)) available"))
        }
        .frame(width: width, height: 56, alignment: .topLeading)
    }

    // MARK: Canvas (design coordinates 0…390 × 103…650, scaled to width)

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            ArtImage(art: .bg01, mode: .fill)
                .frame(width: 390, height: 310)
                .offset(y: -103)
                .frame(width: 390, height: 207, alignment: .top)
                .clipped()
            ArtImage(art: .c02).mockupFrame(x: 211, y: 1, width: 177, height: 215)
            ArtImage(art: .f02).mockupFrame(x: 16, y: 35, width: 228, height: 159)
            SignLettering(text: "LUCKY", size: 42).position(x: 129, y: 98 - 42 * 0.317)
            SignLettering(text: "CAST", size: 46).position(x: 129, y: 145 - 46 * 0.317)
            Text("Workshop Drop")
                .font(.avenirFixed(15, .heavy))
                .foregroundColor(Palette.ink)
                .fixedSize()
                .position(x: 129, y: 173 - 15 * 0.317)
                .accessibilityHidden(true)
            ArtImage(art: .fx01, mode: .stretch).mockupFrame(x: 1, y: 177, width: 389, height: 49)

            board
            ArtImage(art: .f01, mode: .stretch).mockupFrame(x: 13, y: 199, width: 364, height: 303)
            ArtImage(art: .f04, mode: .stretch).mockupFrame(x: 21, y: 503, width: 348, height: 44)
            Text(plaqueText)
                .font(.avenirFixed(14, .heavy))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 300)
                .position(x: 195, y: 531 - 14 * 0.317)
                .offset(y: plaqueLift)
                .accessibilityLabel(Text(plaqueText))
        }
        .accessibilityElement(children: .contain)
    }

    private var plaqueText: String {
        if phase == .result, let receipt {
            return "+\(Format.parts(receipt.parts)) · Added to your workshop"
        }
        return "Collect parts. Craft rare lures."
    }

    private var board: some View {
        ZStack(alignment: .topLeading) {
            ArtImage(art: .bg02, mode: .fill).mockupFrame(x: 40, y: 244, width: 310, height: 218)
            Palette.reelTint.opacity(0.24).mockupFrame(x: 40, y: 244, width: 310, height: 218)
            ForEach(0..<5, id: \.self) { column in
                ForEach(0..<3, id: \.self) { row in
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Palette.reelCellStroke, lineWidth: 0.6)
                        .mockupFrame(x: 43 + CGFloat(column) * 61, y: 247 + CGFloat(row) * 70, width: 60, height: 69)
                }
                reel(column)
                    .mockupFrame(x: 43 + CGFloat(column) * 61, y: 247, width: 60, height: 209)
            }
            Path { path in
                for x in [104, 165, 226, 287] {
                    path.move(to: CGPoint(x: x, y: 247))
                    path.addLine(to: CGPoint(x: x, y: 457))
                }
            }
            .stroke(Palette.reelDivider, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            if ringsVisible, let evaluation {
                ForEach(Array(evaluation.highlightedColumns), id: \.self) { column in
                    Image("selection_ring")
                        .resizable()
                        .mockupFrame(x: 44 + CGFloat(column) * 61, y: 319, width: 58, height: 65)
                        .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.94)))
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(boardAccessibility))
    }

    private var boardAccessibility: String {
        guard strips.count == 5 else { return "Reels" }
        let middle = strips.map { $0.count > 1 ? (phase == .spinning ? "" : $0[1].accessibilityName) : "" }
        if phase == .spinning { return "Reels opening" }
        return "Middle row: " + middle.joined(separator: ", ")
    }

    private func reel(_ column: Int) -> some View {
        let symbols = strips.indices.contains(column) ? strips[column] : []
        let isStopped = stopped.indices.contains(column) ? stopped[column] : true
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    ArtImage(art: Art.symbol(symbol))
                        .frame(width: 52, height: 57)
                        .padding(.leading, 4)
                        .padding(.top, 6)
                        .frame(width: 60, height: pitch, alignment: .topLeading)
                }
            }
            .offset(y: offsets.indices.contains(column) ? offsets[column] : 0)
            .opacity(isStopped ? 1 : 0.45)
            if !isStopped {
                ForEach(0..<3, id: \.self) { row in
                    Path { path in
                        let top = CGFloat(row) * pitch
                        path.move(to: CGPoint(x: 20, y: top))
                        path.addLine(to: CGPoint(x: 20, y: top + 64))
                        path.move(to: CGPoint(x: 37, y: top + 4))
                        path.addLine(to: CGPoint(x: 37, y: top + 67))
                    }
                    .stroke(Palette.reelStreak, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }
            }
        }
        .frame(width: 60, height: 209, alignment: .topLeading)
        .clipped()
    }

    // MARK: Controls (native size)

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 0) {
            switch phase {
            case .spinning:
                GoldButton(title: "Opening…", isEnabled: false) {}
                caption("Uses 1 capsule").padding(.top, 8)
                link("Skip Animation", color: Palette.luckyLink, size: 17, weight: .bold, action: skip)
                    .padding(.top, -3.5)
            case .result:
                GoldButton(title: "Done") { router.popToRoot() }
                caption("Result saved").padding(.top, 8)
                link("My Showcase ›", color: Palette.luckyLink, size: 17, weight: .bold) { router.push(.showcase) }
                    .padding(.top, -3.5)
            case .idle:
                if capsules > 0 {
                    GoldButton(title: "CAST", action: cast)
                        .accessibilityHint(Text("Uses 1 free capsule"))
                    caption("Uses 1 capsule").padding(.top, 8)
                    link("My Showcase ›", color: Palette.luckyLink, size: 17, weight: .bold) { router.push(.showcase) }
                        .padding(.top, -3.5)
                } else {
                    GoldButton(title: "No Capsules", isEnabled: false) {}
                    if let next = cooldownUntil {
                        caption("Next capsule after \(Format.shortDateAndTime(next))", weight: .demiBold).padding(.top, 15)
                        link("My Showcase ›", color: Palette.luckyLinkStrong, size: 16, weight: .heavy) { router.push(.showcase) }
                            .padding(.top, 0)
                    } else {
                        caption("Save a test to earn a free capsule.", weight: .demiBold).padding(.top, 15)
                        link("Log a Test ›", color: Palette.luckyLinkStrong, size: 16, weight: .heavy, action: logTest)
                            .padding(.top, 0)
                    }
                }
            }
        }
    }

    private func caption(_ text: String, weight: AvenirWeight = .medium) -> some View {
        Text(text)
            .font(.avenir(14, weight))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func link(_ title: String, color: Color, size: CGFloat, weight: AvenirWeight, action: @escaping () -> Void) -> some View {
        LinkButton(title: title, size: size, weight: weight, color: color, action: action)
            .padding(.horizontal, 20)
    }

    // MARK: Actions

    private func logTest() {
        if model.activeLures.isEmpty {
            coordinator.open(.journal, stack: [.lureEditor(nil)])
        } else {
            coordinator.open(.journal, stack: [.testEditor(.new(lureID: nil))])
        }
    }

    private func cast() {
        guard phase == .idle else { return }
        let committed: CastReceipt
        do {
            committed = try model.cast()
        } catch {
            haptics.warning()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "The result could not be saved. Nothing was used. Try again."
            return
        }
        haptics.tap()
        receipt = committed
        ringsVisible = false
        let finalColumns = columns(of: committed.matrix)
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.15)) {
                strips = finalColumns
            }
            finish()
            return
        }
        generation += 1
        let token = generation
        let current = strips
        var startOffsets: [CGFloat] = []
        var newStrips: [[CastSymbol]] = []
        for column in 0..<5 {
            let fillerCount = 10 + column * 2
            let filler = (0..<fillerCount).map { _ in model.rules.castSymbols.randomElement() ?? .s01 }
            let previous = current.indices.contains(column) ? Array(current[column].suffix(3)) : finalColumns[column]
            newStrips.append(finalColumns[column] + filler + previous)
            startOffsets.append(-CGFloat(fillerCount + 3) * pitch)
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            strips = newStrips
            offsets = startOffsets
            stopped = Array(repeating: false, count: 5)
            phase = .spinning
        }
        DispatchQueue.main.async {
            for column in 0..<5 {
                let delay = 0.06 * Double(column)
                let duration = 0.8 + 0.1 * Double(column)
                withAnimation(.timingCurve(0.2, 0.55, 0.25, 1, duration: duration).delay(delay)) {
                    offsets[column] = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + duration) {
                    guard token == generation, phase == .spinning else { return }
                    withAnimation(.easeOut(duration: 0.12)) { stopped[column] = true }
                    haptics.reelStop()
                    if column == 4 { finish() }
                }
            }
        }
    }

    private func skip() {
        guard phase == .spinning, receipt != nil else { return }
        generation += 1
        var transaction = Transaction()
        transaction.disablesAnimations = true
        finish()
    }

    private func finish() {
        guard let receipt else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            strips = columns(of: receipt.matrix)
            offsets = Array(repeating: 0, count: 5)
            stopped = Array(repeating: true, count: 5)
            phase = .result
            plaqueLift = reduceMotion ? 0 : 4
        }
        withAnimation(.easeOut(duration: 0.18)) { ringsVisible = true }
        withAnimation(.easeOut(duration: 0.22)) { plaqueLift = 0 }
        model.markPresented(receipt.id)
        haptics.success()
        Accessibility.announce(resultAnnouncement(parts: receipt.parts))
    }

    private func resultAnnouncement(parts: Int) -> String {
        "Lucky Cast result: plus \(Format.parts(parts)). You now have \(Format.parts(model.capsuleState.parts))."
    }
}
