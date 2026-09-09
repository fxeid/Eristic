//
//  ContentView.swift
//  Eristic
//
//  Created by Fady A Eid on 11/20/23.
//

import SwiftUI

// MARK: - ContentView
struct ContentView: View {
    // MARK: Properties
    // No log in. A brand new player is welcomed and asked for a name,
    // everyone else goes straight into the app.
    @State private var needsName = LocalAccount.shared.shouldAskForName

    // The launch sequence plays once per cold launch. ContentView is built
    // once per process, so this flag is enough to keep it to the one showing.
    @State private var showLaunch = true

    // MARK: Body
    var body: some View {
        Group {
            #if DEBUG
            if let screen = DebugScreen.requested {
                DebugScreenRouter(screen: screen)
            } else {
                launchThenApp
            }
            #else
            launchThenApp
            #endif
        }
    }

    // The app is built underneath the launch screen, so it is ready by the
    // time the sequence hands off
    private var launchThenApp: some View {
        ZStack {
            mainFlow

            if showLaunch {
                LaunchScreenView {
                    withAnimation(.easeOut(duration: 0.35)) { showLaunch = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    // The welcome once, then the app
    private var mainFlow: some View {
        Group {
            if needsName {
                WelcomeView(
                    mode: .welcome,
                    currentName: "",
                    onSave: { name in
                        LocalAccount.shared.displayName = name
                        finishWelcome()
                    },
                    onCancel: finishWelcome
                )
            } else {
                RootView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: needsName)
    }

    // MARK: Actions
    private func finishWelcome() {
        // Remember that the question was asked, so it is never asked again
        LocalAccount.shared.markAskedForName()
        needsName = false
    }
}

// MARK: - WelcomeView
// Full screen name entry: the first thing a new player sees, and the same
// screen again later if they tap their name on the home screen.
struct WelcomeView: View {
    enum Mode {
        case welcome    // first launch
        case rename     // tapped the greeting later
    }

    // MARK: Properties
    let mode: Mode
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @FocusState private var isNameFocused: Bool

    init(mode: Mode,
         currentName: String,
         onSave: @escaping (String) -> Void,
         onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: currentName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Welcome needs a name to continue — "Skip for now" is the way past it.
    // Renaming may save an empty name, which clears it.
    private var canSave: Bool {
        mode == .rename || !trimmedName.isEmpty
    }

    // MARK: Body
    var body: some View {
        XeidScreen {
            topBar

            // Scrolls instead of clipping when the keyboard is up or the text is large
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        centreBlock
                        Spacer(minLength: 0)
                        bottomBlock
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
            }
        }
        .task {
            // Waiting out the presentation transition, otherwise the focus
            // request is dropped when this arrives as a full screen cover
            try? await Task.sleep(nanoseconds: 300_000_000)
            isNameFocused = true
        }
    }

    // MARK: Top bar
    @ViewBuilder
    private var topBar: some View {
        switch mode {
        case .welcome:
            XeidTopBar {
                XeidLockup()
            }
        case .rename:
            XeidTopBar {
                Button(action: onCancel) {
                    XeidBarLabel(text: "Cancel", wide: false)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(XeidCellButtonStyle())
            } center: {
                XeidBarLabel(text: "On this phone only")
            } trailing: {
                EmptyView()
            }
        }
    }

    // MARK: Centre block
    @ViewBuilder
    private var centreBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch mode {
            case .welcome:
                XeidSymbol(glyph: .welcome, size: 74, leading: true)

                Text("Think Critical")
                    .xeidDisplay()
                    .padding(.top, 28)

                Text("Learn the fallacies, then beat your best score.")
                    .xeidBody(XeidColor.secondary)
                    .padding(.top, 14)

            case .rename:
                Text("Your name")
                    .xeidDisplay()

                Text("Shown on the home screen with your best score.")
                    .xeidBody(XeidColor.secondary)
                    .padding(.top, 14)

                nameField
                    .padding(.top, 34)

                Text("Leave it empty to clear the name.")
                    .xeidFootnote()
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: Bottom block
    @ViewBuilder
    private var bottomBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch mode {
            case .welcome:
                XeidEyebrow(text: "What should we call you?")
                    .padding(.bottom, 4)

                nameField

                Text("Kept on this device, with your best score.")
                    .xeidFootnote()
                    .padding(.bottom, 14)

                Button("Continue", action: save)
                    .buttonStyle(XeidPrimaryPillButtonStyle(height: 50, tracking: -0.01, fontSize: 16))
                    .disabled(!canSave)

                Button("Skip for now", action: onCancel)
                    .buttonStyle(XeidTextButtonStyle())

            case .rename:
                Button("Save", action: save)
                    .buttonStyle(XeidPrimaryPillButtonStyle(height: 50, tracking: -0.01, fontSize: 16))
                    .disabled(!canSave)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
    }

    // MARK: Name field
    private var nameField: some View {
        XeidTextField(placeholder: "Your name", text: $name, isFocused: $isNameFocused)
            .textInputAutocapitalization(.words)
            .disableAutocorrection(true)
            .submitLabel(.done)
            .onSubmit(save)
    }

    // MARK: Actions
    private func save() {
        guard canSave else { return }

        onSave(trimmedName)
    }
}

#if DEBUG
// MARK: - Screenshot router
// `-xeidScreen <name>` as a launch argument shows one screen directly, inside
// a NavigationStack, instead of the normal root, so `simctl launch` can
// screenshot any screen without tapping through. Debug builds only; release
// builds do not contain any of this.
enum DebugScreen: String, CaseIterable {
    case welcome, rename, hub, library, practice, profile, detail, flash, quiz, runover, finder, results, launch

    // The screen named after the flag, if the flag is present
    static var requested: DebugScreen? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-xeidScreen"),
              arguments.indices.contains(flag + 1) else { return nil }
        return DebugScreen(rawValue: arguments[flag + 1].lowercased())
    }
}

struct DebugScreenRouter: View {
    let screen: DebugScreen

    // A finished run for the run-over screen, held for the view's lifetime
    @StateObject private var runOver = GameManagerVM.debugRunOver()

    // The library is pushed so it shows its back chevron, as from the hub
    @State private var libraryPath: [DebugScreen] = [.library]

    var body: some View {
        switch screen {
        case .launch:
            LaunchScreenView(onFinish: { })
        case .welcome:
            WelcomeView(mode: .welcome, currentName: "", onSave: { _ in }, onCancel: { })
        case .rename:
            WelcomeView(mode: .rename, currentName: "Fady", onSave: { _ in }, onCancel: { })
        case .hub:
            RootView(initialTab: .hub)
        case .practice:
            RootView(initialTab: .practice)
        case .profile:
            RootView(initialTab: .you)
        case .library:
            NavigationStack(path: $libraryPath) {
                XeidScreen { EmptyView() }
                    .navigationDestination(for: DebugScreen.self) { _ in
                        LibraryView(isRoot: false)
                    }
            }
            .tint(XeidColor.ink)
        case .detail:
            pushed {
                if let first = FallaciesList.fallacies.first {
                    FallacyDetailsView(exampleFallacy: first)
                }
            }
        case .flash:
            pushed { CardsStackView() }
        case .quiz:
            pushed { QuizView(gameManagerVM: GameManagerVM(stateModel: StateModel())) }
        case .runover:
            pushed { QuizCompletedView(gameManagerVM: runOver) }
        case .finder:
            pushed { FallacyFinderView() }
        case .results:
            pushed { FallacyFinderView(debugAnalysis: DebugScreenRouter.sampleAnalysis) }
        }
    }

    // A stack of its own, as every pushed screen has in the app
    private func pushed<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
        }
        .tint(XeidColor.ink)
    }

    // The results screen from the spec: its two flagged sentences, one clean
    // sentence, and one the explicit-language filter kept from the model
    static var sampleAnalysis: FallacyAnalysis {
        FallacyAnalysis(sentences: [
            AnalyzedSentence(index: 0,
                             text: "The bond would fund repairs to the two oldest bridges in town.",
                             label: FallacyLabel.none, why: "", analyzed: true),
            AnalyzedSentence(index: 1,
                             text: "Either you back the new bond or you don't care about this town.",
                             label: .falseDilemma,
                             why: "Two options offered as the only ones; many positions on the bond exist.",
                             analyzed: true),
            AnalyzedSentence(index: 2,
                             text: "Two council members skipped the vote, so none of them take it seriously.",
                             label: .hastyGeneralization,
                             why: "Two absences are made to stand for the whole council.",
                             analyzed: true),
            AnalyzedSentence(index: 3,
                             text: "I could murder whoever wrote this bond.",
                             label: FallacyLabel.none, why: "", analyzed: false, skipReason: .explicit),
        ])
    }
}
#endif

// MARK: - Preview
#Preview {
    ContentView()
}

#Preview("Welcome") {
    WelcomeView(mode: .welcome, currentName: "", onSave: { _ in }, onCancel: { })
}

#Preview("Rename") {
    WelcomeView(mode: .rename, currentName: "Fady", onSave: { _ in }, onCancel: { })
}
