import Foundation
import SwiftData

public enum KnowledgeKind: String, CaseIterable, Codable, Sendable {
    case learning
    case reference
    case promptBlock
    case style
    case recipe
    case experiment
    case decision
    case note
    case resource
    case idea
    case workingMemory
    case canonicalMemory
    case sessionSummary
    case flow

    public var displayName: String {
        switch self {
        case .learning: "Aprendizaje"
        case .reference: "Referencia"
        case .promptBlock: "Bloque de prompt"
        case .style: "Estilo"
        case .recipe: "Receta"
        case .experiment: "Experimento"
        case .decision: "Decisión"
        case .note: "Nota"
        case .resource: "Recurso"
        case .idea: "Idea"
        case .workingMemory: "Memoria de trabajo"
        case .canonicalMemory: "Memoria canónica"
        case .sessionSummary: "Resumen de sesión"
        case .flow: "Flujo"
        }
    }
}

public enum KnowledgeStatus: String, CaseIterable, Codable, Sendable {
    case new
    case testing
    case works
    case canonical
    case avoid
    case archived

    public var displayName: String {
        switch self {
        case .new: "Nuevo"
        case .testing: "En pruebas"
        case .works: "Funciona"
        case .canonical: "Canónico"
        case .avoid: "Evitar"
        case .archived: "Archivado"
        }
    }
}

public enum KnowledgeScope: String, CaseIterable, Codable, Sendable {
    case global
    case project
}

public enum SourceType: String, CaseIterable, Codable, Sendable {
    case user
    case claude
    case codex
    case otherAgent

    public var displayName: String {
        switch self {
        case .user: "Usuario"
        case .claude: "Claude"
        case .codex: "Codex"
        case .otherAgent: "Otro agente"
        }
    }
}

public enum ProposalStatus: String, CaseIterable, Codable, Sendable {
    case pending
    case approved
    case rejected
}

public enum ProposalRepositoryError: Error, Equatable, Sendable {
    case proposalNotPending
    case invalidProposalType
}

@Model
public final class FieldProject {
    public var id: UUID
    public var title: String
    public var summary: String
    public var brief: String
    public var creativeDirection: String
    public var constraints: String
    public var alwaysRemember: String
    public var deliverables: String
    public var archived: Bool
    public var pinned: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String = "",
        brief: String = "",
        creativeDirection: String = "",
        constraints: String = "",
        alwaysRemember: String = "",
        deliverables: String = "",
        archived: Bool = false,
        pinned: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.brief = brief
        self.creativeDirection = creativeDirection
        self.constraints = constraints
        self.alwaysRemember = alwaysRemember
        self.deliverables = deliverables
        self.archived = archived
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class FieldTool {
    public var id: UUID
    public var name: String
    public var category: String
    public var websiteURL: String
    public var notes: String
    public var uses: String
    public var strengths: String
    public var weaknesses: String
    public var pinned: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        category: String = "",
        websiteURL: String = "",
        notes: String = "",
        uses: String = "",
        strengths: String = "",
        weaknesses: String = "",
        pinned: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.websiteURL = websiteURL
        self.notes = notes
        self.uses = uses
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class KnowledgeItem {
    public var id: UUID
    public var kindRaw: String
    public var title: String
    public var body: String
    public var statusRaw: String
    public var scopeRaw: String
    public var sourceTypeRaw: String
    public var sourceAgent: String
    public var approvedByUser: Bool
    public var pinned: Bool
    public var projectID: UUID?
    public var toolID: UUID?
    public var tagNames: String
    public var urlString: String
    public var metadataJSON: String
    public var createdAt: Date
    public var updatedAt: Date

    public var kind: KnowledgeKind {
        get { KnowledgeKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    public var status: KnowledgeStatus {
        get { KnowledgeStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    public var scope: KnowledgeScope {
        get { KnowledgeScope(rawValue: scopeRaw) ?? .global }
        set { scopeRaw = newValue.rawValue }
    }

    public var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .user }
        set { sourceTypeRaw = newValue.rawValue }
    }

    public var tags: [String] {
        get {
            tagNames
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set { tagNames = newValue.joined(separator: ", ") }
    }

    @Attribute(.externalStorage)
    public var imageData: Data?

    public init(
        id: UUID = UUID(),
        kind: KnowledgeKind,
        title: String,
        body: String = "",
        status: KnowledgeStatus = .new,
        scope: KnowledgeScope = .global,
        sourceType: SourceType = .user,
        sourceAgent: String = "",
        approvedByUser: Bool = true,
        pinned: Bool = false,
        projectID: UUID? = nil,
        toolID: UUID? = nil,
        tags: [String] = [],
        urlString: String = "",
        imageData: Data? = nil,
        metadataJSON: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.title = title
        self.body = body
        self.statusRaw = status.rawValue
        self.scopeRaw = scope.rawValue
        self.sourceTypeRaw = sourceType.rawValue
        self.sourceAgent = sourceAgent
        self.approvedByUser = approvedByUser
        self.pinned = pinned
        self.projectID = projectID
        self.toolID = toolID
        self.tagNames = tags.joined(separator: ", ")
        self.urlString = urlString
        self.imageData = imageData
        self.metadataJSON = metadataJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class FieldTag {
    public var id: UUID
    public var name: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
public final class AgentProposal {
    public var id: UUID
    public var agent: String
    public var proposalTypeRaw: String
    public var title: String
    public var content: String
    public var projectID: UUID?
    public var toolID: UUID?
    public var referenceID: UUID?
    public var statusRaw: String
    public var createdAt: Date
    public var reviewedAt: Date?
    public var approvedKnowledgeID: UUID?

    public var status: ProposalStatus {
        get { ProposalStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        agent: String,
        proposalType: KnowledgeKind,
        title: String,
        content: String,
        projectID: UUID? = nil,
        toolID: UUID? = nil,
        referenceID: UUID? = nil,
        status: ProposalStatus = .pending,
        createdAt: Date = .now,
        reviewedAt: Date? = nil,
        approvedKnowledgeID: UUID? = nil
    ) {
        self.id = id
        self.agent = agent
        self.proposalTypeRaw = proposalType.rawValue
        self.title = title
        self.content = content
        self.projectID = projectID
        self.toolID = toolID
        self.referenceID = referenceID
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.reviewedAt = reviewedAt
        self.approvedKnowledgeID = approvedKnowledgeID
    }
}

@Model
public final class AgentActivity {
    public var id: UUID
    public var agent: String
    public var action: String
    public var timestamp: Date
    public var projectID: UUID?
    public var detail: String

    public init(
        id: UUID = UUID(),
        agent: String,
        action: String,
        timestamp: Date = .now,
        projectID: UUID? = nil,
        detail: String = ""
    ) {
        self.id = id
        self.agent = agent
        self.action = action
        self.timestamp = timestamp
        self.projectID = projectID
        self.detail = detail
    }
}

@Model
public final class FieldFlow {
    public var id: UUID
    public var title: String
    public var summary: String
    public var pinned: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), title: String, summary: String = "", pinned: Bool = false, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.summary = summary
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class FieldFlowStep {
    public var id: UUID
    public var flowID: UUID
    public var order: Int
    public var title: String
    public var instructions: String
    public var toolID: UUID?
    public var recipeID: UUID?
    public var templateText: String
    public var notes: String

    public init(id: UUID = UUID(), flowID: UUID, order: Int, title: String, instructions: String = "", toolID: UUID? = nil, recipeID: UUID? = nil, templateText: String = "", notes: String = "") {
        self.id = id
        self.flowID = flowID
        self.order = order
        self.title = title
        self.instructions = instructions
        self.toolID = toolID
        self.recipeID = recipeID
        self.templateText = templateText
        self.notes = notes
    }
}

public enum FieldModelContainer {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            FieldProject.self,
            FieldTool.self,
            KnowledgeItem.self,
            FieldTag.self,
            AgentProposal.self,
            AgentActivity.self,
            FieldFlow.self,
            FieldFlowStep.self,
            FieldExperiment.self,
            FieldExperimentRun.self,
            ToolPreset.self,
            FieldReference.self,
            ReferenceCollection.self
        ])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else if let storeDirectory = ProcessInfo.processInfo.environment["FIELD_DATA_DIR"], !storeDirectory.isEmpty {
            let directoryURL = URL(fileURLWithPath: storeDirectory, isDirectory: true)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let storeURL = directoryURL.appendingPathComponent("FIELD.store", isDirectory: false)
            configuration = ModelConfiguration("FIELD", schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
