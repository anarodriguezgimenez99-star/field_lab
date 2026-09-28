import Foundation
import SwiftData
import SwiftUI
import FieldCore

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    let repository: FieldRepository
    let mcpServer: MCPServerManager

    @Published var selectedRoute: FieldRoute? = .lab
    @Published var searchText = ""
    @Published var isPresentingCapture = false
    @Published var isRequestingMCPSettings = false
    @Published var captureKind: KnowledgeKind = .learning
    #if DEBUG
    @Published var snapshotSheet: String?
    #endif
    @Published var language: FieldLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: FieldLanguage.preferenceKey) }
    }
    @Published private(set) var refreshToken = UUID()

    init() {
        language = FieldLanguage(
            rawValue: UserDefaults.standard.string(forKey: FieldLanguage.preferenceKey) ?? FieldLanguage.spanish.rawValue
        ) ?? .spanish
        let configuredCloudKitIdentifier = Bundle.main.object(forInfoDictionaryKey: "FIELD_ICLOUD_CONTAINER_ID") as? String
        let cloudKitContainerIdentifier = configuredCloudKitIdentifier.flatMap {
            !$0.isEmpty && $0 != "iCloud.com.example.field" ? $0 : nil
        }
        do {
            container = try FieldModelContainer.make(cloudKitContainerIdentifier: cloudKitContainerIdentifier)
        } catch {
            guard cloudKitContainerIdentifier?.isEmpty == false else {
                fatalError("Field LAB could not create its local store: \(error)")
            }
            do {
                container = try FieldModelContainer.make()
                NSLog("Field LAB opened its local library because iCloud could not start: %@", error.localizedDescription)
            } catch {
                fatalError("Field LAB could not create its local store: \(error)")
            }
        }
        repository = FieldRepository(context: container.mainContext)
        mcpServer = MCPServerManager(repository: repository)
    }

    func refresh() {
        refreshToken = UUID()
        objectWillChange.send()
    }

    func presentCapture(kind: KnowledgeKind = .learning) {
        captureKind = kind
        isPresentingCapture = true
    }

    func openMCPSettings() {
        selectedRoute = .settings
        isRequestingMCPSettings = true
        if !mcpServer.isRunning && !mcpServer.isStarting {
            mcpServer.start()
        }
    }
}

enum FieldRoute: String, CaseIterable, Identifiable, Hashable {
    case collect
    case lab
    case learn
    case settings

    // Legacy routes remain available to sheets and contextual tools. They are
    // intentionally not part of the primary navigation surface anymore.
    case all
    case references
    case learnings
    case promptBlocks
    case recipes
    case notes
    case promptDeck
    case tools
    case flows
    case projects
    case aiInbox
    case activity
    case mcp

    var id: String { rawValue }

    var title: String {
        let spanishTitle: String = switch self {
        case .collect: "Recopilar"
        case .lab, .all: "Laboratorio"
        case .learn: "Aprender"
        case .settings: "Ajustes"
        case .references: "Referencias"
        case .learnings: "Aprendizajes"
        case .promptBlocks: "Bloques de prompt"
        case .recipes: "Recetas"
        case .notes: "Notas"
        case .promptDeck: "Mazo de prompts"
        case .tools: "Herramientas"
        case .flows: "Flujos"
        case .projects: "Proyectos"
        case .aiInbox: "Bandeja de IA"
        case .activity: "Actividad"
        case .mcp: "Servidor MCP"
        }
        return FieldLocalization.text(spanishTitle)
    }

    var systemImage: String {
        switch self {
        case .collect: "photo.on.rectangle.angled"
        case .lab, .all: "rectangle.split.3x1"
        case .learn: "lightbulb"
        case .settings: "gearshape"
        case .references: "photo.on.rectangle.angled"
        case .learnings: "lightbulb"
        case .promptBlocks: "text.quote"
        case .recipes: "list.bullet.rectangle"
        case .notes: "note.text"
        case .promptDeck: "rectangle.stack"
        case .tools: "wrench.and.screwdriver"
        case .flows: "arrow.triangle.branch"
        case .projects: "folder"
        case .aiInbox: "tray.and.arrow.down"
        case .activity: "waveform.path.ecg"
        case .mcp: "antenna.radiowaves.left.and.right"
        }
    }
}
