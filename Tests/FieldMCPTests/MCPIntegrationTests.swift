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
    private func repository() throws -> FieldRepository {
        let container = try FieldModelContainer.make(inMemory: true)
        return FieldRepository(context: container.mainContext)
    }

    func testBearerAuthenticatorRejectsMissingOrWrongToken() {
        XCTAssertTrue(MCPRequestAuthenticator.isAuthorized(authorization: "Bearer secret", token: "secret"))
        XCTAssertFalse(MCPRequestAuthenticator.isAuthorized(authorization: nil, token: "secret"))
        XCTAssertFalse(MCPRequestAuthenticator.isAuthorized(authorization: "Bearer other", token: "secret"))
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

        await pair.client.disconnect()
        await pair.server.disconnect()
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
        guard case let .text(text) = result.content.first else {
            return XCTFail("Expected a text MCP result")
        }
        XCTAssertTrue(text.contains("Hard sunlight"))

        let workflow = try await client.callTool(name: "get_workflow", arguments: ["flow_id": .string(flow.id.uuidString)])
        XCTAssertFalse(workflow.isError ?? true)
        guard case let .text(workflowText) = workflow.content.first else {
            return XCTFail("Expected a workflow text result")
        }
        XCTAssertTrue(workflowText.contains("Campaign flow"))

        let constraints = try await client.callTool(name: "get_constraints", arguments: ["project_id": .string(project.id.uuidString)])
        XCTAssertFalse(constraints.isError ?? true)
        guard case let .text(constraintText) = constraints.content.first else {
            return XCTFail("Expected a constraints text result")
        }
        XCTAssertTrue(constraintText.contains("product unchanged"))
        XCTAssertTrue(repository.activities().contains { $0.action == "searched_knowledge" })
        XCTAssertTrue(repository.activities().contains { $0.action == "read_workflow" })

        await pair.client.disconnect()
        await pair.server.disconnect()
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

        await pair.client.disconnect()
        await pair.server.disconnect()
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
        guard case let .text(searchText) = search.content.first else { return XCTFail("Expected search text") }
        XCTAssertTrue(searchText.contains(reference.id.uuidString))

        let proposal = try await client.callTool(name: "propose_reference_tags", arguments: [
            "reference_id": .string(reference.id.uuidString),
            "attributes": .array([.object(["category": .string("mood"), "name": .string("Premium")])]),
            "source_agent": .string("Codex")
        ])
        XCTAssertFalse(proposal.isError ?? true)
        XCTAssertTrue(repository.proposals(status: .pending).contains { $0.referenceID == reference.id })
        XCTAssertEqual(reference.visualAttributes.count, 1)

        await pair.client.disconnect()
        await pair.server.disconnect()
        await server.stop()
    }
}
