import XCTest
import SwiftData
import MCP
@testable import FieldCore
@testable import FieldMCP

private enum RegistryTestFeature: MCPToolFeature {
    static let capabilities = [
        MCPToolCapability(
            name: "registry_test_echo",
            description: "Echo a message through a feature-registered MCP capability.",
            properties: ["message": .string("Text to echo")],
            required: ["message"],
            effect: .readOnly
        ) { params, _ in
            let message = params.arguments?["message"]?.stringValue ?? ""
            return .init(content: [.text(text: message, annotations: nil, _meta: nil)], isError: false)
        }
    ]
}

@MainActor
final class MCPIntegrationTests: XCTestCase {
    private var modelContainer: ModelContainer?

    private func repository() throws -> FieldRepository {
        let container = try FieldModelContainer.make(inMemory: true)
        modelContainer = container
        return FieldRepository(context: container.mainContext)
    }

    func testBearerAuthenticatorRejectsMissingOrWrongToken() {
        XCTAssertTrue(MCPRequestAuthenticator.isAuthorized(authorization: "Bearer secret", token: "secret"))
        XCTAssertTrue(MCPRequestAuthenticator.isAuthorized(authorization: "bearer secret", token: "secret"))
        XCTAssertTrue(MCPRequestAuthenticator.isAuthorized(authorization: "BEARER\tsecret", token: "secret"))
        XCTAssertFalse(MCPRequestAuthenticator.isAuthorized(authorization: nil, token: "secret"))
        XCTAssertFalse(MCPRequestAuthenticator.isAuthorized(authorization: "Bearer other", token: "secret"))
        XCTAssertFalse(MCPRequestAuthenticator.isAuthorized(authorization: "Basic secret", token: "secret"))
        XCTAssertFalse(MCPRequestAuthenticator.isAuthorized(authorization: "Bearer ", token: ""))
    }

    func testHTTPRequestHeaderParserSplitsCRLFBeforeReadingContentLength() {
        let lines = MCPHTTPRequestHeaderParser.lines(
            "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:8799\r\nContent-Length: 2"
        )

        XCTAssertEqual(lines, [
            "POST /mcp HTTP/1.1",
            "Host: 127.0.0.1:8799",
            "Content-Length: 2",
        ])
    }

    func testRegisteredFeatureCapabilityIsListedAndDispatched() async throws {
        let repository = try repository()
        let server = Server(
            name: "FIELD",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )
        try await MCPToolCatalog.register(on: server, repository: repository, features: [RegistryTestFeature.self])

        let pair = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: pair.server)
        let client = Client(name: "FIELD registry test client", version: "0.1.0")
        _ = try await client.connect(transport: pair.client)

        let listed = try await client.listTools()
        let echoTool = try XCTUnwrap(listed.tools.first { $0.name == "registry_test_echo" })
        XCTAssertEqual(echoTool.annotations.readOnlyHint, true)

        let response = try await client.callTool(name: "registry_test_echo", arguments: ["message": .string("pong")])
        XCTAssertFalse(response.isError ?? true)
        guard case let .text(text, _, _) = response.content.first else {
            return XCTFail("Expected the feature handler's text response")
        }
        XCTAssertEqual(text, "pong")

        await client.disconnect()
        await server.stop()
    }

    func testRegistryRejectsDuplicateCapabilityNames() throws {
        let capability = RegistryTestFeature.capabilities[0]
        XCTAssertThrowsError(try MCPToolRegistry(capabilities: [capability, capability]))
    }

    func testOfficialInMemoryTransportListsToolsAndSearchesKnowledge() async throws {
        let repository = try repository()
        _ = try repository.createKnowledge(
            kind: .learning,
            title: "Hard sunlight",
            body: "Use hard directional sunlight to preserve texture.",
            status: .works,
            tags: ["lighting"]
        )
        let project = try repository.createProject(title: "Campaign", summary: "A test project")
        project.constraints = "Keep the product unchanged."
        project.alwaysRemember = "Use the 9:16 master."
        try repository.updateProject(project)
        let flow = try repository.createFlow(title: "Campaign flow", summary: "A repeatable method")
        _ = try repository.createFlowStep(flowID: flow.id, title: "Concept", instructions: "Write the concept.")

        let server = Server(
            name: "FIELD",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )
        try await MCPToolCatalog.register(on: server, repository: repository)

        let pair = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: pair.server)

        let client = Client(name: "FIELD test client", version: "0.1.0")
        _ = try await client.connect(transport: pair.client)

        let listed = try await client.listTools()
        XCTAssertEqual(listed.tools.map(\.name), MCPToolCatalog.tools.map(\.name))
        XCTAssertTrue(listed.tools.contains { $0.name == "get_workflow" })
        XCTAssertTrue(listed.tools.contains { $0.name == "get_constraints" })
        let searchTool = try XCTUnwrap(listed.tools.first { $0.name == "search_knowledge" })
        let searchSchema = try XCTUnwrap(searchTool.inputSchema.objectValue)
        let searchProperties = try XCTUnwrap(searchSchema["properties"]?.objectValue)
        let querySchema = try XCTUnwrap(searchProperties["query"]?.objectValue)
        XCTAssertEqual(querySchema["type"]?.stringValue, "string")
        let limitSchema = try XCTUnwrap(searchProperties["limit"]?.objectValue)
        XCTAssertEqual(limitSchema["type"]?.stringValue, "integer")

        let result = try await client.callTool(
            name: "search_knowledge",
            arguments: ["query": .string("hard sunlight")]
        )
        XCTAssertFalse(result.isError ?? true)
        guard case let .text(text, _, _) = result.content.first else {
            return XCTFail("Expected a text MCP result")
        }
        XCTAssertTrue(text.contains("Hard sunlight"))

        let workflow = try await client.callTool(name: "get_workflow", arguments: ["flow_id": .string(flow.id.uuidString)])
        XCTAssertFalse(workflow.isError ?? true)
        guard case let .text(workflowText, _, _) = workflow.content.first else {
            return XCTFail("Expected a workflow text result")
        }
        XCTAssertTrue(workflowText.contains("Campaign flow"))

        let constraints = try await client.callTool(name: "get_constraints", arguments: ["project_id": .string(project.id.uuidString)])
        XCTAssertFalse(constraints.isError ?? true)
        guard case let .text(constraintText, _, _) = constraints.content.first else {
            return XCTFail("Expected a constraints text result")
        }
        XCTAssertTrue(constraintText.contains("product unchanged"))
        XCTAssertTrue(repository.activities().contains { $0.action == "searched_knowledge" })
        XCTAssertTrue(repository.activities().contains { $0.action == "read_workflow" })

        await client.disconnect()
        await server.stop()
    }

    func testProposalToolNeverWritesCanonicalKnowledgeDirectly() async throws {
        let repository = try repository()
        let server = Server(
            name: "FIELD",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )
        try await MCPToolCatalog.register(on: server, repository: repository)

        let pair = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: pair.server)
        let client = Client(name: "FIELD test client", version: "0.1.0")
        _ = try await client.connect(transport: pair.client)

        let response = try await client.callTool(
            name: "propose_learning",
            arguments: [
                "title": .string("Test learning"),
                "content": .string("Needs human approval."),
                "source_agent": .string("Codex")
            ]
        )

        XCTAssertFalse(response.isError ?? true)
        XCTAssertEqual(repository.knowledge().count, 0)
        XCTAssertEqual(repository.proposals(status: .pending).count, 1)

        await client.disconnect()
        await server.stop()
    }

    func testReferenceToolsSearchAndProposeWithoutDirectClassificationWrite() async throws {
        let repository = try repository()
        let reference = try repository.createReference(
            title: "Warm product study",
            userNote: "Hard light on a quiet surface.",
            urlString: "https://pinterest.com/pin/123",
            visualAttributes: [VisualAttribute(category: .medium, name: "Photography")]
        )
        let server = Server(
            name: "FIELD",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )
        try await MCPToolCatalog.register(on: server, repository: repository)

        let pair = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: pair.server)
        let client = Client(name: "FIELD reference test client", version: "0.1.0")
        _ = try await client.connect(transport: pair.client)

        let search = try await client.callTool(name: "search_references", arguments: ["query": .string("warm")])
        XCTAssertFalse(search.isError ?? true)
        guard case let .text(searchText, _, _) = search.content.first else { return XCTFail("Expected search text") }
        XCTAssertTrue(searchText.contains(reference.id.uuidString))

        let proposal = try await client.callTool(name: "propose_reference_tags", arguments: [
            "reference_id": .string(reference.id.uuidString),
            "attributes": .array([.object(["category": .string("mood"), "name": .string("Premium")])]),
            "source_agent": .string("Codex")
        ])
        XCTAssertFalse(proposal.isError ?? true)
        XCTAssertTrue(repository.proposals(status: .pending).contains { $0.referenceID == reference.id })
        XCTAssertEqual(reference.visualAttributes.count, 1)

        let missingReferenceProposal = try await client.callTool(name: "propose_reference_tags", arguments: [
            "reference_id": .string(UUID().uuidString),
            "attributes": .array([.object(["category": .string("mood"), "name": .string("Quiet")])]),
            "source_agent": .string("Codex")
        ])
        XCTAssertTrue(missingReferenceProposal.isError ?? false)
        XCTAssertEqual(repository.proposals(status: .pending).count, 1)

        await client.disconnect()
        await server.stop()
    }

    func testManualCollectionMembershipIsAppliedBeforeSearchLimit() async throws {
        let repository = try repository()
        let selected = try repository.createReference(title: "Summer collection reference")
        selected.updatedAt = .distantPast
        try repository.save()
        for index in 0..<21 {
            let reference = try repository.createReference(title: "Summer outside \(index)")
            reference.updatedAt = .distantFuture
        }
        try repository.save()
        let collection = try repository.createReferenceCollection(
            title: "Summer shortlist",
            kind: .manual,
            referenceIDs: [selected.id]
        )

        let server = Server(name: "FIELD", version: "0.1.0", capabilities: .init(tools: .init(listChanged: false)))
        try await MCPToolCatalog.register(on: server, repository: repository)
        let pair = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: pair.server)
        let client = Client(name: "FIELD collection test client", version: "0.1.0")
        _ = try await client.connect(transport: pair.client)

        let response = try await client.callTool(name: "search_references", arguments: [
            "query": .string("summer"),
            "collection_id": .string(collection.id.uuidString)
        ])
        XCTAssertFalse(response.isError ?? true)
        guard case let .text(text, _, _) = response.content.first else { return XCTFail("Expected reference search text") }
        let results = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [[String: Any]])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?["reference_id"] as? String, selected.id.uuidString)

        let malformedCollection = try await client.callTool(name: "search_references", arguments: [
            "query": .string("summer"),
            "collection_id": .string("not-a-uuid")
        ])
        let missingCollection = try await client.callTool(name: "search_references", arguments: [
            "query": .string("summer"),
            "collection_id": .string(UUID().uuidString)
        ])
        XCTAssertTrue(malformedCollection.isError ?? false)
        XCTAssertTrue(missingCollection.isError ?? false)

        _ = try repository.createReference(
            title: "Cinematic study",
            visualAttributes: [VisualAttribute(category: .style, name: "Cinematic")]
        )
        _ = try repository.createReference(
            title: "Warm study",
            visualAttributes: [VisualAttribute(category: .style, name: "Warm")]
        )
        let smartCollection = try repository.createReferenceCollection(
            title: "Cinematic references",
            kind: .smart,
            filter: ReferenceFilter(style: ["Cinematic"])
        )
        let conflictingSmartFilter = try await client.callTool(name: "search_references", arguments: [
            "collection_id": .string(smartCollection.id.uuidString),
            "style": .array([.string("Warm")])
        ])
        XCTAssertFalse(conflictingSmartFilter.isError ?? true)
        guard case let .text(smartText, _, _) = conflictingSmartFilter.content.first else { return XCTFail("Expected smart collection search text") }
        let smartResults = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(smartText.utf8)) as? [[String: Any]])
        XCTAssertTrue(smartResults.isEmpty, "Additional filters must refine a smart collection, not replace its definition")

        await client.disconnect()
        await server.stop()
    }

    func testGetRecipeAndListRunsReturnCompleteStructuredSettings() async throws {
        let repository = try repository()
        let tool = try repository.createTool(name: "Krea")
        let reference = try repository.createReference(title: "Bottle reference")
        let promptBlock = try repository.createKnowledge(kind: .promptBlock, title: "Material", body: "Preserve the glaze.")
        let experiment = try repository.createExperiment(title: "Material study", toolID: tool.id)
        experiment.prompt = "Natural light on ceramic."
        experiment.model = "Flux"
        experiment.settingsEntries = [SettingEntry(key: "Strength", value: "0.45", unit: "%", type: .number)]
        experiment.referenceIDs = [reference.id]
        experiment.promptBlockIDs = [promptBlock.id]
        try repository.updateExperiment(experiment)
        let run = try repository.createRunFromSetup(experiment: experiment)
        try repository.setBestRun(run, for: experiment)
        let recipe = try repository.saveBestRunAsRecipe(experiment)

        let server = Server(name: "FIELD", version: "0.1.0", capabilities: .init(tools: .init(listChanged: false)))
        try await MCPToolCatalog.register(on: server, repository: repository)
        let pair = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: pair.server)
        let client = Client(name: "FIELD recipe test client", version: "0.1.0")
        _ = try await client.connect(transport: pair.client)

        let recipeResponse = try await client.callTool(name: "get_recipe", arguments: ["recipe_id": .string(recipe.id.uuidString)])
        XCTAssertFalse(recipeResponse.isError ?? true)
        guard case let .text(recipeText, _, _) = recipeResponse.content.first else { return XCTFail("Expected recipe text") }
        let recipeJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(recipeText.utf8)) as? [String: Any])
        let recipePayload = try XCTUnwrap(recipeJSON["payload"] as? [String: Any])
        XCTAssertEqual(recipePayload["model"] as? String, "Flux")
        XCTAssertEqual(recipePayload["prompt"] as? String, "Natural light on ceramic.")
        XCTAssertEqual(recipePayload["reference_ids"] as? [String], [reference.id.uuidString])
        XCTAssertEqual(recipePayload["prompt_block_ids"] as? [String], [promptBlock.id.uuidString])
        let recipeSettings = try XCTUnwrap(recipePayload["settings"] as? [[String: Any]])
        XCTAssertEqual(recipeSettings.first?["unit"] as? String, "%")
        XCTAssertEqual(recipeSettings.first?["type"] as? String, "number")

        let runsResponse = try await client.callTool(name: "list_experiment_runs", arguments: ["experiment_id": .string(experiment.id.uuidString)])
        XCTAssertFalse(runsResponse.isError ?? true)
        guard case let .text(runsText, _, _) = runsResponse.content.first else { return XCTFail("Expected run list text") }
        let runs = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(runsText.utf8)) as? [[String: Any]])
        let listedSettings = try XCTUnwrap(runs.first?["settings"] as? [[String: Any]])
        XCTAssertEqual(listedSettings.first?["unit"] as? String, "%")
        XCTAssertEqual(listedSettings.first?["type"] as? String, "number")

        await client.disconnect()
        await server.stop()
    }

    func testSaveSessionSummaryReportsWhetherItWasDeduplicated() async throws {
        let repository = try repository()
        let server = Server(name: "FIELD", version: "0.1.0", capabilities: .init(tools: .init(listChanged: false)))
        try await MCPToolCatalog.register(on: server, repository: repository)
        let pair = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: pair.server)
        let client = Client(name: "FIELD summary test client", version: "0.1.0")
        _ = try await client.connect(transport: pair.client)

        let arguments: [String: Value] = ["content": .string("Worked on the ceramic study."), "source_agent": .string("Codex")]
        let first = try await client.callTool(name: "save_session_summary", arguments: arguments)
        let second = try await client.callTool(name: "save_session_summary", arguments: arguments)
        XCTAssertFalse(first.isError ?? true)
        XCTAssertFalse(second.isError ?? true)
        guard case let .text(firstText, _, _) = first.content.first,
              case let .text(secondText, _, _) = second.content.first else {
            return XCTFail("Expected session summary results")
        }
        let firstJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(firstText.utf8)) as? [String: Any])
        let secondJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(secondText.utf8)) as? [String: Any])
        XCTAssertEqual(firstJSON["deduplicated"] as? Bool, false)
        XCTAssertEqual(secondJSON["deduplicated"] as? Bool, true)
        XCTAssertEqual(firstJSON["id"] as? String, secondJSON["id"] as? String)
        XCTAssertEqual(repository.knowledge(kind: .sessionSummary).count, 1)

        await client.disconnect()
        await server.stop()
    }

    func testSearchExperimentsWithWhitespaceDoesNotReturnAllExperiments() async throws {
        let repository = try repository()
        _ = try repository.createExperiment(title: "Natural light")
        let server = Server(name: "FIELD", version: "0.1.0", capabilities: .init(tools: .init(listChanged: false)))
        try await MCPToolCatalog.register(on: server, repository: repository)
        let pair = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: pair.server)
        let client = Client(name: "FIELD experiment search test client", version: "0.1.0")
        _ = try await client.connect(transport: pair.client)

        let response = try await client.callTool(name: "search_experiments", arguments: ["query": .string("   ")])
        XCTAssertFalse(response.isError ?? true)
        guard case let .text(text, _, _) = response.content.first else { return XCTFail("Expected experiment search text") }
        let results = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [[String: Any]])
        XCTAssertTrue(results.isEmpty)

        await client.disconnect()
        await server.stop()
    }

    func testOptionalUUIDsRejectMalformedOrMissingScopedTargets() async throws {
        let repository = try repository()
        let server = Server(name: "FIELD", version: "0.1.0", capabilities: .init(tools: .init(listChanged: false)))
        try await MCPToolCatalog.register(on: server, repository: repository)
        let pair = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: pair.server)
        let client = Client(name: "FIELD scoped IDs test client", version: "0.1.0")
        _ = try await client.connect(transport: pair.client)
        let unknownProjectID = UUID()

        let malformedKnowledgeFilter = try await client.callTool(name: "search_knowledge", arguments: [
            "query": .string("campaign"),
            "project_id": .string("not-a-uuid")
        ])
        let malformedReferenceFilter = try await client.callTool(name: "search_references", arguments: [
            "project_id": .string("not-a-uuid")
        ])
        let missingKnowledgeProject = try await client.callTool(name: "search_knowledge", arguments: [
            "query": .string("campaign"),
            "project_id": .string(unknownProjectID.uuidString)
        ])
        let missingReferenceProject = try await client.callTool(name: "search_references", arguments: [
            "project_id": .string(unknownProjectID.uuidString)
        ])
        let missingProjectContext = try await client.callTool(name: "get_project_context", arguments: [
            "project_id": .string(unknownProjectID.uuidString)
        ])
        let missingProjectDecisions = try await client.callTool(name: "get_decisions", arguments: [
            "project_id": .string(unknownProjectID.uuidString)
        ])
        let unknownKnowledgeKind = try await client.callTool(name: "search_knowledge", arguments: [
            "query": .string("campaign"),
            "kind": .string("not-a-kind")
        ])
        let malformedReferenceAttribute = try await client.callTool(name: "search_references", arguments: [
            "style": .object([:])
        ])
        let missingKnowledgeQuery = try await client.callTool(name: "search_knowledge", arguments: [:])
        let missingExperimentQuery = try await client.callTool(name: "search_experiments", arguments: [:])
        let malformedWorkingNote = try await client.callTool(name: "add_working_note", arguments: [
            "content": .string("This must not become global."),
            "project_id": .string("not-a-uuid")
        ])
        let missingWorkingNoteTarget = try await client.callTool(name: "add_working_note", arguments: [
            "content": .string("This must not become global either."),
            "project_id": .string(unknownProjectID.uuidString)
        ])
        let missingProposalTool = try await client.callTool(name: "propose_learning", arguments: [
            "title": .string("Scoped learning"),
            "content": .string("A proposed learning."),
            "tool_id": .string(UUID().uuidString)
        ])
        let missingSummaryProject = try await client.callTool(name: "save_session_summary", arguments: [
            "content": .string("This summary must not become global."),
            "project_id": .string(unknownProjectID.uuidString)
        ])

        XCTAssertTrue(malformedKnowledgeFilter.isError ?? false)
        XCTAssertTrue(malformedReferenceFilter.isError ?? false)
        XCTAssertTrue(missingKnowledgeProject.isError ?? false)
        XCTAssertTrue(missingReferenceProject.isError ?? false)
        XCTAssertTrue(missingProjectContext.isError ?? false)
        XCTAssertTrue(missingProjectDecisions.isError ?? false)
        XCTAssertTrue(unknownKnowledgeKind.isError ?? false)
        XCTAssertTrue(malformedReferenceAttribute.isError ?? false)
        XCTAssertTrue(missingKnowledgeQuery.isError ?? false)
        XCTAssertTrue(missingExperimentQuery.isError ?? false)
        XCTAssertTrue(malformedWorkingNote.isError ?? false)
        XCTAssertTrue(missingWorkingNoteTarget.isError ?? false)
        XCTAssertTrue(missingProposalTool.isError ?? false)
        XCTAssertTrue(missingSummaryProject.isError ?? false)
        XCTAssertTrue(repository.knowledge(kind: .workingMemory).isEmpty)
        XCTAssertTrue(repository.knowledge(kind: .sessionSummary).isEmpty)
        XCTAssertTrue(repository.proposals(status: .pending).isEmpty)
        XCTAssertFalse(repository.activities().contains { $0.projectID == unknownProjectID })

        await client.disconnect()
        await server.stop()
    }

    func testScopedMCPWritesKeepValidProjectAndToolLinks() async throws {
        let repository = try repository()
        let project = try repository.createProject(title: "Scoped project")
        let tool = try repository.createTool(name: "Scoped tool")
        let server = Server(name: "FIELD", version: "0.1.0", capabilities: .init(tools: .init(listChanged: false)))
        try await MCPToolCatalog.register(on: server, repository: repository)
        let pair = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: pair.server)
        let client = Client(name: "FIELD scoped writes test client", version: "0.1.0")
        _ = try await client.connect(transport: pair.client)

        let note = try await client.callTool(name: "add_working_note", arguments: [
            "content": .string("Scoped note."),
            "project_id": .string(project.id.uuidString),
            "tool_id": .string(tool.id.uuidString)
        ])
        let proposal = try await client.callTool(name: "propose_learning", arguments: [
            "title": .string("Scoped learning"),
            "content": .string("This belongs to the project and tool."),
            "project_id": .string(project.id.uuidString),
            "tool_id": .string(tool.id.uuidString)
        ])
        let summary = try await client.callTool(name: "save_session_summary", arguments: [
            "content": .string("Scoped summary."),
            "project_id": .string(project.id.uuidString)
        ])

        XCTAssertFalse(note.isError ?? true)
        XCTAssertFalse(proposal.isError ?? true)
        XCTAssertFalse(summary.isError ?? true)
        let savedNote = try XCTUnwrap(repository.knowledge(kind: .workingMemory).first)
        XCTAssertEqual(savedNote.projectID, project.id)
        XCTAssertEqual(savedNote.toolID, tool.id)
        let savedProposal = try XCTUnwrap(repository.proposals(status: .pending).first)
        XCTAssertEqual(savedProposal.projectID, project.id)
        XCTAssertEqual(savedProposal.toolID, tool.id)
        let savedSummary = try XCTUnwrap(repository.knowledge(kind: .sessionSummary).first)
        XCTAssertEqual(savedSummary.projectID, project.id)

        await client.disconnect()
        await server.stop()
    }
}
