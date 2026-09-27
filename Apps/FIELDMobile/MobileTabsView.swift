import FieldCore
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct MobileTabsView: View {
    @EnvironmentObject private var appModel: MobileAppModel

    var body: some View {
        TabView {
            NavigationStack {
                CollectView()
            }
            .tabItem { Label("Recopilar", systemImage: "photo.on.rectangle.angled") }

            NavigationStack {
                LabView()
            }
            .tabItem { Label("Laboratorio", systemImage: "rectangle.split.3x1") }

            NavigationStack {
                LearnView()
            }
            .tabItem { Label("Aprender", systemImage: "lightbulb") }
        }
        .sheet(item: $appModel.presentedSheet) { sheet in
            Group {
                switch sheet {
                case .capture(let route):
                    CaptureComposer(route: route)
                case .search:
                    GlobalSearchView()
                case .settings:
                    CloudSyncSettingsView()
                }
            }
            .presentationDetents(sheet.isSearch ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

struct MobileToolbar: ToolbarContent {
    @EnvironmentObject private var appModel: MobileAppModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                appModel.presentSearch()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Buscar en FIELD")

            Menu {
                Button("Referencia", systemImage: "link") {
                    appModel.presentCapture(.reference(nil))
                }
                Button("Aprendizaje", systemImage: "lightbulb") {
                    appModel.presentCapture(.knowledge(.learning))
                }
                Button("Nota", systemImage: "note.text") {
                    appModel.presentCapture(.knowledge(.note))
                }
                Button("Bloque de prompt", systemImage: "text.quote") {
                    appModel.presentCapture(.knowledge(.promptBlock))
                }
                Button("Receta", systemImage: "list.bullet.rectangle") {
                    appModel.presentCapture(.knowledge(.recipe))
                }
                Button("Decisión", systemImage: "checkmark.seal") {
                    appModel.presentCapture(.knowledge(.decision))
                }
                Button("Estilo", systemImage: "paintpalette") {
                    appModel.presentCapture(.knowledge(.style))
                }
                Button("Experimento", systemImage: "testtube.2") {
                    appModel.presentCapture(.experiment)
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Crear en FIELD")

            let syncNeedsAttention = appModel.cloudAccountState != .available
            Button {
                appModel.presentSettings()
            } label: {
                Image(systemName: "gearshape")
                    .overlay(alignment: .topTrailing) {
                        if syncNeedsAttention {
                            Image(systemName: appModel.cloudAccountState.symbol)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.orange)
                                .padding(2)
                                .background(.background, in: Circle())
                                .offset(x: 5, y: -5)
                        }
                    }
            }
            .accessibilityLabel(syncNeedsAttention ? "Ajustes. \(appModel.cloudAccountState.title)" : "Ajustes")
        }
    }
}

struct CollectView: View {
    @Query(sort: \FieldReference.updatedAt, order: .reverse) private var references: [FieldReference]
    @Query(sort: \FieldProject.title) private var projects: [FieldProject]
    @Query(sort: \FieldTool.name) private var tools: [FieldTool]
    @EnvironmentObject private var appModel: MobileAppModel
    @State private var searchText = ""
    @State private var showArchived = false

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var visibleReferences: [FieldReference] {
        let matchingArchiveState = references.filter { $0.archived == showArchived }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return matchingArchiveState }
        let projectNamesByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.title) })
        let toolNamesByID = Dictionary(uniqueKeysWithValues: tools.map { ($0.id, $0.name) })
        return matchingArchiveState.filter {
            let attributes = $0.visualAttributes.map { "\($0.category.displayName) \($0.name)" }.joined(separator: " ")
            let contextNames = $0.projectIDs.compactMap { projectNamesByID[$0] }
                + $0.toolIDs.compactMap { toolNamesByID[$0] }
            return mobileSearchMatches(query, in: [
                $0.title,
                $0.userNote,
                $0.ocrText,
                $0.sourceName,
                $0.sourceDomain,
                $0.sourceURL,
                $0.manualTagsRaw,
                $0.automaticTagsRaw,
                attributes
            ] + contextNames)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Colección", selection: $showArchived) {
                    Text("Activas").tag(false)
                    Text("Archivadas").tag(true)
                }
                .pickerStyle(.segmented)
            }
            .listSectionSeparator(.hidden)

            if visibleReferences.isEmpty {
                ContentUnavailableView {
                    Label(showArchived ? "No hay referencias archivadas" : "Tu colección empieza aquí", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text(hasSearchQuery
                         ? "No hay referencias que coincidan con la búsqueda."
                         : showArchived
                            ? "Las referencias archivadas aparecerán aquí y podrás restaurarlas cuando quieras."
                            : "Guarda imágenes, enlaces e ideas que quieras volver a encontrar. También puedes enviar contenido desde el menú Compartir de otras apps.")
                } actions: {
                    if !hasSearchQuery && !showArchived {
                        Button("Guardar una referencia") { appModel.presentCapture(.reference(nil)) }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(.black)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(visibleReferences) { reference in
                        NavigationLink {
                            ReferenceDetailView(reference: reference)
                        } label: {
                            ReferenceRow(reference: reference)
                        }
                    }
                } header: {
                    Text("Referencias · \(visibleReferences.count)")
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Recopilar")
        .searchable(text: $searchText, prompt: "Buscar referencias")
        .toolbar { MobileToolbar() }
    }
}

private struct ReferenceRow: View {
    let reference: FieldReference

    var body: some View {
        HStack(spacing: 14) {
            ReferenceThumbnail(data: reference.thumbnailData ?? reference.imageData)
                .frame(width: 64, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(reference.title.isEmpty ? "Sin título" : reference.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !reference.userNote.isEmpty {
                    Text(reference.userNote)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(reference.sourceDomain.isEmpty ? reference.source.name : reference.sourceDomain)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if reference.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Fijada")
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

struct ReferenceThumbnail: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .tertiarySystemGroupedBackground)
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct ReferenceDetailView: View {
    let reference: FieldReference
    @EnvironmentObject private var appModel: MobileAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var actionError: String?
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        List {
            if let data = reference.imageData ?? reference.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(reference.title.isEmpty ? "Imagen de referencia" : "Imagen de \(reference.title)")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("Origen", value: reference.sourceName.isEmpty ? "Manual" : reference.sourceName)
                if !reference.sourceURL.isEmpty, let url = URL(string: reference.sourceURL) {
                    Link(reference.sourceDomain.isEmpty ? reference.sourceURL : reference.sourceDomain, destination: url)
                }
                if !reference.userNote.isEmpty {
                    Text(reference.userNote)
                        .textSelection(.enabled)
                }
            }

            if !reference.manualTags.isEmpty {
                Section("Etiquetas") {
                    Text(reference.manualTags.joined(separator: " · "))
                }
            }

            Section {
                LabeledContent("Añadida", value: reference.createdAt.formatted(date: .abbreviated, time: .omitted))
                Button(reference.pinned ? "Quitar de fijadas" : "Fijar referencia", systemImage: reference.pinned ? "pin.slash" : "pin") {
                    reference.pinned.toggle()
                    do {
                        try appModel.repository.updateReference(reference)
                    } catch {
                        reference.pinned.toggle()
                        actionError = "No se pudo actualizar la referencia: \(error.localizedDescription)"
                    }
                }
                Button(reference.archived ? "Restaurar referencia" : "Archivar referencia", systemImage: reference.archived ? "tray.and.arrow.up" : "archivebox") {
                    reference.archived.toggle()
                    do {
                        try appModel.repository.updateReference(reference)
                    } catch {
                        reference.archived.toggle()
                        actionError = "No se pudo actualizar la referencia: \(error.localizedDescription)"
                    }
                }
            }
        }
        .navigationTitle(reference.title.isEmpty ? "Referencia" : reference.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: reference.sourceURL.isEmpty ? reference.title : reference.sourceURL)
                    Button("Editar", systemImage: "pencil") {
                        appModel.presentCapture(.editReference(reference))
                    }
                    Button("Eliminar", systemImage: "trash", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Más opciones")
            }
        }
        .alert("No se pudo completar la acción", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("Aceptar", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "Inténtalo de nuevo.")
        }
        .confirmationDialog("¿Eliminar esta referencia?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("Eliminar referencia", role: .destructive) {
                do {
                    try appModel.repository.deleteReference(reference)
                    dismiss()
                } catch {
                    actionError = "No se pudo eliminar la referencia: \(error.localizedDescription)"
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
}

struct LabView: View {
    @Query(sort: \FieldExperiment.updatedAt, order: .reverse) private var experiments: [FieldExperiment]
    @Query(sort: \FieldProject.title) private var projects: [FieldProject]
    @Query(sort: \FieldTool.name) private var tools: [FieldTool]
    @EnvironmentObject private var appModel: MobileAppModel
    @State private var searchText = ""
    @State private var showArchived = false

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var visibleExperiments: [FieldExperiment] {
        let matchingArchiveState = experiments.filter { ($0.status == .archived) == showArchived }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return matchingArchiveState }
        let projectNamesByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.title) })
        let toolNamesByID = Dictionary(uniqueKeysWithValues: tools.map { ($0.id, $0.name) })
        return matchingArchiveState.filter {
            let contextNames = [$0.projectID.flatMap { projectNamesByID[$0] }, $0.toolID.flatMap { toolNamesByID[$0] }].compactMap { $0 }
            return mobileSearchMatches(query, in: [$0.title, $0.goal, $0.prompt, $0.model, $0.conclusion] + contextNames)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Experimentos", selection: $showArchived) {
                    Text("Activos").tag(false)
                    Text("Archivados").tag(true)
                }
                .pickerStyle(.segmented)
            }
            .listSectionSeparator(.hidden)

            if visibleExperiments.isEmpty {
                ContentUnavailableView {
                    Label(showArchived ? "No hay experimentos archivados" : "Prueba una idea", systemImage: "rectangle.split.3x1")
                } description: {
                    Text(hasSearchQuery
                         ? "No hay experimentos que coincidan con la búsqueda."
                         : showArchived
                            ? "Los experimentos archivados aparecerán aquí. Puedes restaurarlos desde Editar."
                            : "El Laboratorio guarda tus experimentos y conclusiones junto a la biblioteca.")
                } actions: {
                    if !hasSearchQuery && !showArchived {
                        Button("Crear experimento") { appModel.presentCapture(.experiment) }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(.black)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(visibleExperiments) { experiment in
                        NavigationLink {
                            ExperimentDetailView(experiment: experiment)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(experiment.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(experiment.status.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !experiment.goal.isEmpty {
                                    Text(experiment.goal)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Text(experiment.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Experimentos · \(visibleExperiments.count)")
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Laboratorio")
        .searchable(text: $searchText, prompt: "Buscar experimentos")
        .toolbar { MobileToolbar() }
    }
}

struct ExperimentDetailView: View {
    let experiment: FieldExperiment
    @Query(sort: \FieldExperimentRun.order) private var allRuns: [FieldExperimentRun]
    @EnvironmentObject private var appModel: MobileAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var actionError: String?
    @State private var isDeleteConfirmationPresented = false

    private var runs: [FieldExperimentRun] {
        allRuns.filter { $0.experimentID == experiment.id }
    }

    private var setup: ExperimentSetup {
        appModel.repository.experimentSetup(experiment)
    }

    private var projectTitle: String? {
        guard let projectID = experiment.projectID else { return nil }
        let project = appModel.repository.projects(includeArchived: true).first { $0.id == projectID }
        guard let project else { return nil }
        return project.archived ? "\(project.title) · Archivado" : project.title
    }

    var body: some View {
        List {
            Section("Objetivo") {
                Text(experiment.goal.isEmpty ? "Añade el propósito de esta prueba." : experiment.goal)
                    .foregroundStyle(experiment.goal.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
            }

            if let projectTitle {
                Section("Proyecto") {
                    Text(projectTitle)
                }
            }

            MobileSetupSection(title: "Configuración", snapshot: MobileSetupSnapshot(setup: setup))

            if !experiment.prompt.isEmpty {
                Section("Prompt") {
                    Text(experiment.prompt)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                    ShareLink(item: experiment.prompt) {
                        Label("Compartir prompt", systemImage: "square.and.arrow.up")
                    }
                }
            }

            if !experiment.conclusion.isEmpty {
                Section("Conclusión") {
                    Text(experiment.conclusion)
                        .textSelection(.enabled)
                }
            }

            Section {
                if runs.isEmpty {
                    Text("Aún no hay resultados. Crea un run para guardar una copia del prompt y empezar a anotar el resultado.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(runs) { run in
                        NavigationLink {
                            ExperimentRunDetailView(run: run)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(run.title)
                                        .font(.body.weight(.medium))
                                    Spacer()
                                    if run.evaluation == .best {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                            .accessibilityLabel("Mejor resultado")
                                    }
                                }
                                Text("\(run.resultStatus.displayName) · \(run.evaluation.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !run.observation.isEmpty {
                                    Text(run.observation)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                Button("Crear run", systemImage: "plus.circle") {
                    do {
                        _ = try appModel.repository.createRunFromSetup(experiment: experiment)
                    } catch {
                        actionError = "No se pudo crear el run: \(error.localizedDescription)"
                    }
                }
            } header: {
                Text("Resultados · \(runs.count)")
            }
            let hasConclusion = !experiment.conclusion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasBestRun = experiment.bestRunID.map { bestRunID in
                runs.contains { $0.id == bestRunID }
            } ?? false
            if hasConclusion || hasBestRun {
                Section("Reutilizar") {
                    if hasConclusion {
                        Button("Guardar conclusión como aprendizaje", systemImage: "lightbulb") {
                            do {
                                _ = try appModel.repository.saveExperimentConclusionAsLearning(experiment)
                            } catch {
                                actionError = "No se pudo guardar el aprendizaje: \(error.localizedDescription)"
                            }
                        }
                    }
                    if hasBestRun {
                        Button("Guardar mejor run como receta", systemImage: "list.bullet.rectangle") {
                            do {
                                _ = try appModel.repository.saveBestRunAsRecipe(experiment)
                            } catch {
                                actionError = "No se pudo guardar la receta: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
            Section {
                LabeledContent("Estado", value: experiment.status.displayName)
                LabeledContent("Actualizado", value: experiment.updatedAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .navigationTitle(experiment.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            MobileToolbar()
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Editar", systemImage: "pencil") {
                        appModel.presentCapture(.editExperiment(experiment))
                    }
                    Button("Eliminar experimento", systemImage: "trash", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Opciones del experimento")
            }
        }
        .alert("No se pudo completar la acción", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("Aceptar", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "Inténtalo de nuevo.")
        }
        .confirmationDialog("¿Eliminar este experimento?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("Eliminar experimento", role: .destructive) {
                do {
                    try appModel.repository.deleteExperiment(experiment)
                    dismiss()
                } catch {
                    actionError = "No se pudo eliminar el experimento: \(error.localizedDescription)"
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("También se eliminarán sus runs. Esta acción no se puede deshacer.")
        }
    }
}

private struct ExperimentRunDetailView: View {
    let run: FieldExperimentRun
    @EnvironmentObject private var appModel: MobileAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var observation: String
    @State private var status: ExperimentRunStatus
    @State private var evaluation: ExperimentRunEvaluation
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var outputData: Data?
    @State private var isRemovingImage = false
    @State private var saveError: String?
    @State private var isLoadingPhoto = false
    @State private var isDeleteConfirmationPresented = false

    init(run: FieldExperimentRun) {
        self.run = run
        _title = State(initialValue: run.title)
        _observation = State(initialValue: run.observation)
        _status = State(initialValue: run.resultStatus)
        _evaluation = State(initialValue: run.evaluation)
        _outputData = State(initialValue: run.outputData)
    }

    var body: some View {
        let photoPickerTitle = isLoadingPhoto ? "Cargando imagen…" : outputData == nil ? "Añadir imagen" : "Cambiar imagen"
        let photoPickerSymbol = isLoadingPhoto ? "hourglass" : "photo"

        Form {
            Section("Resultado") {
                TextField("Nombre del run", text: $title)
                Picker("Estado", selection: $status) {
                    ForEach(ExperimentRunStatus.allCases, id: \.rawValue) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                Picker("Evaluación", selection: $evaluation) {
                    ForEach(ExperimentRunEvaluation.allCases, id: \.rawValue) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                TextField("Observaciones", text: $observation, axis: .vertical)
                    .lineLimit(5...12)
            }

            Section("Prompt guardado") {
                Text(run.prompt.isEmpty ? "Este run no tiene un prompt guardado." : run.prompt)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(run.prompt.isEmpty ? .secondary : .primary)
                if !run.prompt.isEmpty {
                    ShareLink(item: run.prompt) {
                        Label("Compartir prompt", systemImage: "square.and.arrow.up")
                    }
                }
            }

            MobileSetupSection(title: "Configuración del run", snapshot: MobileSetupSnapshot(run: run))

            Section("Imagen del resultado") {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(photoPickerTitle, systemImage: photoPickerSymbol)
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
                                saveError = "No se pudo leer la imagen seleccionada."
                                return
                            }
                            outputData = loadedImage
                            saveError = nil
                        } catch {
                            saveError = "No se pudo cargar la imagen: \(error.localizedDescription)"
                        }
                    }
                }
                if isLoadingPhoto {
                    ProgressView("Preparando imagen")
                }
                if let outputData, let image = UIImage(data: outputData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Imagen del resultado de \(run.title)")
                }
                if outputData != nil {
                    Button("Quitar imagen", systemImage: "trash", role: .destructive) {
                        outputData = nil
                        selectedPhoto = nil
                        isRemovingImage = true
                        saveError = nil
                    }
                    .disabled(isLoadingPhoto)
                }
            }

        }
        .navigationTitle(run.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingPhoto)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Eliminar run", systemImage: "trash", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Opciones del run")
            }
        }
        .alert("No se pudo completar la acción", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Aceptar", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Inténtalo de nuevo.")
        }
        .confirmationDialog("¿Eliminar este run?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("Eliminar run", role: .destructive) {
                do {
                    try appModel.repository.deleteExperimentRun(run)
                    dismiss()
                } catch {
                    saveError = "No se pudo eliminar el run: \(error.localizedDescription)"
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    private func save() {
        guard let experiment = appModel.repository.experiments().first(where: { $0.id == run.experimentID }) else {
            saveError = "No se encontró el experimento de este run."
            return
        }
        run.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        run.observation = observation.trimmingCharacters(in: .whitespacesAndNewlines)
        run.resultStatus = status
        if isRemovingImage || outputData != nil {
            run.outputData = outputData
        }
        do {
            if evaluation == .best {
                try appModel.repository.setBestRun(run, for: experiment)
            } else {
                run.evaluation = evaluation
                if experiment.bestRunID == run.id { experiment.bestRunID = nil }
                try appModel.repository.updateExperimentRun(run)
            }
            dismiss()
        } catch {
            saveError = "No se pudo guardar: \(error.localizedDescription)"
        }
    }
}

private struct MobileSetupSnapshot {
    let toolName: String
    let toolWebsiteURL: String
    let model: String
    let executionMode: ExperimentExecutionMode
    let settings: [SettingEntry]
    let referenceIDs: [UUID]
    let promptBlockIDs: [UUID]

    init(setup: ExperimentSetup) {
        toolName = setup.toolName
        toolWebsiteURL = setup.toolWebsiteURL
        model = setup.model
        executionMode = setup.executionMode
        settings = setup.settings
        referenceIDs = setup.references
        promptBlockIDs = setup.promptBlockIDs
    }

    init(run: FieldExperimentRun) {
        toolName = run.snapshotToolName
        toolWebsiteURL = run.snapshotToolWebsiteURL
        model = run.model
        executionMode = run.executionMode
        settings = run.settingsEntries
        referenceIDs = run.inputReferenceIDs
        promptBlockIDs = run.snapshotPromptBlockIDs
    }

    var hasDetails: Bool {
        !toolName.isEmpty || !model.isEmpty || !settings.isEmpty
            || !referenceIDs.isEmpty || !promptBlockIDs.isEmpty
    }
}

private struct MobileSetupSection: View {
    let title: String
    let snapshot: MobileSetupSnapshot
    @EnvironmentObject private var appModel: MobileAppModel

    private var references: [FieldReference] {
        let referencesByID = Dictionary(uniqueKeysWithValues: appModel.repository.references(filter: .init(includeArchived: true)).map { ($0.id, $0) })
        return snapshot.referenceIDs.compactMap { referencesByID[$0] }
    }

    private var promptBlocks: [KnowledgeItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: appModel.repository.knowledge().map { ($0.id, $0) })
        return snapshot.promptBlockIDs.compactMap { itemsByID[$0] }
    }

    private var missingReferenceCount: Int {
        Set(snapshot.referenceIDs).subtracting(references.map(\.id)).count
    }

    private var missingPromptBlockCount: Int {
        Set(snapshot.promptBlockIDs).subtracting(promptBlocks.map(\.id)).count
    }

    var body: some View {
        if snapshot.hasDetails {
            Section(title) {
                if !snapshot.toolName.isEmpty {
                    if let url = URL(string: snapshot.toolWebsiteURL), url.scheme != nil {
                        Link(snapshot.toolName, destination: url)
                    } else {
                        LabeledContent("Herramienta", value: snapshot.toolName)
                    }
                }
                if !snapshot.model.isEmpty {
                    LabeledContent("Modelo", value: snapshot.model)
                }
                LabeledContent("Ejecución", value: snapshot.executionMode.displayName)
                ForEach(snapshot.settings) { setting in
                    let value = [setting.value, setting.unit].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                    LabeledContent(setting.key, value: value)
                }
                ForEach(references) { reference in
                    NavigationLink {
                        ReferenceDetailView(reference: reference)
                    } label: {
                        Label(
                            reference.archived ? "\(reference.title) · Archivada" : reference.title,
                            systemImage: "photo"
                        )
                            .lineLimit(1)
                    }
                }
                ForEach(promptBlocks) { block in
                    NavigationLink {
                        KnowledgeDetailView(item: block)
                    } label: {
                        Label(block.title, systemImage: "text.quote")
                            .lineLimit(1)
                    }
                }
                if missingReferenceCount > 0 {
                    Text(missingReferenceCount == 1
                         ? "Una referencia vinculada ya no está disponible."
                         : "\(missingReferenceCount) referencias vinculadas ya no están disponibles.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if missingPromptBlockCount > 0 {
                    Text(missingPromptBlockCount == 1
                         ? "Un bloque de prompt vinculado ya no está disponible."
                         : "\(missingPromptBlockCount) bloques de prompt vinculados ya no están disponibles.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct LearnView: View {
    @Query(sort: \KnowledgeItem.updatedAt, order: .reverse) private var allItems: [KnowledgeItem]
    @Query(sort: \FieldProject.title) private var projects: [FieldProject]
    @Query(sort: \FieldTool.name) private var tools: [FieldTool]
    @EnvironmentObject private var appModel: MobileAppModel
    @State private var filter: LearnFilter = .all
    @State private var searchText = ""
    @State private var showArchived = false

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var visibleItems: [KnowledgeItem] {
        let allowedKinds: Set<KnowledgeKind> = switch filter {
        case .all: [.learning, .note, .recipe, .promptBlock, .decision, .style]
        case .learnings: [.learning, .decision]
        case .recipes: [.recipe]
        case .blocks: [.promptBlock, .style]
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectNamesByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.title) })
        let toolNamesByID = Dictionary(uniqueKeysWithValues: tools.map { ($0.id, $0.name) })
        return allItems.filter { item in
            let contextNames = [item.projectID.flatMap { projectNamesByID[$0] }, item.toolID.flatMap { toolNamesByID[$0] }].compactMap { $0 }
            let matchesQuery = query.isEmpty || mobileSearchMatches(query, in: [
                item.title,
                item.body,
                item.tagNames,
                item.urlString,
                item.metadataJSON
            ] + contextNames)
            return allowedKinds.contains(item.kind)
                && ((item.status == .archived) == showArchived)
                && matchesQuery
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Tipo de conocimiento", selection: $filter) {
                    ForEach(LearnFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Picker("Estado", selection: $showArchived) {
                    Text("Activos").tag(false)
                    Text("Archivados").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            }
            .listSectionSeparator(.hidden)

            if visibleItems.isEmpty {
                ContentUnavailableView {
                    Label(showArchived ? "No hay conocimiento archivado" : "Lo que sabes, a mano", systemImage: "lightbulb")
                } description: {
                    Text(hasSearchQuery
                         ? "No hay elementos que coincidan con la búsqueda."
                         : showArchived
                            ? "Los elementos archivados aparecerán aquí. Puedes restaurarlos desde Editar."
                            : "Guarda aprendizajes, recetas y bloques de prompt para reutilizarlos.")
                } actions: {
                    if !hasSearchQuery && !showArchived {
                        Button("Guardar conocimiento") { appModel.presentCapture(.knowledge(.learning)) }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(.black)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(visibleItems) { item in
                        NavigationLink {
                            KnowledgeDetailView(item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Image(systemName: item.kind.mobileSymbol)
                                        .foregroundStyle(.tint)
                                    Text(item.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                }
                                if !item.body.isEmpty {
                                    Text(item.body)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Text(item.kind.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Conocimiento · \(visibleItems.count)")
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Aprender")
        .searchable(text: $searchText, prompt: "Buscar conocimiento")
        .toolbar { MobileToolbar() }
    }
}

struct KnowledgeDetailView: View {
    let item: KnowledgeItem
    @EnvironmentObject private var appModel: MobileAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var actionError: String?
    @State private var isDeleteConfirmationPresented = false

    private var contextProject: FieldProject? {
        guard let projectID = item.projectID else { return nil }
        return appModel.repository.projects(includeArchived: true).first { $0.id == projectID }
    }

    private var contextTool: FieldTool? {
        let toolID = item.toolID ?? appModel.repository.recipePayload(item)?.toolID
        guard let toolID else { return nil }
        return appModel.repository.tools().first { $0.id == toolID }
    }

    var body: some View {
        List {
            if let imageData = item.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Imagen de \(item.title)")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if item.kind != .recipe {
                Section(item.kind.displayName) {
                    Text(item.body.isEmpty ? "Sin contenido adicional." : item.body)
                        .foregroundStyle(item.body.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                }
            }

            if !item.urlString.isEmpty, let url = URL(string: item.urlString) {
                Section("Enlace") {
                    Link(item.urlString, destination: url)
                        .lineLimit(2)
                }
            }

            if contextProject != nil || contextTool != nil {
                Section("Contexto") {
                    if let contextProject {
                        LabeledContent("Proyecto", value: contextProject.archived ? "\(contextProject.title) · Archivado" : contextProject.title)
                    }
                    if let contextTool {
                        LabeledContent("Herramienta") {
                            if let url = URL(string: contextTool.websiteURL), url.scheme != nil {
                                Link(contextTool.name, destination: url)
                            } else {
                                Text(contextTool.name)
                            }
                        }
                    }
                }
            }

            if item.kind == .recipe, appModel.repository.recipePayload(item) != nil {
                Section("Usar esta receta") {
                    Button("Crear experimento", systemImage: "testtube.2") {
                        appModel.presentCapture(.experimentFromRecipe(item))
                    }
                }
            }

            if !item.tags.isEmpty {
                Section("Etiquetas") {
                    Text(item.tags.joined(separator: " · "))
                }
            }

            if let recipe = appModel.repository.recipePayload(item) {
                Section("Receta") {
                    if !recipe.model.isEmpty {
                        LabeledContent("Modelo", value: recipe.model)
                    }
                    if !recipe.prompt.isEmpty {
                        Text(recipe.prompt)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    } else {
                        Text("Esta receta todavía no tiene un prompt.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(recipe.settings) { setting in
                        LabeledContent(setting.key, value: setting.value)
                    }
                }
            }

            Section {
                LabeledContent("Estado", value: item.status.displayName)
                LabeledContent("Guardado", value: item.createdAt.formatted(date: .abbreviated, time: .omitted))
                Button(item.pinned ? "Quitar de fijados" : "Fijar", systemImage: item.pinned ? "pin.slash" : "pin") {
                    item.pinned.toggle()
                    do {
                        try appModel.repository.updateKnowledge(item)
                    } catch {
                        item.pinned.toggle()
                        actionError = "No se pudo actualizar el elemento: \(error.localizedDescription)"
                    }
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: item.body.isEmpty ? item.title : "\(item.title)\n\n\(item.body)")
                    Button("Editar", systemImage: "pencil") {
                        appModel.presentCapture(.editKnowledge(item))
                    }
                    Button("Eliminar", systemImage: "trash", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Más opciones")
            }
        }
        .alert("No se pudo completar la acción", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("Aceptar", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "Inténtalo de nuevo.")
        }
        .confirmationDialog("¿Eliminar este elemento?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                do {
                    try appModel.repository.delete(item)
                    dismiss()
                } catch {
                    actionError = "No se pudo eliminar el elemento: \(error.localizedDescription)"
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
}

private enum LearnFilter: String, CaseIterable, Identifiable {
    case all
    case learnings
    case recipes
    case blocks

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "Todo"
        case .learnings: "Aprendizajes"
        case .recipes: "Recetas"
        case .blocks: "Prompts"
        }
    }
}

private func mobileSearchMatches(_ query: String, in fields: [String]) -> Bool {
    let terms = query.lowercased()
        .split(whereSeparator: { $0.isWhitespace || $0 == "," })
        .map(String.init)
    guard !terms.isEmpty else { return false }
    return terms.allSatisfy { term in
        fields.contains { $0.localizedCaseInsensitiveContains(term) }
    }
}

private extension KnowledgeKind {
    var mobileSymbol: String {
        switch self {
        case .learning: "lightbulb"
        case .recipe: "list.bullet.rectangle"
        case .promptBlock: "text.quote"
        case .decision: "checkmark.seal"
        case .style: "paintpalette"
        default: "note.text"
        }
    }
}

struct GlobalSearchView: View {
    @EnvironmentObject private var appModel: MobileAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [SearchResult] {
        guard !normalizedQuery.isEmpty else { return [] }
        return appModel.repository.search(query: normalizedQuery)
            .filter { ["reference", "knowledge", "experiment"].contains($0.entityType) }
    }

    var body: some View {
        NavigationStack {
            List {
                if normalizedQuery.isEmpty {
                    ContentUnavailableView("Busca en tu memoria creativa", systemImage: "magnifyingglass", description: Text("Referencias, experimentos, aprendizajes, recetas y bloques de prompt."))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(results, id: \.id) { result in
                        NavigationLink {
                            searchDestination(for: result)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(result.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(mobileSearchKindTitle(for: result))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !result.snippet.isEmpty {
                                    Text(result.snippet)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Buscar en FIELD")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func searchDestination(for result: SearchResult) -> some View {
        switch result.entityType {
        case "reference":
            if let reference = appModel.repository.references().first(where: { $0.id == result.id }) {
                ReferenceDetailView(reference: reference)
            } else {
                ContentUnavailableView("Referencia no disponible", systemImage: "photo")
            }
        case "knowledge":
            if let item = appModel.repository.knowledge().first(where: { $0.id == result.id }) {
                KnowledgeDetailView(item: item)
            } else {
                ContentUnavailableView("Elemento no disponible", systemImage: "lightbulb")
            }
        case "experiment":
            if let experiment = appModel.repository.experiments().first(where: { $0.id == result.id }) {
                ExperimentDetailView(experiment: experiment)
            } else {
                ContentUnavailableView("Experimento no disponible", systemImage: "rectangle.split.3x1")
            }
        default:
            ContentUnavailableView("Elemento no disponible", systemImage: "magnifyingglass")
        }
    }
}

private func mobileSearchKindTitle(for result: SearchResult) -> String {
    switch result.entityType {
    case "reference": "Referencia"
    case "experiment": "Experimento"
    default: result.kind
    }
}

extension Color {
    static let fieldAccent = Color(red: 0.753, green: 0.518, blue: 0.988)
}
