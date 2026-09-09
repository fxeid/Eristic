//
//  XeidChrome.swift
//  Eristic
//
//  Created by Fady A Eid on 9/3/26.
//

import SwiftUI

// The shared chrome of the redesign: screen container, top bar, back chevron,
// tab bar, eyebrows, gate cells, avatar, progress bar, text field and the
// three pill button styles. Screens compose these; they never restyle them.

// MARK: - Root tabs
enum RootTab: CaseIterable {
    case hub, library, practice, you

    var title: String {
        switch self {
        case .hub: return "Hub"
        case .library: return "Library"
        case .practice: return "Practice"
        case .you: return "You"
        }
    }
}

// MARK: - Press state
// Presses shift colour only. Button styles hand the pressed flag to their
// label through the environment so the label can pick its colours.
private struct XeidPressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var xeidPressed: Bool {
        get { self[XeidPressedKey.self] }
        set { self[XeidPressedKey.self] = newValue }
    }
}

// A style that draws nothing itself: cells, rows, tab items and bar labels
// read `xeidPressed` and shift their own colours. No dimming, no opacity.
struct XeidCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.xeidPressed, configuration.isPressed)
    }
}

// MARK: - Screen
// Surface background filling the screen, content stacked from the top.
// Every screen hides the native navigation bar; the top bar is ours.
struct XeidScreen<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(XeidColor.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Top bar
// 44pt tall, 22pt side padding. Leading and trailing sit at the edges; the
// centre slot is truly centred. Pass EmptyView for a slot you do not use.
struct XeidTopBar<Leading: View, Center: View, Trailing: View>: View {
    private let leading: Leading
    private let center: Center
    private let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading,
         @ViewBuilder center: () -> Center,
         @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                leading
                Spacer(minLength: 0)
                trailing
            }
            center
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .padding(.horizontal, 22)
    }
}

extension XeidTopBar where Center == EmptyView {
    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.init(leading: leading, center: { EmptyView() }, trailing: trailing)
    }
}

extension XeidTopBar where Center == EmptyView, Trailing == EmptyView {
    init(@ViewBuilder leading: () -> Leading) {
        self.init(leading: leading, center: { EmptyView() }, trailing: { EmptyView() })
    }
}

// MARK: - Lockup
// Neon-X 22pt, gap 10, "Think Critical" 15/300 secondary
struct XeidLockup: View {
    var body: some View {
        HStack(spacing: 10) {
            XeidNeonX(height: 22)
            Text("Think Critical")
                .font(XeidFont.inter(15, relativeTo: .subheadline))
                .tracking(-0.01 * 15)
                .foregroundColor(XeidColor.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Back chevron
// The hand-drawn chevron from the spec, not a XeidSymbol: a 6.5 x 15.8 stroke
// at 1.4pt with round caps and joins, sitting at (16, 13) inside a 44 x 44
// hit box. The box is pulled 14pt left so the ink lands 26pt from the screen
// edge inside a 22pt-padded top bar, exactly as drawn.
struct XeidChevron: View {
    @Environment(\.xeidPressed) private var pressed

    var body: some View {
        Path { path in
            let origin = CGPoint(x: 16, y: 13)
            path.move(to: CGPoint(x: origin.x + 8.5, y: origin.y + 1.6))
            path.addLine(to: CGPoint(x: origin.x + 2, y: origin.y + 9))
            path.addLine(to: CGPoint(x: origin.x + 8.5, y: origin.y + 16.4))
        }
        .stroke(pressed ? XeidColor.ink : XeidColor.secondary,
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .padding(.leading, -14)
    }
}

// Pops the current screen through the dismiss environment
struct XeidBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            XeidChevron()
        }
        .buttonStyle(XeidCellButtonStyle())
        .accessibilityLabel("Back")
    }
}

// MARK: - Bar label
// 12/400 uppercase. Wide (0.18em) for screen-title eyebrows, narrow (0.14em)
// for nav and meta. Actionable labels are ink; everything else secondary.
struct XeidBarLabel: View {
    let text: String
    var action: Bool = false
    var wide: Bool = true

    @Environment(\.xeidPressed) private var pressed

    private var color: Color {
        let resting = action ? XeidColor.ink : XeidColor.secondary
        let pressedColor = action ? XeidColor.secondary : XeidColor.ink
        return pressed ? pressedColor : resting
    }

    var body: some View {
        Text(text)
            .xeidEyebrow(color, wide: wide)
            .lineLimit(1)
            .fixedSize()
    }
}

// MARK: - Eyebrow
// Section label with an optional 5pt dot in front, gap 8
struct XeidEyebrow: View {
    let text: String
    var dot: Color? = nil
    var color: Color = XeidColor.ink
    var wide: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if let dot {
                XeidDot(color: dot)
            }
            Text(text)
                .xeidEyebrow(color, wide: wide)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Gate cell
// A 188pt white cell with 20pt padding: XeidSymbol 64 leading at the top,
// then a text block pinned to the bottom. Hairlines are opt-in per edge so a
// grid can collapse its borders. Rows of cells: put two in an HStack and give
// the HStack .fixedSize(horizontal: false, vertical: true) for equal heights;
// a single column wraps each cell in the same fixedSize.
struct XeidGateCell: View {
    let glyph: XeidGlyph
    let title: String
    let line: String
    let eyebrow: String
    var rightEdge: Bool = false
    var bottomEdge: Bool = false

    @Environment(\.xeidPressed) private var pressed

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            XeidSymbol(glyph: glyph, size: 64, leading: true)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .xeidCardTitle()
                Text(line)
                    .xeidSecondary(XeidColor.ink)
                    .padding(.top, 7)
                Text(eyebrow)
                    .xeidEyebrow(XeidColor.secondary, wide: false)
                    .padding(.top, 12)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 188, maxHeight: .infinity, alignment: .topLeading)
        .background(pressed ? XeidColor.surface : XeidColor.cell)
        .overlay(alignment: .trailing) {
            if rightEdge {
                Rectangle().fill(XeidColor.hairline).frame(width: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if bottomEdge {
                XeidHairline()
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Avatar
// 30pt: the first initial 14/300 secondary in a hairline capsule, or the
// speaker glyph in secondary (no rule, no border) when there is no name.
struct XeidAvatar: View {
    let name: String

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }

    var body: some View {
        Group {
            if initial.isEmpty {
                // Box 30 gives a 23pt light glyph; the drawn colour is
                // secondary, which is not a XeidSymbol tone, so the inline
                // glyph carries it here
                XeidInlineGlyph(glyph: .speaker, size: 23, color: XeidColor.secondary)
            } else {
                Text(initial)
                    .font(XeidFont.caption)
                    .foregroundColor(XeidColor.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8) // 14pt floors at 11.2, the HIG minimum
                    .overlay(Circle().strokeBorder(XeidColor.hairline, lineWidth: 1).frame(width: 30, height: 30))
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityLabel(initial.isEmpty ? "No name set" : name)
    }
}

// MARK: - Progress bar
// A hairline track with a full-strength fill, 3pt tall
struct XeidProgressBar: View {
    let fraction: Double
    var fill: Color = XeidColor.blue
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(XeidColor.hairline)
                Rectangle()
                    .fill(fill)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int((min(max(fraction, 0), 1) * 100).rounded())) percent")
    }
}

// MARK: - Text field
// 54pt, white, 18pt side padding, 19/300 ink, 1pt hairline. Focused: blue
// border plus a 3pt ring at 12% blue, the one tint the tokens allow.
// Keyboard behaviour (capitalisation, submit label, onSubmit) is applied by
// the caller; those modifiers reach the field through the environment.
struct XeidTextField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        let focused = isFocused.wrappedValue

        TextField("", text: $text)
            .focused(isFocused)
            .font(XeidFont.inter(19, relativeTo: .title3))
            .foregroundColor(XeidColor.ink)
            .tint(XeidColor.blue)
            .overlay(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(XeidFont.inter(19, relativeTo: .title3))
                        .foregroundColor(XeidColor.muted)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(XeidColor.cell)
            .overlay(Rectangle().strokeBorder(focused ? XeidColor.blue : XeidColor.hairline, lineWidth: 1))
            .background {
                if focused {
                    Rectangle()
                        .strokeBorder(XeidColor.blue.opacity(0.12), lineWidth: 3)
                        .padding(-3)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isFocused.wrappedValue = true }
            .accessibilityLabel(placeholder)
    }
}

// MARK: - Buttons
// The ink pill: white label 17/400 with 0.06em tracking, 52pt tall on app
// screens. Press shifts to blue; disabled drops to 0.4 opacity.
struct XeidPrimaryPillButtonStyle: ButtonStyle {
    var height: CGFloat = 52
    var tracking: CGFloat = 0.06
    var fontSize: CGFloat = 17

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(XeidFont.inter(fontSize, weight: .regular, relativeTo: .body))
            .tracking(tracking * fontSize)
            .foregroundColor(.white)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(configuration.isPressed ? XeidColor.blue : XeidColor.ink)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
    }
}

// The outline pill: 1pt hairline capsule, secondary label 17/400 0.06em.
// Press shifts label and border to ink.
struct XeidOutlinePillButtonStyle: ButtonStyle {
    var height: CGFloat = 52

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let color = configuration.isPressed ? XeidColor.ink : XeidColor.secondary
        configuration.label
            .font(XeidFont.inter(17, weight: .regular, relativeTo: .body))
            .tracking(0.06 * 17)
            .foregroundColor(color)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: height)
            .overlay(Capsule().strokeBorder(configuration.isPressed ? XeidColor.ink : XeidColor.hairline, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
    }
}

// Text only: secondary 16/400, 50pt tall, press shifts to ink
struct XeidTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(XeidFont.inter(16, weight: .regular, relativeTo: .body))
            .tracking(-0.01 * 16)
            .foregroundColor(configuration.isPressed ? XeidColor.ink : XeidColor.secondary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
    }
}

// MARK: - Tab bar
// 62pt: 1pt top hairline, 13pt top pad, four items of at least 44pt, 4pt
// bottom pad, sitting on the home-indicator inset. Each item is a 4pt dot
// over a 12/400 0.14em uppercase label. Active: blue dot, ink label.
// Inactive: muted dot, secondary label.
struct XeidTabBar: View {
    @Binding var selection: RootTab

    var body: some View {
        VStack(spacing: 0) {
            XeidHairline()
            HStack(spacing: 0) {
                ForEach(RootTab.allCases, id: \.self) { tab in
                    Button {
                        guard tab != selection else { return }
                        withAnimation(XeidMotion.standard) {
                            selection = tab
                        }
                    } label: {
                        XeidTabItem(title: tab.title, active: tab == selection)
                    }
                    .buttonStyle(XeidCellButtonStyle())
                    .accessibilityAddTraits(tab == selection ? [.isSelected] : [])
                }
            }
            .padding(.top, 13)
            .padding(.bottom, 4)
        }
        .background(XeidColor.surface.ignoresSafeArea(edges: .bottom))
    }
}

private struct XeidTabItem: View {
    let title: String
    let active: Bool

    @Environment(\.xeidPressed) private var pressed

    var body: some View {
        VStack(spacing: 8) {
            XeidDot(color: active ? XeidColor.blue : XeidColor.muted, size: 4)
            Text(title)
                .xeidEyebrow(active || pressed ? XeidColor.ink : XeidColor.secondary, wide: false)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview
#Preview("Chrome") {
    struct ChromePreview: View {
        @State private var tab: RootTab = .hub
        @State private var name = ""
        @FocusState private var focused: Bool

        var body: some View {
            XeidScreen {
                XeidTopBar {
                    XeidLockup()
                } trailing: {
                    XeidAvatar(name: "Fady")
                }
                XeidTopBar {
                    XeidBackButton()
                } center: {
                    XeidBarLabel(text: "07 / 60", wide: false)
                } trailing: {
                    XeidBarLabel(text: "Shuffle", action: true, wide: false)
                }
                VStack(alignment: .leading, spacing: 18) {
                    XeidEyebrow(text: "Final score", dot: XeidColor.blue)
                    XeidTextField(placeholder: "Your name", text: $name, isFocused: $focused)
                    XeidProgressBar(fraction: 0.54)
                    Button("Play again") {}.buttonStyle(XeidPrimaryPillButtonStyle())
                    Button("Drill the two you missed") {}.buttonStyle(XeidOutlinePillButtonStyle())
                    Button("Skip for now") {}.buttonStyle(XeidTextButtonStyle())
                }
                .padding(24)
                HStack(spacing: 0) {
                    XeidGateCell(glyph: .flash, title: "Flash", line: "Sixty arguments. Sixty tells.", eyebrow: "07 / 60 today", rightEdge: true, bottomEdge: true)
                    XeidGateCell(glyph: .quiz, title: "Quiz", line: "Sixty seconds. Three lives.", eyebrow: "Best 14", bottomEdge: true)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer()
                XeidTabBar(selection: $tab)
            }
        }
    }
    return ChromePreview()
}
