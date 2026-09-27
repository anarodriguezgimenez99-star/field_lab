import Foundation
import SwiftData

public struct SearchFilter: Sendable {
    public var kind: KnowledgeKind?
    public var status: KnowledgeStatus?
    public var projectID: UUID?
    public var toolID: UUID?
    public var scope: KnowledgeScope?

    public init(
        kind: KnowledgeKind? = nil,
        status: KnowledgeStatus? = nil,
        projectID: UUID? = nil,
        toolID: UUID? = nil,
        scope: KnowledgeScope? = nil
    ) {
        self.kind = kind
        self.status = status
        self.projectID = projectID
        self.toolID = toolID
        self.scope = scope
    }
}

public struct SearchResult: Identifiable, Sendable {
    public let id: UUID
    public let entityType: String
    public let kind: String
    public let title: String
    public let snippet: String
    public let status: String
    public let projectTitle: String?
    public let toolName: String?
    public let sourceName: String?
    public let originalURL: String?
    public let score: Int

    public init(
        id: UUID,
        entityType: String,
        kind: String,
        title: String,
        snippet: String,
        status: String = "",
        projectTitle: String? = nil,
        toolName: String? = nil,
        sourceName: String? = nil,
        originalURL: String? = nil,
        score: Int
    ) {
        self.id = id
        self.entityType = entityType
        self.kind = kind
        self.title = title
        self.snippet = snippet
        self.status = status
        self.projectTitle = projectTitle
        self.toolName = toolName
        self.sourceName = sourceName
        self.originalURL = originalURL
        self.score = score
    }
}

public struct ContextItem: Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: String
    public let title: String
    public let body: String
    public let status: String
    public let sourceAgent: String

    public init(id: UUID, kind: String, title: String, body: String, status: String, sourceAgent: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.status = status
        self.sourceAgent = sourceAgent
    }
}

public struct ProjectContextPack: Codable, Equatable, Sendable {
    public let projectID: UUID
    public let projectTitle: String
    public let depth: String
    public let summary: String
    public let brief: String
    public let creativeDirection: String
    public let constraints: String
    public let deliverables: String
    public let alwaysRemember: String
    public let decisions: [ContextItem]
    public let learnings: [ContextItem]
    public let recipes: [ContextItem]
    public let tools: [String]
    public let openItems: [ContextItem]
    public let references: [ReferenceContextItem]

    public init(
        projectID: UUID,
        projectTitle: String,
        depth: String,
        summary: String,
        brief: String,
        creativeDirection: String,
        constraints: String,
        deliverables: String,
        alwaysRemember: String,
        decisions: [ContextItem],
        learnings: [ContextItem],
        recipes: [ContextItem],
        tools: [String],
        openItems: [ContextItem],
        references: [ReferenceContextItem] = []
    ) {
        self.projectID = projectID
        self.projectTitle = projectTitle
        self.depth = depth
        self.summary = summary
        self.brief = brief
        self.creativeDirection = creativeDirection
        self.constraints = constraints
        self.deliverables = deliverables
        self.alwaysRemember = alwaysRemember
        self.decisions = decisions
        self.learnings = learnings
        self.recipes = recipes
        self.tools = tools
        self.openItems = openItems
        self.references = references
    }
}

public struct ReferenceContextItem: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let source: String
    public let note: String
    public let attributes: [String]

    public init(id: UUID, title: String, source: String, note: String, attributes: [String]) {
        self.id = id
        self.title = title
        self.source = source
        self.note = note
        self.attributes = attributes
    }
}

public enum ContextDepth: String, CaseIterable, Codable, Sendable {
    case essential
    case standard
    case deep
}

@MainActor
public final class FieldRepository {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func save() throws {
        try context.save()
    }

    public func projects(includeArchived: Bool = false) -> [FieldProject] {
        let values = (try? context.fetch(FetchDescriptor<FieldProject>())) ?? []
        return values
            .filter { includeArchived || !$0.archived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func tools() -> [FieldTool] {
        let values = (try? context.fetch(FetchDescriptor<FieldTool>())) ?? []
        return values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func knowledge(kind: KnowledgeKind? = nil, projectID: UUID? = nil) -> [KnowledgeItem] {
        let values = (try? context.fetch(FetchDescriptor<KnowledgeItem>())) ?? []
        return values
            .filter { item in
                (kind == nil || item.kind == kind) && (projectID == nil || item.projectID == projectID)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func references(filter: ReferenceFilter = .init()) -> [FieldReference] {
        let values = (try? context.fetch(FetchDescriptor<FieldReference>())) ?? []
        return values
            .filter(filter.matches)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func queryReferences(_ query: ReferenceQuery) -> [FieldReference] {
        let text = query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let terms = text.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        return references(filter: query.filter)
            .filter { reference in
                guard !terms.isEmpty else { return true }
                let attributes = reference.visualAttributes.map { "\($0.category.rawValue) \($0.name)" }.joined(separator: " ")
                let searchable = [reference.title, reference.userNote, reference.ocrText, reference.sourceName, reference.sourceDomain, reference.sourceURL, reference.manualTagsRaw, reference.automaticTagsRaw, attributes].joined(separator: " ").lowercased()
                return terms.allSatisfy { searchable.contains($0) }
            }
            .prefix(max(1, min(query.limit, 500)))
            .map { $0 }
    }

    public func referenceCollections() -> [ReferenceCollection] {
        let values = (try? context.fetch(FetchDescriptor<ReferenceCollection>())) ?? []
        return values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func proposals(status: ProposalStatus? = nil) -> [AgentProposal] {
        let values = (try? context.fetch(FetchDescriptor<AgentProposal>())) ?? []
        return values
            .filter { status == nil || $0.status == status }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func activities() -> [AgentActivity] {
        let values = (try? context.fetch(FetchDescriptor<AgentActivity>())) ?? []
        return values.sorted { $0.timestamp > $1.timestamp }
    }

    public func flows() -> [FieldFlow] {
        let values = (try? context.fetch(FetchDescriptor<FieldFlow>())) ?? []
        return values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func experiments(status: ExperimentStatus? = nil) -> [FieldExperiment] {
        let values = (try? context.fetch(FetchDescriptor<FieldExperiment>())) ?? []
        return values
            .filter { status == nil || $0.status == status }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func experimentRuns(experimentID: UUID) -> [FieldExperimentRun] {
        let values = (try? context.fetch(FetchDescriptor<FieldExperimentRun>())) ?? []
        return values.filter { $0.experimentID == experimentID }.sorted { $0.order < $1.order }
    }

    public func toolPresets(toolID: UUID? = nil) -> [ToolPreset] {
        let values = (try? context.fetch(FetchDescriptor<ToolPreset>())) ?? []
        return values
            .filter { toolID == nil || $0.toolID == toolID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func experimentSetup(_ experiment: FieldExperiment) -> ExperimentSetup {
        let tool = experiment.toolID.flatMap { id in tools().first { $0.id == id } }
        return ExperimentSetup(
            references: experiment.referenceIDs,
            prompt: experiment.prompt,
            toolID: experiment.toolID,
            toolName: tool?.name ?? "",
            toolWebsiteURL: tool?.websiteURL ?? "",
            model: experiment.model,
            settings: experiment.settingsEntries,
            promptBlockIDs: experiment.promptBlockIDs,
            executionMode: experiment.executionMode
        )
    }

    public func applySetup(_ setup: ExperimentSetup, to experiment: FieldExperiment) throws {
        experiment.referenceIDs = setup.references
        experiment.prompt = setup.prompt
        experiment.toolID = setup.toolID
        experiment.model = setup.model
        experiment.settingsEntries = setup.settings
        experiment.promptBlockIDs = setup.promptBlockIDs
        experiment.executionMode = setup.executionMode
        try updateExperiment(experiment)
    }

    @discardableResult
    public func createExperiment(
        title: String,
        goal: String = "",
        prompt: String = "",
        conclusion: String = "",
        toolID: UUID? = nil,
        projectID: UUID? = nil,
        model: String = "",
        referenceIDs: [UUID] = [],
        settings: [SettingEntry] = [],
        promptBlockIDs: [UUID] = [],
        executionMode: ExperimentExecutionMode = .external
    ) throws -> FieldExperiment {
        let experiment = FieldExperiment(
            title: title,
            goal: goal,
            toolID: toolID,
            projectID: projectID,
            referenceIDs: referenceIDs,
            prompt: prompt,
            model: model,
            settings: settings,
            promptBlockIDs: promptBlockIDs,
            executionMode: executionMode
        )
        experiment.conclusion = conclusion
        context.insert(experiment)
        try save()
        return experiment
    }

    @discardableResult
    public func createExperiment(
        from recipe: KnowledgeItem,
        title: String,
        goal: String = "",
        prompt: String,
        projectID: UUID?,
        toolID: UUID?,
        model: String,
        referenceIDs: [UUID]? = nil,
        settings: [SettingEntry]? = nil,
        promptBlockIDs: [UUID]? = nil,
        executionMode: ExperimentExecutionMode? = nil
    ) throws -> FieldExperiment {
        guard let payload = recipePayload(recipe) else {
            throw ExperimentRepositoryError.recipeNotFound
        }
        let experiment = FieldExperiment(
            title: title,
            goal: goal,
            toolID: toolID,
            projectID: projectID,
            referenceIDs: referenceIDs ?? payload.references,
            prompt: prompt,
            model: model,
            settings: settings ?? payload.settings,
            promptBlockIDs: promptBlockIDs ?? payload.promptBlockIDs,
            executionMode: executionMode ?? .external
        )
        context.insert(experiment)
        try save()
        return experiment
    }

    public func updateExperiment(_ experiment: FieldExperiment) throws {
        experiment.updatedAt = .now
        try save()
    }

    public func deleteExperiment(_ experiment: FieldExperiment) throws {
        for run in experimentRuns(experimentID: experiment.id) { context.delete(run) }
        context.delete(experiment)
        try save()
    }

    @discardableResult
    public func createExperimentRun(
        experimentID: UUID,
        title: String,
        prompt: String = "",
        settings: String = "",
        observation: String = "",
        resultStatus: ExperimentRunStatus = .prepared,
        evaluation: ExperimentRunEvaluation = .unrated,
        executionMode: ExperimentExecutionMode = .external,
        toolID: UUID? = nil,
        snapshotToolName: String = "",
        snapshotToolWebsiteURL: String = "",
        model: String = "",
        inputReferenceIDs: [UUID] = [],
        settingsEntries: [SettingEntry]? = nil,
        snapshotPromptBlockIDs: [UUID] = [],
        parentRunID: UUID? = nil,
        outputData: Data? = nil
    ) throws -> FieldExperimentRun {
        let nextOrder = experimentRuns(experimentID: experimentID).last.map { $0.order + 1 } ?? 1
        let serializedSettings = settingsEntries.map { encodeJSON($0) } ?? settings
        let run = FieldExperimentRun(
            experimentID: experimentID,
            order: nextOrder,
            title: title,
            prompt: prompt,
            settings: serializedSettings,
            observation: observation,
            resultStatus: resultStatus,
            evaluation: evaluation,
            executionMode: executionMode,
            toolID: toolID,
            snapshotToolName: snapshotToolName,
            snapshotToolWebsiteURL: snapshotToolWebsiteURL,
            model: model,
            inputReferenceIDs: inputReferenceIDs,
            snapshotPromptBlockIDs: snapshotPromptBlockIDs,
            parentRunID: parentRunID,
            outputData: outputData
        )
        context.insert(run)
        if let experiment = experiments().first(where: { $0.id == experimentID }) { experiment.updatedAt = .now }
        try save()
        return run
    }

    /// Creates a historical copy of the current setup. This is the only
    /// supported path for a new Run in the Workbench.
    @discardableResult
    public func createRunFromSetup(
        experiment: FieldExperiment,
        title: String? = nil,
        parentRunID: UUID? = nil,
        outputData: Data? = nil
    ) throws -> FieldExperimentRun {
        let setup = experimentSetup(experiment)
        return try createExperimentRun(
            experimentID: experiment.id,
            title: title ?? "Run \(experimentRuns(experimentID: experiment.id).count + 1)",
            prompt: setup.prompt,
            resultStatus: .prepared,
            evaluation: .unrated,
            executionMode: setup.executionMode,
            toolID: setup.toolID,
            snapshotToolName: setup.toolName,
            snapshotToolWebsiteURL: setup.toolWebsiteURL,
            model: setup.model,
            inputReferenceIDs: setup.references,
            settingsEntries: setup.settings,
            snapshotPromptBlockIDs: setup.promptBlockIDs,
            parentRunID: parentRunID,
            outputData: outputData
        )
    }

    /// Copies only the immutable setup from a Run back into the editable
    /// Experiment. Result, status and observation are deliberately excluded.
    public func duplicateRunSetup(_ run: FieldExperimentRun) throws -> FieldExperiment {
        guard let experiment = experiments().first(where: { $0.id == run.experimentID }) else {
            throw ExperimentRepositoryError.experimentNotFound
        }
        let setup = ExperimentSetup(
            references: run.inputReferenceIDs,
            prompt: run.prompt,
            toolID: run.toolID,
            toolName: run.snapshotToolName,
            toolWebsiteURL: run.snapshotToolWebsiteURL,
            model: run.model,
            settings: run.settingsEntries,
            promptBlockIDs: run.snapshotPromptBlockIDs,
            executionMode: run.executionMode
        )
        try applySetup(setup, to: experiment)
        return experiment
    }

    public func runDelta(from parent: FieldExperimentRun, to child: FieldExperimentRun) -> [ExperimentRunDelta] {
        var changes: [ExperimentRunDelta] = []
        if parent.snapshotToolName != child.snapshotToolName || parent.model != child.model {
            let before = [parent.snapshotToolName, parent.model].filter { !$0.isEmpty }.joined(separator: " / ")
            let after = [child.snapshotToolName, child.model].filter { !$0.isEmpty }.joined(separator: " / ")
            changes.append(.init(label: "Tool / model", detail: "\(before.isEmpty ? "Sin definir" : before) → \(after.isEmpty ? "Sin definir" : after)"))
        }

        let parentSettings = Dictionary(uniqueKeysWithValues: parent.settingsEntries.map { ($0.key, $0.value) })
        let childSettings = Dictionary(uniqueKeysWithValues: child.settingsEntries.map { ($0.key, $0.value) })
        for key in Set(parentSettings.keys).union(childSettings.keys).sorted() {
            let before = parentSettings[key] ?? "—"
            let after = childSettings[key] ?? "—"
            if before != after { changes.append(.init(label: key, detail: "\(before) → \(after)")) }
        }
        if parent.prompt != child.prompt { changes.append(.init(label: "Prompt", detail: "Texto cambiado")) }
        if parent.inputReferenceIDs != child.inputReferenceIDs {
            let difference = child.inputReferenceIDs.count - parent.inputReferenceIDs.count
            let suffix = difference == 0 ? "Referencias reorganizadas" : (difference > 0 ? "+\(difference) referencia\(difference == 1 ? "" : "s")" : "\(difference) referencia\(difference == -1 ? "" : "s")")
            changes.append(.init(label: "References", detail: suffix))
        }
        if parent.snapshotPromptBlockIDs != child.snapshotPromptBlockIDs {
            let parentBlocks = Set(parent.snapshotPromptBlockIDs)
            let childBlocks = Set(child.snapshotPromptBlockIDs)
            let added = childBlocks.subtracting(parentBlocks).count
            let removed = parentBlocks.subtracting(childBlocks).count
            changes.append(.init(label: "Prompt blocks", detail: "+\(added) / -\(removed) blocks"))
        }
        return changes
    }

    public func setBestRun(_ run: FieldExperimentRun, for experiment: FieldExperiment) throws {
        for candidate in experimentRuns(experimentID: experiment.id) where candidate.evaluation == .best && candidate.id != run.id {
            candidate.evaluation = .works
        }
        run.evaluation = .best
        run.updatedAt = .now
        experiment.bestRunID = run.id
        experiment.updatedAt = .now
        try save()
    }

    @discardableResult
    public func createToolPreset(name: String, toolID: UUID?, model: String = "", settings: [SettingEntry] = []) throws -> ToolPreset {
        let preset = ToolPreset(toolID: toolID, name: name, model: model, settings: settings)
        context.insert(preset)
        try save()
        return preset
    }

    public func updateToolPreset(_ preset: ToolPreset) throws {
        preset.updatedAt = .now
        try save()
    }

    public func deleteToolPreset(_ preset: ToolPreset) throws {
        context.delete(preset)
        try save()
    }

    public func updateExperimentRun(_ run: FieldExperimentRun) throws {
        run.updatedAt = .now
        if let experiment = experiments().first(where: { $0.id == run.experimentID }) { experiment.updatedAt = .now }
        try save()
    }

    public func deleteExperimentRun(_ run: FieldExperimentRun) throws {
        let experimentID = run.experimentID
        context.delete(run)
        let remaining = experimentRuns(experimentID: experimentID).filter { $0.id != run.id }
        for (index, item) in remaining.enumerated() { item.order = index + 1 }
        if let experiment = experiments().first(where: { $0.id == experimentID }) {
            if experiment.bestRunID == run.id { experiment.bestRunID = nil }
            experiment.updatedAt = .now
        }
        try save()
    }

    @discardableResult
    public func saveExperimentConclusionAsLearning(_ experiment: FieldExperiment) throws -> KnowledgeItem {
        let bestRun = experiment.bestRunID.flatMap { id in experimentRuns(experimentID: experiment.id).first { $0.id == id } }
        let metadata = "{\"sourceExperimentID\":\"\(experiment.id.uuidString)\",\"sourceRunID\":\"\(experiment.bestRunID?.uuidString ?? "")\"}"
        let learning = try createKnowledge(
            kind: .learning,
            title: experiment.title,
            body: experiment.conclusion,
            status: .works,
            scope: experiment.projectID == nil ? .global : .project,
            projectID: experiment.projectID,
            toolID: bestRun?.toolID ?? experiment.toolID,
            metadataJSON: metadata
        )
        learning.metadataJSON = encodeJSON([
            "sourceExperimentID": experiment.id.uuidString,
            "sourceRunID": bestRun?.id.uuidString ?? "",
            "sourceToolID": bestRun?.toolID?.uuidString ?? experiment.toolID?.uuidString ?? "",
            "projectID": experiment.projectID?.uuidString ?? "",
            "referenceIDs": experiment.referenceIDs.map(\.uuidString).joined(separator: ",")
        ])
        try save()
        return learning
    }

    @discardableResult
    public func saveBestRunAsRecipe(_ experiment: FieldExperiment) throws -> KnowledgeItem {
        guard let bestRunID = experiment.bestRunID,
              let run = experimentRuns(experimentID: experiment.id).first(where: { $0.id == bestRunID }) else {
            throw ExperimentRepositoryError.bestRunRequired
        }
        let payload = RecipePayload(
            toolID: run.toolID,
            model: run.model,
            prompt: run.prompt,
            settings: run.settingsEntries,
            promptBlockIDs: run.snapshotPromptBlockIDs,
            references: run.inputReferenceIDs
        )
        let metadata = encodeJSON([
            "sourceExperimentID": experiment.id.uuidString,
            "sourceRunID": run.id.uuidString,
            "payload": encodeJSON(payload)
        ])
        return try createKnowledge(
            kind: .recipe,
            title: "\(experiment.title) · \(run.title)",
            body: run.prompt,
            status: .works,
            scope: experiment.projectID == nil ? .global : .project,
            projectID: experiment.projectID,
            toolID: run.toolID,
            imageData: run.outputData,
            metadataJSON: metadata
        )
    }

    public func recipePayload(_ recipe: KnowledgeItem) -> RecipePayload? {
        guard recipe.kind == .recipe else { return nil }
        if let metadata = try? JSONSerialization.jsonObject(with: Data(recipe.metadataJSON.utf8)) as? [String: Any],
           let encoded = metadata["payload"] as? String,
           let payload = try? JSONDecoder().decode(RecipePayload.self, from: Data(encoded.utf8)) {
            return payload
        }
        // Older and manually imported recipes only stored their prompt in `body`.
        return RecipePayload(toolID: recipe.toolID, prompt: recipe.body)
    }

    @discardableResult
    public func createRecipe(
        title: String,
        prompt: String,
        status: KnowledgeStatus = .works,
        scope: KnowledgeScope = .global,
        projectID: UUID? = nil,
        toolID: UUID? = nil,
        model: String = "",
        tags: [String] = [],
        urlString: String = ""
    ) throws -> KnowledgeItem {
        let payload = RecipePayload(toolID: toolID, model: model, prompt: prompt)
        return try createKnowledge(
            kind: .recipe,
            title: title,
            body: prompt,
            status: status,
            scope: scope,
            projectID: projectID,
            toolID: toolID,
            tags: tags,
            urlString: urlString,
            metadataJSON: encodeJSON(["payload": encodeJSON(payload)])
        )
    }

    public func updateRecipePrompt(_ recipe: KnowledgeItem, prompt: String, toolID: UUID?, model: String) throws {
        guard recipe.kind == .recipe else { throw ExperimentRepositoryError.recipeNotFound }
        var payload = recipePayload(recipe) ?? RecipePayload(toolID: recipe.toolID, prompt: recipe.body)
        payload.prompt = prompt
        payload.toolID = toolID
        payload.model = model
        var metadata = (try? JSONSerialization.jsonObject(with: Data(recipe.metadataJSON.utf8))) as? [String: String] ?? [:]
        metadata["payload"] = encodeJSON(payload)
        recipe.body = prompt
        recipe.toolID = toolID
        recipe.metadataJSON = encodeJSON(metadata)
        try updateKnowledge(recipe)
    }

    public func applyRecipe(_ recipe: KnowledgeItem, to experiment: FieldExperiment) throws {
        guard let payload = recipePayload(recipe) else { throw ExperimentRepositoryError.recipeNotFound }
        try applySetup(ExperimentSetup(
            references: payload.references,
            prompt: payload.prompt,
            toolID: payload.toolID,
            model: payload.model,
            settings: payload.settings,
            promptBlockIDs: payload.promptBlockIDs,
            executionMode: .external
        ), to: experiment)
    }

    public func flowSteps(flowID: UUID) -> [FieldFlowStep] {
        let values = (try? context.fetch(FetchDescriptor<FieldFlowStep>())) ?? []
        return values.filter { $0.flowID == flowID }.sorted { $0.order < $1.order }
    }

    @discardableResult
    public func createFlow(title: String, summary: String = "") throws -> FieldFlow {
        let flow = FieldFlow(title: title, summary: summary)
        context.insert(flow)
        try save()
        return flow
    }

    @discardableResult
    public func createFlowStep(flowID: UUID, title: String, instructions: String = "", toolID: UUID? = nil, recipeID: UUID? = nil, templateText: String = "", notes: String = "") throws -> FieldFlowStep {
        let nextOrder = flowSteps(flowID: flowID).last.map { $0.order + 1 } ?? 1
        let step = FieldFlowStep(flowID: flowID, order: nextOrder, title: title, instructions: instructions, toolID: toolID, recipeID: recipeID, templateText: templateText, notes: notes)
        context.insert(step)
        if let flow = flows().first(where: { $0.id == flowID }) { flow.updatedAt = .now }
        try save()
        return step
    }

    public func updateFlow(_ flow: FieldFlow) throws {
        flow.updatedAt = .now
        try save()
    }

    public func deleteFlow(_ flow: FieldFlow) throws {
        for step in flowSteps(flowID: flow.id) { context.delete(step) }
        context.delete(flow)
        try save()
    }

    public func updateFlowStep(_ step: FieldFlowStep) throws {
        if let flow = flows().first(where: { $0.id == step.flowID }) { flow.updatedAt = .now }
        try save()
    }

    public func deleteFlowStep(_ step: FieldFlowStep) throws {
        let flowID = step.flowID
        context.delete(step)
        let remaining = flowSteps(flowID: flowID).filter { $0.id != step.id }.sorted { $0.order < $1.order }
        for (index, remainingStep) in remaining.enumerated() { remainingStep.order = index + 1 }
        if let flow = flows().first(where: { $0.id == flowID }) { flow.updatedAt = .now }
        try save()
    }

    @discardableResult
    public func createProject(title: String, summary: String = "") throws -> FieldProject {
        let project = FieldProject(title: title, summary: summary)
        context.insert(project)
        try save()
        return project
    }

    @discardableResult
    public func createTool(name: String, category: String = "", websiteURL: String = "") throws -> FieldTool {
        let tool = FieldTool(name: name, category: category, websiteURL: websiteURL)
        context.insert(tool)
        try save()
        return tool
    }

    @discardableResult
    public func createKnowledge(
        kind: KnowledgeKind,
        title: String,
        body: String = "",
        status: KnowledgeStatus = .new,
        scope: KnowledgeScope = .global,
        sourceType: SourceType = .user,
        sourceAgent: String = "",
        projectID: UUID? = nil,
        toolID: UUID? = nil,
        tags: [String] = [],
        urlString: String = "",
        imageData: Data? = nil,
        metadataJSON: String = ""
    ) throws -> KnowledgeItem {
        let item = KnowledgeItem(
            kind: kind,
            title: title,
            body: body,
            status: status,
            scope: scope,
            sourceType: sourceType,
            sourceAgent: sourceAgent,
            approvedByUser: sourceType == .user,
            projectID: projectID,
            toolID: toolID,
            tags: tags,
            urlString: urlString,
            imageData: imageData,
            metadataJSON: metadataJSON
        )
        context.insert(item)
        try save()
        return item
    }

    @discardableResult
    public func createReference(
        title: String = "Untitled reference",
        userNote: String = "",
        urlString: String = "",
        source: ReferenceSource? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        projectIDs: [UUID] = [],
        toolIDs: [UUID] = [],
        tags: [String] = [],
        visualAttributes: [VisualAttribute] = [],
        importRecordID: UUID? = nil
    ) throws -> FieldReference {
        let resolvedSource = source ?? ReferenceSourceResolver.resolve(urlString: urlString)
        let resolvedThumbnail = thumbnailData ?? imageData.flatMap { ReferenceImageThumbnail.make(from: $0) }
        let reference = FieldReference(
            title: title.isEmpty ? (resolvedSource.originalTitle.isEmpty ? "Untitled reference" : resolvedSource.originalTitle) : title,
            userNote: userNote,
            source: resolvedSource,
            imageData: imageData,
            thumbnailData: resolvedThumbnail,
            manualTags: tags,
            visualAttributes: visualAttributes,
            importRecordID: importRecordID,
            projectIDs: projectIDs,
            toolIDs: toolIDs
        )
        context.insert(reference)
        try save()
        return reference
    }

    public func updateReference(_ reference: FieldReference) throws {
        if reference.thumbnailData == nil, let imageData = reference.imageData {
            reference.thumbnailData = ReferenceImageThumbnail.make(from: imageData)
        }
        reference.updatedAt = .now
        try save()
    }

    public func deleteReference(_ reference: FieldReference) throws {
        context.delete(reference)
        try save()
    }

    @discardableResult
    public func createReferenceCollection(
        title: String,
        kind: ReferenceCollectionKind,
        filter: ReferenceFilter? = nil,
        referenceIDs: [UUID] = []
    ) throws -> ReferenceCollection {
        let collection = ReferenceCollection(title: title, kind: kind, filter: filter, referenceIDs: referenceIDs)
        context.insert(collection)
        try save()
        return collection
    }

    public func collectionReferences(_ collection: ReferenceCollection) -> [FieldReference] {
        if collection.kind == .smart, let filter = collection.filter { return references(filter: filter) }
        let ids = Set(collection.referenceIDs)
        return references().filter { ids.contains($0.id) }
    }

    public func attachReference(_ reference: FieldReference, toProject projectID: UUID) throws {
        if !reference.projectIDs.contains(projectID) { reference.projectIDs.append(projectID) }
        reference.updatedAt = .now
        try save()
    }

    public func detachReference(_ reference: FieldReference, fromProject projectID: UUID) throws {
        reference.projectIDs.removeAll { $0 == projectID }
        reference.updatedAt = .now
        try save()
    }

    public func updateProject(_ project: FieldProject) throws {
        project.updatedAt = .now
        try save()
    }

    public func updateKnowledge(_ item: KnowledgeItem) throws {
        item.updatedAt = .now
        try save()
    }

    public func delete<T: PersistentModel>(_ model: T) throws {
        context.delete(model)
        try save()
    }

    public func deleteProject(_ project: FieldProject) throws {
        for item in knowledge(projectID: project.id) {
            item.projectID = nil
            item.scope = .global
        }
        for proposal in proposals() where proposal.projectID == project.id { proposal.projectID = nil }
        for activity in activities() where activity.projectID == project.id { activity.projectID = nil }
        for reference in references(filter: ReferenceFilter(includeArchived: true)) where reference.projectIDs.contains(project.id) {
            reference.projectIDs.removeAll { $0 == project.id }
            reference.updatedAt = .now
        }
        for experiment in experiments() where experiment.projectID == project.id {
            experiment.projectID = nil
            experiment.updatedAt = .now
        }
        context.delete(project)
        try save()
    }

    public func deleteTool(_ tool: FieldTool) throws {
        for item in knowledge() where item.toolID == tool.id { item.toolID = nil }
        for proposal in proposals() where proposal.toolID == tool.id { proposal.toolID = nil }
        for step in (try? context.fetch(FetchDescriptor<FieldFlowStep>())) ?? [] where step.toolID == tool.id { step.toolID = nil }
        for reference in references(filter: ReferenceFilter(includeArchived: true)) where reference.toolIDs.contains(tool.id) {
            reference.toolIDs.removeAll { $0 == tool.id }
            reference.updatedAt = .now
        }
        for experiment in experiments() where experiment.toolID == tool.id {
            experiment.toolID = nil
            experiment.updatedAt = .now
        }
        for run in (try? context.fetch(FetchDescriptor<FieldExperimentRun>())) ?? [] where run.toolID == tool.id {
            run.toolID = nil
        }
        context.delete(tool)
        try save()
    }

    public func search(query: String, filter: SearchFilter = .init(), limit: Int = 50) -> [SearchResult] {
        SearchService.search(query: query, knowledge: knowledge(), references: references(), experiments: experiments(), projects: projects(includeArchived: true), tools: tools(), filter: filter, limit: limit)
    }

    public func projectContext(projectID: UUID, depth: ContextDepth = .standard) -> ProjectContextPack? {
        guard let project = projects(includeArchived: true).first(where: { $0.id == projectID }) else { return nil }
        let projectItems = knowledge(projectID: projectID)
        let projectTools = Set(projectItems.compactMap(\.toolID)).compactMap { id in tools().first { $0.id == id }?.name }.sorted()
        let projectReferences = references().filter { $0.projectIDs.contains(projectID) }
        return ContextPackBuilder.build(project: project, items: projectItems, references: projectReferences, toolNames: projectTools, depth: depth)
    }

    @discardableResult
    public func propose(
        agent: String,
        type: KnowledgeKind,
        title: String,
        content: String,
        projectID: UUID? = nil,
        toolID: UUID? = nil
    ) throws -> AgentProposal {
        let proposal = AgentProposal(agent: agent, proposalType: type, title: title, content: content, projectID: projectID, toolID: toolID)
        context.insert(proposal)
        try save()
        logActivity(agent: agent, action: "proposed_\(type.rawValue)", projectID: projectID, detail: title)
        return proposal
    }

    @discardableResult
    public func proposeReferenceTags(agent: String, referenceID: UUID, attributes: [VisualAttribute]) throws -> AgentProposal {
        let reference = references().first { $0.id == referenceID }
        let title = "Suggested tags · \(reference?.title ?? referenceID.uuidString)"
        let payload = try JSONEncoder().encode(ReferenceTagProposal(referenceID: referenceID, attributes: attributes))
        let proposal = AgentProposal(agent: agent, proposalType: .reference, title: title, content: String(decoding: payload, as: UTF8.self), referenceID: referenceID)
        context.insert(proposal)
        try save()
        logActivity(agent: agent, action: "proposed_reference_tags", detail: title)
        return proposal
    }

    @discardableResult
    public func approveReferenceTags(_ proposal: AgentProposal) throws -> FieldReference {
        guard let referenceID = proposal.referenceID,
              let reference = references(filter: .init(includeArchived: true)).first(where: { $0.id == referenceID }) else {
            throw ReferenceRepositoryError.referenceNotFound
        }
        let payload = try JSONDecoder().decode(ReferenceTagProposal.self, from: Data(proposal.content.utf8))
        let automatic = reference.visualAttributes.filter { $0.origin != .manual }
        let manualNames = Set(reference.visualAttributes.filter { $0.origin == .manual }.map { "\($0.category.rawValue):\($0.name.lowercased())" })
        let accepted = payload.attributes.filter { !manualNames.contains("\($0.category.rawValue):\($0.name.lowercased())") }
        reference.visualAttributes = automatic + accepted.map { VisualAttribute(category: $0.category, name: $0.name, origin: .manual, confidence: $0.confidence) }
        reference.updatedAt = .now
        proposal.status = .approved
        proposal.reviewedAt = .now
        try save()
        logActivity(agent: proposal.agent, action: "approved_reference_tags", detail: reference.title)
        return reference
    }

    @discardableResult
    public func approve(_ proposal: AgentProposal) throws -> KnowledgeItem {
        let kind = KnowledgeKind(rawValue: proposal.proposalTypeRaw) ?? .learning
        let item = KnowledgeItem(
            kind: kind,
            title: proposal.title,
            body: proposal.content,
            status: kind == .decision ? .canonical : .works,
            scope: proposal.projectID == nil ? .global : .project,
            sourceType: sourceType(for: proposal.agent),
            sourceAgent: proposal.agent,
            approvedByUser: true,
            projectID: proposal.projectID,
            toolID: proposal.toolID
        )
        context.insert(item)
        proposal.status = .approved
        proposal.reviewedAt = .now
        proposal.approvedKnowledgeID = item.id
        try save()
        logActivity(agent: proposal.agent, action: "approved_\(kind.rawValue)", projectID: proposal.projectID, detail: proposal.title)
        return item
    }

    public func reject(_ proposal: AgentProposal) throws {
        proposal.status = .rejected
        proposal.reviewedAt = .now
        try save()
        logActivity(agent: proposal.agent, action: "rejected_proposal", projectID: proposal.projectID, detail: proposal.title)
    }

    @discardableResult
    public func addWorkingNote(agent: String, content: String, projectID: UUID? = nil, toolID: UUID? = nil) throws -> KnowledgeItem {
        let item = try createKnowledge(
            kind: .workingMemory,
            title: content.fieldTitle,
            body: content,
            status: .testing,
            scope: projectID == nil ? .global : .project,
            sourceType: sourceType(for: agent),
            sourceAgent: agent,
            projectID: projectID,
            toolID: toolID
        )
        logActivity(agent: agent, action: "added_working_note", projectID: projectID, detail: item.title)
        return item
    }

    @discardableResult
    public func saveSessionSummary(agent: String, projectID: UUID?, content: String) throws -> KnowledgeItem {
        let recent = knowledge().first {
            $0.projectID == projectID &&
            $0.kind == .sessionSummary && $0.sourceAgent == agent && $0.body == content && Date.now.timeIntervalSince($0.createdAt) < 300
        }
        if let recent { return recent }

        let item = try createKnowledge(
            kind: .sessionSummary,
            title: "Session · \(Date.now.formatted(date: .abbreviated, time: .shortened))",
            body: content,
            status: .new,
            scope: projectID == nil ? .global : .project,
            sourceType: sourceType(for: agent),
            sourceAgent: agent,
            projectID: projectID
        )
        logActivity(agent: agent, action: "saved_session_summary", projectID: projectID, detail: item.title)
        return item
    }

    public func logActivity(agent: String, action: String, projectID: UUID? = nil, detail: String = "") {
        context.insert(AgentActivity(agent: agent, action: action, projectID: projectID, detail: detail))
        try? save()
    }

    public func seedSampleDataIfEmpty() throws {
        guard projects(includeArchived: true).isEmpty && tools().isEmpty && knowledge().isEmpty && references().isEmpty else { return }

        let project = try createProject(title: "AI Product Campaign", summary: "Una campaña de producto con lenguaje documental y acabado premium.")
        project.brief = "Construir una campaña visual de producto que conserve materiales y proporciones reales."
        project.creativeDirection = "Documentary Premium · candid · material · imperfecto"
        project.constraints = "El producto no cambia. No inventar tipografía. Evitar sensación CGI."
        project.alwaysRemember = "Master 9:16. Mantener imperfecciones naturales."

        let claude = try createTool(name: "Claude", category: "AI assistant")
        let codex = try createTool(name: "Codex", category: "AI coding")
        let krea = try createTool(name: "Krea", category: "Image generation")
        let runway = try createTool(name: "Runway", category: "Image to video")
        _ = try createTool(name: "Photoshop", category: "Retouching")
        _ = try createTool(name: "Figma", category: "Design")

        _ = try createKnowledge(kind: .promptBlock, title: "Hard Directional Sunlight", body: "hard directional natural sunlight, sharp imperfect shadows", status: .works, toolID: krea.id, tags: ["lighting", "realism"])
        _ = try createKnowledge(kind: .promptBlock, title: "35mm Documentary", body: "35mm documentary photography, natural perspective", status: .works, toolID: krea.id, tags: ["camera", "documentary"])
        _ = try createKnowledge(kind: .promptBlock, title: "Fine Analog Grain", body: "fine analog film grain, natural material texture", status: .works, toolID: krea.id, tags: ["texture"])
        _ = try createKnowledge(kind: .promptBlock, title: "Avoid CGI", body: "avoid CGI appearance, no plastic skin, no perfect symmetry", status: .canonical, projectID: project.id, toolID: krea.id, tags: ["avoid", "realism"])
        _ = try createKnowledge(kind: .learning, title: "Describe movement in Runway", body: "En image-to-video funciona mejor describir el movimiento y no volver a describir completamente la imagen.", status: .works, toolID: runway.id, tags: ["movement", "video"])
        _ = try createReference(
            title: "Direct flash editorial",
            userNote: "Me interesa cómo utiliza flash directo y movimiento sin perder sensación premium.",
            source: ReferenceSource(kind: .web, name: "Web", url: "https://example.com/direct-flash", domain: "example.com"),
            projectIDs: [project.id],
            tags: ["flash", "editorial"],
            visualAttributes: [
                VisualAttribute(category: .medium, name: "Photography"),
                VisualAttribute(category: .lighting, name: "Direct Flash")
            ]
        )
        _ = try createKnowledge(kind: .recipe, title: "Natural Product Photography", body: "Krea · Flux · 50mm · hard lateral sunlight · natural materials · fine grain", status: .works, projectID: project.id, toolID: krea.id, tags: ["product", "photography"])
        let flow = try createFlow(title: "AI Product Campaign", summary: "From concept to final upscale while keeping product truth intact.")
        _ = try createFlowStep(flowID: flow.id, title: "Concept", instructions: "Develop concept and direction.", toolID: claude.id, templateText: "Describe the product story, audience and visual tension.")
        _ = try createFlowStep(flowID: flow.id, title: "References", instructions: "Build a visual direction from Field LAB references.")
        _ = try createFlowStep(flowID: flow.id, title: "Hero Still", instructions: "Generate the hero still using the product recipe.", toolID: krea.id)
        _ = try createFlowStep(flowID: flow.id, title: "Motion", instructions: "Describe only the movement for image-to-video.", toolID: runway.id)
        _ = try createKnowledge(kind: .decision, title: "Keep the master at 9:16", body: "The master format is 9:16 for the first campaign deliverables.", status: .canonical, scope: .project, sourceType: .user, projectID: project.id, tags: ["format"])
        _ = try createKnowledge(kind: .workingMemory, title: "Try lower movement next session", body: "Try lower movement next session.", status: .testing, scope: .project, sourceType: .codex, sourceAgent: codex.name, projectID: project.id)
        _ = try createKnowledge(kind: .workingMemory, title: "Hero visual review", body: "Reviewed the hero visual with Claude.", status: .testing, scope: .project, sourceType: .claude, sourceAgent: claude.name, projectID: project.id)
        try save()
    }

    private func sourceType(for agent: String) -> SourceType {
        switch agent.lowercased() {
        case "claude": .claude
        case "codex": .codex
        case "user", "ana": .user
        default: .otherAgent
        }
    }
}

private func encodeJSON<T: Encodable>(_ value: T) -> String {
    String(decoding: (try? JSONEncoder().encode(value)) ?? Data("{}".utf8), as: UTF8.self)
}

private extension String {
    var fieldTitle: String {
        let cleaned = replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled note" : String(cleaned.prefix(72))
    }
}
