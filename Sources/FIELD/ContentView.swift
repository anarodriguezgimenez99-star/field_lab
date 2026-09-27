import Foundation
import SwiftUI
import SwiftData
import FieldCore
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var mcpServer: MCPServerManager

    init(appModel: AppModel) {
        self.appModel = appModel
        _mcpServer = ObservedObject(wrappedValue: appModel.mcpServer)
    }

    var body: some View {
        #if os(iOS)
        TabView(selection: Binding(
            get: { appModel.selectedRoute ?? .lab },
            set: { appModel.selectedRoute = $0 }
        )) {
            FieldRouteView(appModel: appModel, route: .collect)
                .tabItem { Label(L10n.text("Recopilar"), systemImage: FieldRoute.collect.systemImage) }
                .tag(FieldRoute.collect)
            FieldRouteView(appModel: appModel, route: .lab)
                .tabItem { Label(L10n.text("Laboratorio"), systemImage: FieldRoute.lab.systemImage) }
                .tag(FieldRoute.lab)
            FieldRouteView(appModel: appModel, route: .learn)
                .tabItem { Label(L10n.text("Aprender"), systemImage: FieldRoute.learn.systemImage) }
                .tag(FieldRoute.learn)
        }
        .sheet(isPresented: $appModel.isPresentingCapture) {
            QuickCaptureView(appModel: appModel, initialKind: appModel.captureKind)
                .presentationDetents([.medium])
        }
        #else
        ZStack {
            NavigationSplitView {
                FieldSidebar(appModel: appModel)
                    .navigationSplitViewColumnWidth(min: 145, ideal: 160, max: 200)
            } detail: {
                FieldRouteView(appModel: appModel)
                    .id(appModel.refreshToken)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: appModel.openMCPSettings) {
                        Group {
                            if mcpServer.isStarting || mcpServer.isStopping {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .overlay(alignment: .topTrailing) {
                                        if mcpServer.isRunning {
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 7, height: 7)
                                                .overlay(Circle().strokeBorder(FieldPalette.canvas, lineWidth: 1.5))
                                                .offset(x: 3, y: -3)
                                        }
                                    }
                            }
                        }
                    }
                    .disabled(mcpServer.isStopping)
                    .help(mcpServer.isRunning || mcpServer.isStarting ? L10n.text("Abrir ajustes del servidor MCP") : L10n.text("Iniciar servidor MCP y abrir ajustes"))
                    .accessibilityLabel(mcpServer.isRunning || mcpServer.isStarting ? L10n.text("Abrir ajustes del servidor MCP") : L10n.text("Iniciar servidor MCP"))
                    .accessibilityValue(mcpServer.isRunning ? L10n.text("Activo") : mcpServer.isStarting ? L10n.text("Iniciando") : L10n.text("Detenido"))
                }
            }
            .background(FieldPalette.canvas)

            if appModel.isPresentingCapture {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(10)

                QuickCaptureView(appModel: appModel, initialKind: appModel.captureKind)
                    .frame(width: 620, height: 360)
                    .background(FieldPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(11)
            }
        }
        .frame(minWidth: 1040, minHeight: 700)
        .animation(.easeOut(duration: 0.22), value: appModel.isPresentingCapture)
        #endif
    }
}

struct FieldSidebar: View {
    @ObservedObject var appModel: AppModel

    private var fieldLogo: Image {
        #if os(macOS)
        if let logoURL = Bundle.module.url(forResource: "FIELDLogo", withExtension: "png"),
           let logo = NSImage(contentsOf: logoURL) {
            return Image(nsImage: logo)
        }
        #endif
        return Image(systemName: "square.grid.2x2.fill")
    }

    private var proposalCount: Int {
        appModel.repository.proposals(status: .pending).count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                fieldLogo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)

                Text(L10n.text("FIELD LAB"))
                    .font(.system(.headline, design: .rounded).weight(.semibold))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            List(selection: $appModel.selectedRoute) {
                Section {
                    sidebarLink(.collect)
                    sidebarLink(.lab)
                    NavigationLink(value: FieldRoute.learn) {
                        if proposalCount > 0 {
                            Label(L10n.text("Aprender"), systemImage: FieldRoute.learn.systemImage)
                                .badge(proposalCount)
                        } else {
                            Label(L10n.text("Aprender"), systemImage: FieldRoute.learn.systemImage)
                        }
                    }
                }

                Section {
                    sidebarLink(.settings)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(FieldPalette.sidebar)
        }
        .background(FieldPalette.sidebar)
    }

    @ViewBuilder
    private func sidebarLink(_ route: FieldRoute) -> some View {
        NavigationLink(value: route) {
            Label(route.title, systemImage: route.systemImage)
        }
    }
}

struct FieldRouteView: View {
    @ObservedObject var appModel: AppModel
    var route: FieldRoute? = nil

    var body: some View {
        switch route ?? appModel.selectedRoute ?? .lab {
        case .collect: ReferencesView(appModel: appModel)
        case .lab, .all: LabView(appModel: appModel)
        case .learn: LearnView(appModel: appModel)
        case .settings: SettingsView(appModel: appModel)
        case .references: ReferencesView(appModel: appModel)
        case .learnings: KnowledgeBrowserView(appModel: appModel, kind: .learning)
        case .promptBlocks: KnowledgeBrowserView(appModel: appModel, kind: .promptBlock)
        case .recipes: KnowledgeBrowserView(appModel: appModel, kind: .recipe)
        case .notes: KnowledgeBrowserView(appModel: appModel, kind: nil, inboxOnly: true, titleOverride: "Bandeja")
        case .promptDeck: PromptDeckView(appModel: appModel)
        case .tools: ToolsBrowserView(appModel: appModel)
        case .flows: FlowsBrowserView(appModel: appModel)
        case .projects: ProjectsBrowserView(appModel: appModel)
        case .aiInbox: AIInboxView(appModel: appModel)
        case .activity: ActivityView(appModel: appModel)
        case .mcp: MCPSettingsView(appModel: appModel)
        }
    }
}

struct LegacyOverviewView: View {
    @ObservedObject var appModel: AppModel

    private var recentItems: [KnowledgeItem] {
        Array(appModel.repository.knowledge().prefix(4))
    }

    private var promptBlockCount: Int {
        appModel.repository.knowledge(kind: .promptBlock).count
    }

    private var inboxCount: Int {
        appModel.repository.knowledge().filter { $0.status == .new }.count
    }

    private var projects: [FieldProject] {
        Array(appModel.repository.projects().prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("Laboratorio"))
                            .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        Text(L10n.text("Una vista clara de lo que empieza a ser útil."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    FieldLegacySummaryCard(title: "Capturas recientes", systemImage: "clock") {
                        if recentItems.isEmpty {
                            FieldLegacyEmpty("Tus últimas notas aparecerán aquí.", actionTitle: "Capturar algo") {
                                appModel.presentCapture()
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(recentItems) { item in
                                    Button {
                                        appModel.selectedRoute = route(for: item.kind)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: knowledgeIcon(for: item.kind))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 22, height: 22)
                                                .background(FieldPalette.canvas, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                Text(L10n.text(item.kind.displayName))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    FieldLegacySummaryCard(title: "Mazo de prompts", systemImage: "rectangle.stack") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(promptBlockCount == 0 ? L10n.text("Crea tu primer conjunto de lenguaje reutilizable.") : L10n.blocksReadyToCombine(promptBlockCount))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Button(L10n.text("Abrir mazo de prompts")) { appModel.selectedRoute = .promptDeck }
                                .buttonStyle(.bordered)
                        }
                    }

                    FieldLegacySummaryCard(title: "Bandeja", systemImage: "tray") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(inboxCount == 0 ? L10n.text("No hay nada esperando tu atención.") : L10n.inboxStatus(inboxCount))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Button(L10n.text("Abrir bandeja")) { appModel.selectedRoute = .notes }
                                .buttonStyle(.bordered)
                        }
                    }

                    FieldLegacySummaryCard(title: "Proyectos", systemImage: "folder") {
                        if projects.isEmpty {
                                    FieldLegacyEmpty("Contenedores de contexto para el trabajo que estás haciendo ahora.", actionTitle: "Crear un proyecto") {
                                appModel.selectedRoute = .projects
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 9) {
                                ForEach(projects) { project in
                                    Button(project.title) { appModel.selectedRoute = .projects }
                                        .buttonStyle(.plain)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Button(L10n.text("Ver proyectos")) { appModel.selectedRoute = .projects }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }

                    FieldLegacySummaryCard(title: "Conexión de IA", systemImage: "antenna.radiowaves.left.and.right") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(appModel.mcpServer.isRunning ? L10n.text("El puente local está activo.") : L10n.text("Conecta Claude, Codex y agentes compatibles en local."))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Button(appModel.mcpServer.isRunning ? L10n.text("Gestionar conexión") : L10n.text("Configurar conexión")) { appModel.selectedRoute = .mcp }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(FieldPalette.canvas)
        .searchable(text: $appModel.searchText, placement: .toolbar, prompt: L10n.text("Buscar en FIELD LAB"))
    }

    private func route(for kind: KnowledgeKind) -> FieldRoute {
        switch kind {
        case .reference: .references
        case .learning: .learnings
        case .promptBlock: .promptBlocks
        case .recipe: .recipes
        default: .all
        }
    }

    private func knowledgeIcon(for kind: KnowledgeKind) -> String {
        switch kind {
        case .reference: "photo"
        case .promptBlock: "text.quote"
        case .recipe: "list.bullet.rectangle"
        case .learning: "lightbulb"
        case .decision: "checkmark.seal"
        default: "note.text"
        }
    }
}

struct FieldLegacySummaryCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        BorderGlowCard(
            edgeSensitivity: 30,
            glowColor: Color(red: 0.96, green: 0.853, blue: 0.64),
            backgroundColor: Color(red: 0.071, green: 0.059, blue: 0.090),
            borderRadius: 28,
            glowRadius: 40,
            glowIntensity: 1,
            coneSpread: 25,
            animated: false,
            colors: [
                Color(red: 0.753, green: 0.518, blue: 0.988),
                Color(red: 0.957, green: 0.447, blue: 0.706),
                Color(red: 0.220, green: 0.573, blue: 0.973)
            ]
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.text(title))
                        .font(.headline)
                    Spacer(minLength: 0)
                }
                content()
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, minHeight: 188, alignment: .topLeading)
    }
}

struct FieldLegacyEmpty: View {
    let message: String
    let actionTitle: String
    let action: () -> Void

    init(_ message: String, actionTitle: String, action: @escaping () -> Void) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text(message))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(L10n.text(actionTitle), action: action)
                .buttonStyle(.bordered)
        }
    }
}

struct KnowledgeBrowserView: View {
    @ObservedObject var appModel: AppModel
    let kind: KnowledgeKind?
    var inboxOnly = false
    var titleOverride: String?
    var emptyMessage = "Nothing here yet. Capture a small piece of knowledge to start building your field."

    @State private var selectedID: UUID?
    @State private var isPresentingEditor = false
    @State private var editingItem: KnowledgeItem?

    private var items: [KnowledgeItem] {
        let base = appModel.repository.knowledge(kind: kind).filter { !inboxOnly || $0.status == .new }
        let query = appModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        let ids = Set(appModel.repository.search(query: query, filter: SearchFilter(kind: kind)).filter { $0.entityType == "knowledge" }.map(\.id))
        return base.filter { ids.contains($0.id) }
    }

    private var selectedItem: KnowledgeItem? {
        items.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            FieldPageHeader(
                title: titleOverride ?? kind?.displayName ?? "Todo el conocimiento",
                subtitle: inboxOnly ? "Un lugar tranquilo para lo que aún no estás listo para organizar." : "Conserva lo que quieras encontrar, conectar y reutilizar.",
                count: items.count,
                actionTitle: kind == nil ? "Captura rápida" : "\(L10n.text("Añadir")) \(L10n.text(kind?.displayName ?? "elemento"))",
                actionSystemImage: "plus"
            ) {
                if kind == nil {
                    appModel.presentCapture()
                } else {
                    editingItem = nil
                    isPresentingEditor = true
                }
            }

            Divider()

            if items.isEmpty {
                FieldEmptyState(
                    systemImage: inboxOnly ? "tray" : "square.stack.3d.up",
                    title: inboxOnly ? "Tu bandeja está despejada" : "Empieza a construir tu campo",
                    message: inboxOnly ? "Las nuevas capturas y notas de trabajo esperarán aquí hasta que estés listo para organizarlas." : emptyMessage,
                    actionTitle: inboxOnly ? nil : "Capturar algo",
                    action: inboxOnly ? nil : { appModel.presentCapture() }
                )
            } else {
                HSplitView {
                    List(selection: $selectedID) {
                        ForEach(items) { item in
                            KnowledgeRow(item: item)
                                .tag(item.id)
                                .contextMenu {
                                    Button(L10n.text("Editar")) {
                                        editingItem = item
                                        isPresentingEditor = true
                                    }
                                    Button(item.pinned ? L10n.text("Desfijar") : L10n.text("Fijar")) {
                                        item.pinned.toggle()
                                        try? appModel.repository.updateKnowledge(item)
                                        appModel.refresh()
                                    }
                                    Divider()
                                    Button(L10n.text("Eliminar"), role: .destructive) {
                                        try? appModel.repository.delete(item)
                                        if selectedID == item.id { selectedID = nil }
                                        appModel.refresh()
                                    }
                                }
                        }
                    }
                    .frame(minWidth: 320, idealWidth: 390)

                    Group {
                        if let selectedItem {
                            KnowledgeDetailView(item: selectedItem, appModel: appModel) {
                                editingItem = selectedItem
                                isPresentingEditor = true
                            }
                        } else {
                            FieldContextHint(
                                systemImage: "sidebar.right",
                                title: "Elige un elemento de conocimiento",
                                message: "Selecciona un elemento para leer su contexto completo y sus conexiones."
                            )
                        }
                    }
                    .frame(minWidth: 420)
                }
            }
        }
        .searchable(text: $appModel.searchText, placement: .toolbar, prompt: L10n.text("Buscar en FIELD LAB"))
        .sheet(isPresented: $isPresentingEditor) {
            KnowledgeEditorView(appModel: appModel, item: editingItem, defaultKind: kind ?? .note)
                .frame(width: 560, height: 500)
        }
    }
}

struct KnowledgeRow: View {
    let item: KnowledgeItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if item.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary) }
                }
                Text(item.body.isEmpty ? L10n.text("Aún no hay descripción") : item.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(L10n.text(item.kind.displayName))
                    Text(L10n.text("·"))
                    Text(L10n.text(item.status.displayName))
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch item.kind {
        case .reference: "photo"
        case .promptBlock: "text.quote"
        case .recipe: "list.bullet.rectangle"
        case .learning: "lightbulb"
        case .decision: "checkmark.seal"
        case .workingMemory: "hourglass"
        default: "note.text"
        }
    }
}

struct KnowledgeDetailView: View {
    let item: KnowledgeItem
    @ObservedObject var appModel: AppModel
    let edit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text(item.kind.displayName))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                        Text(item.title)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                        Text(L10n.text(item.status.displayName))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("Editar"), action: edit)
                        .buttonStyle(.bordered)
                }

                Divider()

                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: 680, alignment: .leading)
                }

                if item.kind == .reference {
                    #if os(macOS)
                    if let imageData = item.imageData, let image = NSImage(data: imageData) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 720, maxHeight: 420, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    #endif
                    if let url = URL(string: item.urlString), !item.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Link(destination: url) { Label(L10n.text("Abrir referencia"), systemImage: "arrow.up.right.square") }
                    }
                }

                if !item.tags.isEmpty {
                        DetailSection(title: "Etiquetas") {
                        FlowTags(tags: item.tags)
                    }
                }

                DetailSection(title: "Procedencia") {
                    LabeledContent(L10n.text("Fuente"), value: L10n.text(item.sourceType.displayName))
                    if !item.sourceAgent.isEmpty { LabeledContent(L10n.text("Agente"), value: item.sourceAgent) }
                    LabeledContent(L10n.text("Creado"), value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let project = appModel.repository.projects(includeArchived: true).first(where: { $0.id == item.projectID }) {
                        LabeledContent(L10n.text("Proyecto"), value: project.title)
                    }
                    if let tool = appModel.repository.tools().first(where: { $0.id == item.toolID }) {
                        LabeledContent(L10n.text("Herramienta"), value: tool.name)
                    }
                }
            }
            .padding(32)
        }
    }
}

struct KnowledgeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let item: KnowledgeItem?
    let defaultKind: KnowledgeKind

    @State private var kind: KnowledgeKind
    @State private var status: KnowledgeStatus
    @State private var title: String
    @State private var knowledgeBody: String
    @State private var tags: String
    @State private var selectedProjectID: UUID?
    @State private var selectedToolID: UUID?
    @State private var urlString: String
    @State private var imageData: Data?
    @State private var isImportingImage = false

    init(appModel: AppModel, item: KnowledgeItem?, defaultKind: KnowledgeKind) {
        self.appModel = appModel
        self.item = item
        self.defaultKind = defaultKind
        _kind = State(initialValue: item?.kind ?? defaultKind)
        _status = State(initialValue: item?.status ?? .new)
        _title = State(initialValue: item?.title ?? "")
        _knowledgeBody = State(initialValue: item?.body ?? "")
        _tags = State(initialValue: item?.tagNames ?? "")
        _selectedProjectID = State(initialValue: item?.projectID)
        _selectedToolID = State(initialValue: item?.toolID)
        _urlString = State(initialValue: item?.urlString ?? "")
        _imageData = State(initialValue: item?.imageData)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(item == nil ? L10n.text("Nuevo conocimiento") : L10n.text("Editar conocimiento"))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button(L10n.text("Cancelar")) { dismiss() }
            }

            Form {
                Picker(L10n.text("Tipo"), selection: $kind) {
                    ForEach(KnowledgeKind.allCases, id: \.self) { Text(L10n.text($0.displayName)).tag($0) }
                }
                TextField(L10n.text("Título"), text: $title)
                TextField(L10n.text("Etiquetas"), text: $tags, prompt: Text(L10n.text("luz, realismo")))
                if kind == .reference {
                    TextField(L10n.text("URL (opcional)"), text: $urlString)
                    HStack {
                        Text(imageData == nil ? L10n.text("No hay imagen adjunta") : L10n.text("Imagen adjunta"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.text("Elegir imagen")) { isImportingImage = true }
                        if imageData != nil {
                            Button(L10n.text("Eliminar"), role: .destructive) { imageData = nil }
                        }
                    }
                }
                Picker(L10n.text("Estado"), selection: $status) {
                    ForEach(KnowledgeStatus.allCases, id: \.self) { Text(L10n.text($0.displayName)).tag($0) }
                }
                Picker(L10n.text("Proyecto"), selection: $selectedProjectID) {
                    Text(L10n.text("Global")).tag(Optional<UUID>.none)
                    ForEach(appModel.repository.projects(includeArchived: true)) { project in
                        Text(project.title).tag(Optional(project.id))
                    }
                }
                Picker(L10n.text("Herramienta"), selection: $selectedToolID) {
                    Text(L10n.text("Sin herramienta")).tag(Optional<UUID>.none)
                    ForEach(appModel.repository.tools()) { tool in
                        Text(tool.name).tag(Optional(tool.id))
                    }
                }
                TextEditor(text: $knowledgeBody)
                    .frame(minHeight: 150)
            }

            HStack {
                Spacer()
                Button(item == nil ? L10n.text("Guardar") : L10n.text("Guardar cambios")) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .fileImporter(isPresented: $isImportingImage, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            imageData = try? Data(contentsOf: url)
        }
    }

    private func save() {
        do {
            if let item {
                item.kind = kind
                item.title = title
                item.body = knowledgeBody
                item.status = status
                item.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                item.scope = selectedProjectID == nil ? .global : .project
                item.projectID = selectedProjectID
                item.toolID = selectedToolID
                item.urlString = kind == .reference ? urlString : ""
                item.imageData = kind == .reference ? imageData : nil
                try appModel.repository.updateKnowledge(item)
            } else {
                _ = try appModel.repository.createKnowledge(
                    kind: kind,
                    title: title,
                    body: knowledgeBody,
                    status: status,
                    scope: selectedProjectID == nil ? .global : .project,
                    projectID: selectedProjectID,
                    toolID: selectedToolID,
                    tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                    urlString: kind == .reference ? urlString : "",
                    imageData: kind == .reference ? imageData : nil
                )
            }
            appModel.refresh()
            dismiss()
        } catch {
            // The first slice keeps error presentation lightweight; the repository remains the source of truth.
        }
    }
}

struct QuickCaptureView: View {
    @ObservedObject var appModel: AppModel
    let initialKind: KnowledgeKind

    @State private var kind: KnowledgeKind
    @State private var title = ""
    @State private var captureBody = ""
    @State private var tags = ""
    @State private var projectID: UUID?
    @State private var toolID: UUID?
    @State private var createMore = false
    @FocusState private var focusedField: CaptureField?

    private enum CaptureField {
        case title
        case body
    }

    init(appModel: AppModel, initialKind: KnowledgeKind) {
        self.appModel = appModel
        self.initialKind = initialKind
        _kind = State(initialValue: initialKind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("Captura rápida"))
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    Text(L10n.text("Guarda un fragmento útil en FIELD LAB"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    appModel.isPresentingCapture = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(FieldPalette.muted, in: Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(L10n.text("Cerrar captura rápida"))
            }
            .padding(.bottom, 18)

            Divider()

            HStack {
                Picker(L10n.text("Tipo"), selection: $kind) {
                    ForEach([KnowledgeKind.learning, .reference, .note, .idea, .promptBlock], id: \.self) {
                        Text(L10n.text($0.displayName)).tag($0)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
            }
            .padding(.vertical, 14)

            TextField(kind == .learning ? L10n.text("¿Qué has aprendido?") : L10n.text("Título"), text: $title)
                .textFieldStyle(.plain)
                .font(.system(.title3, design: .rounded))
                .focused($focusedField, equals: .title)
                .padding(.bottom, 10)

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: $captureBody)
                    .textEditorStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .body)
                    .frame(minHeight: 88)

                if captureBody.isEmpty {
                    Text(L10n.text("Añadir descripción"))
                        .foregroundStyle(.secondary)
                        .padding(.top, 7)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 14) {
                TextField(L10n.text("Etiquetas"), text: $tags)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 150)

                Picker(L10n.text("Proyecto"), selection: $projectID) {
                    Text(L10n.text("Global")).tag(Optional<UUID>.none)
                    ForEach(appModel.repository.projects()) { project in
                        Text(project.title).tag(Optional(project.id))
                    }
                }
                .pickerStyle(.menu)

                Picker(L10n.text("Herramienta"), selection: $toolID) {
                    Text(L10n.text("Sin herramienta")).tag(Optional<UUID>.none)
                    ForEach(appModel.repository.tools()) { tool in
                        Text(tool.name).tag(Optional(tool.id))
                    }
                }
                .pickerStyle(.menu)

                Spacer()
            }
            .font(.subheadline)

            HStack {
                Toggle(L10n.text("Crear otra"), isOn: $createMore)
                    .toggleStyle(.switch)
                Spacer()
                Button(L10n.text("Guardar")) { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(FieldPalette.accent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && captureBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 18)
        }
        .padding(24)
        .onAppear {
            focusedField = .title
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = captureBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? String(cleanBody.prefix(72)) : cleanTitle
        let parsedTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if kind == .reference {
            _ = try? appModel.repository.createReference(
                title: finalTitle.isEmpty ? "Referencia sin título" : finalTitle,
                userNote: cleanBody,
                projectIDs: projectID.map { [$0] } ?? [],
                toolIDs: toolID.map { [$0] } ?? [],
                tags: parsedTags
            )
        } else {
            _ = try? appModel.repository.createKnowledge(
                kind: kind,
                title: finalTitle.isEmpty ? "Captura sin título" : finalTitle,
                body: cleanBody,
                status: .new,
                scope: projectID == nil ? .global : .project,
                projectID: projectID,
                toolID: toolID,
                tags: parsedTags
            )
        }
        appModel.refresh()
        if createMore {
            title = ""
            captureBody = ""
            tags = ""
            projectID = nil
            toolID = nil
            focusedField = .title
        } else {
            appModel.isPresentingCapture = false
        }
    }
}

struct PromptDeckView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedIDs = Set<UUID>()
    @State private var copied = false
    @State private var isSavingRecipe = false

    private var blocks: [KnowledgeItem] { appModel.repository.knowledge(kind: .promptBlock) }
    private var selectedBlocks: [KnowledgeItem] { blocks.filter { selectedIDs.contains($0.id) } }
    private var stack: String { PromptStackBuilder.concatenate(selectedBlocks) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FieldPageHeader(
                title: "Mazo de prompts",
                subtitle: "Selecciona el lenguaje que quieres llevar a tu próxima herramienta.",
                count: blocks.count,
                actionTitle: copied ? "Copiado" : "Copiar conjunto",
                actionSystemImage: copied ? "checkmark" : "doc.on.doc"
            ) {
                copyStack()
            }
            .disabled(stack.isEmpty)
            Divider()

            HSplitView {
                List {
                    Section(L10n.text("Bloques")) {
                        ForEach(blocks) { block in
                            Button {
                                if selectedIDs.contains(block.id) { selectedIDs.remove(block.id) } else { selectedIDs.insert(block.id) }
                            } label: {
                                HStack {
                                    Image(systemName: selectedIDs.contains(block.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDs.contains(block.id) ? Color.accentColor : Color.secondary)
                                    VStack(alignment: .leading) {
                                        Text(block.title)
                                        Text(block.body).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(minWidth: 360)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(L10n.text("Conjunto actual"))
                            .font(.headline)
                        Spacer()
                        Button(L10n.text("Guardar como receta")) { isSavingRecipe = true }
                            .buttonStyle(.bordered)
                            .disabled(stack.isEmpty)
                    }
                    Text(stack.isEmpty ? L10n.text("Elige dos o más bloques para crear un conjunto reutilizable.") : stack)
                        .font(.body)
                        .foregroundStyle(stack.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: 620, alignment: .leading)
                    if !selectedBlocks.isEmpty {
                        FlowTags(tags: selectedBlocks.map(\.title))
                    }
                    Spacer()
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(isPresented: $isSavingRecipe) {
            SaveRecipeView(appModel: appModel, stack: stack).frame(width: 520, height: 320)
        }
    }

    private func copyStack() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(stack, forType: .string)
        #endif
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }
}

struct SaveRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let stack: String
    @State private var title = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(L10n.text("Guardar como receta")).font(.title2.weight(.semibold)); Spacer(); Button(L10n.text("Cancelar")) { dismiss() } }
            TextField(L10n.text("Título de la receta"), text: $title)
            TextEditor(text: $notes).frame(minHeight: 100).overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            DetailSection(title: "Conjunto de prompts") { Text(stack).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
            HStack { Spacer(); Button(L10n.text("Guardar receta")) {
                _ = try? appModel.repository.createKnowledge(kind: .recipe, title: title, body: [stack, notes].filter { !$0.isEmpty }.joined(separator: "\n\n"), status: .works, tags: ["prompt-stack"])
                appModel.refresh(); dismiss()
            }.buttonStyle(.borderedProminent).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(24)
    }
}

struct FlowsBrowserView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedID: UUID?
    @State private var isPresentingEditor = false
    @State private var isStartingFlow = false
    @State private var editingFlow: FieldFlow?

    private var flows: [FieldFlow] { appModel.repository.flows() }
    private var selected: FieldFlow? { flows.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            FieldPageHeader(
                title: "Flujos",
                subtitle: "Tu método, documentado paso a paso, no automatizado.",
                count: flows.count,
                actionTitle: "Nuevo flujo",
                actionSystemImage: "plus"
            ) {
                editingFlow = nil
                isPresentingEditor = true
            }
            Divider()
            HSplitView {
                List(selection: $selectedID) {
                    if flows.isEmpty {
                        ContentUnavailableView(L10n.text("Aún no hay flujos"), systemImage: "arrow.triangle.branch", description: Text(L10n.text("Documenta un método creativo repetible para poder reutilizarlo.")))
                    } else {
                        ForEach(flows) { flow in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(flow.title).font(.headline)
                                Text("\(L10n.pluralized(appModel.repository.flowSteps(flowID: flow.id).count, singular: "paso", plural: "pasos")) · \(flow.summary)").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            .padding(.vertical, 4)
                            .tag(flow.id)
                            .contextMenu {
                                Button(L10n.text("Editar")) { editingFlow = flow; isPresentingEditor = true }
                                Button(L10n.text("Eliminar"), role: .destructive) { try? appModel.repository.deleteFlow(flow); if selectedID == flow.id { selectedID = nil }; appModel.refresh() }
                            }
                        }
                    }
                }.frame(minWidth: 340)

                if let selected {
                    FlowDetailView(flow: selected, appModel: appModel, edit: { editingFlow = selected; isPresentingEditor = true }) { isStartingFlow = true }
                } else {
                    FieldContextHint(systemImage: "arrow.triangle.branch", title: "Elige un flujo", message: "Un flujo te ayuda a repetir lo que ya funciona.")
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) { FlowEditorView(appModel: appModel, flow: editingFlow).frame(width: 560, height: 360) }
        .sheet(isPresented: $isStartingFlow) {
            if let selected { StartFlowView(flow: selected, appModel: appModel).frame(width: 620, height: 520) }
        }
    }
}

struct FlowDetailView: View {
    let flow: FieldFlow
    @ObservedObject var appModel: AppModel
    let edit: () -> Void
    let start: () -> Void
    @State private var editingStep: FieldFlowStep?
    @State private var isPresentingStepEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(flow.title).font(.system(size: 32, weight: .semibold, design: .rounded))
                        Text(flow.summary).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("Editar"), action: edit).buttonStyle(.bordered)
                    Button(L10n.text("Iniciar flujo"), action: start).buttonStyle(.borderedProminent)
                }
                let steps = appModel.repository.flowSteps(flowID: flow.id)
                if steps.isEmpty {
                        ContentUnavailableView(L10n.text("Aún no hay pasos"), systemImage: "list.number", description: Text(L10n.text("Añade el primer paso para convertir este método en una guía ejecutable.")))
                } else {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 14) {
                            Text(String(format: L10n.text("%02d"), step.order)).font(.system(.title3, design: .monospaced)).foregroundStyle(.tint).frame(width: 34, alignment: .leading)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(step.title).font(.headline)
                                if !step.instructions.isEmpty { Text(step.instructions).foregroundStyle(.secondary) }
                                if let toolID = step.toolID, let tool = appModel.repository.tools().first(where: { $0.id == toolID }) { Label(tool.name, systemImage: "wrench.and.screwdriver").font(.caption).foregroundStyle(.tint) }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture { editingStep = step; isPresentingStepEditor = true }
                        .contextMenu {
                            Button(L10n.text("Editar paso")) { editingStep = step; isPresentingStepEditor = true }
                            Button(L10n.text("Eliminar paso"), role: .destructive) {
                                try? appModel.repository.deleteFlowStep(step)
                                appModel.refresh()
                            }
                        }
                        Divider()
                    }
                }
                Button(L10n.text("Añadir paso")) {
                    guard let step = try? appModel.repository.createFlowStep(flowID: flow.id, title: "Nuevo paso") else { return }
                    editingStep = step
                    isPresentingStepEditor = true
                    appModel.refresh()
                }.buttonStyle(.bordered)
            }.padding(32)
        }
        .sheet(isPresented: $isPresentingStepEditor) {
            if let editingStep {
                FlowStepEditorView(appModel: appModel, step: editingStep)
                    .frame(width: 620, height: 560)
            }
        }
    }
}

struct FlowStepEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let step: FieldFlowStep
    @State private var title: String
    @State private var instructions: String
    @State private var toolIDString: String
    @State private var recipeIDString: String
    @State private var templateText: String
    @State private var notes: String

    init(appModel: AppModel, step: FieldFlowStep) {
        self.appModel = appModel
        self.step = step
        _title = State(initialValue: step.title)
        _instructions = State(initialValue: step.instructions)
        _toolIDString = State(initialValue: step.toolID?.uuidString ?? "")
        _recipeIDString = State(initialValue: step.recipeID?.uuidString ?? "")
        _templateText = State(initialValue: step.templateText)
        _notes = State(initialValue: step.notes)
    }

    private var tools: [FieldTool] { appModel.repository.tools() }
    private var recipes: [KnowledgeItem] { appModel.repository.knowledge(kind: .recipe) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.text("Editar paso")).font(.title2.weight(.semibold))
                Spacer()
                Button(L10n.text("Cancelar")) { dismiss() }
            }
            Form {
                TextField(L10n.text("Título del paso"), text: $title)
                TextField(L10n.text("¿Qué ocurre en este paso?"), text: $instructions, axis: .vertical).lineLimit(2...4)
                Picker(L10n.text("Herramienta"), selection: $toolIDString) {
                    Text(L10n.text("Sin herramienta")).tag("")
                    ForEach(tools) { Text($0.name).tag($0.id.uuidString) }
                }
                Picker(L10n.text("Receta"), selection: $recipeIDString) {
                    Text(L10n.text("Sin receta")).tag("")
                    ForEach(recipes) { Text($0.title).tag($0.id.uuidString) }
                }
                TextField(L10n.text("Prompt o plantilla de trabajo"), text: $templateText, axis: .vertical).lineLimit(3...7)
                TextField(L10n.text("Notas privadas"), text: $notes, axis: .vertical).lineLimit(2...5)
            }
            HStack {
                Spacer()
                Button(L10n.text("Guardar paso")) { save() }.buttonStyle(.borderedProminent).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
    }

    private func save() {
        step.title = title
        step.instructions = instructions
        step.toolID = UUID(uuidString: toolIDString)
        step.recipeID = UUID(uuidString: recipeIDString)
        step.templateText = templateText
        step.notes = notes
        try? appModel.repository.updateFlowStep(step)
        appModel.refresh()
        dismiss()
    }
}

struct FlowEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let flow: FieldFlow?
    @State private var title = ""
    @State private var summary = ""

    init(appModel: AppModel, flow: FieldFlow? = nil) {
        self.appModel = appModel
        self.flow = flow
        _title = State(initialValue: flow?.title ?? "")
        _summary = State(initialValue: flow?.summary ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(flow == nil ? L10n.text("Nuevo flujo") : L10n.text("Editar flujo")).font(.title2.weight(.semibold)); Spacer(); Button(L10n.text("Cancelar")) { dismiss() } }
            Form { TextField(L10n.text("Título del flujo"), text: $title); TextField(L10n.text("¿Qué consigue este método?"), text: $summary, axis: .vertical).lineLimit(2...4) }
            HStack { Spacer(); Button(flow == nil ? L10n.text("Crear flujo") : L10n.text("Guardar cambios")) { save() }.buttonStyle(.borderedProminent).disabled(title.isEmpty) }
        }.padding(24)
    }

    private func save() {
        if let flow {
            flow.title = title
            flow.summary = summary
            try? appModel.repository.updateFlow(flow)
        } else {
            guard (try? appModel.repository.createFlow(title: title, summary: summary)) != nil else { return }
        }
        appModel.refresh(); dismiss()
    }
}

struct StartFlowView: View {
    @Environment(\.dismiss) private var dismiss
    let flow: FieldFlow
    @ObservedObject var appModel: AppModel
    @State private var index = 0
    @State private var copied = false

    private var steps: [FieldFlowStep] { appModel.repository.flowSteps(flowID: flow.id) }
    private var step: FieldFlowStep? { steps.indices.contains(index) ? steps[index] : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { VStack(alignment: .leading, spacing: 4) { Text(flow.title).font(.title2.weight(.semibold)); Text(L10n.stepProgress(current: min(index + 1, max(steps.count, 1)), total: steps.count)).font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Button(L10n.text("Hecho")) { dismiss() } }
            if let step {
                Text(step.title).font(.largeTitle.weight(.semibold))
                if let toolID = step.toolID, let tool = appModel.repository.tools().first(where: { $0.id == toolID }) { Label(tool.name, systemImage: "wrench.and.screwdriver").foregroundStyle(.tint) }
                Text(step.instructions.isEmpty ? L10n.text("Aún no hay instrucciones.") : step.instructions).font(.title3)
                if !step.templateText.isEmpty {
                    DetailSection(title: "Plantilla") {
                        Text(step.templateText).textSelection(.enabled)
                        Button(copied ? L10n.text("Copiado") : L10n.text("Copiar plantilla")) { copy(step.templateText) }.buttonStyle(.bordered)
                    }
                }
                Spacer()
                HStack { Button(L10n.text("Anterior")) { index = max(index - 1, 0) }.disabled(index == 0); Spacer(); Button(index == steps.count - 1 ? L10n.text("Terminar") : L10n.text("Siguiente")) { if index < steps.count - 1 { index += 1 } else { dismiss() } }.buttonStyle(.borderedProminent) }
            } else {
                ContentUnavailableView(L10n.text("No hay pasos"), systemImage: "list.number", description: Text(L10n.text("Añade pasos a este flujo antes de iniciarlo.")))
                Spacer()
            }
        }.padding(28)
    }

    private func copy(_ value: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string)
        #endif
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }
}

struct ProjectsBrowserView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedID: UUID?
    @State private var isPresentingEditor = false
    @State private var editingProject: FieldProject?

    private var projects: [FieldProject] { appModel.repository.projects(includeArchived: true) }
    private var selected: FieldProject? { projects.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            FieldPageHeader(
                title: "Proyectos",
                subtitle: "Contenedores de contexto, no tableros de tareas.",
                count: projects.count,
                actionTitle: "Nuevo proyecto",
                actionSystemImage: "plus"
            ) {
                editingProject = nil
                isPresentingEditor = true
            }
            Divider()

            HSplitView {
                List(selection: $selectedID) {
                    ForEach(projects) { project in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.title).font(.headline)
                            Text(project.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        .padding(.vertical, 4)
                        .tag(project.id)
                        .contextMenu {
                            Button(L10n.text("Editar")) { editingProject = project; isPresentingEditor = true }
                            Button(L10n.text("Archivar")) { project.archived = true; try? appModel.repository.updateProject(project); appModel.refresh() }
                            Button(L10n.text("Eliminar"), role: .destructive) { try? appModel.repository.deleteProject(project); appModel.refresh() }
                        }
                    }
                }
                .frame(minWidth: 320)
                if let selected {
                    ProjectDetailView(project: selected, appModel: appModel) {
                        editingProject = selected
                        isPresentingEditor = true
                    }
                } else {
                    FieldContextHint(systemImage: "folder", title: "Elige un proyecto", message: "Un proyecto ofrece a los agentes un paquete de contexto compacto y duradero.")
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            ProjectEditorView(appModel: appModel, project: editingProject).frame(width: 560, height: 520)
        }
    }
}

struct ProjectDetailView: View {
    let project: FieldProject
    @ObservedObject var appModel: AppModel
    let edit: () -> Void
    @State private var isShowingReferences = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Text(project.title).font(.system(size: 32, weight: .semibold, design: .rounded)); Spacer(); Button(L10n.text("Editar"), action: edit).buttonStyle(.bordered) }
                if !project.summary.isEmpty { Text(project.summary).font(.title3).foregroundStyle(.secondary) }
                DetailSection(title: "Resumen") { Text(project.brief.isEmpty ? L10n.text("Aún no escrito.") : project.brief) }
                DetailSection(title: "Dirección creativa") { Text(project.creativeDirection.isEmpty ? L10n.text("Aún no escrita.") : project.creativeDirection) }
                DetailSection(title: "Restricciones") { Text(project.constraints.isEmpty ? L10n.text("Aún no escritas.") : project.constraints) }
                DetailSection(title: "Entregables") { Text(project.deliverables.isEmpty ? L10n.text("Aún no escritos.") : project.deliverables) }
                DetailSection(title: "Recordar siempre") {
                    Text(project.alwaysRemember.isEmpty ? L10n.text("Aún no escrito.") : project.alwaysRemember)
                        .foregroundStyle(.tint)
                }
                DetailSection(title: "Conocimiento del proyecto") {
                    let items = appModel.repository.knowledge(projectID: project.id)
                    if items.isEmpty { Text(L10n.text("Aún no hay conocimiento conectado.")).foregroundStyle(.secondary) }
                    else { ForEach(items.prefix(10)) { item in Text("• \(item.title)") } }
                }
                DetailSection(title: "Referencias") {
                    let references = appModel.repository.references().filter { $0.projectIDs.contains(project.id) }
                    HStack {
                        if references.isEmpty {
                            Text(L10n.text("Aún no hay referencias visuales conectadas.")).foregroundStyle(.secondary)
                        } else {
                            ForEach(references.prefix(6)) { reference in
                                ReferenceImageView(data: reference.thumbnailData ?? reference.imageData)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .help(reference.title)
                            }
                        }
                        Spacer()
                        Button(L10n.text("Añadir desde la biblioteca")) { isShowingReferences = true }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .padding(32)
        }
        .sheet(isPresented: $isShowingReferences) {
            ProjectReferencePicker(appModel: appModel, project: project)
        }
    }
}

struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let project: FieldProject?
    @State private var title: String
    @State private var summary: String
    @State private var brief: String
    @State private var direction: String
    @State private var constraints: String
    @State private var deliverables: String
    @State private var remember: String

    init(appModel: AppModel, project: FieldProject? = nil) {
        self.appModel = appModel
        self.project = project
        _title = State(initialValue: project?.title ?? "")
        _summary = State(initialValue: project?.summary ?? "")
        _brief = State(initialValue: project?.brief ?? "")
        _direction = State(initialValue: project?.creativeDirection ?? "")
        _constraints = State(initialValue: project?.constraints ?? "")
        _deliverables = State(initialValue: project?.deliverables ?? "")
        _remember = State(initialValue: project?.alwaysRemember ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(project == nil ? L10n.text("Nuevo proyecto") : L10n.text("Editar proyecto")).font(.title2.weight(.semibold)); Spacer(); Button(L10n.text("Cancelar")) { dismiss() } }
            Form {
                TextField(L10n.text("Título del proyecto"), text: $title)
                TextField(L10n.text("Resumen en una línea"), text: $summary)
                TextField(L10n.text("Resumen"), text: $brief, axis: .vertical).lineLimit(2...4)
                TextField(L10n.text("Dirección creativa"), text: $direction, axis: .vertical).lineLimit(2...4)
                TextField(L10n.text("Restricciones"), text: $constraints, axis: .vertical).lineLimit(2...4)
                TextField(L10n.text("Entregables"), text: $deliverables, axis: .vertical).lineLimit(2...4)
                TextField(L10n.text("Recordar siempre"), text: $remember, axis: .vertical).lineLimit(2...4)
            }
            HStack { Spacer(); Button(project == nil ? L10n.text("Crear proyecto") : L10n.text("Guardar cambios")) { save() }.buttonStyle(.borderedProminent).disabled(title.isEmpty) }
        }
        .padding(24)
    }

    private func save() {
        let target: FieldProject?
        if let project {
            target = project
            project.title = title
            project.summary = summary
        } else {
            target = try? appModel.repository.createProject(title: title, summary: summary)
        }
        guard let target else { return }
        target.brief = brief
        target.creativeDirection = direction
        target.constraints = constraints
        target.deliverables = deliverables
        target.alwaysRemember = remember
        try? appModel.repository.updateProject(target)
        appModel.refresh()
        dismiss()
    }
}

struct ToolsBrowserView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedID: UUID?
    @State private var isPresentingEditor = false
    @State private var editingTool: FieldTool?

    private var tools: [FieldTool] { appModel.repository.tools() }
    private var selected: FieldTool? { tools.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            FieldPageHeader(
                title: "Herramientas",
                subtitle: "Tu experiencia con las herramientas, no descripciones genéricas.",
                count: tools.count,
                actionTitle: "Añadir herramienta",
                actionSystemImage: "plus"
            ) {
                editingTool = nil
                isPresentingEditor = true
            }
            Divider()
            HSplitView {
                List(selection: $selectedID) {
                    ForEach(tools) { tool in
                        HStack(spacing: 10) {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) { Text(tool.name).font(.headline); Text(tool.category).font(.caption).foregroundStyle(.secondary) }
                        }
                        .tag(tool.id)
                        .contextMenu {
                            Button(L10n.text("Editar")) { editingTool = tool; isPresentingEditor = true }
                            Button(L10n.text("Eliminar"), role: .destructive) { try? appModel.repository.deleteTool(tool); appModel.refresh() }
                        }
                    }
                }.frame(minWidth: 320)
                if let selected { ToolDetailView(tool: selected, appModel: appModel) { editingTool = selected; isPresentingEditor = true } }
                else { FieldContextHint(systemImage: "wrench.and.screwdriver", title: "Elige una herramienta", message: "La página de una herramienta reúne el conocimiento acumulado sobre cómo funciona para ti.") }
            }
        }
        .sheet(isPresented: $isPresentingEditor) { ToolEditorView(appModel: appModel, tool: editingTool).frame(width: 520, height: 360) }
    }
}

struct ToolDetailView: View {
    let tool: FieldTool
    @ObservedObject var appModel: AppModel
    let edit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Text(tool.name).font(.system(size: 32, weight: .semibold, design: .rounded)); Spacer(); Button(L10n.text("Editar"), action: edit).buttonStyle(.bordered) }
                Text(tool.category).foregroundStyle(.tint)
                if let url = URL(string: tool.websiteURL), !tool.websiteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Link(destination: url) { Label(L10n.text("Abrir web de la herramienta"), systemImage: "arrow.up.right.square") }
                }
                DetailSection(title: "La uso para") { Text(tool.uses.isEmpty ? L10n.text("Aún no escrito.") : tool.uses) }
                DetailSection(title: "Funciona bien para") { Text(tool.strengths.isEmpty ? L10n.text("Aún no escrito.") : tool.strengths) }
                DetailSection(title: "Problemas habituales") { Text(tool.weaknesses.isEmpty ? L10n.text("Aún no escritos.") : tool.weaknesses) }
                DetailSection(title: "Notas") { Text(tool.notes.isEmpty ? L10n.text("Aún no escritas.") : tool.notes) }
                DetailSection(title: "Conocimiento conectado") {
                    let items = appModel.repository.knowledge().filter { $0.toolID == tool.id }
                    if items.isEmpty { Text(L10n.text("Aún no hay conocimiento conectado.")).foregroundStyle(.secondary) }
                    else { ForEach(items.prefix(12)) { Text("• \($0.title)") } }
                }
            }.padding(32)
        }
    }
}

struct ToolEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let tool: FieldTool?
    @State private var name: String
    @State private var category: String
    @State private var websiteURL: String
    @State private var uses: String
    @State private var strengths: String
    @State private var weaknesses: String
    @State private var notes: String

    init(appModel: AppModel, tool: FieldTool? = nil) {
        self.appModel = appModel
        self.tool = tool
        _name = State(initialValue: tool?.name ?? "")
        _category = State(initialValue: tool?.category ?? "")
        _websiteURL = State(initialValue: tool?.websiteURL ?? "")
        _uses = State(initialValue: tool?.uses ?? "")
        _strengths = State(initialValue: tool?.strengths ?? "")
        _weaknesses = State(initialValue: tool?.weaknesses ?? "")
        _notes = State(initialValue: tool?.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(tool == nil ? L10n.text("Añadir herramienta") : L10n.text("Editar herramienta")).font(.title2.weight(.semibold)); Spacer(); Button(L10n.text("Cancelar")) { dismiss() } }
            Form {
                TextField(L10n.text("Nombre"), text: $name)
                TextField(L10n.text("Categoría"), text: $category)
                TextField(L10n.text("Web (opcional)"), text: $websiteURL)
                TextField(L10n.text("La uso para"), text: $uses, axis: .vertical)
                TextField(L10n.text("Funciona bien para"), text: $strengths, axis: .vertical)
                TextField(L10n.text("Problemas habituales"), text: $weaknesses, axis: .vertical)
                TextField(L10n.text("Notas"), text: $notes, axis: .vertical)
            }
            HStack { Spacer(); Button(tool == nil ? L10n.text("Guardar herramienta") : L10n.text("Guardar cambios")) { save() }.buttonStyle(.borderedProminent).disabled(name.isEmpty) }
        }.padding(24)
    }

    private func save() {
        let target: FieldTool?
        if let tool {
            target = tool
            tool.name = name
            tool.category = category
            tool.websiteURL = websiteURL
            tool.updatedAt = .now
        } else {
            target = try? appModel.repository.createTool(name: name, category: category)
        }
        guard let target else { return }
        target.websiteURL = websiteURL; target.uses = uses; target.strengths = strengths; target.weaknesses = weaknesses; target.notes = notes
        try? appModel.repository.save()
        appModel.refresh(); dismiss()
    }
}

struct AIInboxView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedID: UUID?
    private var proposals: [AgentProposal] { appModel.repository.proposals(status: .pending) }
    private var selected: AgentProposal? { proposals.first { $0.id == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
                FieldSectionHeader(title: "Bandeja de IA", subtitle: "La memoria permanente siempre pide confirmación.")
            Divider()
            HSplitView {
                List(selection: $selectedID) {
                    if proposals.isEmpty { ContentUnavailableView(L10n.text("Nada pendiente"), systemImage: "checkmark.circle", description: Text(L10n.text("Las propuestas de los agentes aparecerán aquí para revisarlas."))) }
                    else {
                        ForEach(proposals) { proposal in
                            VStack(alignment: .leading, spacing: 4) { Text(proposal.title).font(.headline); Text("\(proposal.agent) · \(L10n.text(proposal.proposalTypeRaw.capitalized))").font(.caption).foregroundStyle(.secondary) }.tag(proposal.id)
                        }
                    }
                }.frame(minWidth: 350)
                if let selected { ProposalDetailView(proposal: selected, appModel: appModel) }
                else { FieldContextHint(systemImage: "tray.and.arrow.down", title: "Elige una propuesta", message: "Revisa lo que un agente quiere conservar antes de convertirlo en memoria.") }
            }
        }
    }
}

struct ProposalDetailView: View {
    let proposal: AgentProposal
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(proposal.title).font(.title.weight(.semibold))
            Text(proposal.content).textSelection(.enabled)
            Text("\(L10n.text("Propuesta de")) \(proposal.agent) · \(proposal.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            HStack {
                Button(L10n.text("Rechazar"), role: .destructive) { try? appModel.repository.reject(proposal); appModel.refresh() }.buttonStyle(.bordered)
                Spacer()
            Button(L10n.text("Aprobar")) {
                if proposal.referenceID != nil {
                    _ = try? appModel.repository.approveReferenceTags(proposal)
                } else {
                    _ = try? appModel.repository.approve(proposal)
                }
                appModel.refresh()
            }
            .buttonStyle(.borderedProminent)
            }
        }.padding(32)
    }
}

struct ActivityView: View {
    @ObservedObject var appModel: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                FieldSectionHeader(title: "Actividad", subtitle: "Acciones en FIELD LAB, nunca razonamiento privado.")
            Divider()
            List {
                ForEach(appModel.repository.activities()) { activity in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "circle.fill").font(.caption2).foregroundStyle(.tint).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 4) { Text(activity.agent).font(.headline); Text(L10n.activityAction(activity.action)).font(.caption).foregroundStyle(.secondary); if !activity.detail.isEmpty { Text(activity.detail).foregroundStyle(.secondary) }; Text(activity.timestamp.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.tertiary) }
                    }.padding(.vertical, 4)
                }
            }
        }
    }
}

struct MCPSettingsView: View {
    @ObservedObject private var mcpServer: MCPServerManager
    @State private var showToken = false
    @State private var copiedItem: String?

    init(appModel: AppModel) {
        _mcpServer = ObservedObject(wrappedValue: appModel.mcpServer)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FieldSectionHeader(title: "Servidor MCP", subtitle: "Un puente de memoria local para Claude, Codex y agentes compatibles.")
                Divider()
                HStack(spacing: 10) {
                    Circle()
                        .fill(mcpServer.isRunning ? .green : mcpServer.lastError == nil ? .secondary : .red)
                        .frame(width: 10, height: 10)
                    Text(serverStatus).font(.headline)
                    Spacer()
                    Text(L10n.text("Solo este Mac · 127.0.0.1"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                DetailSection(title: "Punto de conexión") {
                    HStack {
                        Text(mcpServer.endpoint)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button(copiedItem == L10n.text("endpoint") ? L10n.text("Copiado") : L10n.text("Copiar")) { copy(mcpServer.endpoint, item: "endpoint") }
                            .buttonStyle(.bordered)
                    }
                    Text(L10n.portDescription(mcpServer.port))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !mcpServer.isRunning {
                        Text(mcpServer.isStarting ? L10n.text("Esperando a que termine la selección de puerto…") : L10n.text("Inicia el servidor antes de copiar la configuración; el puerto definitivo aparece al activarse."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DetailSection(title: "Token local") {
                    HStack {
                        Text(showToken ? mcpServer.token : String(repeating: L10n.text("•"), count: 20))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button(showToken ? L10n.text("Ocultar") : L10n.text("Mostrar")) { showToken.toggle() }
                            .buttonStyle(.bordered)
                        Button(copiedItem == L10n.text("token") ? L10n.text("Copiado") : L10n.text("Copiar")) { copy(mcpServer.token, item: "token") }
                            .buttonStyle(.bordered)
                    }
                    Text(mcpServer.usesKeychainHeaderHelper
                         ? L10n.text("Guardado en el Llavero de macOS. Codex y Claude Code lo consultan con un helper local al conectar; macOS puede pedir permiso la primera vez.")
                         : L10n.text("Guardado en el Llavero de macOS. Configura FIELD_MCP_TOKEN en el entorno del cliente MCP."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button {
                        mcpServer.isRunning ? mcpServer.stop() : mcpServer.start()
                    } label: {
                        if mcpServer.isStarting || mcpServer.isStopping {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(mcpServer.isRunning ? L10n.text("Detener servidor") : L10n.text("Iniciar servidor"), systemImage: mcpServer.isRunning ? "stop.fill" : "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(mcpServer.isStarting || mcpServer.isStopping)
                    Button(L10n.text("Regenerar token")) { mcpServer.regenerateToken() }
                        .buttonStyle(.bordered)
                        .disabled(mcpServer.isStarting || mcpServer.isStopping)
                    Spacer()
                    if let copiedItem {
                        Label(L10n.copiedDescription(copiedItem), systemImage: "checkmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(L10n.text("Regenerar el token detiene el servidor para revocar el anterior. Inícialo otra vez antes de reconectar las IA."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let lastError = mcpServer.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                DetailSection(title: "Conectar Codex") {
                    Text(mcpServer.codexSetup).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    Button(copiedItem == L10n.text("Codex") ? L10n.text("Copiado") : L10n.text("Copiar configuración de Codex")) { copy(mcpServer.codexSetup, item: "Codex") }
                        .buttonStyle(.bordered)
                    Text(mcpServer.usesKeychainHeaderHelper
                         ? L10n.text("Codex consulta el Llavero mediante un helper local; el token no queda en config.toml.")
                         : L10n.text("Codex lee FIELD_MCP_TOKEN del entorno del proceso. Reinícialo si acabas de configurar esa variable."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DetailSection(title: "Conectar Claude Code") {
                    Text(mcpServer.claudeCodeSetup)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(copiedItem == L10n.text("Claude Code") ? L10n.text("Copiado") : L10n.text("Copiar configuración de Claude Code")) { copy(mcpServer.claudeCodeSetup, item: "Claude Code") }
                        .buttonStyle(.bordered)
                    Text(mcpServer.usesKeychainHeaderHelper
                         ? L10n.text("Claude Code consulta el Llavero mediante un helper local; verifica el estado con /mcp.")
                         : L10n.text("Claude Code expande FIELD_MCP_TOKEN en su configuración MCP. Comprueba la conexión con /mcp."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DetailSection(title: "Configurar con una IA") {
                    Text(mcpServer.setupPrompt)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(copiedItem == L10n.text("prompt") ? L10n.text("Prompt copiado") : L10n.text("Copiar prompt de configuración")) { copy(mcpServer.setupPrompt, item: "prompt") }
                        .buttonStyle(.bordered)
                }
                DetailSection(title: "Permisos") {
                    PermissionRow(title: "Leer conocimiento", enabled: true)
                    PermissionRow(title: "Buscar conocimiento", enabled: true)
                    PermissionRow(title: "Añadir memoria de trabajo", enabled: true)
                    PermissionRow(title: "Proponer memoria permanente", enabled: true)
                    PermissionRow(title: "Escrituras canónicas directas", enabled: false)
                    PermissionRow(title: "Eliminar conocimiento", enabled: false)
                }
            }.padding(32)
        }
    }

    private var serverStatus: String {
        if mcpServer.isStarting { return L10n.text("MCP server starting") }
        if mcpServer.isStopping { return L10n.text("MCP server stopping") }
        return mcpServer.isRunning ? L10n.text("MCP server active") : L10n.text("MCP server stopped")
    }

    private func copy(_ value: String, item: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string)
        #endif
        copiedItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedItem = nil }
    }
}

struct MenuBarContent: View {
    @ObservedObject var appModel: AppModel
    var body: some View {
        Button(L10n.text("Aprendizaje")) { appModel.presentCapture(kind: .learning) }
        Button(L10n.text("Referencia")) { appModel.presentCapture(kind: .reference) }
        Button(L10n.text("Nota")) { appModel.presentCapture(kind: .note) }
        Divider()
        Button(L10n.text("Abrir FIELD LAB")) { appModel.selectedRoute = .lab }
        Button(L10n.text("Crear prompt")) { appModel.selectedRoute = .learn }
        Button(L10n.text("Ajustes")) { appModel.selectedRoute = .settings }
    }
}

enum FieldPalette {
    static let canvas = Color(red: 0.043, green: 0.039, blue: 0.055)
    static let sidebar = Color(red: 0.055, green: 0.047, blue: 0.071)
    static let surface = Color(red: 0.071, green: 0.059, blue: 0.090)
    static let ink = Color(red: 0.965, green: 0.945, blue: 0.980)
    static let line = Color.white.opacity(0.12)
    static let selected = Color.white.opacity(0.12)
    static let muted = Color(red: 0.15, green: 0.13, blue: 0.18)
    static let accent = Color(red: 0.753, green: 0.518, blue: 0.988)
    static let edgeGlow = Color(red: 0.96, green: 0.853, blue: 0.64)
}

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { Text(L10n.text(title).uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary); content() }
    }
}

struct FlowTags: View {
    let tags: [String]
    var body: some View { HStack(spacing: 6) { ForEach(tags, id: \.self) { Text($0).font(.caption).padding(.horizontal, 8).padding(.vertical, 4).background(.quaternary, in: Capsule()) } } }
}

struct PermissionRow: View {
    let title: String
    let enabled: Bool
    var body: some View { HStack { Image(systemName: enabled ? "checkmark.circle.fill" : "minus.circle").foregroundStyle(enabled ? .green : .secondary); Text(L10n.text(title)); Spacer(); Text(enabled ? L10n.text("Activo") : L10n.text("Desactivado")).font(.caption).foregroundStyle(.secondary) } }
}

struct FieldPageHeader: View {
    let title: String
    let subtitle: String
    let count: Int?
    let actionTitle: String
    let actionSystemImage: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text(title))
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(L10n.text(subtitle))
                        .foregroundStyle(.secondary)
                    if let count {
                        Text(L10n.text("·"))
                            .foregroundStyle(.tertiary)
                        Text(L10n.pluralized(count, singular: "item", plural: "items"))
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.subheadline)
                .lineLimit(2)
            }

            Spacer(minLength: 16)

            if !actionTitle.isEmpty {
                Button(action: action) {
                    Label(L10n.text(actionTitle), systemImage: actionSystemImage)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
    }
}

struct FieldSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.text(title))
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            Text(L10n.text(subtitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
    }
}

struct FieldEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: systemImage)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(.tint)
            }
            .frame(width: 56, height: 56)

            Text(L10n.text(title))
                .font(.title2.weight(.semibold))

            Text(L10n.text(message))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            if let actionTitle, let action {
                Button(L10n.text(actionTitle), action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct FieldContextHint: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(L10n.text(title))
                .font(.headline)
            Text(L10n.text(message))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
