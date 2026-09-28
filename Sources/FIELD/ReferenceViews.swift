import Foundation
import SwiftUI
import SwiftData
import FieldCore
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ReferencesView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedID: UUID?
    @State private var isPresentingEditor = false
    @State private var editingReference: FieldReference?
    @State private var showUnclassified = false
    @State private var showPinned = false
    @State private var selectedSource = "Todas las fuentes"
    @State private var isImportingFile = false
    @State private var isShowingFilters = false
    @State private var isShowingSettings = false

    private var allReferences: [FieldReference] { appModel.repository.references() }

    private var sourceNames: [String] {
        ["Todas las fuentes"] + Array(Set(allReferences.map(\.sourceName).filter { !$0.isEmpty })).sorted()
    }

    private var filter: ReferenceFilter {
        ReferenceFilter(
            sourceName: selectedSource == "Todas las fuentes" ? nil : selectedSource,
            pinnedOnly: showPinned,
            unclassifiedOnly: showUnclassified
        )
    }

    private var references: [FieldReference] {
        let query = appModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return appModel.repository.queryReferences(ReferenceQuery(text: query, filter: filter, limit: 500))
    }

    private var hasActiveSearchOrFilter: Bool {
        !appModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || showUnclassified
            || showPinned
            || selectedSource != "Todas las fuentes"
    }

    private var noMatchingReferencesState: some View {
        FieldEmptyState(
            systemImage: "magnifyingglass",
            title: "No matching references",
            message: "Try another search or change the selected filters.",
            actionTitle: "Clear search and filters",
            action: {
                appModel.searchText = ""
                showUnclassified = false
                showPinned = false
                selectedSource = "Todas las fuentes"
            }
        )
    }

    private var selectedReference: FieldReference? { references.first { $0.id == selectedID } }

    var body: some View {
        #if os(iOS)
        mobileBody
        #else
        VStack(spacing: 0) {
            FieldPageHeader(
                title: "Recopilar",
                subtitle: "Guarda referencias, ideas y cosas que quieras volver a visitar.",
                count: references.count,
                actionTitle: "",
                actionSystemImage: "plus"
            ) {
                editingReference = nil
                isPresentingEditor = true
            }

            filterBar
            Divider()

            HSplitView {
                ScrollView {
                    if references.isEmpty {
                        if hasActiveSearchOrFilter {
                            noMatchingReferencesState
                                .frame(minWidth: 520, minHeight: 360)
                        } else {
                            FieldEmptyState(
                                systemImage: "photo.on.rectangle.angled",
                                title: "Guarda inspiración desde cualquier lugar",
                                message: "Trae una imagen, URL o nota desde Pinterest, Cosmos, Safari, Fotos, LinkedIn y más. La fuente queda vinculada para que la referencia siga siendo útil.",
                                actionTitle: "Añadir referencia",
                                action: { editingReference = nil; isPresentingEditor = true }
                            )
                            .frame(minWidth: 520, minHeight: 360)
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 184), spacing: 18)], spacing: 18) {
                            ForEach(references) { reference in
                                Button { selectedID = reference.id } label: {
                                    ReferenceLibraryTile(reference: reference, isSelected: selectedID == reference.id)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(L10n.text("Editar")) { editingReference = reference; isPresentingEditor = true }
                                    Button(reference.pinned ? L10n.text("Desfijar") : L10n.text("Fijar")) {
                                        reference.pinned.toggle()
                                        try? appModel.repository.updateReference(reference)
                                        appModel.refresh()
                                    }
                                    Divider()
                                    Button(L10n.text("Eliminar"), role: .destructive) {
                                        try? appModel.repository.deleteReference(reference)
                                        if selectedID == reference.id { selectedID = nil }
                                        appModel.refresh()
                                    }
                                }
                            }
                        }
                        .padding(24)
                    }
                }
                .frame(minWidth: 540)
                .background(FieldPalette.canvas)
                .onDrop(of: [UTType.image.identifier, UTType.url.identifier, UTType.fileURL.identifier, UTType.plainText.identifier], isTargeted: nil, perform: handleDrop)

                Group {
                    if let selectedReference {
                        ReferenceDetailView(reference: selectedReference, appModel: appModel) {
                            editingReference = selectedReference
                            isPresentingEditor = true
                        }
                    } else {
                        FieldContextHint(systemImage: "sidebar.right", title: "Elige una referencia", message: "Selecciona una imagen para ver su fuente, nota, atributos y conexiones de proyecto.")
                    }
                }
                .frame(minWidth: 420)
            }
        }
        .background(FieldPalette.canvas)
        .searchable(text: $appModel.searchText, placement: .toolbar, prompt: L10n.text("Buscar referencias, OCR y etiquetas…"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(L10n.text("Referencia")) { editingReference = nil; isPresentingEditor = true }
                    Button(L10n.text("Nota")) { appModel.presentCapture(kind: .note) }
                } label: {
                    Label(L10n.text("Añadir"), systemImage: "plus")
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button { isShowingSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel(L10n.text("Ajustes"))
            }
            #endif
        }
        .sheet(isPresented: $isPresentingEditor) {
            ReferenceEditorView(appModel: appModel, reference: editingReference)
                .frame(width: 620, height: 720)
        }
        .sheet(isPresented: $isShowingSettings) { SettingsView(appModel: appModel) }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first, let data = try? Data(contentsOf: url) else { return }
            let title = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ")
            _ = try? appModel.repository.createReference(title: title.isEmpty ? "Referencia importada" : title, imageData: data)
            appModel.refresh()
        }
        #endif
    }

    #if os(iOS)
    private var mobileBody: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filterBar
                    if references.isEmpty {
                        if hasActiveSearchOrFilter {
                            noMatchingReferencesState
                                .frame(minHeight: 320)
                        } else {
                            FieldEmptyState(
                                systemImage: "photo.on.rectangle.angled",
                                title: "Guarda inspiración desde cualquier lugar",
                                message: "Trae una imagen, URL o nota. Puedes clasificarla más tarde.",
                                actionTitle: "Importar referencia",
                                action: { editingReference = nil; isPresentingEditor = true }
                            )
                            .frame(minHeight: 320)
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                            ForEach(references) { reference in
                                Button { selectedID = reference.id } label: {
                                    ReferenceLibraryTile(reference: reference, isSelected: selectedID == reference.id)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(FieldPalette.canvas)
            .navigationTitle(L10n.text("Recopilar"))
            .searchable(text: $appModel.searchText, prompt: L10n.text("Buscar referencias"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(L10n.text("Referencia")) { editingReference = nil; isPresentingEditor = true }
                        Button(L10n.text("Nota")) { appModel.presentCapture(kind: .note) }
                    } label: { Image(systemName: "plus") }
                        .accessibilityLabel(L10n.text("Añadir a Recopilar"))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { isShowingSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(L10n.text("Ajustes"))
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                ReferenceEditorView(appModel: appModel, reference: editingReference)
            }
            .sheet(isPresented: $isShowingSettings) { SettingsView(appModel: appModel) }
            .sheet(isPresented: Binding(
                get: { selectedReference != nil },
                set: { if !$0 { selectedID = nil } }
            )) {
                if let selectedReference {
                    ReferenceDetailView(reference: selectedReference, appModel: appModel) {
                        editingReference = selectedReference
                        isPresentingEditor = true
                    }
                }
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
                guard case .success(let urls) = result, let url = urls.first, let data = try? Data(contentsOf: url) else { return }
                _ = try? appModel.repository.createReference(title: url.deletingPathExtension().lastPathComponent, imageData: data)
                appModel.refresh()
            }
        }
    }
    #endif

    private var filterBar: some View {
        HStack(spacing: 8) {
            filterChip("Todo", isSelected: !showUnclassified && !showPinned) {
                showUnclassified = false
                showPinned = false
            }
            filterChip("Sin clasificar", isSelected: showUnclassified) { showUnclassified.toggle(); showPinned = false }
            filterChip("Fijadas", isSelected: showPinned) { showPinned.toggle(); showUnclassified = false }

            Divider().frame(height: 20).padding(.horizontal, 4)

            Picker(L10n.text("Fuente"), selection: $selectedSource) {
                ForEach(sourceNames, id: \.self) { source in
                    let count = source == "Todas las fuentes" ? allReferences.count : allReferences.filter { $0.sourceName == source }.count
                    Text("\(L10n.text(source))  \(count)").tag(source)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 190, alignment: .leading)

            Spacer(minLength: 0)

            #if os(iOS)
            Button { isShowingFilters = true } label: { Label(L10n.text("Filtros"), systemImage: "line.3.horizontal.decrease.circle") }
                .buttonStyle(.bordered)
                .sheet(isPresented: $isShowingFilters) { ReferenceFilterSheet(showUnclassified: $showUnclassified, showPinned: $showPinned) }
            #else
            Button { isImportingFile = true } label: { Label(L10n.text("Elegir imagen"), systemImage: "photo.badge.plus") }
                .buttonStyle(.bordered)
            #endif
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .controlSize(.small)
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(L10n.text(title))
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minHeight: 44)
                .background(isSelected ? FieldPalette.accent : FieldPalette.surface, in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .overlay(Capsule().stroke(isSelected ? .clear : FieldPalette.line))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in
                        _ = try? appModel.repository.createReference(title: "Referencia soltada", imageData: data)
                        appModel.refresh()
                    }
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    let value: String?
                    if let url = item as? URL { value = url.absoluteString }
                    else if let data = item as? Data { value = String(data: data, encoding: .utf8) }
                    else { value = (item as? NSString).map(String.init) }
                    guard let value, !value.isEmpty else { return }
                    Task { @MainActor in
                        let source = ReferenceSourceResolver.resolve(urlString: value)
                        _ = try? appModel.repository.createReference(title: source.name, urlString: value, source: source)
                        appModel.refresh()
                    }
                }
                return true
            }
        }
        return false
    }
}

struct ReferenceLibraryTile: View {
    let reference: FieldReference
    let isSelected: Bool

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
            VStack(alignment: .leading, spacing: 9) {
                ReferenceImageView(data: reference.thumbnailData ?? reference.imageData)
                    .frame(height: 164)
                    .frame(maxWidth: .infinity)
                    .background(FieldPalette.muted)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if reference.pinned {
                            Image(systemName: "pin.fill")
                                .font(.caption.weight(.semibold))
                                .padding(7)
                                .background(.regularMaterial, in: Circle())
                                .padding(8)
                        }
                    }

                HStack(spacing: 6) {
                    Image(systemName: reference.source.kind == .web ? "link" : "square.and.arrow.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.text(reference.source.name))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                Text(reference.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            .padding(12)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(FieldPalette.accent.opacity(0.65), lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reference.title), \(L10n.text("Fuente")) \(L10n.text(reference.source.name))")
    }
}

struct ReferenceImageView: View {
    let data: Data?

    var body: some View {
        Group {
            #if os(macOS)
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
            #elseif os(iOS)
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
            #else
            placeholder
            #endif
        }
    }

    private var placeholder: some View {
        ZStack {
            FieldPalette.muted
            Image(systemName: "photo")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct ReferenceDetailView: View {
    let reference: FieldReference
    @ObservedObject var appModel: AppModel
    let edit: () -> Void
    @State private var isShowingUseInExperiment = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ReferenceImageView(data: reference.imageData ?? reference.thumbnailData)
                    .frame(maxWidth: .infinity)
                    .frame(height: 310)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(reference.title).font(.system(.title, design: .rounded).weight(.semibold))
                        HStack(spacing: 6) {
                            Image(systemName: "link").font(.caption)
                            Text(L10n.text(reference.source.name)).font(.subheadline.weight(.medium))
                            if !reference.sourceDomain.isEmpty { Text("· \(reference.sourceDomain)").font(.subheadline).foregroundStyle(.secondary) }
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Button(reference.pinned ? L10n.text("Desfijar") : L10n.text("Fijar")) {
                        reference.pinned.toggle()
                        try? appModel.repository.updateReference(reference)
                        appModel.refresh()
                    }
                    .buttonStyle(.bordered)
                    Button(L10n.text("Usar en LAB"), systemImage: "testtube.2") { isShowingUseInExperiment = true }
                        .buttonStyle(.bordered)
                    Button(L10n.text("Editar"), action: edit).buttonStyle(.borderedProminent)
                }

                if !reference.userNote.isEmpty {
                    DetailSection(title: "Por qué guardé esto") { Text(reference.userNote).textSelection(.enabled) }
                }

                if !reference.sourceURL.isEmpty, let url = URL(string: reference.sourceURL) {
                    DetailSection(title: "Fuente") {
                        Link(destination: url) { Label(L10n.text("Abrir original"), systemImage: "arrow.up.right") }
                        Text(reference.sourceURL).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }

                if !reference.visualAttributes.isEmpty {
                    DetailSection(title: "Atributos visuales") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(VisualAttributeCategory.allCases, id: \.self) { category in
                                let values = reference.visualAttributes.filter { $0.category == category }
                                if !values.isEmpty {
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(L10n.text(category.displayName).uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 88, alignment: .leading)
                                        FlowTags(tags: values.map(\.name))
                                    }
                                }
                            }
                        }
                    }
                }

                if !reference.manualTags.isEmpty {
                    DetailSection(title: "Etiquetas") { FlowTags(tags: reference.manualTags) }
                }

                DetailSection(title: "Proyectos") {
                    let projects = appModel.repository.projects(includeArchived: true).filter { reference.projectIDs.contains($0.id) }
                    if projects.isEmpty { Text(L10n.text("Aún no está conectada a ningún proyecto.")).foregroundStyle(.secondary) }
                    else { FlowTags(tags: projects.map(\.title)) }
                }

                DetailSection(title: "Experimentos relacionados") {
                    let experiments = appModel.repository.experiments().filter { $0.referenceIDs.contains(reference.id) }
                    if experiments.isEmpty { Text(L10n.text("Aún no hay experimentos conectados.")).foregroundStyle(.secondary) }
                    else { FlowTags(tags: experiments.map(\.title)) }
                }

                DetailSection(title: "Herramientas") {
                    let tools = appModel.repository.tools().filter { reference.toolIDs.contains($0.id) }
                    if tools.isEmpty { Text(L10n.text("Aún no hay metadatos de herramientas.")).foregroundStyle(.secondary) }
                    else { FlowTags(tags: tools.map(\.name)) }
                }

                DetailSection(title: "Metadatos") {
                    LabeledContent(L10n.text("Importada"), value: reference.importedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent(L10n.text("Análisis"), value: L10n.referenceAnalysisState(reference.analysisState.rawValue))
                    if let width = reference.imageWidth, let height = reference.imageHeight { LabeledContent(L10n.text("Dimensiones"), value: "\(Int(width)) × \(Int(height))") }
                    if !reference.ocrText.isEmpty { LabeledContent("OCR", value: String(reference.ocrText.prefix(180))) }
                }
            }
            .padding(28)
        }
        .background(FieldPalette.surface)
        .sheet(isPresented: $isShowingUseInExperiment) {
            ReferenceUseInExperimentSheet(appModel: appModel, reference: reference)
                .frame(width: 520, height: 360)
        }
    }
}

struct ReferenceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let reference: FieldReference?

    @State private var title: String
    @State private var note: String
    @State private var urlString: String
    @State private var tags: String
    @State private var imageData: Data?
    @State private var attributes: [VisualAttribute]
    @State private var newAttributeName = ""
    @State private var newAttributeCategory: VisualAttributeCategory = .style
    @State private var selectedProjectIDs: Set<UUID>
    @State private var isImportingImage = false

    init(appModel: AppModel, reference: FieldReference?) {
        self.appModel = appModel
        self.reference = reference
        _title = State(initialValue: reference?.title ?? "")
        _note = State(initialValue: reference?.userNote ?? "")
        _urlString = State(initialValue: reference?.sourceURL ?? "")
        _tags = State(initialValue: reference?.manualTagsRaw ?? "")
        _imageData = State(initialValue: reference?.imageData ?? reference?.thumbnailData)
        _attributes = State(initialValue: reference?.visualAttributes ?? [])
        _selectedProjectIDs = State(initialValue: Set(reference?.projectIDs ?? []))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(reference == nil ? L10n.text("Guardar referencia") : L10n.text("Editar referencia")).font(.title2.weight(.semibold))
                    Text(L10n.text("La clasificación puede esperar. Conserva la fuente y el motivo.")).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.text("Cancelar")) { dismiss() }.keyboardShortcut(.cancelAction)
            }

            Form {
                TextField(L10n.text("Título"), text: $title)
                TextField(L10n.text("URL original"), text: $urlString)
                TextField(L10n.text("¿Por qué guardé esto?"), text: $note, axis: .vertical).lineLimit(3...6)
                TextField(L10n.text("Etiquetas"), text: $tags, prompt: Text(L10n.text("campaña, verano, luz de producto")))

                HStack {
                    Text(imageData == nil ? L10n.text("No hay imagen adjunta") : L10n.text("Imagen adjunta")).foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.text("Elegir imagen")) { isImportingImage = true }
                    if imageData != nil { Button(L10n.text("Eliminar"), role: .destructive) { imageData = nil } }
                }

                Section(L10n.text("Atributos visuales manuales")) {
                    HStack {
                        Picker(L10n.text("Categoría"), selection: $newAttributeCategory) { ForEach(VisualAttributeCategory.allCases, id: \.self) { Text(L10n.text($0.displayName)).tag($0) } }
                        TextField(L10n.text("Añadir atributo"), text: $newAttributeName)
                        Button(L10n.text("Añadir")) { addAttribute() }.disabled(newAttributeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if attributes.isEmpty {
                        Text(L10n.text("Aún no hay clasificación creativa. Esta referencia aparecerá en Sin clasificar.")).font(.caption).foregroundStyle(.secondary)
                    } else {
                        FlowTags(tags: attributes.map { "\(L10n.text($0.category.displayName)): \($0.name)" })
                        Button(L10n.text("Borrar atributos"), role: .destructive) { attributes.removeAll() }.font(.caption)
                    }
                }

                Section(L10n.text("Proyectos")) {
                    let projects = appModel.repository.projects(includeArchived: true)
                    if projects.isEmpty { Text(L10n.text("Crea primero un proyecto para conectar esta referencia.")).font(.caption).foregroundStyle(.secondary) }
                    else {
                        ForEach(projects) { project in
                            Toggle(project.title, isOn: Binding(
                                get: { selectedProjectIDs.contains(project.id) },
                                set: { isSelected in
                                    if isSelected { selectedProjectIDs.insert(project.id) } else { selectedProjectIDs.remove(project.id) }
                                }
                            ))
                        }
                    }
                }
            }

            HStack {
                if !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let source = ReferenceSourceResolver.resolve(urlString: urlString)
                    Label("\(L10n.text("Fuente detectada")): \(L10n.text(source.name))", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(reference == nil ? L10n.text("Guardar en FIELD LAB") : L10n.text("Guardar cambios")) { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageData == nil)
            }
        }
        .padding(24)
        .fileImporter(isPresented: $isImportingImage, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            imageData = try? Data(contentsOf: url)
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { title = url.deletingPathExtension().lastPathComponent }
        }
    }

    private func addAttribute() {
        let value = newAttributeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        attributes.removeAll { $0.category == newAttributeCategory && $0.name.localizedCaseInsensitiveCompare(value) == .orderedSame }
        attributes.append(VisualAttribute(category: newAttributeCategory, name: value, origin: .manual))
        newAttributeName = ""
    }

    private func save() {
        let cleanedURL = ReferenceSourceResolver.normalize(urlString)
        let source = ReferenceSourceResolver.resolve(urlString: cleanedURL)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = cleanTitle.isEmpty ? (source.name == "Manual" ? "Referencia sin título" : source.name) : cleanTitle
        let parsedTags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        do {
            if let reference {
                reference.title = finalTitle
                reference.userNote = note
                reference.source = source
                reference.imageData = imageData
                reference.projectIDs = Array(selectedProjectIDs)
                reference.manualTags = parsedTags
                reference.visualAttributes = attributes
                try appModel.repository.updateReference(reference)
            } else {
                _ = try appModel.repository.createReference(title: finalTitle, userNote: note, urlString: cleanedURL, source: source, imageData: imageData, projectIDs: Array(selectedProjectIDs), tags: parsedTags, visualAttributes: attributes)
            }
            appModel.refresh()
            dismiss()
        } catch {
            // Saving the canonical record is the only required step; secondary analysis is independent.
        }
    }
}

struct ProjectReferencePicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let project: FieldProject
    @State private var selectedIDs: Set<UUID>

    init(appModel: AppModel, project: FieldProject) {
        self.appModel = appModel
        self.project = project
        _selectedIDs = State(initialValue: Set(appModel.repository.references().filter { $0.projectIDs.contains(project.id) }.map(\.id)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(L10n.text("Referencias del proyecto")).font(.title2.weight(.semibold)); Spacer(); Button(L10n.text("Hecho")) { save(); dismiss() } }
            Text(L10n.text("Elige referencias existentes. Seguirán siendo elementos compartidos de la biblioteca.")).font(.subheadline).foregroundStyle(.secondary)
            List(appModel.repository.references()) { reference in
                Toggle(isOn: Binding(
                    get: { selectedIDs.contains(reference.id) },
                    set: { selected in if selected { selectedIDs.insert(reference.id) } else { selectedIDs.remove(reference.id) } }
                )) {
                    HStack(spacing: 10) {
                        ReferenceImageView(data: reference.thumbnailData ?? reference.imageData).frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading) { Text(reference.title).lineLimit(1); Text(L10n.text(reference.source.name)).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 480)
    }

    private func save() {
        for reference in appModel.repository.references() {
            if selectedIDs.contains(reference.id) { try? appModel.repository.attachReference(reference, toProject: project.id) }
            else { try? appModel.repository.detachReference(reference, fromProject: project.id) }
        }
        appModel.refresh()
    }
}

#if os(iOS)
struct ReferenceFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showUnclassified: Bool
    @Binding var showPinned: Bool

    var body: some View {
        NavigationStack {
            Form {
                Toggle(L10n.text("Sin clasificar"), isOn: $showUnclassified)
                Toggle(L10n.text("Fijadas"), isOn: $showPinned)
            }
            .navigationTitle(L10n.text("Filtros"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Hecho")) { dismiss() } } }
        }
    }
}
#endif
