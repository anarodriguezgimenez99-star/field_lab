import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#endif

@main
struct FIELDApp: App {
    @StateObject private var appModel = AppModel()

    init() {
        #if os(macOS)
#if SWIFT_PACKAGE
        let logoURL = Bundle.module.url(forResource: "FIELDLogo", withExtension: "png")
#else
        let logoURL = Bundle.main.url(forResource: "FIELDLogo", withExtension: "png")
#endif
        if let logoURL,
           let appIcon = NSImage(contentsOf: logoURL) {
            NSApplication.shared.applicationIconImage = appIcon
        }
        #endif
    }

    var body: some Scene {
        WindowGroup("FIELD LAB") {
            ContentView(appModel: appModel)
                .environment(\.modelContext, appModel.container.mainContext)
                .environment(\.locale, appModel.language.locale)
                .tint(FieldPalette.accent)
                .preferredColorScheme(.dark)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.text("Quick Capture")) {
                    appModel.presentCapture()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button(L10n.text("Focus Search")) {
                    appModel.selectedRoute = .lab
                }
                .keyboardShortcut("f", modifiers: [.command])
            }
        }

        #if os(macOS)
        MenuBarExtra("FIELD LAB", systemImage: "square.grid.2x2") {
            MenuBarContent(appModel: appModel)
                .environment(\.locale, appModel.language.locale)
        }
        #endif
    }
}
