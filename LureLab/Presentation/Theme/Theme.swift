import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Design tokens from docs/02_DESIGN_SYSTEM and the screen SVGs.
enum Palette {
    static let background = Color(hex: 0xF0FCFF)
    static let panel = Color.white
    static let ink = Color(hex: 0x102653)
    static let secondary = Color(hex: 0x526D87)
    static let sea = Color(hex: 0x008DCE)
    static let seaShadow = Color(hex: 0x006DA9)
    static let deepOcean = Color(hex: 0x073D68)
    static let turquoise = Color(hex: 0x25D1DE)
    static let gold = Color(hex: 0xFFC94A)
    static let coral = Color(hex: 0xFF7449)
    static let success = Color(hex: 0x167B61)
    static let error = Color(hex: 0xB93436)

    static let cardShadow = Color(hex: 0xD9ECF0)
    static let cardStroke = Color(hex: 0xE0EEF1)
    static let fieldStroke = Color(hex: 0xD6E7ED)
    static let fieldErrorFill = Color(hex: 0xFFF5F3)
    static let chip = Color(hex: 0xE0EFF4)
    static let draftChip = Color(hex: 0xDDEFF5)
    static let photoChip = Color(hex: 0xDDF1FA)
    static let statusGood = Color(hex: 0xDFF5EB)
    static let statusNeutral = Color(hex: 0xE3EDF5)
    static let secondaryButton = Color(hex: 0xF0FAFE)
    static let secondaryButtonStroke = Color(hex: 0xAACAD8)
    static let disabledButton = Color(hex: 0xDEE7E8)
    static let disabledButtonStroke = Color(hex: 0xB4C5CF)
    static let toggleOff = Color(hex: 0x9CB2BE)
    static let dim = Color(hex: 0x102653, opacity: 0.42)
    static let inputFill = Color(hex: 0xF2F7FA)
    static let compareGold = Color(hex: 0xFFBF43)

    static let onboardingBody = Color(hex: 0xD8F2FB)
    static let dotInactive = Color(hex: 0x6086A0)
    static let luckyLink = Color(hex: 0xD5F8FF)
    static let luckyLinkStrong = Color(hex: 0xC5F6FF)
    static let collectionCaption = Color(hex: 0xE0F9FF)
    static let collectionSubtitle = Color(hex: 0xE4F5FF)
    static let madeItYours = Color(hex: 0xFFE27B)
    static let signShadow = Color(hex: 0x714013)
    static let signStroke = Color(hex: 0xFFF2AE)
    static let reelCellStroke = Color(hex: 0x60CADD)
    static let reelDivider = Color(hex: 0xDDAA43)
    static let reelTint = Color(hex: 0x064570)
    static let reelStreak = Color(hex: 0xB9F5FF)

    static let goldGradient = LinearGradient(
        stops: [.init(color: Color(hex: 0xFFF78F), location: 0),
                .init(color: Color(hex: 0xFFDD37), location: 0.45),
                .init(color: Color(hex: 0xFFB719), location: 1)],
        startPoint: .top, endPoint: .bottom)
}

/// Mockups are typeset in Avenir Next (bundled with iOS). Ascender = 1.0 × size, line height = 1.366 × size.
enum AvenirWeight {
    case medium, demiBold, bold, heavy

    var fontName: String {
        switch self {
        case .medium: return "AvenirNext-Medium"
        case .demiBold: return "AvenirNext-DemiBold"
        case .bold: return "AvenirNext-Bold"
        case .heavy: return "AvenirNext-Heavy"
        }
    }

    /// Maps SVG font-weight values (500/600/700/800/900).
    init(svg weight: Int) {
        switch weight {
        case ..<550: self = .medium
        case ..<650: self = .demiBold
        case ..<750: self = .bold
        default: self = .heavy
        }
    }
}

extension Font {
    /// Dynamic-Type aware Avenir Next.
    static func avenir(_ size: CGFloat, _ weight: AvenirWeight) -> Font {
        .custom(weight.fontName, size: size, relativeTo: textStyle(for: size))
    }

    /// Fixed-size Avenir Next for decorative lettering baked into art compositions.
    static func avenirFixed(_ size: CGFloat, _ weight: AvenirWeight) -> Font {
        .custom(weight.fontName, fixedSize: size)
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 30...: return .largeTitle
        case 26..<30: return .title
        case 22..<26: return .title2
        case 20..<22: return .title3
        case 17..<20: return .body
        case 16..<17: return .callout
        case 15..<16: return .subheadline
        case 13..<15: return .footnote
        case 12..<13: return .caption
        default: return .caption2
        }
    }
}

/// Converts mockup geometry. Mockup content is laid out for a 47 pt status area (390 × 844 baseline).
enum Metrics {
    static let mockupSafeTop: CGFloat = 47
    static let mockupSafeBottom: CGFloat = 34
    static let margin: CGFloat = 20
    static let fieldRadius: CGFloat = 14
    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 26

}

extension View {
    /// Places text at an exact SVG baseline offset inside an absolute composition.
    func mockupFrame(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        frame(width: width, height: height).position(x: x + width / 2, y: y + height / 2)
    }
}
