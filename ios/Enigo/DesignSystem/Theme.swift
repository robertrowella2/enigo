import SwiftUI
import CoreText

// Design tokens transcribed from design_handoff_enigo/README.md. Both themes
// are first-class (not inversions of each other) — dark is gold-on-navy,
// light is navy-on-ivory, and gold recedes to accents only in light mode.
enum EnigoColor {
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0B1D3A) : Color(hex: 0xEFE9D8)
    }
    static func pageSurround(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x08152B) : Color(hex: 0xDED5BD)
    }
    static func sheetBase(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0F2547) : Color(hex: 0xEFE9D8)
    }
    static func dominant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xD4AF37) : Color(hex: 0x0B1D3A)
    }
    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xD4AF37) : Color(hex: 0xA8861C)
    }
    static func body(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xE8D9A8) : Color(hex: 0x0B1D3A)
    }
    static func danger(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xE4A08C) : Color(hex: 0x9E3A1C)
    }
    /// Primary button: gold fill/navy label in dark, navy fill/ivory label in light.
    static func primaryFill(_ scheme: ColorScheme) -> Color { dominant(scheme) }
    static func primaryLabel(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0B1D3A) : Color(hex: 0xEFE9D8)
    }
    static func fgAlpha(_ scheme: ColorScheme, _ alpha: Double) -> Color {
        body(scheme).opacity(alpha)
    }
    static func goldAlpha(_ scheme: ColorScheme, _ alpha: Double) -> Color {
        accent(scheme).opacity(alpha)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Typography (Fraunces for headings/answers, Inter for body/UI/chat)

enum EnigoFont {
    private static let frauncesName = "Fraunces"
    private static let interName = "Inter"

    /// Weight axis on the variable font. Fraunces/Inter ship as single
    /// variable-font files, so a specific weight is selected via the `wght`
    /// axis rather than a distinct PostScript name.
    static func fraunces(size: CGFloat, weight: CGFloat = 500) -> Font {
        variableFont(named: frauncesName, size: size, weight: weight)
    }
    static func inter(size: CGFloat, weight: CGFloat = 400) -> Font {
        variableFont(named: interName, size: size, weight: weight)
    }

    private static func variableFont(named name: String, size: CGFloat, weight: CGFloat) -> Font {
        let descriptor = UIFontDescriptor(name: name, size: size)
        let variedDescriptor = descriptor.addingAttributes([
            .init(rawValue: "NSCTFontVariationAttribute"): ["wght": weight]
        ])
        return Font(UIFont(descriptor: variedDescriptor, size: size))
    }

    // Named roles from the token table.
    static let screenTitle = fraunces(size: 31, weight: 600)
    static let questionText = fraunces(size: 28, weight: 600)
    static let matchUsername = fraunces(size: 34, weight: 600)
    static let answerOption = fraunces(size: 17, weight: 500)
    static let chipLabel = fraunces(size: 15, weight: 500)
    static let body = inter(size: 14.5, weight: 400)
    static let chatMessage = inter(size: 15, weight: 400)
    static let eyebrow = inter(size: 11, weight: 500)
    static let meta = inter(size: 12, weight: 400)
}

// MARK: - Shape & spacing

enum EnigoRadius {
    static let control: CGFloat = 14
    static let input: CGFloat = 16
    static let card: CGFloat = 18
    static let photoWell: CGFloat = 22
    static let sheetTop: CGFloat = 26
    static let pill: CGFloat = 99
}

enum EnigoSpacing {
    static let screenHorizontal: CGFloat = 28
    static let listHorizontal: CGFloat = 22
    static let stackGap: CGFloat = 20
    static let tightGap: CGFloat = 9
}

enum EnigoMotion {
    static let rise = Animation.easeOut(duration: 0.4)
    static let breathe = Animation.easeInOut(duration: 3.5).repeatForever(autoreverses: true)
    static let tapAdvance = Animation.easeInOut(duration: 0.24)
}

/// Registers the bundled Fraunces/Inter variable fonts. UIAppFonts in
/// Info.plist already causes UIKit to load them at launch; this is a
/// belt-and-suspenders manual registration used by SwiftUI previews.
enum EnigoFontLoader {
    static func registerIfNeeded() {
        for name in ["Fraunces", "Inter"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
