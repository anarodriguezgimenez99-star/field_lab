import Foundation

public enum PromptStackBuilder {
    public static func concatenate(_ blocks: [KnowledgeItem]) -> String {
        blocks
            .map { $0.body.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
