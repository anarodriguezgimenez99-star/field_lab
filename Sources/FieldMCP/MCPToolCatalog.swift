import Foundation
import SwiftData
import FieldCore
import MCP

public enum MCPRequestAuthenticator {
    public static func isAuthorized(authorization: String?, token: String) -> Bool {
        authorization == "Bearer \(token)"
    }
}

/// The public MCP surface of Field LAB.
///
/// This type deliberately depends on the repository rather than on SwiftUI or
/// the localhost listener. That keeps the protocol contract testable with the
/// official in-memory transport and makes it possible to reuse the same tools
/// from a future stdio or authenticated HTTP adapter.
public enum MCPToolCatalog {
    private struct WorkflowPayload: Encodable, Sendable {
        let id: String
        let title: String
        let summary: String
        let steps: [WorkflowStepPayload]
    }

    private struct WorkflowStepPayload: Encodable, Sendable {
        let id: String
        let order: Int
        let title: String
        let instructions: String
        let toolID: String
        let recipeID: String
        let template: String
        let notes: String

        enum CodingKeys: String, CodingKey {
            case id
            case order
            case title
            case instructions
            case toolID = "tool_id"
            case recipeID = "recipe_id"
            case template
            case notes
        }
    }

    private static let builtInToolDefinitions: [Tool] = [
        tool("search_knowledge", "Search Field LAB knowledge by query and optional filters.", properties: [
            "query": .string("Text to search for"),
            "project_id": .string("Optional project UUID"),
            "tool_id": .string("Optional tool UUID"),
            "kind": .string("Optional knowledge kind raw value"),
            "status": .string("Optional knowledge status raw value"),
            "limit": .object([
                "type": .string("integer"),
                "description": .string("Maximum number of results")
            ]),
            "source_agent": .string("Optional agent name")
        ], required: ["query"]),
        tool("search_references", "Search visual references by text, source and structured attributes.", properties: [
            "query": .string("Optional text to search in title, note, OCR, source and tags"),
            "project_id": .string("Optional project UUID"),
            "collection_id": .string("Optional collection UUID"),
            "style": stringArrayProperty("Optional style values"),
            "medium": stringArrayProperty("Optional medium values"),
            "subject": stringArrayProperty("Optional subject values"),
            "lighting": stringArrayProperty("Optional lighting values"),
            "composition": stringArrayProperty("Optional composition values"),
            "mood": stringArrayProperty("Optional mood values"),
            "color_character": stringArrayProperty("Optional color character values"),
            "source": .string("Optional source display name, for example Pinterest"),
            "tags": stringArrayProperty("Optional manual tags"),
            "limit": .object(["type": .string("integer"), "description": .string("Maximum number of results")]),
            "include_archived": .object(["type": .string("boolean"), "description": .string("Include archived references")]),
            "source_agent": .string("Optional agent name")
        ]),
        tool("get_reference", "Return complete metadata for one visual reference.", properties: [
            "reference_id": .string("Reference UUID"),
            "source_agent": .string("Optional agent name")
        ], required: ["reference_id"]),
        tool("add_reference_note", "Add a working note associated with a reference without changing canonical classification.", properties: [
            "reference_id": .string("Reference UUID"),
            "content": .string("Working note content"),
            "source_agent": .string("Agent name")
        ], required: ["reference_id", "content"]),
        tool("propose_reference_tags", "Suggest visual attributes for human approval in AI Inbox.", properties: [
            "reference_id": .string("Reference UUID"),
            "attributes": .object(["type": .string("array"), "items": .object(["type": .string("object")])]),
            "source_agent": .string("Agent name")
        ], required: ["reference_id", "attributes"]),
        tool("get_project_context", "Return a compact project context pack.", properties: [
            "project_id": .string("Project UUID"),
            "depth": .string("essential, standard or deep"),
            "source_agent": .string("Optional agent name")
        ], required: ["project_id"]),
        tool("get_constraints", "Return the non-negotiable constraints and Always Remember rules for a project.", properties: [
            "project_id": .string("Project UUID"),
            "source_agent": .string("Optional agent name")
        ], required: ["project_id"]),
        tool("get_tool_knowledge", "Return knowledge connected to a tool.", properties: [
            "tool_id": .string("Optional tool UUID"),
            "tool_name": .string("Optional exact tool name"),
            "source_agent": .string("Optional agent name")
        ]),
        tool("get_decisions", "Return project decisions.", properties: [
            "project_id": .string("Project UUID"),
            "source_agent": .string("Optional agent name")
        ], required: ["project_id"]),
        tool("get_recipe", "Return one recipe by id.", properties: [
            "recipe_id": .string("Recipe UUID"),
            "source_agent": .string("Optional agent name")
        ], required: ["recipe_id"]),
        tool("get_experiment", "Return an experiment Workbench setup and provenance metadata.", properties: [
            "experiment_id": .string("Experiment UUID"),
            "source_agent": .string("Optional agent name")
        ], required: ["experiment_id"]),
        tool("list_experiment_runs", "List immutable Run snapshots for an experiment.", properties: [
            "experiment_id": .string("Experiment UUID"),
            "source_agent": .string("Optional agent name")
        ], required: ["experiment_id"]),
        tool("compare_runs_metadata", "Compare structured metadata between two Runs. Never selects a winner.", properties: [
            "run_a_id": .string("First Run UUID"),
            "run_b_id": .string("Second Run UUID"),
            "source_agent": .string("Optional agent name")
        ], required: ["run_a_id", "run_b_id"]),
        tool("search_experiments", "Search experiments by title, goal, prompt and conclusion.", properties: [
            "query": .string("Search text"),
            "limit": .object(["type": .string("integer"), "description": .string("Maximum results")]),
            "source_agent": .string("Optional agent name")
        ], required: ["query"]),
        tool("get_best_run", "Return the human-selected Best Run for an experiment.", properties: [
            "experiment_id": .string("Experiment UUID"),
            "source_agent": .string("Optional agent name")
        ], required: ["experiment_id"]),
        tool("get_workflow", "Return one documented workflow and its ordered steps.", properties: [
            "flow_id": .string("Flow UUID"),
            "source_agent": .string("Optional agent name")
        ], required: ["flow_id"]),
        tool("add_working_note", "Write temporary working memory.", properties: [
            "content": .string("Working note content"),
            "source_agent": .string("Agent name"),
            "project_id": .string("Optional project UUID"),
            "tool_id": .string("Optional tool UUID")
        ], required: ["content"]),
        tool("propose_learning", "Propose permanent learning for human approval.", properties: [
            "title": .string("Proposal title"),
            "content": .string("Learning content"),
            "source_agent": .string("Agent name"),
            "project_id": .string("Optional project UUID"),
            "tool_id": .string("Optional tool UUID")
        ], required: ["title", "content"]),
        tool("propose_decision", "Propose a lasting decision for human approval.", properties: [
            "title": .string("Proposal title"),
            "content": .string("Decision content"),
            "source_agent": .string("Agent name"),
            "project_id": .string("Optional project UUID"),
            "tool_id": .string("Optional tool UUID")
        ], required: ["title", "content"]),
        tool("save_session_summary", "Save a deduplicated summary of an agent session.", properties: [
            "content": .string("Summary content"),
            "source_agent": .string("Agent name"),
            "project_id": .string("Optional project UUID")
        ], required: ["content"])
    ]

    /// The built-in MCP surface, kept for callers that need to inspect its schemas.
    public static var tools: [Tool] { builtInToolDefinitions }

    /// Registers built-in capabilities and feature-provided capabilities on an MCP server.
    /// A feature supplies its schema, safety classification and handler together;
    /// the transport publishes and dispatches the resulting registry automatically.
    public static func register(
        on server: Server,
        repository: FieldRepository,
        features: [any MCPToolFeature.Type] = []
    ) async throws {
        let builtIns = builtInToolDefinitions.map { definition in
            MCPToolCapability(
                tool: definition,
                effect: effect(for: definition.name),
                handler: { params, repository in
                    await dispatchBuiltIn(params, repository: repository)
                }
            )
        }
        let featureCapabilities = features.flatMap { feature in feature.capabilities }
        let registry = try MCPToolRegistry(capabilities: builtIns + featureCapabilities)
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: registry.tools)
        }
        await server.withMethodHandler(CallTool.self) { params in
            await registry.call(params, repository: repository)
        }
    }

    public static func call(_ params: CallTool.Parameters, repository: FieldRepository) async -> CallTool.Result {
        await dispatchBuiltIn(params, repository: repository)
    }

    private static func effect(for toolName: String) -> MCPToolEffect {
        switch toolName {
        case "add_reference_note", "add_working_note", "save_session_summary":
            .workingWrite
        case "propose_reference_tags", "propose_learning", "propose_decision":
            .proposalWrite
        default:
            .readOnly
        }
    }

    private static func dispatchBuiltIn(_ params: CallTool.Parameters, repository: FieldRepository) async -> CallTool.Result {
        switch params.name {
        case "search_knowledge":
            let query = params.arguments?["query"]?.stringValue ?? ""
            let projectID = uuid(params.arguments?["project_id"])
            let toolID = uuid(params.arguments?["tool_id"])
            let kind = params.arguments?["kind"]?.stringValue.flatMap(KnowledgeKind.init(rawValue:))
            let status = params.arguments?["status"]?.stringValue.flatMap(KnowledgeStatus.init(rawValue:))
            let limit = params.arguments?["limit"]?.intValue ?? Int(params.arguments?["limit"]?.stringValue ?? "20") ?? 20
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let results: [SearchResult] = await MainActor.run {
                let results = repository.search(query: query, filter: SearchFilter(kind: kind, status: status, projectID: projectID, toolID: toolID), limit: min(max(limit, 1), 100))
                repository.logActivity(agent: agent, action: "searched_knowledge", projectID: projectID, detail: query)
                return results
            }
            return textResult(results.map { [
                "id": $0.id.uuidString,
                "kind": $0.kind,
                "title": $0.title,
                "snippet": $0.snippet,
                "status": $0.status,
                "project": $0.projectTitle ?? "",
                "tool": $0.toolName ?? ""
            ] })

        case "search_references":
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let limit = params.arguments?["limit"]?.intValue ?? Int(params.arguments?["limit"]?.stringValue ?? "20") ?? 20
            let projectID = uuid(params.arguments?["project_id"])
            let collectionID = uuid(params.arguments?["collection_id"])
            let filter = ReferenceFilter(
                style: strings(params.arguments?["style"]),
                medium: strings(params.arguments?["medium"]),
                subject: strings(params.arguments?["subject"]),
                lighting: strings(params.arguments?["lighting"]),
                composition: strings(params.arguments?["composition"]),
                mood: strings(params.arguments?["mood"]),
                colorCharacter: strings(params.arguments?["color_character"]),
                sourceName: params.arguments?["source"]?.stringValue,
                projectID: projectID,
                tags: strings(params.arguments?["tags"]),
                includeArchived: params.arguments?["include_archived"]?.boolValue ?? false
            )
            let results: [[String: Any]] = await MainActor.run {
                let projects = repository.projects(includeArchived: true)
                let baseFilter: ReferenceFilter
                if let collectionID, let collection = repository.referenceCollections().first(where: { $0.id == collectionID }), collection.kind == .smart, let collectionFilter = collection.filter {
                    baseFilter = ReferenceFilter(
                        style: filter.style.isEmpty ? collectionFilter.style : filter.style,
                        medium: filter.medium.isEmpty ? collectionFilter.medium : filter.medium,
                        subject: filter.subject.isEmpty ? collectionFilter.subject : filter.subject,
                        lighting: filter.lighting.isEmpty ? collectionFilter.lighting : filter.lighting,
                        composition: filter.composition.isEmpty ? collectionFilter.composition : filter.composition,
                        mood: filter.mood.isEmpty ? collectionFilter.mood : filter.mood,
                        colorCharacter: filter.colorCharacter.isEmpty ? collectionFilter.colorCharacter : filter.colorCharacter,
                        sourceName: filter.sourceName ?? collectionFilter.sourceName,
                        sourceKind: filter.sourceKind ?? collectionFilter.sourceKind,
                        projectID: filter.projectID ?? collectionFilter.projectID,
                        tags: filter.tags.isEmpty ? collectionFilter.tags : filter.tags,
                        pinnedOnly: filter.pinnedOnly || collectionFilter.pinnedOnly,
                        unclassifiedOnly: filter.unclassifiedOnly || collectionFilter.unclassifiedOnly,
                        includeArchived: filter.includeArchived || collectionFilter.includeArchived
                    )
                } else if let collectionID, let collection = repository.referenceCollections().first(where: { $0.id == collectionID }) {
                    let ids = Set(collection.referenceIDs)
                    let queried = repository.queryReferences(ReferenceQuery(text: params.arguments?["query"]?.stringValue ?? "", filter: filter, limit: limit)).filter { ids.contains($0.id) }
                    repository.logActivity(agent: agent, action: "searched_references", projectID: projectID, detail: params.arguments?["query"]?.stringValue ?? "")
                    return queried.map { referenceSearchPayload($0, projects: projects) }
                } else {
                    baseFilter = filter
                }
                let queried = repository.queryReferences(ReferenceQuery(text: params.arguments?["query"]?.stringValue ?? "", filter: baseFilter, limit: limit))
                repository.logActivity(agent: agent, action: "searched_references", projectID: projectID, detail: params.arguments?["query"]?.stringValue ?? "")
                return queried.map { referenceSearchPayload($0, projects: projects) }
            }
            return textResult(results)

        case "get_reference":
            guard let referenceID = uuid(params.arguments?["reference_id"]) else { return errorResult("reference_id is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let payload: [String: Any]? = await MainActor.run {
                guard let reference = repository.references(filter: ReferenceFilter(includeArchived: true)).first(where: { $0.id == referenceID }) else { return nil }
                repository.logActivity(agent: agent, action: "read_reference", detail: reference.title)
                return referenceDetailPayload(reference, projects: repository.projects(includeArchived: true))
            }
            guard let payload else { return errorResult("Reference not found") }
            return textResult(payload)

        case "add_reference_note":
            guard let referenceID = uuid(params.arguments?["reference_id"]) else { return errorResult("reference_id is required") }
            guard let content = params.arguments?["content"]?.stringValue, !content.isEmpty else { return errorResult("content is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let item = try? await MainActor.run {
                guard let reference = repository.references(filter: ReferenceFilter(includeArchived: true)).first(where: { $0.id == referenceID }) else { throw ReferenceRepositoryError.referenceNotFound }
                return try repository.addWorkingNote(agent: agent, content: "Reference \(reference.title): \(content)")
            }
            guard let item else { return errorResult("Reference not found") }
            return textResult(["id": item.id.uuidString, "kind": item.kind.rawValue, "reference_id": referenceID.uuidString])

        case "propose_reference_tags":
            guard let referenceID = uuid(params.arguments?["reference_id"]) else { return errorResult("reference_id is required") }
            guard let values = params.arguments?["attributes"]?.arrayValue else { return errorResult("attributes must be an array") }
            let attributes = values.compactMap { value -> VisualAttribute? in
                guard let object = value.objectValue,
                      let category = object["category"]?.stringValue.flatMap(VisualAttributeCategory.init(rawValue:)),
                      let name = object["name"]?.stringValue, !name.isEmpty else { return nil }
                return VisualAttribute(category: category, name: name, origin: .agentProposal, confidence: object["confidence"]?.doubleValue)
            }
            guard !attributes.isEmpty else { return errorResult("attributes must contain category and name") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let proposal = try? await MainActor.run { try repository.proposeReferenceTags(agent: agent, referenceID: referenceID, attributes: attributes) }
            guard let proposal else { return errorResult("Could not create reference tag proposal") }
            return textResult(["id": proposal.id.uuidString, "status": proposal.status.rawValue, "reference_id": referenceID.uuidString])

        case "get_project_context":
            guard let projectID = uuid(params.arguments?["project_id"]) else { return errorResult("project_id is required") }
            let depth = params.arguments?["depth"]?.stringValue.flatMap(ContextDepth.init(rawValue:)) ?? .essential
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let context = await MainActor.run {
                let context = repository.projectContext(projectID: projectID, depth: depth)
                repository.logActivity(agent: agent, action: "read_project_context", projectID: projectID, detail: depth.rawValue)
                return context
            }
            guard let context else { return errorResult("Project not found") }
            return codableResult(context)

        case "get_constraints":
            guard let projectID = uuid(params.arguments?["project_id"]) else { return errorResult("project_id is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let payload: [String: String]? = await MainActor.run {
                guard let project = repository.projects(includeArchived: true).first(where: { $0.id == projectID }) else { return nil }
                repository.logActivity(agent: agent, action: "read_project_constraints", projectID: projectID, detail: project.title)
                return [
                    "project_id": project.id.uuidString,
                    "project_title": project.title,
                    "constraints": project.constraints,
                    "always_remember": project.alwaysRemember,
                    "deliverables": project.deliverables
                ]
            }
            guard let payload else { return errorResult("Project not found") }
            return textResult(payload)

        case "get_tool_knowledge":
            let toolID = uuid(params.arguments?["tool_id"])
            let toolName = params.arguments?["tool_name"]?.stringValue?.lowercased()
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let payload: [[String: String]] = await MainActor.run {
                let tools = repository.tools()
                let resolvedID = toolID ?? tools.first(where: { $0.name.lowercased() == toolName })?.id
                guard let resolvedID, let tool = tools.first(where: { $0.id == resolvedID }) else { return [] }
                repository.logActivity(agent: agent, action: "read_tool_knowledge", detail: tool.name)
                return repository.knowledge().filter { $0.toolID == resolvedID }.map {
                    [
                        "id": $0.id.uuidString,
                        "kind": $0.kind.rawValue,
                        "title": $0.title,
                        "body": $0.body,
                        "status": $0.status.rawValue,
                        "tool": tool.name
                    ]
                }
            }
            return textResult(payload)

        case "get_decisions":
            guard let projectID = uuid(params.arguments?["project_id"]) else { return errorResult("project_id is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let decisions = await MainActor.run {
                let decisions = repository.knowledge(kind: .decision, projectID: projectID)
                    .filter { $0.status != .archived }
                    .map { ["id": $0.id.uuidString, "title": $0.title, "body": $0.body, "status": $0.status.rawValue] }
                repository.logActivity(agent: agent, action: "read_project_decisions", projectID: projectID, detail: "\(decisions.count) decisions")
                return decisions
            }
            return textResult(decisions)

        case "get_experiment":
            guard let experimentID = uuid(params.arguments?["experiment_id"]) else { return errorResult("experiment_id is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let payload: [String: Any]? = await MainActor.run {
                guard let experiment = repository.experiments().first(where: { $0.id == experimentID }) else { return nil }
                let setup = repository.experimentSetup(experiment)
                repository.logActivity(agent: agent, action: "read_experiment", detail: experiment.title)
                return [
                    "id": experiment.id.uuidString,
                    "title": experiment.title,
                    "goal": experiment.goal,
                    "status": experiment.status.rawValue,
                    "conclusion": experiment.conclusion,
                    "best_run_id": experiment.bestRunID?.uuidString ?? "",
                    "project_id": experiment.projectID?.uuidString ?? "",
                    "setup": [
                        "reference_ids": setup.references.map(\.uuidString),
                        "prompt": setup.prompt,
                        "tool_id": setup.toolID?.uuidString ?? "",
                        "tool": setup.toolName,
                        "model": setup.model,
                        "settings": setup.settings.map { ["key": $0.key, "value": $0.value, "unit": $0.unit ?? "", "type": $0.type.rawValue] },
                        "prompt_block_ids": setup.promptBlockIDs.map(\.uuidString),
                        "execution_mode": setup.executionMode.rawValue
                    ]
                ]
            }
            guard let payload else { return errorResult("Experiment not found") }
            return textResult(payload)

        case "list_experiment_runs":
            guard let experimentID = uuid(params.arguments?["experiment_id"]) else { return errorResult("experiment_id is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let payload: [[String: Any]]? = await MainActor.run {
                guard repository.experiments().contains(where: { $0.id == experimentID }) else { return nil }
                let runs = repository.experimentRuns(experimentID: experimentID)
                repository.logActivity(agent: agent, action: "list_experiment_runs", detail: "\(runs.count) runs")
                return runs.map { run in
                    [
                        "id": run.id.uuidString,
                        "order": run.order,
                        "title": run.title,
                        "status": run.resultStatus.rawValue,
                        "evaluation": run.evaluation.rawValue,
                        "tool": run.snapshotToolName,
                        "model": run.model,
                        "prompt": run.prompt,
                        "settings": run.settingsEntries.map { ["key": $0.key, "value": $0.value] },
                        "reference_ids": run.inputReferenceIDs.map(\.uuidString),
                        "parent_run_id": run.parentRunID?.uuidString ?? "",
                        "has_result": run.outputData != nil,
                        "created_at": run.createdAt.ISO8601Format()
                    ]
                }
            }
            guard let payload else { return errorResult("Experiment not found") }
            return textResult(payload)

        case "compare_runs_metadata":
            guard let firstID = uuid(params.arguments?["run_a_id"]), let secondID = uuid(params.arguments?["run_b_id"]) else { return errorResult("run_a_id and run_b_id are required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let payload: [String: Any]? = await MainActor.run {
                let allRuns = (try? repository.context.fetch(FetchDescriptor<FieldExperimentRun>())) ?? []
                guard let first = allRuns.first(where: { $0.id == firstID }), let second = allRuns.first(where: { $0.id == secondID }) else { return nil }
                repository.logActivity(agent: agent, action: "compare_runs_metadata", detail: "\(first.title) · \(second.title)")
                return [
                    "run_a_id": first.id.uuidString,
                    "run_b_id": second.id.uuidString,
                    "run_a": ["title": first.title, "tool": first.snapshotToolName, "model": first.model, "evaluation": first.evaluation.rawValue],
                    "run_b": ["title": second.title, "tool": second.snapshotToolName, "model": second.model, "evaluation": second.evaluation.rawValue],
                    "changes": repository.runDelta(from: first, to: second).map { ["label": $0.label, "detail": $0.detail] }
                ]
            }
            guard let payload else { return errorResult("Run not found") }
            return textResult(payload)

        case "search_experiments":
            let query = params.arguments?["query"]?.stringValue ?? ""
            let limit = params.arguments?["limit"]?.intValue ?? Int(params.arguments?["limit"]?.stringValue ?? "20") ?? 20
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let payload = await MainActor.run {
                let terms = query.lowercased().split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
                let matches = repository.experiments().filter { experiment in
                    let searchable = [experiment.title, experiment.goal, experiment.prompt, experiment.conclusion].joined(separator: " ").lowercased()
                    return terms.isEmpty || terms.allSatisfy { searchable.contains($0) }
                }.prefix(max(1, min(limit, 100)))
                repository.logActivity(agent: agent, action: "search_experiments", detail: query)
                return matches.map { ["id": $0.id.uuidString, "title": $0.title, "goal": $0.goal, "status": $0.status.rawValue, "updated_at": $0.updatedAt.ISO8601Format()] }
            }
            return textResult(payload)

        case "get_best_run":
            guard let experimentID = uuid(params.arguments?["experiment_id"]) else { return errorResult("experiment_id is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let payload: [String: Any]? = await MainActor.run {
                guard let experiment = repository.experiments().first(where: { $0.id == experimentID }), let bestRunID = experiment.bestRunID,
                      let run = repository.experimentRuns(experimentID: experiment.id).first(where: { $0.id == bestRunID }) else { return nil }
                repository.logActivity(agent: agent, action: "read_best_run", detail: run.title)
                return ["id": run.id.uuidString, "title": run.title, "tool": run.snapshotToolName, "model": run.model, "evaluation": run.evaluation.rawValue, "has_result": run.outputData != nil]
            }
            guard let payload else { return errorResult("Best Run not found") }
            return textResult(payload)

        case "get_recipe":
            guard let recipeID = uuid(params.arguments?["recipe_id"]) else { return errorResult("recipe_id is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let recipe = await MainActor.run {
                let recipe = repository.knowledge(kind: .recipe).first { $0.id == recipeID }
                if let recipe { repository.logActivity(agent: agent, action: "read_recipe", detail: recipe.title) }
                return recipe
            }
            guard let recipe else { return errorResult("Recipe not found") }
            return textResult(["id": recipe.id.uuidString, "title": recipe.title, "body": recipe.body, "status": recipe.status.rawValue])

        case "get_workflow":
            guard let flowID = uuid(params.arguments?["flow_id"]) else { return errorResult("flow_id is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let payload: WorkflowPayload? = await MainActor.run {
                guard let flow = repository.flows().first(where: { $0.id == flowID }) else { return nil }
                repository.logActivity(agent: agent, action: "read_workflow", detail: flow.title)
                let steps = repository.flowSteps(flowID: flow.id).map { step in
                    WorkflowStepPayload(
                        id: step.id.uuidString,
                        order: step.order,
                        title: step.title,
                        instructions: step.instructions,
                        toolID: step.toolID?.uuidString ?? "",
                        recipeID: step.recipeID?.uuidString ?? "",
                        template: step.templateText,
                        notes: step.notes
                    )
                }
                return WorkflowPayload(id: flow.id.uuidString, title: flow.title, summary: flow.summary, steps: steps)
            }
            guard let payload else { return errorResult("Workflow not found") }
            return codableResult(payload)

        case "add_working_note":
            guard let content = params.arguments?["content"]?.stringValue, !content.isEmpty else { return errorResult("content is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let item = try? await MainActor.run {
                try repository.addWorkingNote(agent: agent, content: content, projectID: uuid(params.arguments?["project_id"]), toolID: uuid(params.arguments?["tool_id"]))
            }
            guard let item else { return errorResult("Could not save working note") }
            return textResult(["id": item.id.uuidString, "title": item.title, "kind": item.kind.rawValue])

        case "propose_learning", "propose_decision":
            guard let title = params.arguments?["title"]?.stringValue, !title.isEmpty else { return errorResult("title is required") }
            guard let content = params.arguments?["content"]?.stringValue, !content.isEmpty else { return errorResult("content is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let kind: KnowledgeKind = params.name == "propose_decision" ? .decision : .learning
            let proposal = try? await MainActor.run {
                try repository.propose(agent: agent, type: kind, title: title, content: content, projectID: uuid(params.arguments?["project_id"]), toolID: uuid(params.arguments?["tool_id"]))
            }
            guard let proposal else { return errorResult("Could not create proposal") }
            return textResult(["id": proposal.id.uuidString, "status": proposal.status.rawValue, "title": proposal.title])

        case "save_session_summary":
            guard let content = params.arguments?["content"]?.stringValue, !content.isEmpty else { return errorResult("content is required") }
            let agent = params.arguments?["source_agent"]?.stringValue ?? "unknown-agent"
            let item = try? await MainActor.run {
                try repository.saveSessionSummary(agent: agent, projectID: uuid(params.arguments?["project_id"]), content: content)
            }
            guard let item else { return errorResult("Could not save session summary") }
            return textResult(["id": item.id.uuidString, "title": item.title, "deduplicated": "true"])

        default:
            return errorResult("Unknown tool: \(params.name)")
        }
    }

    private static func tool(_ name: String, _ description: String, properties: [String: Value], required: [String] = []) -> Tool {
        Tool(
            name: name,
            description: description,
            inputSchema: MCPToolCapability.objectInputSchema(properties: properties, required: required)
        )
    }

    private static func uuid(_ value: Value?) -> UUID? {
        guard let string = value?.stringValue else { return nil }
        return UUID(uuidString: string)
    }

    private static func strings(_ value: Value?) -> [String] {
        if let values = value?.arrayValue { return values.compactMap(\.stringValue) }
        return value?.stringValue?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
    }

    private static func stringArrayProperty(_ description: String) -> Value {
        .object([
            "type": .string("array"),
            "description": .string(description),
            "items": .object(["type": .string("string")])
        ])
    }

    private static func referenceSearchPayload(_ reference: FieldReference, projects: [FieldProject] = []) -> [String: Any] {
        [
            "reference_id": reference.id.uuidString,
            "title": reference.title,
            "user_note": String(reference.userNote.prefix(240)),
            "source": reference.source.name,
            "source_kind": reference.source.kind.rawValue,
            "source_domain": reference.source.domain,
            "source_url": reference.sourceURL,
            "attributes": reference.visualAttributes.map { "\($0.category.rawValue): \($0.name)" },
            "tags": reference.manualTags,
            "automatic_tags": reference.automaticTags,
            "project_ids": reference.projectIDs.map(\.uuidString),
            "projects": reference.projectIDs.compactMap { id in projects.first { $0.id == id }?.title },
            "analysis_state": reference.analysisState.rawValue
        ]
    }

    private static func referenceDetailPayload(_ reference: FieldReference, projects: [FieldProject]) -> [String: Any] {
        var payload = referenceSearchPayload(reference, projects: projects)
        payload["created_at"] = reference.createdAt.ISO8601Format()
        payload["imported_at"] = reference.importedAt.ISO8601Format()
        payload["author"] = reference.author
        payload["original_title"] = reference.originalTitle
        payload["orientation"] = reference.orientationRaw ?? ""
        payload["width"] = reference.imageWidth ?? 0
        payload["height"] = reference.imageHeight ?? 0
        payload["ocr_text"] = String(reference.ocrText.prefix(2000))
        payload["dominant_colors"] = (try? JSONSerialization.jsonObject(with: Data(reference.dominantColorsJSON.utf8))) ?? []
        payload["collection_ids"] = reference.collectionIDs.map(\.uuidString)
        payload["pinned"] = reference.pinned
        payload["archived"] = reference.archived
        return payload
    }

    private static func errorResult(_ message: String) -> CallTool.Result {
        .init(content: [.text(message)], isError: true)
    }

    private static func textResult(_ value: Any) -> CallTool.Result {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])) ?? Data("{}".utf8)
        return .init(content: [.text(String(decoding: data, as: UTF8.self))], isError: false)
    }

    private static func codableResult<T: Encodable>(_ value: T) -> CallTool.Result {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(value)) ?? Data("{}".utf8)
        return .init(content: [.text(String(decoding: data, as: UTF8.self))], isError: false)
    }
}
