import UIKit

extension UIColor {
    convenience init(keyboardHex value: UInt32) {
        self.init(red: CGFloat((value >> 16) & 255) / 255,
                  green: CGFloat((value >> 8) & 255) / 255,
                  blue: CGFloat(value & 255) / 255, alpha: 1)
    }
}

struct KeyboardPalette {
    let colors: KeyboardColors
    var font: LegendFont = .system
    var shape: KeycapShape?
    /// Key Scratch's native-feeling design leaves the original themes available.
    var iosAppearance = false
    var darkAppearance = false
    var background: UIColor {
        guard iosAppearance else { return UIColor(keyboardHex: colors.background) }
        return UIColor(keyboardHex: darkAppearance ? 0x25262A : 0xD1D5DD)
    }
    var key: UIColor {
        guard iosAppearance else { return UIColor(keyboardHex: colors.key) }
        return UIColor(keyboardHex: darkAppearance ? 0x62636B : 0xFFFFFF)
    }
    var control: UIColor {
        guard iosAppearance else { return UIColor(keyboardHex: colors.control) }
        return UIColor(keyboardHex: darkAppearance ? 0x45464D : 0xACB5C2)
    }
    var text: UIColor {
        guard iosAppearance else { return UIColor(keyboardHex: colors.text) }
        return UIColor(keyboardHex: darkAppearance ? 0xFFFFFF : 0x20232B)
    }
    var secondary: UIColor {
        guard iosAppearance else { return UIColor(keyboardHex: colors.secondary) }
        return UIColor(keyboardHex: darkAppearance ? 0xC4C4CA : 0x5D6470)
    }
    var border: UIColor {
        guard iosAppearance else { return UIColor(keyboardHex: colors.border) }
        return UIColor(keyboardHex: darkAppearance ? 0x34343A : 0xC8CDD6)
    }
    var accent: UIColor {
        guard iosAppearance else { return UIColor(keyboardHex: colors.accent) }
        return .systemBlue
    }
    var controlText: UIColor {
        guard iosAppearance else { return colors.controlText.map(UIColor.init(keyboardHex:)) ?? text }
        return text
    }

    /// A legend font in the colorway's typeface.
    func legend(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let design: UIFontDescriptor.SystemDesign? = switch font {
        case .system: nil
        case .rounded: .rounded
        case .mono: .monospaced
        case .serif: .serif
        }
        guard let design, let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
    var borderWidth: CGFloat {
        if colors.highContrast { return 1.5 }
        if iosAppearance { return 0 }
        return switch shape { case .flat: 0; case .outlined: 1.2; default: 0.5 }
    }
    var highlightOpacity: CGFloat { colors.highContrast ? 0.12 : (iosAppearance ? 0.08 : 0.16) }
}
