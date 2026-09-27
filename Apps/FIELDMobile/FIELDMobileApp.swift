import CloudKit
import FieldCore
import SwiftData
import SwiftUI

@main
struct FIELDMobileApp: App {
    @StateObject private var appModel = MobileAppModel()
    @AppStorage(FieldLanguage.preferenceKey) private var languageCode = FieldLanguage.spanish.rawValue
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MobileTabsView()
                .environmentObject(appModel)
                .modelContainer(appModel.container)
                .environment(\.locale, (FieldLanguage(rawValue: languageCode) ?? .spanish).locale)
                .tint(.fieldAccent)
                .onOpenURL { url in
                    appModel.open(url: url)
                }
                .task {
                    syncLanguageWithShareExtension()
                    appModel.processPendingImports()
                }
                .onChange(of: languageCode) { _, _ in syncLanguageWithShareExtension() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { appModel.processPendingImports() }
                }
        }
    }

    private func syncLanguageWithShareExtension() {
        guard
            let groupID = Bundle.main.object(forInfoDictionaryKey: "FIELD_APP_GROUP_ID") as? String,
            !groupID.isEmpty,
            groupID != "group.com.example.field"
        else { return }
        UserDefaults(suiteName: groupID)?.set(languageCode, forKey: FieldLanguage.preferenceKey)
    }
}

@MainActor
final class MobileAppModel: ObservableObject {
    let container: ModelContainer
    let repository: FieldRepository
    let cloudKitContainerIdentifier: String?
    private let cloudKitStartupError: String?

    @Published var presentedSheet: MobileSheet?
    @Published private(set) var importedReferenceCount = 0
    @Published private(set) var importError: String?
    @Published private(set) var cloudAccountState: CloudAccountState = .checking
    @Published private(set) var cloudAccountDetail = ""

    var shareImportsConfigured: Bool {
        guard
            let groupID = Bundle.main.object(forInfoDictionaryKey: "FIELD_APP_GROUP_ID") as? String,
            !groupID.isEmpty,
            groupID != "group.com.example.field"
        else { return false }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) != nil
    }

    init() {
        let identifier = Bundle.main.object(forInfoDictionaryKey: "FIELD_ICLOUD_CONTAINER_ID") as? String
        cloudKitContainerIdentifier = identifier.flatMap { !$0.isEmpty && $0 != "iCloud.com.example.field" ? $0 : nil }

        do {
            container = try FieldModelContainer.make(cloudKitContainerIdentifier: cloudKitContainerIdentifier)
            cloudKitStartupError = nil
        } catch {
            guard cloudKitContainerIdentifier != nil else {
                fatalError("FIELD could not open its local library: \(error)")
            }
            do {
                container = try FieldModelContainer.make()
                cloudKitStartupError = error.localizedDescription
            } catch {
                fatalError("FIELD could not open its local library: \(error)")
            }
        }
        repository = FieldRepository(context: container.mainContext)
        if let cloudKitStartupError {
            cloudAccountState = .unavailable
            cloudAccountDetail = L10n.format("FIELD ha abierto la biblioteca local. iCloud no se pudo iniciar: %@", cloudKitStartupError)
        } else {
            refreshCloudAccountState()
        }
    }

    func presentCapture(_ route: CaptureRoute) {
        presentedSheet = .capture(route)
    }

    func presentSearch() {
        presentedSheet = .search
    }

    func presentSettings() {
        presentedSheet = .settings
    }

    func processPendingImports() {
        guard
            let groupID = Bundle.main.object(forInfoDictionaryKey: "FIELD_APP_GROUP_ID") as? String,
            groupID != "group.com.example.field",
            let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        else { return }

        do {
            let directory = groupURL.appendingPathComponent("ReferenceImports", isDirectory: true)
            let queue = try ReferenceImportQueue(directory: directory)
            let report = try ReferenceImportService(repository: repository).processPendingReport(queue)
            importedReferenceCount += report.imported.count
            importError = report.failures.isEmpty ? nil : report.failures.joined(separator: "\n")
        } catch {
            importError = L10n.format("No se pudieron importar las referencias compartidas: %@", error.localizedDescription)
        }
    }

    func open(url: URL) {
        if isWebURL(url) {
            presentCapture(.reference(url.absoluteString))
            return
        }

        guard
            url.scheme?.lowercased() == "fieldlab",
            url.host?.lowercased() == "capture",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let destination = components.queryItems?.first(where: { $0.name == "url" })?.value,
            let destinationURL = URL(string: destination),
            isWebURL(destinationURL)
        else { return }

        presentCapture(.reference(destinationURL.absoluteString))
    }

    private func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else { return false }
        return scheme == "http" || scheme == "https"
    }

    func refreshCloudAccountState() {
        if let cloudKitStartupError {
            cloudAccountState = .unavailable
            cloudAccountDetail = L10n.format("FIELD ha abierto la biblioteca local. iCloud no se pudo iniciar: %@", cloudKitStartupError)
            return
        }
        guard let cloudKitContainerIdentifier else {
            cloudAccountState = .notConfigured
            cloudAccountDetail = L10n.text("Añade el contenedor iCloud de tu equipo en la configuración del proyecto.")
            return
        }

        cloudAccountState = .checking
        CKContainer(identifier: cloudKitContainerIdentifier).accountStatus { [weak self] status, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.cloudAccountState = .unavailable
                    self.cloudAccountDetail = error.localizedDescription
                    return
                }

                switch status {
                case .available:
                    self.cloudAccountState = .available
                    self.cloudAccountDetail = L10n.text("La cuenta iCloud está disponible. FIELD conserva los cambios en el iPhone sin conexión y los envía a CloudKit en segundo plano cuando puede.")
                case .noAccount:
                    self.cloudAccountState = .noAccount
                    self.cloudAccountDetail = L10n.text("Inicia sesión en iCloud desde Ajustes del iPhone para sincronizar FIELD.")
                case .restricted:
                    self.cloudAccountState = .restricted
                    self.cloudAccountDetail = L10n.text("Este dispositivo tiene restringido el acceso a iCloud.")
                default:
                    self.cloudAccountState = .unavailable
                    self.cloudAccountDetail = L10n.text("No se pudo comprobar el estado de iCloud.")
                }
            }
        }
    }
}

enum MobileSheet: Identifiable {
    case capture(CaptureRoute)
    case search
    case settings

    var id: String {
        switch self {
        case .capture(let route): "capture-\(route.id)"
        case .search: "search"
        case .settings: "settings"
        }
    }

    var isSearch: Bool {
        if case .search = self { return true }
        return false
    }
}

enum CloudAccountState: Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case unavailable
    case notConfigured

    var title: String {
        switch self {
        case .checking: L10n.text("Comprobando iCloud")
        case .available: L10n.text("Cuenta iCloud disponible")
        case .noAccount: L10n.text("Inicia sesión en iCloud")
        case .restricted: L10n.text("iCloud restringido")
        case .unavailable: L10n.text("iCloud no disponible")
        case .notConfigured: L10n.text("Falta configurar iCloud")
        }
    }

    var symbol: String {
        switch self {
        case .checking: "icloud"
        case .available: "checkmark.icloud"
        case .noAccount, .restricted, .unavailable, .notConfigured: "exclamationmark.icloud"
        }
    }
}
