import FieldCore
import PhotosUI
import SwiftData
import SwiftUI

enum CaptureRoute: Identifiable {
    case reference(String?)
    case knowledge(KnowledgeKind)
    case experiment
    case experimentFromRecipe(KnowledgeItem)
    case editReference(FieldReference)
    case editKnowledge(KnowledgeItem)
    case editExperiment(FieldExperiment)

    var id: String {
        switch self {
        case .reference: "reference"
        case .knowledge(let kind): "knowledge-\(kind.rawValue)"
        case .experiment: "experiment"
        case .experimentFromRecipe(let item): "experiment-recipe-\(item.id)"
        case .editReference(let reference): "edit-reference-\(reference.id)"
        case .editKnowledge(let item): "edit-knowledge-\(item.id)"
        case .editExperiment(let experiment): "edit-experiment-\(experiment.id)"
        }
    }

    var title: String {
        switch self {
        case .reference: L10n.text("Nueva referencia")
        case .knowledge(.learning): L10n.text("Nuevo aprendizaje")
        case .knowledge(.promptBlock): L10n.text("Nuevo bloque de prompt")
        case .knowledge(.recipe): L10n.text("Nueva") + " " + L10n.text("Receta").lowercased()
        case .knowledge(.note): L10n.text("Nueva") + " " + L10n.text("Nota").lowercased()
        case .knowledge(.decision): L10n.text("Nueva") + " " + L10n.text("Decisión").lowercased()
        case .knowledge(.style): L10n.text("Nuevo") + " " + L10n.text("Estilo").lowercased()
        case .knowledge(let kind): newKnowledgeTitle(for: kind)
        case .experiment: L10n.text("Nuevo") + " " + L10n.text("Experimento").lowercased()
        case .experimentFromRecipe: L10n.text("Experimento desde receta")
        case .editReference: L10n.text("Editar referencia")
        case .editKnowledge: L10n.text("Editar conocimiento")
        case .editExperiment: L10n.text("Editar experimento")
        }
    }

    private func newKnowledgeTitle(for kind: KnowledgeKind) -> String {
        let masculineKinds: Set<KnowledgeKind> = [.learning, .promptBlock, .resource, .sessionSummary, .flow]
        let prefix = L10n.text(masculineKinds.contains(kind) ? "Nuevo" : "Nueva")
        return "\(prefix) \(L10n.text(kind.displayName).lowercased())"
    }

    var isReference: Bool {
        switch self {
        case .reference, .editReference: true
        default: false
        }
    }

    var defaultURL: String? {
        if case .reference(let url) = self { return url }
        return nil
    }
}

struct CaptureComposer: View {
    let route: CaptureRoute
    @Query(sort: \FieldProject.title) private var projects: [FieldProject]
    @Query(sort: \FieldTool.name) private var tools: [FieldTool]
    @Query(sort: \FieldReference.updatedAt, order: .reverse) private var references: [FieldReference]
    @Query(sort: \KnowledgeItem.updatedAt, order: .reverse) private var knowledgeItems: [KnowledgeItem]
    @EnvironmentObject private var appModel: MobileAppModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @State private var title = ""
    @State private var autoSuggestedTitle: String?
    @State private var bodyText = ""
    @State private var urlText = ""
    @State private var tagsText = ""
    @State private var promptText = ""
    @State private var conclusionText = ""
    @State private var selectedProjectID: UUID?
    @State private var selectedReferenceProjectIDs = Set<UUID>()
    @State private var selectedExperimentReferenceIDs = Set<UUID>()
    @State private var selectedExperimentPromptBlockIDs = Set<UUID>()
    @State private var experimentSettings: [SettingEntry] = []
    @State private var experimentExecutionMode: ExperimentExecutionMode = .external
    @State private var selectedToolID: UUID?
    @State private var modelText = ""
    @State private var experimentStatus: ExperimentStatus = .testing
    @State private var knowledgeStatus: KnowledgeStatus = .new
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isRemovingImage = false
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var saveError: String?
    @State private var isSaving = false

    private var titlePlaceholder: String {
        switch route {
        case .reference, .editReference: "¿Qué quieres recordar?"
        case .knowledge(.learning): "¿Qué has aprendido?"
        case .knowledge(.promptBlock): "Nombre del bloque"
        case .knowledge(.recipe): "Nombre de la receta"
        case .editKnowledge(let item) where item.kind == .recipe: "Nombre de la receta"
        case .knowledge, .editKnowledge: "Título"
        case .experiment, .experimentFromRecipe, .editExperiment: "Nombre de la prueba"
        }
    }

    private var bodyPlaceholder: String {
        switch route {
        case .reference, .editReference: "Añade una nota para explicar por qué te interesa…"
        case .knowledge(.recipe): "Escribe el prompt de la receta…"
        case .editKnowledge(let item) where item.kind == .recipe: "Escribe el prompt de la receta…"
        case .knowledge, .editKnowledge: "Escribe los detalles que quieras conservar…"
        case .experiment, .experimentFromRecipe, .editExperiment: "¿Qué quieres probar?"
        }
    }

    var body: some View {
        let photoPickerTitle = isLoadingPhoto ? "Cargando imagen…" : imageData == nil ? "Añadir imagen" : "Cambiar imagen"
        let photoPickerSymbol = isLoadingPhoto ? "hourglass" : "photo"

        NavigationStack {
            Form {
                Section {
                    TextField(L10n.text(titlePlaceholder), text: $title, axis: .vertical)
                        .font(.title3.weight(.medium))
                        .lineLimit(1...3)
                        .focused($titleFocused)

                    if route.isReference {
                        TextField(L10n.text("Pega un enlace"), text: $urlText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: urlText) { _, newValue in
                                guard isCreatingReference else { return }
                                let currentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard currentTitle.isEmpty || currentTitle == autoSuggestedTitle else { return }
                                let suggestion = suggestedReferenceTitle(for: newValue)
                                title = suggestion ?? ""
                                autoSuggestedTitle = suggestion
                            }
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(L10n.text(photoPickerTitle), systemImage: photoPickerSymbol)
                        }
                        .disabled(isLoadingPhoto)
                        .onChange(of: selectedPhoto) { _, selection in
                            guard let selection else { return }
                            Task {
                                isLoadingPhoto = true
                                isRemovingImage = false
                                defer { isLoadingPhoto = false }
                                do {
                                    guard let loadedImage = try await selection.loadTransferable(type: Data.self) else {
                                        photoError = L10n.text("No se pudo leer la imagen seleccionada.")
                                        return
                                    }
                                    imageData = loadedImage
                                    photoError = nil
                                } catch {
                                    photoError = L10n.format("No se pudo cargar la imagen: %@", error.localizedDescription)
                                }
                            }
                        }
                        if isLoadingPhoto {
                            ProgressView(L10n.text("Preparando imagen"))
                        }
                        if imageData != nil {
                            Label(L10n.text("Imagen preparada"), systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let photoError {
                            Label(photoError, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        if case let .editReference(reference) = route,
                           imageData != nil || reference.thumbnailData != nil {
                            Button(L10n.text("Quitar imagen"), systemImage: "trash", role: .destructive) {
                                imageData = nil
                                selectedPhoto = nil
                                isRemovingImage = true
                                photoError = nil
                            }
                            .disabled(isLoadingPhoto)
                        }
                    }

                    if isKnowledgeRoute {
                        TextField(L10n.text("Enlace (opcional)"), text: $urlText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    TextField(L10n.text(bodyPlaceholder), text: $bodyText, axis: .vertical)
                        .lineLimit(4...10)

                    if isRecipeRoute && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(L10n.text("Una receta necesita un prompt para poder crear un experimento."), systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if route.isReference || isKnowledgeRoute {
                        TextField(L10n.text("Etiquetas, separadas por comas"), text: $tagsText)
                    }

                    if isExperimentRoute {
                        TextField(L10n.text("Prompt (opcional)"), text: $promptText, axis: .vertical)
                            .lineLimit(3...8)
                            .font(.body.monospaced())
                        if isEditingExperiment {
                            TextField(L10n.text("Conclusión"), text: $conclusionText, axis: .vertical)
                                .lineLimit(3...8)
                            Picker(L10n.text("Estado"), selection: $experimentStatus) {
                                ForEach(ExperimentStatus.allCases, id: \.rawValue) { status in
                                    Text(L10n.text(status.displayName)).tag(status)
                                }
                            }
                        }
                    }

                    if isEditingKnowledge {
                        Picker(L10n.text("Estado"), selection: $knowledgeStatus) {
                            ForEach(KnowledgeStatus.allCases, id: \.rawValue) { status in
                                Text(L10n.text(status.displayName)).tag(status)
                            }
                        }
                    }
                } header: {
                    Text(L10n.text(sectionTitle))
                }

                if showsContextFields {
                    Section(L10n.text("Contexto")) {
                        if route.isReference, !contextProjects.isEmpty {
                            Menu {
                                ForEach(contextProjects) { project in
                                    let isSelected = selectedReferenceProjectIDs.contains(project.id)
                                    Button {
                                        if isSelected {
                                            selectedReferenceProjectIDs.remove(project.id)
                                        } else {
                                            selectedReferenceProjectIDs.insert(project.id)
                                        }
                                    } label: {
                                        Label(project.title, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                                    }
                                }
                            } label: {
                                let selectedNames = selectedReferenceProjectNames
                                LabeledContent(L10n.text("Proyectos"), value: selectedNames.count == 1 ? selectedNames[0] : selectedNames.isEmpty ? L10n.text("Sin proyecto") : "\(selectedNames.count) \(L10n.text("proyectos"))")
                            }
                        } else if !route.isReference, !contextProjects.isEmpty {
                            Picker(L10n.text("Proyecto"), selection: $selectedProjectID) {
                                Text(L10n.text("Sin proyecto")).tag(nil as UUID?)
                                ForEach(contextProjects) { project in
                                    Text(project.archived ? "\(project.title) · \(L10n.text("Archivado"))" : project.title)
                                        .tag(Optional(project.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        if !tools.isEmpty {
                            Picker(L10n.text("Herramienta"), selection: $selectedToolID) {
                                Text(L10n.text("Sin herramienta")).tag(nil as UUID?)
                                ForEach(tools) { tool in
                                    Text(tool.name).tag(Optional(tool.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        if needsModel {
                            TextField(L10n.text("Modelo (opcional)"), text: $modelText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                }

                if isExperimentRoute {
                    Section(L10n.text("Configuración de cada run")) {
                        Text(L10n.text("Al añadir un bloque, su texto se suma al prompt. Quitar el vínculo conserva el texto insertado."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Menu {
                            if selectableExperimentReferences.isEmpty {
                                Text(L10n.text("Guarda referencias desde Recopilar para vincularlas aquí."))
                            } else {
                                ForEach(selectableExperimentReferences) { reference in
                                    let isSelected = selectedExperimentReferenceIDs.contains(reference.id)
                                    let title = reference.archived ? "\(reference.title) · \(L10n.text("Archivada"))" : reference.title
                                    Button {
                                        if isSelected {
                                            selectedExperimentReferenceIDs.remove(reference.id)
                                        } else {
                                            selectedExperimentReferenceIDs.insert(reference.id)
                                        }
                                    } label: {
                                        Label(title, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                                    }
                                }
                            }
                        } label: {
                            LabeledContent(
                                L10n.text("Referencias"),
                                value: selectionCount(
                                    selectedExperimentReferenceIDs.count,
                                    empty: "Ninguna",
                                    one: "seleccionada",
                                    many: "seleccionadas"
                                )
                            )
                        }

                        Menu {
                            if selectablePromptBlocks.isEmpty {
                                Text(L10n.text("Crea bloques de prompt desde Aprender para vincularlos aquí."))
                            } else {
                                ForEach(selectablePromptBlocks) { block in
                                    let isSelected = selectedExperimentPromptBlockIDs.contains(block.id)
                                    let title = block.status == .archived ? "\(block.title) · \(L10n.text("Archivado"))" : block.title
                                    Button {
                                        if isSelected {
                                            selectedExperimentPromptBlockIDs.remove(block.id)
                                        } else {
                                            selectedExperimentPromptBlockIDs.insert(block.id)
                                            appendPromptBlock(block.body)
                                        }
                                    } label: {
                                        Label(title, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                                    }
                                }
                            }
                        } label: {
                            LabeledContent(
                                L10n.text("Bloques de prompt"),
                                value: selectionCount(
                                    selectedExperimentPromptBlockIDs.count,
                                    empty: "Ninguno",
                                    one: "seleccionado",
                                    many: "seleccionados"
                                )
                            )
                        }

                        if experimentSettings.isEmpty {
                            Text(L10n.text("Añade parámetros que quieras conservar en cada resultado."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        ForEach($experimentSettings) { $setting in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField(L10n.text("Parámetro"), text: $setting.key)
                                    TextField(L10n.text("Valor"), text: $setting.value)
                                    TextField(L10n.text("Unidad"), text: Binding(get: { setting.unit ?? "" }, set: { setting.unit = $0.isEmpty ? nil : $0 }))
                                }
                                Button(L10n.text("Eliminar ajuste"), systemImage: "trash", role: .destructive) {
                                    let settingID = setting.id
                                    experimentSettings.removeAll { $0.id == settingID }
                                }
                                .labelStyle(.iconOnly)
                            }
                        }
                        Button(L10n.text("Añadir ajuste"), systemImage: "plus") {
                            experimentSettings.append(SettingEntry(key: "", value: ""))
                        }
                    }
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(L10n.text(route.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Cancelar")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Guardar")) { save() }
                        .disabled(
                            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || (isRecipeRoute && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                || isSaving
                                || isLoadingPhoto
                        )
                }
            }
            .task {
                if let defaultURL = route.defaultURL {
                    urlText = defaultURL
                    let suggestion = suggestedReferenceTitle(for: defaultURL)
                    title = suggestion ?? ""
                    autoSuggestedTitle = suggestion
                }
                switch route {
                case .editReference(let reference):
                    title = reference.title
                    bodyText = reference.userNote
                    urlText = reference.sourceURL
                    tagsText = reference.manualTags.joined(separator: ", ")
                    imageData = reference.imageData
                    selectedReferenceProjectIDs = Set(reference.projectIDs)
                case .editKnowledge(let item):
                    title = item.title
                    bodyText = item.body
                    urlText = item.urlString
                    tagsText = item.tags.joined(separator: ", ")
                    knowledgeStatus = item.status
                    selectedProjectID = item.projectID
                    selectedToolID = item.toolID ?? appModel.repository.recipePayload(item)?.toolID
                    modelText = appModel.repository.recipePayload(item)?.model ?? ""
                case .editExperiment(let experiment):
                    title = experiment.title
                    bodyText = experiment.goal
                    promptText = experiment.prompt
                    conclusionText = experiment.conclusion
                    experimentStatus = experiment.status
                    selectedProjectID = experiment.projectID
                    selectedToolID = experiment.toolID
                    modelText = experiment.model
                    selectedExperimentReferenceIDs = Set(experiment.referenceIDs)
                    selectedExperimentPromptBlockIDs = Set(experiment.promptBlockIDs)
                    experimentSettings = experiment.settingsEntries
                    experimentExecutionMode = experiment.executionMode
                case .experimentFromRecipe(let item):
                    title = item.title
                    bodyText = L10n.format("Prueba de la receta «%@».", item.title)
                    let payload = appModel.repository.recipePayload(item)
                    promptText = payload?.prompt ?? ""
                    selectedProjectID = item.projectID
                    selectedToolID = payload?.toolID ?? item.toolID
                    modelText = payload?.model ?? ""
                    selectedExperimentReferenceIDs = Set(payload?.references ?? [])
                    selectedExperimentPromptBlockIDs = Set(payload?.promptBlockIDs ?? [])
                    experimentSettings = payload?.settings ?? []
                case .reference, .knowledge, .experiment:
                    break
                }
                try? await Task.sleep(for: .milliseconds(350))
                titleFocused = true
            }
        }
    }

    private var sectionTitle: String {
        switch route {
        case .reference, .editReference: "REFERENCIA"
        case .knowledge, .editKnowledge: "CONOCIMIENTO"
        case .experiment, .experimentFromRecipe, .editExperiment: "LABORATORIO"
        }
    }

    private var isKnowledgeRoute: Bool {
        switch route {
        case .knowledge, .editKnowledge: true
        default: false
        }
    }

    private var isExperimentRoute: Bool {
        switch route {
        case .experiment, .experimentFromRecipe, .editExperiment: true
        default: false
        }
    }

    private var isEditingExperiment: Bool {
        if case .editExperiment = route { return true }
        return false
    }

    private var isEditingKnowledge: Bool {
        if case .editKnowledge = route { return true }
        return false
    }

    private var isRecipeRoute: Bool {
        switch route {
        case .knowledge(.recipe): true
        case .editKnowledge(let item): item.kind == .recipe
        default: false
        }
    }

    private var isCreatingReference: Bool {
        if case .reference = route { return true }
        return false
    }

    private func suggestedReferenceTitle(for rawURL: String) -> String? {
        let normalizedURL = ReferenceSourceResolver.normalize(rawURL)
        guard let host = URLComponents(string: normalizedURL)?.host else { return nil }
        let title = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return title.isEmpty ? nil : title
    }

    private var showsContextFields: Bool {
        route.isReference || isKnowledgeRoute || isExperimentRoute
    }

    private var needsModel: Bool {
        isRecipeRoute || isExperimentRoute
    }

    private var contextProjects: [FieldProject] {
        projects.filter { project in
            guard project.archived else { return true }
            let singleSelectionMatches = selectedProjectID.map { $0 == project.id } ?? false
            return singleSelectionMatches || selectedReferenceProjectIDs.contains(project.id)
        }
    }

    private var selectedReferenceProjectNames: [String] {
        contextProjects
            .filter { selectedReferenceProjectIDs.contains($0.id) }
            .map { $0.archived ? "\($0.title) · \(L10n.text("Archivado"))" : $0.title }
    }

    private var referenceProjectIDsForSave: [UUID] {
        contextProjects.filter { selectedReferenceProjectIDs.contains($0.id) }.map(\.id)
    }

    private var selectableExperimentReferences: [FieldReference] {
        references.filter { !$0.archived || selectedExperimentReferenceIDs.contains($0.id) }
    }

    private var selectablePromptBlocks: [KnowledgeItem] {
        knowledgeItems.filter {
            $0.kind == .promptBlock
                && ($0.status != .archived || selectedExperimentPromptBlockIDs.contains($0.id))
        }
    }

    private var experimentReferenceIDsForSave: [UUID] {
        orderedSelectedIDs(selectedExperimentReferenceIDs, from: selectableExperimentReferences.map(\.id))
    }

    private var experimentPromptBlockIDsForSave: [UUID] {
        orderedSelectedIDs(selectedExperimentPromptBlockIDs, from: selectablePromptBlocks.map(\.id))
    }

    private func orderedSelectedIDs(_ selectedIDs: Set<UUID>, from availableIDs: [UUID]) -> [UUID] {
        let selectedInDisplayOrder = availableIDs.filter { selectedIDs.contains($0) }
        let unresolved = selectedIDs.subtracting(selectedInDisplayOrder)
            .sorted { $0.uuidString < $1.uuidString }
        return selectedInDisplayOrder + unresolved
    }

    private func selectionCount(_ count: Int, empty: String, one: String, many: String) -> String {
        guard count > 0 else { return L10n.text(empty) }
        return "\(count) \(L10n.text(count == 1 ? one : many))"
    }

    private func appendPromptBlock(_ blockBody: String) {
        let block = blockBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !block.isEmpty else { return }
        let existingBlocks = promptText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !existingBlocks.contains(block) else { return }
        let currentPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        promptText = [currentPrompt, block].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private var projectIDForSave: UUID? {
        guard let selectedProjectID,
              projects.contains(where: { $0.id == selectedProjectID }) else { return nil }
        return selectedProjectID
    }

    private var toolIDForSave: UUID? {
        guard let selectedToolID,
              tools.contains(where: { $0.id == selectedToolID }) else { return nil }
        return selectedToolID
    }

    private func save() {
        isSaving = true
        saveError = nil
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectID = projectIDForSave
        let toolID = toolIDForSave
        let scope: KnowledgeScope = projectID == nil ? .global : .project
        do {
            switch route {
            case .reference:
                _ = try appModel.repository.createReference(
                    title: cleanTitle,
                    userNote: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                    urlString: urlText.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageData: imageData,
                    projectIDs: referenceProjectIDsForSave,
                    tags: tags
                )
            case .editReference(let reference):
                reference.title = cleanTitle
                reference.userNote = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanURL != reference.sourceURL {
                    reference.source = ReferenceSourceResolver.resolve(urlString: cleanURL)
                }
                reference.manualTags = tags
                reference.projectIDs = referenceProjectIDsForSave
                if isRemovingImage {
                    reference.imageData = nil
                    reference.thumbnailData = nil
                } else if let imageData {
                    reference.imageData = imageData
                    reference.thumbnailData = nil
                }
                try appModel.repository.updateReference(reference)
            case .knowledge(let kind):
                let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
                if kind == .recipe {
                    _ = try appModel.repository.createRecipe(
                        title: cleanTitle,
                        prompt: cleanBody,
                        scope: scope,
                        projectID: projectID,
                        toolID: toolID,
                        model: modelText.trimmingCharacters(in: .whitespacesAndNewlines),
                        tags: tags,
                        urlString: urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                } else {
                    _ = try appModel.repository.createKnowledge(
                        kind: kind,
                        title: cleanTitle,
                        body: cleanBody,
                        status: .new,
                        scope: scope,
                        projectID: projectID,
                        toolID: toolID,
                        tags: tags,
                        urlString: urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            case .editKnowledge(let item):
                item.title = cleanTitle
                item.body = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
                item.urlString = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                item.tags = tags
                item.status = knowledgeStatus
                item.projectID = projectID
                item.scope = scope
                item.toolID = toolID
                if item.kind == .recipe {
                    try appModel.repository.updateRecipePrompt(
                        item,
                        prompt: item.body,
                        toolID: toolID,
                        model: modelText.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                } else {
                    try appModel.repository.updateKnowledge(item)
                }
            case .experiment:
                _ = try appModel.repository.createExperiment(
                    title: cleanTitle,
                    goal: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                    prompt: promptText.trimmingCharacters(in: .whitespacesAndNewlines),
                    toolID: toolID,
                    projectID: projectID,
                    model: modelText.trimmingCharacters(in: .whitespacesAndNewlines),
                    referenceIDs: experimentReferenceIDsForSave,
                    settings: experimentSettings.filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                    promptBlockIDs: experimentPromptBlockIDsForSave,
                    executionMode: experimentExecutionMode
                )
            case .experimentFromRecipe(let recipe):
                _ = try appModel.repository.createExperiment(
                    from: recipe,
                    title: cleanTitle,
                    goal: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                    prompt: promptText.trimmingCharacters(in: .whitespacesAndNewlines),
                    projectID: projectID,
                    toolID: toolID,
                    model: modelText.trimmingCharacters(in: .whitespacesAndNewlines),
                    referenceIDs: experimentReferenceIDsForSave,
                    settings: experimentSettings.filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                    promptBlockIDs: experimentPromptBlockIDsForSave,
                    executionMode: experimentExecutionMode
                )
            case .editExperiment(let experiment):
                experiment.title = cleanTitle
                experiment.goal = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
                experiment.prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
                experiment.conclusion = conclusionText.trimmingCharacters(in: .whitespacesAndNewlines)
                experiment.status = experimentStatus
                experiment.projectID = projectID
                experiment.toolID = toolID
                experiment.model = modelText.trimmingCharacters(in: .whitespacesAndNewlines)
                experiment.referenceIDs = experimentReferenceIDsForSave
                experiment.settingsEntries = experimentSettings.filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                experiment.promptBlockIDs = experimentPromptBlockIDsForSave
                experiment.executionMode = experimentExecutionMode
                try appModel.repository.updateExperiment(experiment)
            }
            dismiss()
        } catch {
            isSaving = false
            saveError = L10n.format("No se pudo guardar: %@", error.localizedDescription)
        }
    }

    private var tags: [String] {
        tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
