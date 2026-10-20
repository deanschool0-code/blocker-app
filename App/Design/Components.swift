import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.accent
    var onTint: Color = Palette.onAccent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.m)
            .padding(.horizontal, Space.l)
            .foregroundStyle(onTint)
            .background(tint.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: Radius.m))
            .contentShape(RoundedRectangle(cornerRadius: Radius.m))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.m)
            .padding(.horizontal, Space.l)
            .foregroundStyle(Palette.accent)
            .background(Palette.accentSoft.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: Radius.m))
            .contentShape(RoundedRectangle(cornerRadius: Radius.m))
    }
}

/// The big "I need a minute" button.
struct PanicButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                Image(systemName: "wind").font(Typo.title2)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("I need a minute").font(Typo.title2)
                    Text("Breathe, reset, ride it out").font(Typo.callout).opacity(0.85)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(Typo.headline)
            }
            .padding(Space.l)
            .frame(minHeight: Size.panicButton)
            .foregroundStyle(Palette.onCalm)
            .background(Palette.calm, in: RoundedRectangle(cornerRadius: Radius.l))
            .contentShape(RoundedRectangle(cornerRadius: Radius.l))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("I need a minute. Opens a short breathing and distraction exercise.")
    }
}

// MARK: - Surfaces

struct Card<Content: View>: View {
    var padding: CGFloat = Space.l
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.l))
            .overlay(RoundedRectangle(cornerRadius: Radius.l).strokeBorder(Palette.border, lineWidth: Size.border))
    }
}

struct StatusPill: View {
    let state: ProtectionState
    var body: some View {
        Label(state.title, systemImage: state.symbol)
            .font(Typo.callout.weight(.semibold))
            .padding(.vertical, Space.xs)
            .padding(.horizontal, Space.m)
            .foregroundStyle(state.foreground)
            .background(state.background, in: Capsule())
            .accessibilityLabel("Protection: \(state.title)")
    }
}

extension ProtectionState {
    var title: String {
        switch self {
        case .on: "Protected"
        case .partial: "Partly protected"
        case .off: "Blocker is off"
        case .unknown: "Checking…"
        }
    }
    var symbol: String {
        switch self {
        case .on: "checkmark.shield.fill"
        case .partial: "exclamationmark.shield.fill"
        case .off: "shield.slash.fill"
        case .unknown: "shield"
        }
    }
    var foreground: Color {
        switch self {
        case .on: Palette.clean
        case .partial, .off: Palette.warning
        case .unknown: Palette.textSecondary
        }
    }
    var background: Color {
        switch self {
        case .on: Palette.cleanSoft
        case .partial, .off: Palette.slipSoft
        case .unknown: Palette.surfaceRaised
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(value).font(Typo.title).foregroundStyle(Palette.textPrimary).monospacedDigit()
            Text(label).font(Typo.caption).foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.m)
        .background(Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m))
        .accessibilityElement(children: .combine)
    }
}

struct Banner: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warning)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).font(Typo.headline).foregroundStyle(Palette.textPrimary)
                Text(message).font(Typo.callout).foregroundStyle(Palette.textSecondary)
                Button(actionTitle, action: action)
                    .font(Typo.callout.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.l)
        .background(Palette.slipSoft, in: RoundedRectangle(cornerRadius: Radius.l))
    }
}

/// Selectable chip used in the panic plan step.
struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typo.callout.weight(.medium))
                .padding(.vertical, Space.s)
                .padding(.horizontal, Space.m)
                .frame(maxWidth: .infinity)
                .foregroundStyle(selected ? Palette.onAccent : Palette.textPrimary)
                .background(selected ? Palette.accent : Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(Typo.headline).foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Screen background + readable width, used by every scrolling screen.
struct ScreenScroll<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) { content }
                .frame(maxWidth: Size.maxReadable)
                .padding(Space.l)
                .frame(maxWidth: .infinity)
        }
        .background(Palette.background.ignoresSafeArea())
    }
}
