import Foundation
import SwiftData

public enum ExperimentStatus: String, CaseIterable, Codable, Sendable {
    case testing
    case works
    case failed
    case archived

    public var displayName: String {
        switch self {
        case .testing: "En pruebas"
        case .works: "Funciona"
        case .failed: "Fallido"
        case .archived: "Archivado"
        }
    }
}

public enum ExperimentRepositoryError: Error, Equatable, Sendable {
    case experimentNotFound
    case runNotFound
    case bestRunRequired
    case recipeNotFound
}

/// Technical lifecycle of a run. `works` remains as a legacy value so stores
/// created by the first LAB prototype continue to decode correctly.
public enum ExperimentRunStatus: String, CaseIterable, Codable, Sendable {
    case prepared
    case testing
    case completed
    case failed
    case archived
    case works

    public static var allCases: [ExperimentRunStatus] { [.prepared, .testing, .completed, .failed, .archived] }

    public var displayName: String {
        switch self {
        case .prepared: "Preparado"
        case .testing: "En pruebas"
        case .completed, .works: "Completado"
        case .failed: "Fallido"
        case .archived: "Archivado"
        }
    }
}

public enum ExperimentRunEvaluation: String, CaseIterable, Codable, Sendable {
    case unrated
    case bad
    case interesting
    case works
    case best

    public var displayName: String {
        switch self {
        case .unrated: "Sin valorar"
        case .bad: "No funciona"
        case .interesting: "Interesante"
        case .works: "Funciona"
        case .best: "Mejor resultado"
        }
    }
}

public enum ExperimentExecutionMode: String, CaseIterable, Codable, Sendable {
    case external
    case connected

    public var displayName: String {
        switch self {
        case .external: "Externa"
        case .connected: "Conectada"
        }
    }
}

public enum SettingValueType: String, CaseIterable, Codable, Sendable {
    case text
    case number
    case boolean
    case choice

    public var displayName: String {
        switch self {
        case .text: "Texto"
        case .number: "Número"
        case .boolean: "Booleano"
        case .choice: "Opción"
        }
    }
}

public struct SettingEntry: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var key: String
    public var value: String
    public var unit: String?
    public var type: SettingValueType

    public init(id: UUID = UUID(), key: String, value: String, unit: String? = nil, type: SettingValueType = .text) {
        self.id = id
        self.key = key
        self.value = value
        self.unit = unit
        self.type = type
    }
}

/// The editable state of an experiment. A run receives a serialized copy of
/// this value; it never reads the live experiment after creation.
public struct ExperimentSetup: Codable, Equatable, Sendable {
    public var references: [UUID]
    public var prompt: String
    public var toolID: UUID?
    public var toolName: String
    public var toolWebsiteURL: String
    public var model: String
    public var settings: [SettingEntry]
    public var promptBlockIDs: [UUID]
    public var executionMode: ExperimentExecutionMode

    public init(
        references: [UUID] = [],
        prompt: String = "",
        toolID: UUID? = nil,
        toolName: String = "",
        toolWebsiteURL: String = "",
        model: String = "",
        settings: [SettingEntry] = [],
        promptBlockIDs: [UUID] = [],
        executionMode: ExperimentExecutionMode = .external
    ) {
        self.references = references
        self.prompt = prompt
        self.toolID = toolID
        self.toolName = toolName
        self.toolWebsiteURL = toolWebsiteURL
        self.model = model
        self.settings = settings
        self.promptBlockIDs = promptBlockIDs
        self.executionMode = executionMode
    }
}

public struct ExperimentRunDelta: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let label: String
    public let detail: String

    public init(id: UUID = UUID(), label: String, detail: String) {
        self.id = id
        self.label = label
        self.detail = detail
    }
}

public struct RecipePayload: Codable, Equatable, Sendable {
    public var toolID: UUID?
    public var model: String
    public var prompt: String
    public var settings: [SettingEntry]
    public var promptBlockIDs: [UUID]
    public var references: [UUID]

    public init(toolID: UUID? = nil, model: String = "", prompt: String = "", settings: [SettingEntry] = [], promptBlockIDs: [UUID] = [], references: [UUID] = []) {
        self.toolID = toolID
        self.model = model
        self.prompt = prompt
        self.settings = settings
        self.promptBlockIDs = promptBlockIDs
        self.references = references
    }
}

private enum ExperimentJSON {
    static func encode<T: Encodable>(_ value: T, fallback: String = "[]") -> String {
        String(decoding: (try? JSONEncoder().encode(value)) ?? Data(fallback.utf8), as: UTF8.self)
    }

    static func decode<T: Decodable>(_ type: T.Type, from value: String, fallback: T) -> T {
        (try? JSONDecoder().decode(type, from: Data(value.utf8))) ?? fallback
    }
}

@Model
public final class FieldExperiment {
    public var id: UUID = UUID()
    public var title: String = ""
    public var goal: String = ""
    public var statusRaw: String = ""
    public var toolID: UUID? = nil
    public var projectID: UUID? = nil
    public var conclusion: String = ""
    public var referenceIDsJSON: String = ""
    public var prompt: String = ""
    public var model: String = ""
    public var settingsJSON: String = ""
    public var promptBlockIDsJSON: String = ""
    public var executionModeRaw: String = ""
    public var bestRunID: UUID? = nil
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public var status: ExperimentStatus {
        get { ExperimentStatus(rawValue: statusRaw) ?? .testing }
        set { statusRaw = newValue.rawValue }
    }

    public var executionMode: ExperimentExecutionMode {
        get { ExperimentExecutionMode(rawValue: executionModeRaw) ?? .external }
        set { executionModeRaw = newValue.rawValue }
    }

    public var referenceIDs: [UUID] {
        get { ExperimentJSON.decode([UUID].self, from: referenceIDsJSON, fallback: []) }
        set { referenceIDsJSON = ExperimentJSON.encode(newValue) }
    }

    public var settingsEntries: [SettingEntry] {
        get { ExperimentJSON.decode([SettingEntry].self, from: settingsJSON, fallback: []) }
        set { settingsJSON = ExperimentJSON.encode(newValue) }
    }

    public var promptBlockIDs: [UUID] {
        get { ExperimentJSON.decode([UUID].self, from: promptBlockIDsJSON, fallback: []) }
        set { promptBlockIDsJSON = ExperimentJSON.encode(newValue) }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        goal: String = "",
        status: ExperimentStatus = .testing,
        toolID: UUID? = nil,
        projectID: UUID? = nil,
        conclusion: String = "",
        referenceIDs: [UUID] = [],
        prompt: String = "",
        model: String = "",
        settings: [SettingEntry] = [],
        promptBlockIDs: [UUID] = [],
        executionMode: ExperimentExecutionMode = .external,
        bestRunID: UUID? = nil,
        createdAt: Date = Date.now,
        updatedAt: Date = Date.now
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.statusRaw = status.rawValue
        self.toolID = toolID
        self.projectID = projectID
        self.conclusion = conclusion
        self.referenceIDsJSON = ExperimentJSON.encode(referenceIDs)
        self.prompt = prompt
        self.model = model
        self.settingsJSON = ExperimentJSON.encode(settings)
        self.promptBlockIDsJSON = ExperimentJSON.encode(promptBlockIDs)
        self.executionModeRaw = executionMode.rawValue
        self.bestRunID = bestRunID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class FieldExperimentRun {
    public var id: UUID = UUID()
    public var experimentID: UUID = UUID()
    public var order: Int = 0
    public var title: String = ""
    public var prompt: String = ""
    /// Kept as a string for backwards compatibility; new Runs store the
    /// serialized `[SettingEntry]` value here.
    public var settings: String = ""
    public var observation: String = ""
    public var resultStatusRaw: String = ""
    public var evaluationRaw: String = ""
    public var executionModeRaw: String = ""
    public var toolID: UUID? = nil
    public var snapshotToolName: String = ""
    public var snapshotToolWebsiteURL: String = ""
    public var model: String = ""
    public var inputReferenceIDsJSON: String = ""
    public var snapshotPromptBlockIDsJSON: String = ""
    public var parentRunID: UUID? = nil
    @Attribute(.externalStorage)
    public var outputData: Data? = nil
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public var resultStatus: ExperimentRunStatus {
        get { ExperimentRunStatus(rawValue: resultStatusRaw) ?? .prepared }
        set { resultStatusRaw = newValue.rawValue }
    }

    public var evaluation: ExperimentRunEvaluation {
        get { ExperimentRunEvaluation(rawValue: evaluationRaw) ?? .unrated }
        set { evaluationRaw = newValue.rawValue }
    }

    public var executionMode: ExperimentExecutionMode {
        get { ExperimentExecutionMode(rawValue: executionModeRaw) ?? .external }
        set { executionModeRaw = newValue.rawValue }
    }

    public var inputReferenceIDs: [UUID] {
        get { ExperimentJSON.decode([UUID].self, from: inputReferenceIDsJSON, fallback: []) }
        set { inputReferenceIDsJSON = ExperimentJSON.encode(newValue) }
    }

    public var snapshotPromptBlockIDs: [UUID] {
        get { ExperimentJSON.decode([UUID].self, from: snapshotPromptBlockIDsJSON, fallback: []) }
        set { snapshotPromptBlockIDsJSON = ExperimentJSON.encode(newValue) }
    }

    public var settingsEntries: [SettingEntry] {
        get {
            let decoded = ExperimentJSON.decode([SettingEntry].self, from: settings, fallback: [])
            if !decoded.isEmpty || settings == "[]" || settings.isEmpty { return decoded }
            return settings
                .split(separator: "\n")
                .compactMap { line in
                    let pair = line.split(separator: ":", maxSplits: 1).map(String.init)
                    guard pair.count == 2 else { return nil }
                    return SettingEntry(key: pair[0].trimmingCharacters(in: .whitespaces), value: pair[1].trimmingCharacters(in: .whitespaces))
                }
        }
        set { settings = ExperimentJSON.encode(newValue) }
    }

    public init(
        id: UUID = UUID(),
        experimentID: UUID,
        order: Int,
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
        snapshotPromptBlockIDs: [UUID] = [],
        parentRunID: UUID? = nil,
        outputData: Data? = nil,
        createdAt: Date = Date.now,
        updatedAt: Date = Date.now
    ) {
        self.id = id
        self.experimentID = experimentID
        self.order = order
        self.title = title
        self.prompt = prompt
        self.settings = settings
        self.observation = observation
        self.resultStatusRaw = resultStatus.rawValue
        self.evaluationRaw = evaluation.rawValue
        self.executionModeRaw = executionMode.rawValue
        self.toolID = toolID
        self.snapshotToolName = snapshotToolName
        self.snapshotToolWebsiteURL = snapshotToolWebsiteURL
        self.model = model
        self.inputReferenceIDsJSON = ExperimentJSON.encode(inputReferenceIDs)
        self.snapshotPromptBlockIDsJSON = ExperimentJSON.encode(snapshotPromptBlockIDs)
        self.parentRunID = parentRunID
        self.outputData = outputData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class ToolPreset {
    public var id: UUID = UUID()
    public var toolID: UUID? = nil
    public var name: String = ""
    public var model: String = ""
    public var settingsJSON: String = ""
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public var settings: [SettingEntry] {
        get { ExperimentJSON.decode([SettingEntry].self, from: settingsJSON, fallback: []) }
        set { settingsJSON = ExperimentJSON.encode(newValue) }
    }

    public init(id: UUID = UUID(), toolID: UUID? = nil, name: String, model: String = "", settings: [SettingEntry] = [], createdAt: Date = Date.now, updatedAt: Date = Date.now) {
        self.id = id
        self.toolID = toolID
        self.name = name
        self.model = model
        self.settingsJSON = ExperimentJSON.encode(settings)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
