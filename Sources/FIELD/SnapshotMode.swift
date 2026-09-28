#if DEBUG && os(macOS)
import AppKit
import SwiftUI

/// Development-only: set `FIELD_SNAPSHOT_DIR` to seed sample data, render each
/// primary route of the window to a PNG and quit. Uses the view's own
/// backing store, so it needs no Screen Recording permission.
@MainActor
enum SnapshotMode {
    private static var started = false

    static var directory: URL? {
        ProcessInfo.processInfo.environment["FIELD_SNAPSHOT_DIR"]
            .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
    }

    static func runIfRequested(appModel: AppModel) {
        guard let directory, !started else { return }
        started = true
        Task { @MainActor in
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? appModel.repository.seedSampleDataIfEmpty()
            appModel.refresh()
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.isVisible })?.makeKeyAndOrderFront(nil)
            try? await Task.sleep(for: .seconds(2))
            for route in [FieldRoute.lab, .collect, .learn, .settings] {
                appModel.selectedRoute = route
                try? await Task.sleep(for: .seconds(1.5))
                capture(named: route.rawValue, in: directory)
            }
            appModel.selectedRoute = .lab
            appModel.presentCapture()
            try? await Task.sleep(for: .seconds(1))
            capture(named: "capture", in: directory)
            NSApp.terminate(nil)
        }
    }

    private static func capture(named name: String, in directory: URL) {
        guard let view = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil })?.contentView?.superview,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?
            .write(to: directory.appendingPathComponent("\(name).png"))
    }
}
#endif
