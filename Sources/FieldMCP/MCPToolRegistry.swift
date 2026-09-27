import Foundation
import FieldCore
import MCP

/// Describes the persistence boundary of an MCP capability.
public enum MCPToolEffect: Sendable, Equatable {
    case readOnly
    case workingWrite
    case proposalWrite
}

/// A single MCP capability. Its schema, safety classification and implementation
/// travel together so a feature does not need a catalog entry and a dispatch case.
public struct MCPToolCapability: Sendable {
    public typealias Handler = @Sendable (CallTool.Parameters, FieldRepository) async -> CallTool.Result

    public let tool: Tool
    public let effect: MCPToolEffect
    private let handler: Handler

    public init(
        name: String,
        description: String,
        properties: [String: Value],
        required: [String] = [],
        effect: MCPToolEffect,
        handler: @escaping Handler
    ) {
        let tool = Tool(
            name: name,
            description: description,
            inputSchema: Self.objectInputSchema(properties: properties, required: required)
        )
        self.init(tool: tool, effect: effect, handler: handler)
    }

    public init(tool: Tool, effect: MCPToolEffect, handler: @escaping Handler) {
        var annotatedTool = tool
        annotatedTool.annotations.readOnlyHint = effect == .readOnly
        annotatedTool.annotations.destructiveHint = false
        annotatedTool.annotations.idempotentHint = effect == .readOnly
        annotatedTool.annotations.openWorldHint = false
        self.tool = annotatedTool
        self.effect = effect
        self.handler = handler
    }

    /// Creates the standard JSON object input schema used by MCP tools.
    public static func objectInputSchema(properties: [String: Value], required: [String] = []) -> Value {
        let normalizedProperties = properties.mapValues { value in
            if case let .string(propertyDescription) = value {
                return Value.object([
                    "type": .string("string"),
                    "description": .string(propertyDescription)
                ])
            }
            return value
        }
        var schema: [String: Value] = [
            "type": .string("object"),
            "properties": .object(normalizedProperties)
        ]
        if !required.isEmpty { schema["required"] = .array(required.map { .string($0) }) }
        return .object(schema)
    }

    fileprivate func call(_ params: CallTool.Parameters, repository: FieldRepository) async -> CallTool.Result {
        await handler(params, repository)
    }
}

/// Feature modules provide capabilities as one cohesive declaration. The MCP
/// server enumerates these declarations for `tools/list` and routes `tools/call`.
public protocol MCPToolFeature: Sendable {
    static var capabilities: [MCPToolCapability] { get }
}

public enum MCPToolRegistryError: Error, LocalizedError, Sendable {
    case emptyName
    case invalidName(String)
    case duplicateName(String)

    public var errorDescription: String? {
        return switch self {
        case .emptyName:
            "MCP tool names cannot be empty."
        case let .invalidName(name):
            "MCP tool names cannot start or end with whitespace: \(name)"
        case let .duplicateName(name):
            "More than one MCP capability is registered as \(name)."
        }
    }
}

/// Composes MCP capabilities and provides a single list/call surface to the
/// transport. Registration rejects collisions instead of silently replacing a tool.
public struct MCPToolRegistry: Sendable {
    private var capabilitiesByName: [String: MCPToolCapability] = [:]
    private var orderedNames: [String] = []

    public init(capabilities: [MCPToolCapability] = []) throws {
        for capability in capabilities {
            try register(capability)
        }
    }

    public var tools: [Tool] {
        orderedNames.compactMap { capabilitiesByName[$0]?.tool }
    }

    public mutating func register(_ capability: MCPToolCapability) throws {
        let name = capability.tool.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw MCPToolRegistryError.emptyName }
        guard name == capability.tool.name else { throw MCPToolRegistryError.invalidName(capability.tool.name) }
        guard capabilitiesByName[name] == nil else { throw MCPToolRegistryError.duplicateName(name) }
        capabilitiesByName[name] = capability
        orderedNames.append(name)
    }

    public func call(_ params: CallTool.Parameters, repository: FieldRepository) async -> CallTool.Result {
        guard let capability = capabilitiesByName[params.name] else {
            return .init(content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)], isError: true)
        }
        return await capability.call(params, repository: repository)
    }
}
