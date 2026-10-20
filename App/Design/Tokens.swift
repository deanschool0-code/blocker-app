import SwiftUI

/// Design tokens. Components use these, never raw colours or sizes.
/// Colours live in Assets.xcassets with light and dark values.
enum Palette {
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let surfaceRaised = Color("SurfaceRaised")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let border = Color("Border")
    static let accent = Color("Accent")
    static let accentSoft = Color("AccentSoft")
    static let onAccent = Color("OnAccent")
    static let calm = Color("Calm")
    static let calmSoft = Color("CalmSoft")
    static let onCalm = Color("OnCalm")
    static let clean = Color("Clean")
    static let cleanSoft = Color("CleanSoft")
    static let slip = Color("Slip")
    static let slipSoft = Color("SlipSoft")
    static let warning = Color("Warning")
}

enum Space {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let huge: CGFloat = 48
}

enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 14
    static let l: CGFloat = 22
    static let xl: CGFloat = 32
}

enum Size {
    static let maxReadable: CGFloat = 560
    static let panicButton: CGFloat = 64
    static let breathingRing: CGFloat = 220
    static let dot: CGFloat = 54
    static let calendarCell: CGFloat = 40
    static let reasonPhoto: CGFloat = 260
    static let icon: CGFloat = 22
    static let border: CGFloat = 1
    static let focusRing: CGFloat = 2
    static let badge: CGFloat = 28
    static let iconColumn: CGFloat = 32
    static let symbolHero: CGFloat = 60
    static let gameArea: CGFloat = 280
    static let sheetWidth: CGFloat = 480
    static let sheetHeight: CGFloat = 420
    static let coverWidth: CGFloat = 520
    static let coverHeight: CGFloat = 620
}

enum Typo {
    static let hero = Font.system(size: 76, weight: .bold, design: .rounded)
    static let title = Font.system(.title, design: .rounded).weight(.bold)
    static let title2 = Font.system(.title2, design: .rounded).weight(.semibold)
    static let headline = Font.headline
    static let body = Font.body
    static let callout = Font.callout
    static let caption = Font.caption
    static let mono = Font.system(.footnote, design: .monospaced)
}

enum Motion {
    static let quick = Animation.easeOut(duration: 0.2)
    static let gentle = Animation.easeInOut(duration: 0.35)
}
