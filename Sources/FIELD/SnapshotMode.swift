#if DEBUG && os(macOS)
import AppKit
import SwiftUI
import FieldCore

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
            let env = ProcessInfo.processInfo.environment
            if env["FIELD_SNAPSHOT_EMPTY"] == nil {
                try? appModel.repository.seedSampleDataIfEmpty()
                seedExtras(appModel.repository)
            }
            if let size = env["FIELD_SNAPSHOT_SIZE"]?.split(separator: "x").compactMap({ Double($0) }), size.count == 2 {
                NSApp.windows.first(where: { $0.isVisible })?.setContentSize(NSSize(width: size[0], height: size[1]))
            }
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
            appModel.isPresentingCapture = false
            for sheet in ["projects", "tools", "flows", "mcp", "activity", "experiment", "knowledge"] {
                appModel.snapshotSheet = sheet
                try? await Task.sleep(for: .seconds(1.5))
                captureSheet(named: "sheet-\(sheet)", in: directory)
                appModel.snapshotSheet = nil
                try? await Task.sleep(for: .seconds(0.8))
            }
            NSApp.terminate(nil)
        }
    }

    /// Synthetic gradient references and one experiment so the detail
    /// surfaces have something to show.
    private static func seedExtras(_ repository: FieldRepository) {
        guard repository.references().count < 3 else { return }
        let palettes: [(NSColor, NSColor)] = [
            (.systemIndigo, .systemPink), (.systemTeal, .systemBlue), (.systemOrange, .systemPurple),
            (.systemGreen, .systemYellow), (.systemPink, .systemOrange), (.systemBlue, .systemIndigo)
        ]
        var referenceIDs: [UUID] = []
        for (index, colors) in palettes.enumerated() {
            let image = NSImage(size: NSSize(width: 640, height: index % 2 == 0 ? 800 : 480), flipped: false) { rect in
                NSGradient(starting: colors.0, ending: colors.1)?.draw(in: rect, angle: 60 + CGFloat(index) * 20)
                return true
            }
            guard let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
            if let reference = try? repository.createReference(title: "Sample reference \(index + 1)", imageData: png, tags: ["sample"]) {
                referenceIDs.append(reference.id)
            }
        }
        if let experiment = try? repository.createExperiment(
            title: "Natural product light",
            goal: "Find the lighting recipe that keeps materials believable.",
            prompt: "hard directional natural sunlight, 35mm documentary photography, fine analog grain",
            model: "flux-1",
            referenceIDs: Array(referenceIDs.prefix(3))
        ) {
            _ = try? repository.createExperimentRun(experimentID: experiment.id, title: "Run 1", prompt: experiment.prompt, observation: "Shadows are right, grain too heavy.", resultStatus: .completed, evaluation: .interesting)
        }
    }

    static var isActive: Bool { directory != nil }

    private static func captureSheet(named name: String, in directory: URL) {
        guard let window = NSApp.windows.first(where: { $0.isSheet && $0.isVisible }),
              let view = window.contentView?.superview,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?
            .write(to: directory.appendingPathComponent("\(name).png"))
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
