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

struct LabView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedID: UUID?
    @State private var iOSPath: [UUID] = []
    @State private var isPresentingNewExperiment = false

    private var experiments: [FieldExperiment] { appModel.repository.experiments() }
    private var selectedExperiment: FieldExperiment? { experiments.first { $0.id == selectedID } }

    var body: some View {
        #if os(iOS)
        NavigationStack(path: $iOSPath) {
            List {
                if experiments.isEmpty {
                    LabEmptyState { isPresentingNewExperiment = true }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } else {
                    Section("Recent Experiments") {
                        ForEach(experiments) { experiment in
                            NavigationLink(value: experiment.id) {
                                ExperimentRow(experiment: experiment, appModel: appModel)
                            }
                        }
                    }
                }
            }
            .navigationTitle("LAB")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isPresentingNewExperiment = true } label: { Label("New Experiment", systemImage: "plus") }
                }
            }
            .searchable(text: $appModel.searchText, prompt: "Search experiments")
            .navigationDestination(for: UUID.self) { id in
                if let experiment = experiments.first(where: { $0.id == id }) {
                    ExperimentWorkspaceView(appModel: appModel, experiment: experiment)
                }
            }
            .onAppear {
                if iOSPath.isEmpty, let active = experiments.first(where: { $0.status != .archived }) ?? experiments.first {
                    iOSPath = [active.id]
                }
            }
            .sheet(isPresented: $isPresentingNewExperiment) {
                ExperimentEditorView(appModel: appModel) { selectedID = $0.id; iOSPath = [$0.id] }
            }
        }
        #else
        VStack(spacing: 0) {
            FieldPageHeader(
                title: "LAB",
                subtitle: "Test, compare and document what works.",
                count: nil,
                actionTitle: "New Experiment",
                actionSystemImage: "plus"
            ) { isPresentingNewExperiment = true }

            Divider()

            if experiments.isEmpty {
                LabEmptyState { isPresentingNewExperiment = true }
            } else {
                HSplitView {
                    List(selection: $selectedID) {
                        Section("Recent Experiments") {
                            ForEach(experiments) { experiment in
                                ExperimentRow(experiment: experiment, appModel: appModel)
                                    .tag(experiment.id)
                                    .contextMenu {
                                        Button("Delete", role: .destructive) {
                                            try? appModel.repository.deleteExperiment(experiment)
                                            if selectedID == experiment.id { selectedID = nil }
                                            appModel.refresh()
                                        }
                                    }
                            }
                        }
                    }
                    .frame(minWidth: 280, idealWidth: 350)

                    Group {
                        if let selectedExperiment {
                            ExperimentWorkspaceView(appModel: appModel, experiment: selectedExperiment)
                        } else {
                            FieldContextHint(systemImage: "rectangle.split.3x1", title: "Choose an experiment", message: "Your Workbench is where references, prompts, tools and settings become reproducible Runs.")
                        }
                    }
                    .frame(minWidth: 700)
                }
            }
        }
        .background(FieldPalette.canvas)
        .searchable(text: $appModel.searchText, placement: .toolbar, prompt: "Search experiments")
        .onAppear {
            if selectedID == nil {
                selectedID = experiments.first(where: { $0.status != .archived })?.id ?? experiments.first?.id
            }
        }
        .sheet(isPresented: $isPresentingNewExperiment) {
            ExperimentEditorView(appModel: appModel) { selectedID = $0.id }
                .frame(width: 620, height: 520)
        }
        #endif
    }
}

struct LabEmptyState: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("LAB")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            Text("Test, compare and document what works.")
                .font(.title3)
            Text("Build a visual workbench from references, a prompt, a tool and the settings that matter. Each Run stays reproducible while you learn.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: 500, alignment: .leading)
            Button("New Experiment", action: action)
                .buttonStyle(.borderedProminent)
                .tint(FieldPalette.accent)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)

            HStack(spacing: 8) {
                Text("INGREDIENTS")
                Image(systemName: "arrow.right")
                Text("RUNS")
                Image(systemName: "arrow.right")
                Text("COMPARE")
                Image(systemName: "arrow.right")
                Text("LEARN")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 5) {
                Text("Recent Experiments").font(.headline)
                Text("Your documented Runs will appear here.").font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(36)
    }
}

struct ExperimentRow: View {
    let experiment: FieldExperiment
    @ObservedObject var appModel: AppModel

    private var runCount: Int { appModel.repository.experimentRuns(experimentID: experiment.id).count }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "square.split.2x2")
                .foregroundStyle(.tint)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(experiment.title).font(.headline).lineLimit(1)
                    Spacer()
                    Text(runCount == 0 ? "Setup" : "(runCount) run\(runCount == 1 ? "" : "s")")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if !experiment.goal.isEmpty { Text(experiment.goal).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                Text(experiment.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

struct ExperimentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let onCreate: (FieldExperiment) -> Void
    @State private var title = ""
    @State private var goal = ""
    @State private var selectedToolID: UUID?
    @State private var selectedProjectID: UUID?
    @State private var selectedRecipeID: UUID?

    init(appModel: AppModel, onCreate: @escaping (FieldExperiment) -> Void = { _ in }) {
        self.appModel = appModel
        self.onCreate = onCreate
    }

    private var recipes: [KnowledgeItem] { appModel.repository.knowledge(kind: .recipe) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Experiment").font(.title2.weight(.semibold))
                    Text("Start with a question, or load a Recipe as a starting point.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }

            Form {
                TextField("Experiment title", text: $title)
                TextField("What am I trying to learn?", text: $goal, axis: .vertical).lineLimit(2...4)
                Picker("Starting tool", selection: $selectedToolID) {
                    Text("Choose later").tag(Optional<UUID>.none)
                    ForEach(appModel.repository.tools()) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("Start from Recipe", selection: $selectedRecipeID) {
                    Text("Blank setup").tag(Optional<UUID>.none)
                    ForEach(recipes) { Text($0.title).tag(Optional($0.id)) }
                }
                Picker("Project", selection: $selectedProjectID) {
                    Text("No project").tag(Optional<UUID>.none)
                    ForEach(appModel.repository.projects(includeArchived: true)) { Text($0.title).tag(Optional($0.id)) }
                }
            }

            HStack {
                Spacer()
                Button("Create Experiment") { create() }
                    .buttonStyle(.borderedProminent)
                    .tint(FieldPalette.accent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
    }

    private func create() {
        guard let experiment = try? appModel.repository.createExperiment(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            goal: goal,
            toolID: selectedToolID,
            projectID: selectedProjectID
        ) else { return }
        if let recipe = selectedRecipeID.flatMap({ id in recipes.first { $0.id == id } }) {
            try? appModel.repository.applyRecipe(recipe, to: experiment)
        }
        appModel.refresh()
        onCreate(experiment)
        dismiss()
    }
}

private enum WorkbenchMode: String, CaseIterable {
    case build = "BUILD"
    case compare = "COMPARE"
}

struct ExperimentWorkspaceView: View {
    @ObservedObject var appModel: AppModel
    let experiment: FieldExperiment
    @Environment(\.openURL) private var openURL
    @State private var mode: WorkbenchMode = .build
    @State private var prompt: String
    @State private var selectedToolID: UUID?
    @State private var model: String
    @State private var settings: [SettingEntry]
    @State private var selectedReferenceIDs: Set<UUID>
    @State private var selectedPromptBlockIDs: Set<UUID>
    @State private var conclusion: String
    @State private var selectedRunID: UUID?
    @State private var isShowingReferencePicker = false
    @State private var isShowingBlockPicker = false
    @State private var isShowingToolCreator = false
    @State private var isShowingPresetPicker = false
    @State private var isShowingPresetCreator = false
    @State private var isShowingFileImporter = false
    @State private var isShowingReferenceImporter = false
    @State private var duplicateNotice = false
    @State private var parentRunIDForNextRun: UUID?
    @State private var savedLearning = false
    @State private var savedRecipe = false

    init(appModel: AppModel, experiment: FieldExperiment) {
        self.appModel = appModel
        self.experiment = experiment
        let setup = appModel.repository.experimentSetup(experiment)
        _prompt = State(initialValue: setup.prompt)
        _selectedToolID = State(initialValue: setup.toolID)
        _model = State(initialValue: setup.model)
        _settings = State(initialValue: setup.settings)
        _selectedReferenceIDs = State(initialValue: Set(setup.references))
        _selectedPromptBlockIDs = State(initialValue: Set(setup.promptBlockIDs))
        _conclusion = State(initialValue: experiment.conclusion)
    }

    private var runs: [FieldExperimentRun] { appModel.repository.experimentRuns(experimentID: experiment.id) }
    private var selectedRun: FieldExperimentRun? { runs.first { $0.id == selectedRunID } }
    private var references: [FieldReference] { appModel.repository.references().filter { selectedReferenceIDs.contains($0.id) } }
    private var selectedTool: FieldTool? { selectedToolID.flatMap { id in appModel.repository.tools().first { $0.id == id } } }
    private var resultRuns: [FieldExperimentRun] { runs.filter { $0.outputData != nil } }
    private var canCompare: Bool { resultRuns.count >= 2 }
    private var relatedLearnings: [KnowledgeItem] {
        appModel.repository.knowledge(kind: .learning).filter { item in
            item.projectID == nil || item.projectID == experiment.projectID || item.toolID == selectedToolID
        }.prefix(3).map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            workbenchHeader
            Divider()
            Picker("Workbench mode", selection: $mode) {
                ForEach(WorkbenchMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .padding(.vertical, 12)
            .disabled(mode == .compare && !canCompare)

            #if os(macOS)
            HSplitView {
                ScrollView {
                    workbenchMain
                }
                .frame(minWidth: 650)

                if let selectedRun {
                    RunInspectorView(appModel: appModel, experiment: experiment, run: selectedRun, isBest: selectedRun.id == experiment.bestRunID, onDuplicate: { duplicateRun(selectedRun) }, onChanged: refresh, onSelectBest: { selectBest(selectedRun) })
                        .frame(minWidth: 310, idealWidth: 360, maxWidth: 420)
                } else {
                    InspectorEmptyState()
                        .frame(minWidth: 310, idealWidth: 360, maxWidth: 420)
                }
            }
            #else
            ScrollView {
                workbenchMain
                if let selectedRun {
                    RunInspectorView(appModel: appModel, experiment: experiment, run: selectedRun, isBest: selectedRun.id == experiment.bestRunID, onDuplicate: { duplicateRun(selectedRun) }, onChanged: refresh, onSelectBest: { selectBest(selectedRun) })
                }
            }
            #endif
        }
        .background(FieldPalette.canvas)
        .onDisappear { persistSetup() }
        .sheet(isPresented: $isShowingReferencePicker) {
            ExperimentReferencePickerView(appModel: appModel, selectedIDs: $selectedReferenceIDs)
                .frame(width: 580, height: 540)
        }
        .sheet(isPresented: $isShowingBlockPicker) {
            PromptBlockPicker(appModel: appModel, selectedIDs: $selectedPromptBlockIDs) { block in
                if !prompt.isEmpty && !prompt.hasSuffix("\n") { prompt += "\n\n" }
                prompt += block.body
                persistSetup()
            }
                .frame(width: 500, height: 460)
        }
        .sheet(isPresented: $isShowingToolCreator) {
            ToolCreatorView(appModel: appModel) { tool in
                selectedToolID = tool.id
                persistSetup()
            }
            .frame(width: 480, height: 360)
        }
        .sheet(isPresented: $isShowingPresetPicker) {
            PresetPickerView(appModel: appModel, toolID: selectedToolID) { preset in
                model = preset.model
                settings = preset.settings
                persistSetup()
            }
            .frame(width: 500, height: 420)
        }
        .sheet(isPresented: $isShowingPresetCreator) {
            ToolPresetCreatorView(appModel: appModel, toolID: selectedToolID, model: model, settings: settings)
                .frame(width: 500, height: 420)
        }
        .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first, let run = selectedRun else { return }
            attachResult(to: run, data: try? Data(contentsOf: url))
        }
        .fileImporter(isPresented: $isShowingReferenceImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first, let data = try? Data(contentsOf: url) else { return }
            guard let reference = try? appModel.repository.createReference(title: url.deletingPathExtension().lastPathComponent, imageData: data) else { return }
            selectedReferenceIDs.insert(reference.id)
            persistSetup()
            refresh()
        }
    }

    private var workbenchHeader: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(experiment.title)
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                Text(experiment.goal.isEmpty ? "What am I trying to learn?" : experiment.goal)
                    .font(.title3)
                    .foregroundStyle(experiment.goal.isEmpty ? .secondary : .primary)
            }
            Spacer()
            Menu {
                ForEach(ExperimentStatus.allCases, id: \.self) { status in
                    Button(status.displayName) {
                        experiment.status = status
                        try? appModel.repository.updateExperiment(experiment)
                        refresh()
                    }
                }
            } label: {
                Label(experiment.status.displayName, systemImage: "chevron.up.chevron.down")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var workbenchMain: some View {
        VStack(alignment: .leading, spacing: 26) {
            if mode == .build {
                ingredients
                if duplicateNotice {
                    Label("Setup copied from the selected Run. Change one ingredient, then create a new Run.", systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
            runsSection
            if mode == .compare {
                compareSection
            }
            conclusionSection
        }
        .padding(28)
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 18) {
            WorkbenchSectionTitle(title: "INGREDIENTS", detail: "The setup you are testing")

            WorkbenchSection(title: "REFERENCES", systemImage: "photo.on.rectangle") {
                HStack(spacing: 10) {
                    ForEach(references) { reference in
                        ReferenceImageView(data: reference.thumbnailData ?? reference.imageData)
                            .frame(width: 88, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                Text(reference.title).font(.caption2.weight(.medium)).lineLimit(1).padding(5).frame(maxWidth: 88, alignment: .leading).background(.black.opacity(0.5)).foregroundStyle(.white)
                            }
                    }
                    Button { isShowingReferencePicker = true } label: {
                        Label("Add reference", systemImage: "plus")
                            .frame(width: 88, height: 72)
                            .background(FieldPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    Button("Import", systemImage: "square.and.arrow.down") { isShowingReferenceImporter = true }.buttonStyle(.bordered)
                    Button("Paste", systemImage: "doc.on.clipboard") { pasteReference() }.buttonStyle(.bordered)
                }
                if references.isEmpty { Text("Browse Collect, drag images here, or add an existing reference.").font(.subheadline).foregroundStyle(.secondary) }
            }
            .onDrop(of: [UTType.image.identifier], isTargeted: nil) { providers in
                guard let provider = providers.first else { return false }
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    Task { @MainActor in importReference(data) }
                }
                return true
            }

            WorkbenchSection(title: "PROMPT", systemImage: "text.quote") {
                TextEditor(text: $prompt)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(FieldPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                HStack(spacing: 8) {
                    Button("+ Block") { isShowingBlockPicker = true }.buttonStyle(.bordered)
                    if !selectedPromptBlockIDs.isEmpty { Text("\(selectedPromptBlockIDs.count) block\(selectedPromptBlockIDs.count == 1 ? "" : "s") inserted").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button("Copy Prompt", systemImage: "doc.on.doc") { copyToClipboard(prompt) }.buttonStyle(.bordered)
                }
            }

            WorkbenchSection(title: "TOOL", systemImage: "wrench.and.screwdriver") {
                HStack(spacing: 10) {
                    Picker("Tool", selection: $selectedToolID) {
                        Text("Choose a tool").tag(Optional<UUID>.none)
                        ForEach(appModel.repository.tools()) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 240)
                    Button("+ Add Tool") { isShowingToolCreator = true }.buttonStyle(.bordered)
                    Button("Presets") { isShowingPresetPicker = true }.buttonStyle(.bordered).disabled(selectedToolID == nil)
                    Button("Save Preset") { isShowingPresetCreator = true }.buttonStyle(.bordered).disabled(selectedToolID == nil)
                }
                HStack(spacing: 12) {
                    TextField("Model", text: $model)
                    Text("External")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                }
                if let selectedTool { Text(selectedTool.websiteURL.isEmpty ? "External workflow · copy prompt, open the tool, then bring the result back." : selectedTool.websiteURL).font(.caption).foregroundStyle(.secondary) }
            }

            WorkbenchSection(title: "SETTINGS", systemImage: "slider.horizontal.3") {
                VStack(spacing: 8) {
                    ForEach($settings) { $setting in
                        SettingEntryRow(setting: $setting) { settings.removeAll { $0.id == setting.id }; persistSetup() }
                    }
                    Button("+ Add Setting", systemImage: "plus") {
                        settings.append(SettingEntry(key: "", value: ""))
                        persistSetup()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !relatedLearnings.isEmpty {
                WorkbenchSection(title: "RELATED GUIDANCE", systemImage: "lightbulb") {
                    ForEach(relatedLearnings) { learning in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(learning.title).font(.subheadline.weight(.medium))
                            Text(learning.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
            }

            Button("Create Run", systemImage: "play.fill") { createRun() }
                .buttonStyle(.borderedProminent)
                .tint(FieldPalette.accent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
    }

    private var runsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            WorkbenchSectionTitle(title: "RUNS", detail: runs.isEmpty ? "No snapshots yet" : "\(runs.count) immutable setup snapshot\(runs.count == 1 ? "" : "s")")
            if runs.isEmpty {
                Text("Create a Run when the setup is ready. It keeps its own prompt, references, tool and settings.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                #if os(macOS)
                LazyVGrid(columns: [GridItem(.flexible(minimum: 260), spacing: 14), GridItem(.flexible(minimum: 260), spacing: 14)], spacing: 14) {
                    ForEach(runs) { runCard($0) }
                }
                #else
                VStack(spacing: 12) { ForEach(runs) { runCard($0) } }
                #endif
            }
        }
    }

    private func runCard(_ run: FieldExperimentRun) -> some View {
        Button { selectedRunID = run.id } label: {
            VStack(alignment: .leading, spacing: 11) {
                ZStack {
                    ReferenceImageView(data: run.outputData)
                    if run.outputData == nil {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.down.to.line.compact").font(.title3)
                            Text("DROP RESULT HERE").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(FieldPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(alignment: .firstTextBaseline) {
                    Text(run.title.isEmpty ? "Run \(run.order)" : run.title).font(.headline)
                    Spacer()
                    if run.evaluation == .best { Image(systemName: "checkmark.seal.fill").foregroundStyle(.tint) }
                }
                HStack(spacing: 6) {
                    Text(run.snapshotToolName.isEmpty ? "No tool" : run.snapshotToolName)
                    if !run.model.isEmpty { Text("· \(run.model)") }
                    Text("· \(run.evaluation.displayName)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let parentID = run.parentRunID, let parent = runs.first(where: { $0.id == parentID }) {
                    let delta = appModel.repository.runDelta(from: parent, to: run)
                    Text(delta.isEmpty ? "Duplicated from \(parent.title)" : "Changed from \(parent.title) · \(delta.count) change\(delta.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
            }
            .padding(13)
            .background(FieldPalette.surface.opacity(selectedRunID == run.id ? 0.95 : 0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(selectedRunID == run.id ? Color.accentColor.opacity(0.7) : Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(run.title), \(run.evaluation.displayName)")
    }

    private var compareSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            WorkbenchSectionTitle(title: "COMPARE", detail: canCompare ? "Select the result that teaches you the most" : "Add results to at least two Runs to compare")
            if canCompare {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(resultRuns) { run in
                            CompareRunColumn(run: run, isBest: run.id == experiment.bestRunID) { selectBest(run) }
                        }
                    }
                }
            } else {
                Text("Compare becomes available after two Runs have results.").foregroundStyle(.secondary)
            }
        }
    }

    private var conclusionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            WorkbenchSectionTitle(title: "CONCLUSION", detail: "What did you learn?")
            TextEditor(text: $conclusion)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(FieldPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: conclusion) { _, value in experiment.conclusion = value; try? appModel.repository.updateExperiment(experiment) }
            HStack(spacing: 10) {
                Button("Save as Learning", systemImage: "lightbulb") { saveLearning() }
                    .buttonStyle(.borderedProminent)
                    .tint(FieldPalette.accent)
                    .disabled(conclusion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Save Best Run as Recipe", systemImage: "bookmark") { saveRecipe() }
                    .buttonStyle(.bordered)
                    .disabled(experiment.bestRunID == nil)
                if savedLearning { Label("Saved to Learn", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption) }
                if savedRecipe { Label("Recipe saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption) }
            }
        }
    }

    private func persistSetup() {
        experiment.prompt = prompt
        experiment.toolID = selectedToolID
        experiment.model = model
        experiment.settingsEntries = settings
        experiment.referenceIDs = Array(selectedReferenceIDs)
        experiment.promptBlockIDs = Array(selectedPromptBlockIDs)
        try? appModel.repository.updateExperiment(experiment)
    }

    private func createRun() {
        persistSetup()
        guard let run = try? appModel.repository.createRunFromSetup(experiment: experiment, parentRunID: parentRunIDForNextRun) else { return }
        parentRunIDForNextRun = nil
        selectedRunID = run.id
        mode = .build
        refresh()
    }

    private func duplicateRun(_ run: FieldExperimentRun) {
        guard let _ = try? appModel.repository.duplicateRunSetup(run) else { return }
        let setup = appModel.repository.experimentSetup(experiment)
        prompt = setup.prompt
        selectedToolID = setup.toolID
        model = setup.model
        settings = setup.settings
        selectedReferenceIDs = Set(setup.references)
        selectedPromptBlockIDs = Set(setup.promptBlockIDs)
        parentRunIDForNextRun = run.id
        duplicateNotice = true
        refresh()
    }

    private func attachResult(to run: FieldExperimentRun, data: Data?) {
        guard let data else { return }
        run.outputData = data
        run.resultStatus = .completed
        try? appModel.repository.updateExperimentRun(run)
        refresh()
    }

    private func importReference(_ data: Data?) {
        guard let data, let reference = try? appModel.repository.createReference(title: "Imported reference", imageData: data) else { return }
        selectedReferenceIDs.insert(reference.id)
        persistSetup()
        refresh()
    }

    private func pasteReference() {
        importReference(clipboardImageData())
    }

    private func selectBest(_ run: FieldExperimentRun) {
        try? appModel.repository.setBestRun(run, for: experiment)
        refresh()
    }

    private func saveLearning() {
        experiment.conclusion = conclusion.trimmingCharacters(in: .whitespacesAndNewlines)
        experiment.status = .works
        if (try? appModel.repository.saveExperimentConclusionAsLearning(experiment)) != nil { savedLearning = true }
        try? appModel.repository.updateExperiment(experiment)
        refresh()
    }

    private func saveRecipe() {
        guard (try? appModel.repository.saveBestRunAsRecipe(experiment)) != nil else { return }
        savedRecipe = true
        refresh()
    }

    private func refresh() { appModel.refresh() }
}

struct WorkbenchSectionTitle: View {
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title).font(.caption.weight(.bold)).tracking(1.2)
            Text(detail).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .foregroundStyle(.primary)
    }
}

struct WorkbenchSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: systemImage).foregroundStyle(.tint)
                Text(title).font(.subheadline.weight(.semibold))
            }
            content()
        }
        .padding(.bottom, 3)
    }
}

struct SettingEntryRow: View {
    @Binding var setting: SettingEntry
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Key", text: $setting.key)
            TextField("Value", text: $setting.value)
            TextField("Unit", text: Binding(get: { setting.unit ?? "" }, set: { setting.unit = $0.isEmpty ? nil : $0 }))
                .frame(width: 90)
            Button("Remove", systemImage: "minus.circle") { remove() }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove setting")
        }
        .onChange(of: setting) { _, _ in }
    }
}

struct ExperimentReferencePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    @Binding var selectedIDs: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("REFERENCES").font(.title2.weight(.semibold))
                    Text("Reuse existing Collect entities. Nothing is duplicated.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            if appModel.repository.references().isEmpty {
                FieldEmptyState(systemImage: "photo.on.rectangle", title: "No references yet", message: "Save visual material in Collect first.", actionTitle: nil, action: nil)
            } else {
                List(appModel.repository.references()) { reference in
                    Toggle(isOn: Binding(
                        get: { selectedIDs.contains(reference.id) },
                        set: { if $0 { selectedIDs.insert(reference.id) } else { selectedIDs.remove(reference.id) } }
                    )) {
                        HStack(spacing: 10) {
                            ReferenceImageView(data: reference.thumbnailData ?? reference.imageData)
                                .frame(width: 54, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            VStack(alignment: .leading) {
                                Text(reference.title).lineLimit(1)
                                Text(reference.source.name).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
    }
}

struct PromptBlockPicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    @Binding var selectedIDs: Set<UUID>
    let onInsert: (KnowledgeItem) -> Void

    private let categories = ["Camera", "Lighting", "Texture", "Realism", "Avoid", "Custom"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Insert from Learn").font(.title2.weight(.semibold))
                    Text("Choose Prompt Blocks to include in this setup.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(categories, id: \.self) { category in
                        let blocks = appModel.repository.knowledge(kind: .promptBlock).filter { $0.tags.contains { $0.localizedCaseInsensitiveCompare(category) == .orderedSame } || category == "Custom" }
                        if !blocks.isEmpty {
                            Text(category.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.secondary).padding(.top, 8)
                            ForEach(blocks) { block in
                                HStack(spacing: 10) {
                                    Toggle(isOn: Binding(get: { selectedIDs.contains(block.id) }, set: { if $0 { selectedIDs.insert(block.id) } else { selectedIDs.remove(block.id) } })) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(block.title)
                                            Text(block.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                        }
                                    }
                                    Button("Insert") { selectedIDs.insert(block.id); onInsert(block) }.buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    if appModel.repository.knowledge(kind: .promptBlock).isEmpty { Text("Create Prompt Blocks in Learn first.").foregroundStyle(.secondary) }
                }
            }
        }
        .padding(24)
    }
}

struct RunInspectorView: View {
    @ObservedObject var appModel: AppModel
    let experiment: FieldExperiment
    let run: FieldExperimentRun
    let isBest: Bool
    let onDuplicate: () -> Void
    let onChanged: () -> Void
    let onSelectBest: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var observation: String
    @State private var status: ExperimentRunStatus
    @State private var evaluation: ExperimentRunEvaluation
    @State private var isImportingImage = false

    init(appModel: AppModel, experiment: FieldExperiment, run: FieldExperimentRun, isBest: Bool, onDuplicate: @escaping () -> Void, onChanged: @escaping () -> Void, onSelectBest: @escaping () -> Void) {
        self.appModel = appModel
        self.experiment = experiment
        self.run = run
        self.isBest = isBest
        self.onDuplicate = onDuplicate
        self.onChanged = onChanged
        self.onSelectBest = onSelectBest
        _observation = State(initialValue: run.observation)
        _status = State(initialValue: run.resultStatus)
        _evaluation = State(initialValue: run.evaluation)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(run.title.isEmpty ? "Run \(run.order)" : run.title).font(.title3.weight(.semibold))
                        Text("Snapshot · \(run.createdAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isBest { Image(systemName: "checkmark.seal.fill").foregroundStyle(.tint) }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("RESULT").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ZStack {
                        ReferenceImageView(data: run.outputData)
                        if run.outputData == nil {
                            VStack(spacing: 8) {
                                Text("DROP RESULT HERE").font(.caption.weight(.bold))
                                HStack(spacing: 8) {
                                    Button("Add Result") { isImportingImage = true }.buttonStyle(.bordered)
                                    Button("Paste") { attach(data: clipboardImageData()) }.buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .background(FieldPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: nil) { providers in
                        loadDrop(providers)
                    }
                    if run.outputData != nil { Button("Replace Result") { isImportingImage = true }.buttonStyle(.bordered) }
                }

                LabeledContent("Tool", value: run.snapshotToolName.isEmpty ? "No tool" : run.snapshotToolName)
                LabeledContent("Model", value: run.model.isEmpty ? "Not defined" : run.model)
                LabeledContent("References", value: "\(run.inputReferenceIDs.count)")
                if !run.settingsEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("SETTINGS SNAPSHOT").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        ForEach(run.settingsEntries) { setting in
                            HStack { Text(setting.key).foregroundStyle(.secondary); Spacer(); Text(setting.value) }
                                .font(.subheadline)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("STATUS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Picker("Status", selection: $status) { ForEach(ExperimentRunStatus.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                    Picker("Evaluation", selection: $evaluation) { ForEach(ExperimentRunEvaluation.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("OBSERVATION").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    TextEditor(text: $observation).frame(minHeight: 110).scrollContentBackground(.hidden).padding(8).background(FieldPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(spacing: 8) {
                    Button("Copy Prompt & Open \(run.snapshotToolName.isEmpty ? "Tool" : run.snapshotToolName)", systemImage: "arrow.up.right") {
                        copyToClipboard(run.prompt)
                        if let url = URL(string: run.snapshotToolWebsiteURL), !run.snapshotToolWebsiteURL.isEmpty { openURL(url) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FieldPalette.accent)
                    .frame(maxWidth: .infinity)
                    Button("Save Run Changes") { save() }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                    Button("Duplicate Run to Ingredients", systemImage: "plus.square.on.square") { onDuplicate() }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                    if run.outputData != nil && !isBest { Button("Select Best Result", systemImage: "checkmark.seal") { save(); onSelectBest() }.buttonStyle(.bordered).frame(maxWidth: .infinity) }
                }
            }
            .padding(22)
        }
        .background(FieldPalette.surface.opacity(0.36))
        .fileImporter(isPresented: $isImportingImage, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            attach(data: try? Data(contentsOf: url))
        }
        .onChange(of: run.id) { _, _ in
            observation = run.observation
            status = run.resultStatus
            evaluation = run.evaluation
        }
    }

    private func save() {
        run.observation = observation
        run.resultStatus = status
        run.evaluation = evaluation == .best ? .works : evaluation
        try? appModel.repository.updateExperimentRun(run)
        if evaluation == .best { onSelectBest() } else { onChanged() }
    }

    private func attach(data: Data?) {
        guard let data else { return }
        run.outputData = data
        run.resultStatus = .completed
        try? appModel.repository.updateExperimentRun(run)
        onChanged()
    }

    private func loadDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL? = if let data = item as? Data { URL(dataRepresentation: data, relativeTo: nil) } else if let url = item as? URL { url } else { nil }
                guard let url else { return }
                Task { @MainActor in attach(data: try? Data(contentsOf: url)) }
            }
            return true
        }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            Task { @MainActor in attach(data: data) }
        }
        return true
    }
}

struct CompareRunColumn: View {
    let run: FieldExperimentRun
    let isBest: Bool
    let selectBest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ReferenceImageView(data: run.outputData).frame(width: 250, height: 220).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack {
                Text(run.title).font(.headline)
                if isBest { Image(systemName: "checkmark.seal.fill").foregroundStyle(.tint) }
            }
            Text([run.snapshotToolName, run.model].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
            if !run.settingsEntries.isEmpty { Text(run.settingsEntries.map { "\($0.key): \($0.value)" }.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
            if !run.observation.isEmpty { Text(run.observation).font(.caption).foregroundStyle(.secondary).lineLimit(4) }
            Text(run.evaluation.displayName).font(.caption.weight(.medium)).foregroundStyle(isBest ? Color.accentColor : Color.secondary)
            Button(isBest ? "Best Result" : "Select Best Result", action: selectBest).buttonStyle(.bordered)
        }
        .frame(width: 250, alignment: .leading)
    }
}

struct InspectorEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "sidebar.right").font(.title2).foregroundStyle(.tint)
            Text("Select a Run").font(.headline)
            Text("Its result, snapshot settings, status, evaluation and observation will appear here.").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(28)
    }
}

struct ToolCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let onCreate: (FieldTool) -> Void
    @State private var name = ""
    @State private var category = "Image generation"
    @State private var websiteURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Tool").font(.title2.weight(.semibold))
            TextField("Name", text: $name)
            TextField("Category", text: $category)
            TextField("Website / launch URL", text: $websiteURL)
            Spacer()
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Add Tool") { create() }.buttonStyle(.borderedProminent).tint(FieldPalette.accent).disabled(name.isEmpty) }
        }
        .padding(24)
    }

    private func create() {
        guard let tool = try? appModel.repository.createTool(name: name, category: category, websiteURL: websiteURL) else { return }
        onCreate(tool)
        appModel.refresh()
        dismiss()
    }
}

struct PresetPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let toolID: UUID?
    let onSelect: (ToolPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Tool Presets").font(.title2.weight(.semibold)); Spacer(); Button("Done") { dismiss() } }
            if appModel.repository.toolPresets(toolID: toolID).isEmpty {
                Text("No presets saved for this tool yet.").foregroundStyle(.secondary)
                Spacer()
            } else {
                List(appModel.repository.toolPresets(toolID: toolID)) { preset in
                    Button { onSelect(preset); dismiss() } label: {
                        VStack(alignment: .leading) { Text(preset.name); Text([preset.model, preset.settings.map { "\($0.key): \($0.value)" }.joined(separator: " · ")].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                    }.buttonStyle(.plain)
                }
            }
        }.padding(24)
    }
}

struct ToolPresetCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let toolID: UUID?
    let model: String
    let settings: [SettingEntry]
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Tool Preset").font(.title2.weight(.semibold))
            Text("Save the current model and settings for reuse.").foregroundStyle(.secondary)
            TextField("Preset name", text: $name)
            VStack(alignment: .leading, spacing: 5) {
                if !model.isEmpty { Text("Model · \(model)").font(.subheadline) }
                ForEach(settings) { setting in Text("\(setting.key) · \(setting.value)").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save Preset") { save() }.buttonStyle(.borderedProminent).tint(FieldPalette.accent).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .padding(24)
    }

    private func save() {
        _ = try? appModel.repository.createToolPreset(name: name, toolID: toolID, model: model, settings: settings)
        appModel.refresh()
        dismiss()
    }
}

struct ToolPresetEditor: View {
    var body: some View { EmptyView() }
}

struct ReferenceUseInExperimentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let reference: FieldReference
    @State private var selectedExperimentID: UUID?
    @State private var title = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Use in Experiment").font(.title2.weight(.semibold))
            Text("Reuse \"\(reference.title)\" in an existing setup or start a new one.").foregroundStyle(.secondary)
            Picker("Existing Experiment", selection: $selectedExperimentID) {
                Text("Choose later").tag(Optional<UUID>.none)
                ForEach(appModel.repository.experiments()) { Text($0.title).tag(Optional($0.id)) }
            }
            if selectedExperimentID == nil {
                TextField("New experiment title", text: $title)
            }
            Spacer()
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Use in Lab") { save() }.buttonStyle(.borderedProminent).tint(FieldPalette.accent) }
        }
        .padding(24)
    }

    private func save() {
        let experiment: FieldExperiment?
        if let id = selectedExperimentID { experiment = appModel.repository.experiments().first { $0.id == id } }
        else { experiment = try? appModel.repository.createExperiment(title: title.isEmpty ? "New visual test" : title) }
        guard let experiment else { return }
        var ids = experiment.referenceIDs
        if !ids.contains(reference.id) { ids.append(reference.id) }
        experiment.referenceIDs = ids
        var related = reference.experimentIDs
        if !related.contains(experiment.id) { related.append(experiment.id) }
        reference.experimentIDs = related
        try? appModel.repository.updateExperiment(experiment)
        try? appModel.repository.updateReference(reference)
        appModel.refresh()
        dismiss()
    }
}

struct LearnView: View {
    @ObservedObject var appModel: AppModel
    @State private var filter: LearnFilter = .all
    @State private var selectedID: UUID?
    @State private var isPresentingEditor = false
    @State private var editorKind: KnowledgeKind = .learning
    @State private var isShowingPromptDeck = false
    @State private var isShowingSuggestions = false

    private var items: [KnowledgeItem] {
        let kinds: [KnowledgeKind] = switch filter { case .all: [.learning, .recipe, .promptBlock, .decision]; case .learnings: [.learning]; case .recipes: [.recipe]; case .blocks: [.promptBlock] }
        let base = appModel.repository.knowledge().filter { kinds.contains($0.kind) }
        let query = appModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        let ids = Set(appModel.repository.search(query: query).filter { $0.entityType == "knowledge" }.map(\.id))
        return base.filter { ids.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            FieldPageHeader(title: "Learn", subtitle: "Keep the techniques and recipes worth reusing.", count: items.count, actionTitle: "Add", actionSystemImage: "plus") { isPresentingEditor = true }
            #endif
            Picker("Knowledge type", selection: $filter) { ForEach(LearnFilter.allCases, id: \.self) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 12)
            if items.isEmpty {
                FieldEmptyState(systemImage: "lightbulb", title: "Your reusable knowledge lives here", message: "Conclusions become Learnings, Recipes and Prompt Blocks.", actionTitle: "Add Learning") { editorKind = .learning; isPresentingEditor = true }
            } else {
                #if os(macOS)
                HSplitView {
                    List(selection: $selectedID) { ForEach(items) { item in KnowledgeRow(item: item).tag(item.id) } }.frame(minWidth: 340, idealWidth: 420)
                    if let item = items.first(where: { $0.id == selectedID }) { KnowledgeDetailView(item: item, appModel: appModel) { isPresentingEditor = true } } else { FieldContextHint(systemImage: "lightbulb", title: "Choose something to reuse", message: "Read each item in its complete context.") }
                }
                #else
                List { ForEach(items) { item in NavigationLink { KnowledgeDetailView(item: item, appModel: appModel) { isPresentingEditor = true } } label: { KnowledgeRow(item: item) } } }
                #endif
            }
        }
        .background(FieldPalette.canvas)
        .searchable(text: $appModel.searchText, placement: .toolbar, prompt: "Search Learn")
        .sheet(isPresented: $isPresentingEditor) { KnowledgeEditorView(appModel: appModel, item: nil, defaultKind: editorKind).frame(width: 560, height: 500) }
        .sheet(isPresented: $isShowingPromptDeck) { PromptDeckView(appModel: appModel).frame(minWidth: 760, minHeight: 560) }
        .sheet(isPresented: $isShowingSuggestions) { AIInboxView(appModel: appModel).frame(width: 720, height: 560) }
    }
}

enum LearnFilter: String, CaseIterable, Hashable {
    case all, learnings, recipes, blocks
    var title: String { switch self { case .all: "All"; case .learnings: "Learnings"; case .recipes: "Recipes"; case .blocks: "Prompt Blocks" } }
}

struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var mcpServer: MCPServerManager
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingMCP = false
    @State private var isShowingActivity = false
    @State private var isShowingProjects = false
    @State private var isShowingTools = false
    @State private var isShowingFlows = false

    init(appModel: AppModel) {
        self.appModel = appModel
        _mcpServer = ObservedObject(wrappedValue: appModel.mcpServer)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Connections") {
                    Button { isShowingMCP = true } label: { SettingsRow(title: "AI connections", detail: connectionStatus, systemImage: "antenna.radiowaves.left.and.right") }
                    Button { isShowingActivity = true } label: { SettingsRow(title: "Activity", detail: "Review agent actions", systemImage: "waveform.path.ecg") }
                }
                Section("Context") {
                    Button { isShowingProjects = true } label: { SettingsRow(title: "Projects", detail: "Organize your experiments", systemImage: "folder") }
                    Button { isShowingTools = true } label: { SettingsRow(title: "Tools", detail: "Shared tool metadata", systemImage: "wrench.and.screwdriver") }
                    Button { isShowingFlows = true } label: { SettingsRow(title: "Flows", detail: "Advanced reusable methods", systemImage: "arrow.triangle.branch") }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $isShowingMCP) { MCPSettingsView(appModel: appModel).frame(width: 700, height: 620) }
            .sheet(isPresented: $isShowingActivity) { ActivityView(appModel: appModel).frame(width: 700, height: 560) }
            .sheet(isPresented: $isShowingProjects) { ProjectsBrowserView(appModel: appModel).frame(width: 900, height: 620) }
            .sheet(isPresented: $isShowingTools) { ToolsBrowserView(appModel: appModel).frame(width: 900, height: 620) }
            .sheet(isPresented: $isShowingFlows) { FlowsBrowserView(appModel: appModel).frame(width: 900, height: 620) }
            .onAppear(perform: presentRequestedMCPSettings)
            .onChange(of: appModel.isRequestingMCPSettings) { _, requested in
                if requested { presentRequestedMCPSettings() }
            }
        }
    }

    private var connectionStatus: String {
        if mcpServer.isStarting { return "MCP server starting" }
        if mcpServer.isStopping { return "MCP server stopping" }
        return mcpServer.isRunning ? "MCP server active" : "MCP server stopped"
    }

    private func presentRequestedMCPSettings() {
        guard appModel.isRequestingMCPSettings else { return }
        isShowingMCP = true
        appModel.isRequestingMCPSettings = false
    }
}

struct SettingsRow: View {
    let title: String
    let detail: String
    let systemImage: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundStyle(.tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) { Text(title); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }
}

private func copyToClipboard(_ text: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #elseif os(iOS)
    UIPasteboard.general.string = text
    #endif
}

private func clipboardImageData() -> Data? {
    #if os(macOS)
    return NSPasteboard.general.data(forType: .png) ?? NSPasteboard.general.data(forType: .tiff)
    #elseif os(iOS)
    return UIPasteboard.general.image?.pngData()
    #else
    return nil
    #endif
}
