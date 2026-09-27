import Foundation

public enum SearchService {
    public static func search(
        query: String,
        knowledge: [KnowledgeItem],
        references: [FieldReference] = [],
        experiments: [FieldExperiment] = [],
        projects: [FieldProject],
        tools: [FieldTool],
        filter: SearchFilter = .init(),
        limit: Int = 50
    ) -> [SearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return [] }
        let terms = normalizedQuery.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        var results: [SearchResult] = []

        for item in knowledge {
            guard filter.kind == nil || item.kind == filter.kind else { continue }
            guard filter.status == nil || item.status == filter.status else { continue }
            guard filter.projectID == nil || item.projectID == filter.projectID else { continue }
            guard filter.toolID == nil || item.toolID == filter.toolID else { continue }
            guard filter.scope == nil || item.scope == filter.scope else { continue }

            let project = projects.first { $0.id == item.projectID }
            let tool = tools.first { $0.id == item.toolID }
            let searchable = [item.title, item.body, item.tagNames, item.urlString, project?.title ?? "", tool?.name ?? ""].joined(separator: " ").lowercased()
            let matchedTerms = terms.filter { searchable.contains($0) }
            guard !matchedTerms.isEmpty else { continue }

            var score = matchedTerms.count * 2
            if item.title.lowercased().contains(normalizedQuery) { score += 10 }
            if item.body.lowercased().contains(normalizedQuery) { score += 4 }
            if item.tagNames.lowercased().contains(normalizedQuery) { score += 3 }
            results.append(SearchResult(
                id: item.id,
                entityType: "knowledge",
                kind: item.kind.displayName,
                title: item.title,
                snippet: item.body.fieldSnippet,
                status: item.status.displayName,
                projectTitle: project?.title,
                toolName: tool?.name,
                score: score
            ))
        }

        if filter.kind == nil || filter.kind == .reference {
            for reference in references where !reference.archived {
                guard filter.status == nil, filter.scope == nil else { continue }
                let projectTitles = reference.projectIDs.compactMap { id in projects.first { $0.id == id }?.title }
                let attributes = reference.visualAttributes.map { "\($0.category.rawValue) \($0.name)" }.joined(separator: " ")
                let searchable = [
                    reference.title,
                    reference.userNote,
                    reference.ocrText,
                    reference.sourceName,
                    reference.sourceDomain,
                    reference.sourceURL,
                    reference.manualTagsRaw,
                    reference.automaticTagsRaw,
                    attributes,
                    projectTitles.joined(separator: " ")
                ].joined(separator: " ").lowercased()
                let matchedTerms = terms.filter { searchable.contains($0) }
                guard !matchedTerms.isEmpty else { continue }
                guard filter.projectID == nil || reference.projectIDs.contains(filter.projectID!) else { continue }
                guard filter.toolID == nil || reference.toolIDs.contains(filter.toolID!) else { continue }
                let projectTitle = reference.projectIDs.compactMap { id in projects.first { $0.id == id }?.title }.first
                var score = matchedTerms.count * 2
                if reference.title.lowercased().contains(normalizedQuery) { score += 10 }
                if reference.userNote.lowercased().contains(normalizedQuery) { score += 4 }
                if reference.ocrText.lowercased().contains(normalizedQuery) { score += 3 }
                if reference.sourceName.lowercased().contains(normalizedQuery) { score += 3 }
                results.append(SearchResult(
                    id: reference.id,
                    entityType: "reference",
                    kind: "Reference",
                    title: reference.title,
                    snippet: reference.userNote.fieldSnippet,
                    status: reference.analysisState.rawValue,
                    projectTitle: projectTitle,
                    sourceName: reference.source.name,
                    originalURL: reference.sourceURL.isEmpty ? nil : reference.sourceURL,
                    score: score
                ))
            }
        }

        if filter.kind == nil || filter.kind == .experiment {
            for experiment in experiments {
                guard filter.projectID == nil || experiment.projectID == filter.projectID else { continue }
                guard filter.toolID == nil || experiment.toolID == filter.toolID else { continue }
                guard filter.status == nil || experiment.status.rawValue == filter.status?.rawValue else { continue }
                let project = projects.first { $0.id == experiment.projectID }
                let tool = tools.first { $0.id == experiment.toolID }
                let searchable = [experiment.title, experiment.goal, experiment.prompt, experiment.model, experiment.conclusion, project?.title ?? "", tool?.name ?? ""].joined(separator: " ").lowercased()
                let matchedTerms = terms.filter { searchable.contains($0) }
                guard !matchedTerms.isEmpty else { continue }
                var score = matchedTerms.count * 2
                if experiment.title.lowercased().contains(normalizedQuery) { score += 10 }
                if experiment.goal.lowercased().contains(normalizedQuery) { score += 4 }
                results.append(SearchResult(
                    id: experiment.id,
                    entityType: "experiment",
                    kind: "Experiment",
                    title: experiment.title,
                    snippet: experiment.goal.fieldSnippet,
                    status: experiment.status.displayName,
                    projectTitle: project?.title,
                    toolName: tool?.name,
                    score: score
                ))
            }
        }

        if filter.isEmpty {
            for project in projects where project.title.localizedCaseInsensitiveContains(normalizedQuery) || project.summary.localizedCaseInsensitiveContains(normalizedQuery) {
                results.append(SearchResult(id: project.id, entityType: "project", kind: "Project", title: project.title, snippet: project.summary.fieldSnippet, score: 9))
            }
            for tool in tools where tool.name.localizedCaseInsensitiveContains(normalizedQuery) || tool.notes.localizedCaseInsensitiveContains(normalizedQuery) {
                results.append(SearchResult(id: tool.id, entityType: "tool", kind: "Tool", title: tool.name, snippet: tool.notes.fieldSnippet, score: 9))
            }
        }

        return results
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending }
                return lhs.score > rhs.score
            }
            .prefix(max(1, limit))
            .map { $0 }
    }
}

private extension SearchFilter {
    var isEmpty: Bool { kind == nil && status == nil && projectID == nil && toolID == nil && scope == nil }
}

private extension String {
    var fieldSnippet: String {
        let cleaned = replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count > 180 ? String(cleaned.prefix(177)) + "…" : cleaned
    }
}
