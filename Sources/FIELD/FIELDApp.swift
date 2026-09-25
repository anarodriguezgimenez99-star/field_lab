import SwiftUI
import SwiftData

@main
struct FIELDApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup("FIELD LAB") {
            ContentView(appModel: appModel)
                .environment(\.modelContext, appModel.container.mainContext)
                .tint(FieldPalette.accent)
        }
        .preferredColorScheme(.dark)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Quick Capture") {
                    appModel.presentCapture()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Focus Search") {
                    appModel.selectedRoute = .lab
                }
                .keyboardShortcut("f", modifiers: [.command])
            }
        }

        #if os(macOS)
        MenuBarExtra("FIELD LAB", systemImage: "square.grid.2x2") {
            MenuBarContent(appModel: appModel)
        }
        #endif
    }
}
