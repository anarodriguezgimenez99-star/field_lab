import Foundation
import SwiftData

public enum ReferenceSourceKind: String, CaseIterable, Codable, Sendable {
    case web
    case native
    case manual
    case clipboard

    public var displayName: String {
        switch self {
        case .web: "Web"
        case .native: "Native app"
        case .manual: "Manual"
        case .clipboard: "Clipboard"
        }
    }
}

public struct ReferenceSource: Codable, Equatable, Sendable {
    public var kind: ReferenceSourceKind
    public var name: String
    public var url: String
    public var domain: String
    public var identifier: String
    public var author: String
    public var originalTitle: String

    public init(
        kind: ReferenceSourceKind = .manual,
        name: String = "Manual",
        url: String = "",
        domain: String = "",
        identifier: String = "",
        author: String = "",
        originalTitle: String = ""
    ) {
        self.kind = kind
        self.name = name
        self.url = url
        self.domain = domain
        self.identifier = identifier
        self.author = author
        self.originalTitle = originalTitle
    }
}

public protocol ReferenceSourceAdapter: Sendable {
    var displayName: String { get }
    func matches(host: String) -> Bool
}

public struct DomainReferenceSourceAdapter: ReferenceSourceAdapter {
    public let displayName: String
    public let domains: [String]

    public init(displayName: String, domains: [String]) {
        self.displayName = displayName
        self.domains = domains
    }

    public func matches(host: String) -> Bool {
        domains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}

/// Centralized URL/source detection. Adding a provider should only require a
/// new rule here, never a comparison inside a SwiftUI view.
public enum ReferenceSourceResolver {
    public static let adapters: [any ReferenceSourceAdapter] = [
        DomainReferenceSourceAdapter(displayName: "Pinterest", domains: ["pinterest.com", "pin.it"]),
        DomainReferenceSourceAdapter(displayName: "Cosmos", domains: ["cosmos.so"]),
        DomainReferenceSourceAdapter(displayName: "LinkedIn", domains: ["linkedin.com"]),
        DomainReferenceSourceAdapter(displayName: "Instagram", domains: ["instagram.com"]),
        DomainReferenceSourceAdapter(displayName: "Behance", domains: ["behance.net"]),
        DomainReferenceSourceAdapter(displayName: "Dribbble", domains: ["dribbble.com"])
    ]

    public static func resolve(urlString: String) -> ReferenceSource {
        let normalized = normalize(urlString)
        guard let url = URL(string: normalized), let host = url.host?.lowercased() else {
            return ReferenceSource(kind: .manual, name: "Manual", url: normalized)
        }

        let name = adapters.first(where: { $0.matches(host: host) })?.displayName ?? "Web"

        return ReferenceSource(
            kind: .web,
            name: name,
            url: normalized,
            domain: host,
            identifier: identifier(from: url)
        )
    }

    public static func normalize(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate) else { return trimmed }
        components.host = components.host?.lowercased()
        components.queryItems = components.queryItems?.filter {
            let name = $0.name.lowercased()
            return !name.hasPrefix("utm_") && name != "fbclid" && name != "gclid"
        }
        if components.path.count > 1 && components.path.hasSuffix("/") { components.path.removeLast() }
        return components.string ?? trimmed
    }

    private static func identifier(from url: URL) -> String {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.split(separator: "/").last.map(String.init) ?? ""
    }
}

public enum VisualAttributeCategory: String, CaseIterable, Codable, Sendable {
    case style
    case medium
    case subject
    case lighting
    case composition
    case mood
    case colorCharacter

    public var displayName: String {
        switch self {
        case .style: "Style"
        case .medium: "Medium"
        case .subject: "Subject"
        case .lighting: "Lighting"
        case .composition: "Composition"
        case .mood: "Mood"
        case .colorCharacter: "Color"
        }
    }
}

public enum VisualAttributeOrigin: String, Codable, Sendable {
    case manual
    case automatic
    case agentProposal
}

public struct VisualAttribute: Codable, Hashable, Sendable {
    public var category: VisualAttributeCategory
    public var name: String
    public var origin: VisualAttributeOrigin
    public var confidence: Double?

    public init(
        category: VisualAttributeCategory,
        name: String,
        origin: VisualAttributeOrigin = .manual,
        confidence: Double? = nil
    ) {
        self.category = category
        self.name = name
        self.origin = origin
        self.confidence = confidence
    }
}

public enum ReferenceAnalysisState: String, CaseIterable, Codable, Sendable {
    case pending
    case processing
    case complete
    case failed
    case notAvailable
}

public enum ReferenceRepositoryError: Error, Equatable, Sendable {
    case referenceNotFound
    case invalidImport
}

public enum ReferenceCollectionKind: String, CaseIterable, Codable, Sendable {
    case manual
    case smart
}

public struct ReferenceFilter: Codable, Equatable, Sendable {
    public var style: [String]
    public var medium: [String]
    public var subject: [String]
    public var lighting: [String]
    public var composition: [String]
    public var mood: [String]
    public var colorCharacter: [String]
    public var sourceName: String?
    public var sourceKind: ReferenceSourceKind?
    public var projectID: UUID?
    public var tags: [String]
    public var pinnedOnly: Bool
    public var unclassifiedOnly: Bool
    public var includeArchived: Bool

    public init(
        style: [String] = [],
        medium: [String] = [],
        subject: [String] = [],
        lighting: [String] = [],
        composition: [String] = [],
        mood: [String] = [],
        colorCharacter: [String] = [],
        sourceName: String? = nil,
        sourceKind: ReferenceSourceKind? = nil,
        projectID: UUID? = nil,
        tags: [String] = [],
        pinnedOnly: Bool = false,
        unclassifiedOnly: Bool = false,
        includeArchived: Bool = false
    ) {
        self.style = style
        self.medium = medium
        self.subject = subject
        self.lighting = lighting
        self.composition = composition
        self.mood = mood
        self.colorCharacter = colorCharacter
        self.sourceName = sourceName
        self.sourceKind = sourceKind
        self.projectID = projectID
        self.tags = tags
        self.pinnedOnly = pinnedOnly
        self.unclassifiedOnly = unclassifiedOnly
        self.includeArchived = includeArchived
    }

    public var isEmpty: Bool {
        style.isEmpty && medium.isEmpty && subject.isEmpty && lighting.isEmpty && composition.isEmpty && mood.isEmpty && colorCharacter.isEmpty && sourceName == nil && sourceKind == nil && projectID == nil && tags.isEmpty && !pinnedOnly && !unclassifiedOnly && includeArchived == false
    }

    public func matches(_ reference: FieldReference) -> Bool {
        guard includeArchived || !reference.archived else { return false }
        guard !pinnedOnly || reference.pinned else { return false }
        guard !unclassifiedOnly || reference.isUnclassified else { return false }
        guard projectID == nil || reference.projectIDs.contains(projectID!) else { return false }
        guard sourceName == nil || reference.source.name.localizedCaseInsensitiveCompare(sourceName!) == .orderedSame else { return false }
        guard sourceKind == nil || reference.source.kind == sourceKind else { return false }
        let normalizedTags = Set(reference.manualTags.map { $0.lowercased() })
        guard tags.allSatisfy({ normalizedTags.contains($0.lowercased()) }) else { return false }

        let attributes = reference.visualAttributes
        let matches: (VisualAttributeCategory, [String]) -> Bool = { category, values in
            values.isEmpty || values.allSatisfy { expected in
                attributes.contains { $0.category == category && $0.name.localizedCaseInsensitiveCompare(expected) == .orderedSame }
            }
        }
        return matches(.style, style)
            && matches(.medium, medium)
            && matches(.subject, subject)
            && matches(.lighting, lighting)
            && matches(.composition, composition)
            && matches(.mood, mood)
            && matches(.colorCharacter, colorCharacter)
    }
}

public struct ReferenceQuery: Codable, Equatable, Sendable {
    public var text: String
    public var filter: ReferenceFilter
    public var limit: Int

    public init(text: String = "", filter: ReferenceFilter = .init(), limit: Int = 100) {
        self.text = text
        self.filter = filter
        self.limit = limit
    }
}

@Model
public final class FieldReference {
    public var id: UUID = UUID()
    public var title: String = ""
    public var userNote: String = ""
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var importedAt: Date = Date.now
    public var importRecordID: UUID? = nil
    public var pinned: Bool = false
    public var archived: Bool = false

    @Attribute(.externalStorage)
    public var imageData: Data? = nil
    @Attribute(.externalStorage)
    public var thumbnailData: Data? = nil
    public var imageWidth: Double? = nil
    public var imageHeight: Double? = nil
    public var aspectRatio: Double? = nil
    public var orientationRaw: String? = nil

    public var sourceKindRaw: String = ""
    public var sourceName: String = ""
    public var sourceURL: String = ""
    public var sourceDomain: String = ""
    public var sourceIdentifier: String = ""
    public var author: String = ""
    public var originalTitle: String = ""

    public var manualTagsRaw: String = ""
    public var automaticTagsRaw: String = ""
    public var visualAttributesJSON: String = ""
    public var dominantColorsJSON: String = ""
    public var ocrText: String = ""
    public var analysisStateRaw: String = ""
    public var duplicateFingerprint: String = ""

    /// Relationships are stored as UUID lists, following Field LAB's current
    /// CloudKit-safe relationship strategy and avoiding required cycles.
    public var projectIDsJSON: String = ""
    public var toolIDsJSON: String = ""
    public var styleIDsJSON: String = ""
    public var recipeIDsJSON: String = ""
    public var experimentIDsJSON: String = ""
    public var flowIDsJSON: String = ""
    public var collectionIDsJSON: String = ""

    public var source: ReferenceSource {
        get {
            ReferenceSource(
                kind: ReferenceSourceKind(rawValue: sourceKindRaw) ?? .manual,
                name: sourceName,
                url: sourceURL,
                domain: sourceDomain,
                identifier: sourceIdentifier,
                author: author,
                originalTitle: originalTitle
            )
        }
        set {
            sourceKindRaw = newValue.kind.rawValue
            sourceName = newValue.name
            sourceURL = newValue.url
            sourceDomain = newValue.domain
            sourceIdentifier = newValue.identifier
            author = newValue.author
            originalTitle = newValue.originalTitle
        }
    }

    public var analysisState: ReferenceAnalysisState {
        get { ReferenceAnalysisState(rawValue: analysisStateRaw) ?? .pending }
        set { analysisStateRaw = newValue.rawValue }
    }

    public var manualTags: [String] {
        get { Self.decodeList(manualTagsRaw) }
        set { manualTagsRaw = Self.encodeList(newValue) }
    }

    public var automaticTags: [String] {
        get { Self.decodeList(automaticTagsRaw) }
        set { automaticTagsRaw = Self.encodeList(newValue) }
    }

    public var visualAttributes: [VisualAttribute] {
        get { (try? JSONDecoder().decode([VisualAttribute].self, from: Data(visualAttributesJSON.utf8))) ?? [] }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8)
            visualAttributesJSON = String(decoding: data, as: UTF8.self)
        }
    }

    public var projectIDs: [UUID] {
        get { Self.decodeUUIDs(projectIDsJSON) }
        set { projectIDsJSON = Self.encodeUUIDs(newValue) }
    }

    public var experimentIDs: [UUID] {
        get { Self.decodeUUIDs(experimentIDsJSON) }
        set { experimentIDsJSON = Self.encodeUUIDs(newValue) }
    }

    public var toolIDs: [UUID] {
        get { Self.decodeUUIDs(toolIDsJSON) }
        set { toolIDsJSON = Self.encodeUUIDs(newValue) }
    }

    public var collectionIDs: [UUID] {
        get { Self.decodeUUIDs(collectionIDsJSON) }
        set { collectionIDsJSON = Self.encodeUUIDs(newValue) }
    }

    public var isUnclassified: Bool {
        let creativeCategories: Set<VisualAttributeCategory> = [.style, .medium, .subject, .mood]
        return !visualAttributes.contains { creativeCategories.contains($0.category) }
    }

    public init(
        id: UUID = UUID(),
        title: String = "Untitled reference",
        userNote: String = "",
        source: ReferenceSource = .init(),
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        aspectRatio: Double? = nil,
        orientation: String? = nil,
        manualTags: [String] = [],
        automaticTags: [String] = [],
        visualAttributes: [VisualAttribute] = [],
        dominantColorsJSON: String = "[]",
        ocrText: String = "",
        analysisState: ReferenceAnalysisState = .pending,
        duplicateFingerprint: String = "",
        importRecordID: UUID? = nil,
        projectIDs: [UUID] = [],
        toolIDs: [UUID] = [],
        collectionIDs: [UUID] = [],
        pinned: Bool = false,
        archived: Bool = false,
        createdAt: Date = Date.now,
        updatedAt: Date = Date.now,
        importedAt: Date = Date.now
    ) {
        self.id = id
        self.title = title
        self.userNote = userNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.importedAt = importedAt
        self.importRecordID = importRecordID
        self.pinned = pinned
        self.archived = archived
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.aspectRatio = aspectRatio
        self.orientationRaw = orientation
        self.sourceKindRaw = source.kind.rawValue
        self.sourceName = source.name
        self.sourceURL = source.url
        self.sourceDomain = source.domain
        self.sourceIdentifier = source.identifier
        self.author = source.author
        self.originalTitle = source.originalTitle
        self.manualTagsRaw = Self.encodeList(manualTags)
        self.automaticTagsRaw = Self.encodeList(automaticTags)
        self.visualAttributesJSON = String(decoding: (try? JSONEncoder().encode(visualAttributes)) ?? Data("[]".utf8), as: UTF8.self)
        self.dominantColorsJSON = dominantColorsJSON
        self.ocrText = ocrText
        self.analysisStateRaw = analysisState.rawValue
        self.duplicateFingerprint = duplicateFingerprint
        self.projectIDsJSON = Self.encodeUUIDs(projectIDs)
        self.toolIDsJSON = Self.encodeUUIDs(toolIDs)
        self.styleIDsJSON = ""
        self.recipeIDsJSON = ""
        self.experimentIDsJSON = ""
        self.flowIDsJSON = ""
        self.collectionIDsJSON = Self.encodeUUIDs(collectionIDs)
    }

    private static func encodeList(_ values: [String]) -> String {
        values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private static func decodeList(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func encodeUUIDs(_ values: [UUID]) -> String { values.map(\.uuidString).joined(separator: ",") }

    private static func decodeUUIDs(_ value: String) -> [UUID] {
        value.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
    }
}

@Model
public final class ReferenceCollection {
    public var id: UUID = UUID()
    public var title: String = ""
    public var kindRaw: String = ""
    public var filterDefinitionJSON: String = ""
    public var referenceIDsJSON: String = ""
    public var pinned: Bool = false
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public var kind: ReferenceCollectionKind {
        get { ReferenceCollectionKind(rawValue: kindRaw) ?? .manual }
        set { kindRaw = newValue.rawValue }
    }

    public var filter: ReferenceFilter? {
        get { try? JSONDecoder().decode(ReferenceFilter.self, from: Data(filterDefinitionJSON.utf8)) }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                filterDefinitionJSON = ""
                return
            }
            filterDefinitionJSON = String(decoding: data, as: UTF8.self)
        }
    }

    public var referenceIDs: [UUID] {
        get { referenceIDsJSON.split(separator: ",").compactMap { UUID(uuidString: String($0)) } }
        set { referenceIDsJSON = newValue.map(\.uuidString).joined(separator: ",") }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        kind: ReferenceCollectionKind,
        filter: ReferenceFilter? = nil,
        referenceIDs: [UUID] = [],
        pinned: Bool = false,
        createdAt: Date = Date.now,
        updatedAt: Date = Date.now
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kind.rawValue
        self.filterDefinitionJSON = ""
        self.referenceIDsJSON = referenceIDs.map(\.uuidString).joined(separator: ",")
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.filter = filter
    }
}

public struct ReferenceTagProposal: Codable, Equatable, Sendable {
    public var referenceID: UUID
    public var attributes: [VisualAttribute]

    public init(referenceID: UUID, attributes: [VisualAttribute]) {
        self.referenceID = referenceID
        self.attributes = attributes
    }
}

public enum ReferenceImportContentType: String, Codable, Sendable {
    case image
    case url
    case imageAndURL
    case text
}

public struct ReferenceImportRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let contentType: ReferenceImportContentType
    public let assetFileName: String
    public let urlString: String
    public let text: String
    public let note: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date.now,
        contentType: ReferenceImportContentType,
        assetFileName: String = "",
        urlString: String = "",
        text: String = "",
        note: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.contentType = contentType
        self.assetFileName = assetFileName
        self.urlString = urlString
        self.text = text
        self.note = note
    }
}

/// Small App Group-compatible staging queue. The extension can write a JSON
/// record plus an optional image file without opening Field LAB's main store.
public final class ReferenceImportQueue: @unchecked Sendable {
    public let directory: URL
    private let fileManager: FileManager
    public private(set) var malformedRecordCount = 0
    public private(set) var malformedRecordQuarantineFailureCount = 0

    public init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @discardableResult
    public func enqueue(
        contentType: ReferenceImportContentType,
        assetData: Data? = nil,
        urlString: String = "",
        text: String = "",
        note: String = ""
    ) throws -> ReferenceImportRecord {
        let id = UUID()
        let assetFileName = assetData == nil ? "" : "\(id.uuidString).asset"
        let record = ReferenceImportRecord(id: id, contentType: contentType, assetFileName: assetFileName, urlString: urlString, text: text, note: note)
        if let assetData { try assetData.write(to: directory.appendingPathComponent(assetFileName), options: .atomic) }
        let data = try JSONEncoder().encode(record)
        try data.write(to: directory.appendingPathComponent("\(id.uuidString).json"), options: .atomic)
        return record
    }

    public func pending() throws -> [ReferenceImportRecord] {
        malformedRecordCount = 0
        malformedRecordQuarantineFailureCount = 0
        var records: [ReferenceImportRecord] = []
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        for file in files {
            do {
                let data = try Data(contentsOf: file)
                records.append(try JSONDecoder().decode(ReferenceImportRecord.self, from: data))
            } catch {
                malformedRecordCount += 1
                do {
                    try quarantine(file)
                } catch {
                    malformedRecordQuarantineFailureCount += 1
                }
            }
        }
        return records.sorted { $0.createdAt < $1.createdAt }
    }

    public func assetData(for record: ReferenceImportRecord) throws -> Data? {
        guard !record.assetFileName.isEmpty else { return nil }
        return try Data(contentsOf: directory.appendingPathComponent(record.assetFileName))
    }

    public func remove(_ record: ReferenceImportRecord) throws {
        if !record.assetFileName.isEmpty {
            let assetURL = directory.appendingPathComponent(record.assetFileName)
            if fileManager.fileExists(atPath: assetURL.path) { try fileManager.removeItem(at: assetURL) }
        }
        let recordURL = directory.appendingPathComponent("\(record.id.uuidString).json")
        if fileManager.fileExists(atPath: recordURL.path) { try fileManager.removeItem(at: recordURL) }
    }

    private func quarantine(_ recordURL: URL) throws {
        let quarantineDirectory = directory.appendingPathComponent("FailedImports", isDirectory: true)
        try fileManager.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
        let assetURL = directory
            .appendingPathComponent(recordURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("asset")
        if fileManager.fileExists(atPath: assetURL.path) {
            let quarantinedAssetURL = quarantineDirectory.appendingPathComponent(assetURL.lastPathComponent)
            try fileManager.moveItem(at: assetURL, to: quarantinedAssetURL)
        }

        let quarantinedRecordURL = quarantineDirectory.appendingPathComponent(recordURL.lastPathComponent)
        try fileManager.moveItem(at: recordURL, to: quarantinedRecordURL)
    }
}

public struct ReferenceImportReport {
    public let imported: [FieldReference]
    public let failures: [String]

    public init(imported: [FieldReference], failures: [String]) {
        self.imported = imported
        self.failures = failures
    }
}

public enum ReferenceImportServiceError: LocalizedError, Equatable {
    case partialFailure([String])

    public var errorDescription: String? {
        switch self {
        case .partialFailure(let failures): failures.joined(separator: "\n")
        }
    }
}

@MainActor
public final class ReferenceImportService {
    private let repository: FieldRepository

    public init(repository: FieldRepository) {
        self.repository = repository
    }

    /// Imports staged records one at a time. If a previous run saved the
    /// canonical record but failed before cleanup, importRecordID makes the
    /// retry converge instead of creating a duplicate.
    @discardableResult
    public func processPending(_ queue: ReferenceImportQueue) throws -> [FieldReference] {
        let report = try processPendingReport(queue)
        guard report.failures.isEmpty else {
            throw ReferenceImportServiceError.partialFailure(report.failures)
        }
        return report.imported
    }

    public func processPendingReport(_ queue: ReferenceImportQueue) throws -> ReferenceImportReport {
        var imported: [FieldReference] = []
        var failures: [String] = []
        for record in try queue.pending() {
            do {
                if repository.references(filter: ReferenceFilter(includeArchived: true)).contains(where: { $0.importRecordID == record.id }) {
                    try queue.remove(record)
                    continue
                }

                let asset = try queue.assetData(for: record)
                let source = ReferenceSourceResolver.resolve(urlString: record.urlString)
                let sharedTextLines = record.text
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let fallbackTitle = sharedTextLines.first ?? ""
                let sourceTitle: String
                if source.name == "Web", !source.domain.isEmpty {
                    sourceTitle = source.domain
                } else if source.name == "Manual" {
                    sourceTitle = "Referencia importada"
                } else {
                    sourceTitle = source.name
                }
                let title = fallbackTitle.isEmpty ? sourceTitle : String(fallbackTitle.prefix(120))
                let sharedNote: String
                if sharedTextLines.count > 1 {
                    sharedNote = sharedTextLines.dropFirst().joined(separator: "\n")
                } else if fallbackTitle.count > 120 {
                    sharedNote = record.text
                } else {
                    sharedNote = ""
                }
                let note = record.note.isEmpty ? sharedNote : record.note
                let reference = try repository.createReference(
                    title: title,
                    userNote: note,
                    urlString: record.urlString,
                    source: source,
                    imageData: asset,
                    importRecordID: record.id
                )
                imported.append(reference)
                try queue.remove(record)
            } catch {
                failures.append("\(record.id.uuidString): \(error.localizedDescription)")
            }
        }

        if queue.malformedRecordCount > 0 {
            failures.insert(
                "Se apartaron \(queue.malformedRecordCount) importaciones dañadas en FailedImports.",
                at: 0
            )
        }
        if queue.malformedRecordQuarantineFailureCount > 0 {
            failures.insert(
                "No se pudieron apartar \(queue.malformedRecordQuarantineFailureCount) importaciones dañadas; siguen en la cola.",
                at: 0
            )
        }
        return ReferenceImportReport(imported: imported, failures: failures)
    }
}
