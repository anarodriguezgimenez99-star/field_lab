import Foundation

public enum ContextPackBuilder {
    public static func build(
        project: FieldProject,
        items: [KnowledgeItem],
        references: [FieldReference] = [],
        toolNames: [String],
        depth: ContextDepth
    ) -> ProjectContextPack {
        let decisions = items.filter { $0.kind == .decision && $0.status != .archived }.map(contextItem)
        let learnings = items.filter { $0.kind == .learning && $0.status != .archived }.map(contextItem)
        let recipes = items.filter { $0.kind == .recipe && $0.status != .archived }.map(contextItem)
        let openItems = items.filter { [.new, .testing].contains($0.status) }.map(contextItem)

        return ProjectContextPack(
            projectID: project.id,
            projectTitle: project.title,
            depth: depth.rawValue,
            summary: project.summary,
            brief: project.brief,
            creativeDirection: project.creativeDirection,
            constraints: project.constraints,
            deliverables: project.deliverables,
            alwaysRemember: project.alwaysRemember,
            decisions: decisions.limited(for: depth, essential: 8, standard: 20, deep: 100),
            learnings: depth == .essential ? [] : learnings.limited(for: depth, essential: 8, standard: 20, deep: 100),
            recipes: depth == .essential ? [] : recipes.limited(for: depth, essential: 8, standard: 12, deep: 100),
            tools: toolNames.sorted(),
            openItems: openItems.limited(for: depth, essential: 8, standard: 12, deep: 100),
            references: references
                .filter { !$0.archived }
                .prefix(depth == .essential ? 4 : depth == .standard ? 8 : 20)
                .map {
                    ReferenceContextItem(
                        id: $0.id,
                        title: $0.title,
                        source: $0.source.name,
                        note: String($0.userNote.replacingOccurrences(of: "\n", with: " ").prefix(180)),
                        attributes: $0.visualAttributes.map { "\($0.category.displayName): \($0.name)" }
                    )
                }
        )
    }

    private static func contextItem(_ item: KnowledgeItem) -> ContextItem {
        ContextItem(id: item.id, kind: item.kind.displayName, title: item.title, body: item.body, status: item.status.displayName, sourceAgent: item.sourceAgent)
    }
}

private extension Array where Element == ContextItem {
    func limited(for depth: ContextDepth, essential: Int, standard: Int, deep: Int) -> [ContextItem] {
        switch depth {
        case .essential: Array(prefix(essential))
        case .standard: Array(prefix(standard))
        case .deep: Array(prefix(deep))
        }
    }
}
