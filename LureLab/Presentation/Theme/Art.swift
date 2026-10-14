import SwiftUI

/// Original art masters from assets/art with their alpha bounds (assets/art/manifest.json).
enum Art: String, CaseIterable {
    case bg01 = "BG01", bg02 = "BG02", bg03 = "BG03"
    case ob01 = "OB01", ob02 = "OB02", ob03 = "OB03"
    case c01 = "C01", c02 = "C02", c03 = "C03"
    case f01 = "F01", f02 = "F02", f03 = "F03", f04 = "F04", f05 = "F05"
    case s01 = "S01", s02 = "S02", s03 = "S03", s04 = "S04", s05 = "S05", s06 = "S06"
    case l01 = "L01", l02 = "L02", l03 = "L03", l04 = "L04"
    case p01 = "P01", p02 = "P02", p03 = "P03"
    case fx01 = "FX01", fx02 = "FX02"
    case i01 = "I01"

    var pixelSize: CGSize {
        switch self {
        case .bg01, .bg02, .bg03, .ob01, .ob02, .ob03: return CGSize(width: 1024, height: 1536)
        case .c01: return CGSize(width: 1191, height: 1321)
        case .c02, .c03: return CGSize(width: 1199, height: 1312)
        case .f01: return CGSize(width: 1456, height: 1080)
        case .f02: return CGSize(width: 1510, height: 1041)
        case .f03: return CGSize(width: 1898, height: 829)
        case .f04, .fx01: return CGSize(width: 2172, height: 724)
        case .f05: return CGSize(width: 1190, height: 1322)
        case .s01: return CGSize(width: 1312, height: 1199)
        case .s02, .s03, .s06, .l02, .l03, .l04, .p03: return CGSize(width: 1536, height: 1024)
        case .s04, .s05, .fx02, .i01: return CGSize(width: 1254, height: 1254)
        case .l01: return CGSize(width: 1672, height: 941)
        case .p01: return CGSize(width: 1235, height: 1274)
        case .p02: return CGSize(width: 1358, height: 1159)
        }
    }

    /// Useful alpha bounds (x, y, width, height) — the SVG viewBox used by `fitAlphaBounds` placements.
    var alphaBounds: CGRect {
        switch self {
        case .bg01, .bg02, .bg03, .ob01, .ob02, .ob03, .i01: return CGRect(origin: .zero, size: pixelSize)
        case .c01: return CGRect(x: 25, y: 37, width: 1129, height: 1260)
        case .c02: return CGRect(x: 77, y: 77, width: 1012, height: 1142)
        case .c03: return CGRect(x: 42, y: 86, width: 1130, height: 1197)
        case .f01: return CGRect(x: 22, y: 68, width: 1412, height: 912)
        case .f02: return CGRect(x: 9, y: 8, width: 1493, height: 1017)
        case .f03: return CGRect(x: 68, y: 207, width: 1761, height: 392)
        case .f04: return CGRect(x: 49, y: 173, width: 2074, height: 356)
        case .f05: return CGRect(x: 55, y: 26, width: 1080, height: 1248)
        case .s01: return CGRect(x: 268, y: 20, width: 869, height: 1118)
        case .s02: return CGRect(x: 26, y: 132, width: 1490, height: 782)
        case .s03: return CGRect(x: 81, y: 141, width: 1374, height: 759)
        case .s04: return CGRect(x: 150, y: 145, width: 942, height: 928)
        case .s05: return CGRect(x: 14, y: 30, width: 1208, height: 1180)
        case .s06: return CGRect(x: 63, y: 23, width: 1423, height: 940)
        case .l01: return CGRect(x: 32, y: 164, width: 1611, height: 707)
        case .l02: return CGRect(x: 19, y: 150, width: 1498, height: 788)
        case .l03: return CGRect(x: 20, y: 267, width: 1498, height: 588)
        case .l04: return CGRect(x: 32, y: 25, width: 1481, height: 945)
        case .p01: return CGRect(x: 23, y: 8, width: 1196, height: 1259)
        case .p02: return CGRect(x: 43, y: 102, width: 1256, height: 968)
        case .p03: return CGRect(x: 207, y: 80, width: 1217, height: 845)
        case .fx01: return CGRect(x: 38, y: 67, width: 2090, height: 626)
        case .fx02: return CGRect(x: 62, y: 49, width: 1120, height: 1149)
        }
    }

    static func symbol(_ symbol: CastSymbol) -> Art {
        switch symbol {
        case .s01: return .s01
        case .s02: return .s02
        case .s03: return .s03
        case .s04: return .s04
        case .s05: return .s05
        case .s06: return .s06
        }
    }

    static func collectible(_ id: String) -> Art {
        switch id {
        case "L02": return .l02
        case "L03": return .l03
        case "L04": return .l04
        default: return .l01
        }
    }
}

enum ArtMode {
    /// `fitAlphaBounds`: alpha bounds fit inside the frame, aspect preserved, centred.
    case fit
    /// `stretch`: alpha bounds stretched to the frame (buttons, plaques, frames).
    case stretch
    /// `aspectFill`: full image covers the frame (backgrounds).
    case fill
}

/// Renders a master PNG exactly like the screen SVGs map it into a placement rect. Decorative by default.
struct ArtImage: View {
    let art: Art
    var mode: ArtMode = .fit
    var anchor: UnitPoint = .center

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.size
            let bounds = mode == .fill ? CGRect(origin: .zero, size: art.pixelSize) : art.alphaBounds
            let scales = scale(bounds: bounds, frame: frame)
            let drawWidth = art.pixelSize.width * scales.width
            let drawHeight = art.pixelSize.height * scales.height
            let offsetX = (frame.width - bounds.width * scales.width) * anchor.x - bounds.minX * scales.width
            let offsetY = (frame.height - bounds.height * scales.height) * anchor.y - bounds.minY * scales.height
            Image(art.rawValue)
                .resizable()
                .interpolation(.high)
                .frame(width: drawWidth, height: drawHeight)
                .offset(x: offsetX, y: offsetY)
                .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        }
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func scale(bounds: CGRect, frame: CGSize) -> CGSize {
        guard bounds.width > 0, bounds.height > 0 else { return CGSize(width: 1, height: 1) }
        let sx = frame.width / bounds.width
        let sy = frame.height / bounds.height
        switch mode {
        case .fit:
            let s = min(sx, sy)
            return CGSize(width: s, height: s)
        case .fill:
            let s = max(sx, sy)
            return CGSize(width: s, height: s)
        case .stretch:
            return CGSize(width: sx, height: sy)
        }
    }
}

/// Template UI icon from assets/ui (44 pt artboard, 2.3 pt stroke).
struct UIIcon: View {
    let name: String
    var size: CGFloat = 28
    var color: Color = Palette.ink

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .foregroundColor(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
