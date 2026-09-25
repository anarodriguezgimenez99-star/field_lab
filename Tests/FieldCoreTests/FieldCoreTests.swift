import XCTest
import SwiftData
@testable import FieldCore

@MainActor
final class FieldCoreTests: XCTestCase {
    private func repository() throws -> FieldRepository {
        let container = try FieldModelContainer.make(inMemory: true)
        return FieldRepository(context: container.mainContext)
    }

    func testRepositoryCRUDCreatesProjectToolAndKnowledge() throws {
        let repository = try repository()

        let project = try repository.createProject(title: "Beauty Campaign", summary: "A product story")
        let tool = try repository.createTool(name: "Krea", category: "Image generation")
        let learning = try repository.createKnowledge(
            kind: .learning,
            title: "Hard light keeps texture",
            body: "Use hard directional sunlight for honest material texture.",
            status: .works,
            projectID: project.id,
            toolID: tool.id,
            tags: ["lighting", "texture"]
        )

        XCTAssertEqual(repository.projects().count, 1)
        XCTAssertEqual(repository.tools().first?.name, "Krea")
        XCTAssertEqual(repository.knowledge(kind: .learning).first?.id, learning.id)
        XCTAssertEqual(repository.knowledge().first?.tags, ["lighting", "texture"])

        try repository.delete(learning)
        XCTAssertTrue(repository.knowledge().isEmpty)
    }

    func testSearchScoresTitleBeforeBodyAndIncludesToolAndProject() throws {
        let repository = try repository()
        let project = try repository.createProject(title: "Outdoor Product", summary: "Natural campaign")
        let tool = try repository.createTool(name: "Krea", category: "Image generation")
        _ = try repository.createKnowledge(
            kind: .promptBlock,
            title: "Hard Light",
            body: "Sharp imperfect shadows.",
            status: .works,
            projectID: project.id,
            toolID: tool.id,
            tags: ["lighting"]
        )
        _ = try repository.createKnowledge(kind: .note, title: "A note", body: "Hard light is useful in outdoor work.")

        let results = repository.search(query: "hard light")

        XCTAssertEqual(results.first?.title, "Hard Light")
        XCTAssertTrue(results.contains { $0.kind == "Prompt Block" })
    }

    func testContextPackHonorsDepth() throws {
        let repository = try repository()
        let project = try repository.createProject(title: "Campaign", summary: "Goal")
        project.brief = "Brief"
        project.creativeDirection = "Documentary premium"
        project.constraints = "No CGI"
        project.deliverables = "Hero still and 9:16 motion"
        project.alwaysRemember = "Keep product unchanged"
        try repository.updateProject(project)

        _ = try repository.createKnowledge(kind: .decision, title: "Use 35mm", body: "Less polished.", status: .canonical, scope: .project, projectID: project.id)
        _ = try repository.createKnowledge(kind: .learning, title: "Hard sunlight", body: "Preserves texture.", status: .works, scope: .project, projectID: project.id)
        _ = try repository.createKnowledge(kind: .recipe, title: "Natural product", body: "A repeatable setup.", status: .works, scope: .project, projectID: project.id)

        let essential = try XCTUnwrap(repository.projectContext(projectID: project.id, depth: .essential))
        XCTAssertEqual(essential.brief, "Brief")
        XCTAssertEqual(essential.deliverables, "Hero still and 9:16 motion")
        XCTAssertEqual(essential.decisions.count, 1)
        XCTAssertTrue(essential.learnings.isEmpty)
        XCTAssertTrue(essential.recipes.isEmpty)

        let standard = try XCTUnwrap(repository.projectContext(projectID: project.id, depth: .standard))
        XCTAssertEqual(standard.learnings.count, 1)
        XCTAssertEqual(standard.recipes.count, 1)
    }

    func testApprovalFlowPromotesProposalToApprovedKnowledge() throws {
        let repository = try repository()
        let project = try repository.createProject(title: "Project X")
        let proposal = try repository.propose(
            agent: "Claude",
            type: .learning,
            title: "Describe movement only",
            content: "For image-to-video, describe movement instead of the whole image.",
            projectID: project.id
        )

        XCTAssertEqual(repository.proposals(status: .pending).count, 1)
        let item = try repository.approve(proposal)

        XCTAssertEqual(proposal.status, .approved)
        XCTAssertTrue(item.approvedByUser)
        XCTAssertEqual(item.sourceType, .claude)
        XCTAssertEqual(repository.knowledge(kind: .learning).count, 1)
        XCTAssertTrue(repository.activities().contains { $0.action == "approved_learning" })
    }

    func testPromptStackConcatenatesReusableBlocksCleanly() throws {
        let repository = try repository()
        let first = try repository.createKnowledge(kind: .promptBlock, title: "Camera", body: "35mm documentary")
        let second = try repository.createKnowledge(kind: .promptBlock, title: "Light", body: "hard directional natural sunlight")
        let empty = try repository.createKnowledge(kind: .promptBlock, title: "Empty", body: "  ")

        XCTAssertEqual(
            PromptStackBuilder.concatenate([first, second, empty]),
            "35mm documentary, hard directional natural sunlight"
        )
    }

    func testSessionSummaryDeduplicatesIdenticalRecentCalls() throws {
        let repository = try repository()
        let project = try repository.createProject(title: "Project")

        let first = try repository.saveSessionSummary(agent: "Codex", projectID: project.id, content: "Worked on the hero visual.")
        let second = try repository.saveSessionSummary(agent: "Codex", projectID: project.id, content: "Worked on the hero visual.")

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(repository.knowledge(kind: .sessionSummary).count, 1)

        let otherProject = try repository.createProject(title: "Other project")
        let projectSummary = try repository.saveSessionSummary(agent: "Codex", projectID: otherProject.id, content: "Worked on the hero visual.")
        XCTAssertNotEqual(first.id, projectSummary.id)
    }

    func testFlowStepEditingAndCascadeDelete() throws {
        let repository = try repository()
        let flow = try repository.createFlow(title: "Campaign flow", summary: "Repeatable method")
        let first = try repository.createFlowStep(flowID: flow.id, title: "Concept")
        let second = try repository.createFlowStep(flowID: flow.id, title: "References")

        first.instructions = "Write the tension."
        first.templateText = "Describe the visual tension."
        try repository.updateFlowStep(first)
        XCTAssertEqual(repository.flowSteps(flowID: flow.id).first?.templateText, "Describe the visual tension.")

        try repository.deleteFlowStep(first)
        XCTAssertEqual(repository.flowSteps(flowID: flow.id).count, 1)
        XCTAssertEqual(repository.flowSteps(flowID: flow.id).first?.order, 1)
        XCTAssertEqual(repository.flowSteps(flowID: flow.id).first?.id, second.id)

        try repository.deleteFlow(flow)
        XCTAssertTrue(repository.flows().isEmpty)
        XCTAssertTrue(repository.flowSteps(flowID: flow.id).isEmpty)
    }

    func testDeletingProjectAndToolClearsReferencesWithoutDeletingKnowledge() throws {
        let repository = try repository()
        let project = try repository.createProject(title: "Campaign")
        let tool = try repository.createTool(name: "Krea")
        let item = try repository.createKnowledge(kind: .learning, title: "Learning", projectID: project.id, toolID: tool.id, scope: .project)

        try repository.deleteTool(tool)
        XCTAssertEqual(repository.knowledge().first?.id, item.id)
        XCTAssertNil(repository.knowledge().first?.toolID)

        try repository.deleteProject(project)
        XCTAssertEqual(repository.knowledge().first?.id, item.id)
        XCTAssertNil(repository.knowledge().first?.projectID)
        XCTAssertEqual(repository.knowledge().first?.scope, .global)
    }

    func testReferenceCreationResolvesSourceAndPreservesManualClassification() throws {
        let repository = try repository()
        let reference = try repository.createReference(
            title: "Product study",
            userNote: "The light feels honest.",
            urlString: "https://www.pinterest.com/pin/123/?utm_source=share",
            tags: ["campaign"],
            visualAttributes: [VisualAttribute(category: .style, name: "Editorial", origin: .manual)]
        )

        XCTAssertEqual(reference.source.name, "Pinterest")
        XCTAssertEqual(reference.sourceURL, "https://www.pinterest.com/pin/123")
        XCTAssertEqual(reference.manualTags, ["campaign"])
        XCTAssertFalse(reference.isUnclassified)
    }

    func testReferenceFilterCombinesAttributesSourceProjectAndTags() throws {
        let repository = try repository()
        let project = try repository.createProject(title: "Spring campaign")
        _ = try repository.createReference(
            title: "Warm bottle",
            urlString: "https://cosmos.so/example",
            projectIDs: [project.id],
            tags: ["hero"],
            visualAttributes: [
                VisualAttribute(category: .style, name: "Hyperrealistic"),
                VisualAttribute(category: .medium, name: "Photography"),
                VisualAttribute(category: .subject, name: "Product"),
                VisualAttribute(category: .lighting, name: "Hard Light")
            ]
        )
        _ = try repository.createReference(title: "Editorial portrait", urlString: "https://pinterest.com/pin/456", tags: ["portrait"])

        let results = repository.references(filter: ReferenceFilter(
            style: ["Hyperrealistic"],
            medium: ["Photography"],
            subject: ["Product"],
            lighting: ["Hard Light"],
            sourceName: "Cosmos",
            projectID: project.id,
            tags: ["hero"]
        ))

        XCTAssertEqual(results.map(\.title), ["Warm bottle"])
    }

    func testReferenceSearchFindsOCRAndProjectConnections() throws {
        let repository = try repository()
        let project = try repository.createProject(title: "Summer Collection")
        let reference = try repository.createReference(title: "Poster", projectIDs: [project.id])
        reference.ocrText = "Summer Collection"
        try repository.updateReference(reference)

        let results = repository.search(query: "summer")
        XCTAssertTrue(results.contains { $0.entityType == "reference" && $0.id == reference.id })
    }

    func testReferenceTagApprovalPreservesManualPriority() throws {
        let repository = try repository()
        let reference = try repository.createReference(
            title: "Study",
            visualAttributes: [VisualAttribute(category: .style, name: "Editorial", origin: .manual)]
        )
        let proposal = try repository.proposeReferenceTags(
            agent: "Claude",
            referenceID: reference.id,
            attributes: [
                VisualAttribute(category: .style, name: "Editorial", origin: .agentProposal, confidence: 0.91),
                VisualAttribute(category: .mood, name: "Premium", origin: .agentProposal, confidence: 0.82)
            ]
        )

        _ = try repository.approveReferenceTags(proposal)
        XCTAssertEqual(reference.visualAttributes.filter { $0.category == .style }.count, 1)
        XCTAssertEqual(reference.visualAttributes.first { $0.category == .style }?.origin, .manual)
        XCTAssertTrue(reference.visualAttributes.contains { $0.category == .mood && $0.origin == .manual })
    }

    func testSmartCollectionEvaluatesItsSerializableFilterWithoutCopyingReferences() throws {
        let repository = try repository()
        let match = try repository.createReference(title: "Match", visualAttributes: [VisualAttribute(category: .subject, name: "Product")])
        _ = try repository.createReference(title: "Other")
        let collection = try repository.createReferenceCollection(title: "Product studies", kind: .smart, filter: ReferenceFilter(subject: ["Product"]))

        XCTAssertEqual(repository.collectionReferences(collection).map(\.id), [match.id])
        XCTAssertTrue(collection.referenceIDs.isEmpty)
    }

    func testImportQueueIsIdempotentUntilTheRecordIsRemoved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("field-import-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = try ReferenceImportQueue(directory: directory)
        let record = try queue.enqueue(contentType: .imageAndURL, assetData: Data("image".utf8), urlString: "https://example.com/image", note: "Keep the crop")

        XCTAssertEqual(try queue.pending().map(\.id), [record.id])
        XCTAssertEqual(try queue.assetData(for: record), Data("image".utf8))
        XCTAssertEqual(try queue.pending().count, 1)

        try queue.remove(record)
        XCTAssertTrue(try queue.pending().isEmpty)
    }

    func testImportServiceDoesNotDuplicateARecordWhenCleanupIsRetried() throws {
        let repository = try repository()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("field-import-service-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = try ReferenceImportQueue(directory: directory)
        _ = try queue.enqueue(contentType: .url, urlString: "https://cosmos.so/idea", note: "Save the material contrast")

        let service = ReferenceImportService(repository: repository)
        let first = try service.processPending(queue)
        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(try queue.pending().isEmpty)

        XCTAssertTrue(try service.processPending(queue).isEmpty)
        XCTAssertEqual(repository.references().count, 1)
    }

    func testExperimentCRUDAndRunOrdering() throws {
        let repository = try repository()
        let experiment = try repository.createExperiment(title: "Hard light", goal: "Find the most natural product light")
        let first = try repository.createExperimentRun(experimentID: experiment.id, title: "Soft studio")
        let second = try repository.createExperimentRun(experimentID: experiment.id, title: "Directional sun")

        XCTAssertEqual(repository.experiments().first?.id, experiment.id)
        XCTAssertEqual(repository.experimentRuns(experimentID: experiment.id).map(\.id), [first.id, second.id])

        try repository.deleteExperimentRun(first)
        XCTAssertEqual(repository.experimentRuns(experimentID: experiment.id).first?.order, 1)
        try repository.deleteExperiment(experiment)
        XCTAssertTrue(repository.experiments().isEmpty)
        XCTAssertTrue(repository.experimentRuns(experimentID: experiment.id).isEmpty)
    }

    func testExperimentConclusionCreatesLearningWithProvenance() throws {
        let repository = try repository()
        let project = try repository.createProject(title: "Campaign")
        let tool = try repository.createTool(name: "Krea")
        let experiment = try repository.createExperiment(title: "Natural light", goal: "Keep material texture", toolID: tool.id, projectID: project.id)
        experiment.conclusion = "Hard directional light preserves texture."
        let run = try repository.createExperimentRun(experimentID: experiment.id, title: "Hard sun")
        experiment.bestRunID = run.id
        let learning = try repository.saveExperimentConclusionAsLearning(experiment)

        XCTAssertEqual(learning.kind, .learning)
        XCTAssertEqual(learning.projectID, project.id)
        XCTAssertEqual(learning.toolID, tool.id)
        XCTAssertTrue(learning.metadataJSON.contains(experiment.id.uuidString))
        XCTAssertTrue(learning.metadataJSON.contains(run.id.uuidString))
    }

    func testRunSnapshotsStayStableWhenExperimentSetupChanges() throws {
        let repository = try repository()
        let tool = try repository.createTool(name: "Krea", category: "Image generation")
        let reference = try repository.createReference(title: "Bottle")
        let experiment = try repository.createExperiment(title: "Material realism", toolID: tool.id)
        experiment.prompt = "soft daylight"
        experiment.model = "Flux"
        experiment.referenceIDs = [reference.id]
        experiment.settingsEntries = [SettingEntry(key: "Strength", value: "0.45")]
        try repository.updateExperiment(experiment)

        let run = try repository.createRunFromSetup(experiment: experiment)
        experiment.prompt = "hard sunlight"
        experiment.settingsEntries = [SettingEntry(key: "Strength", value: "0.30")]
        experiment.referenceIDs = []
        try repository.updateExperiment(experiment)

        XCTAssertEqual(run.prompt, "soft daylight")
        XCTAssertEqual(run.settingsEntries.first?.value, "0.45")
        XCTAssertEqual(run.inputReferenceIDs, [reference.id])
    }

    func testDuplicateRunCopiesSetupAndDeltaIsStructured() throws {
        let repository = try repository()
        let experiment = try repository.createExperiment(title: "Lighting")
        experiment.prompt = "product photo"
        experiment.settingsEntries = [SettingEntry(key: "Strength", value: "0.45")]
        let first = try repository.createRunFromSetup(experiment: experiment)
        try repository.duplicateRunSetup(first)
        experiment.settingsEntries = [SettingEntry(key: "Strength", value: "0.30")]
        let second = try repository.createRunFromSetup(experiment: experiment, parentRunID: first.id)

        XCTAssertEqual(second.parentRunID, first.id)
        XCTAssertEqual(repository.runDelta(from: first, to: second).first?.label, "Strength")
        XCTAssertEqual(repository.experimentSetup(experiment).settings.first?.value, "0.30")
    }

    func testBestRunAndRecipeKeepHumanSelectionAndProvenance() throws {
        let repository = try repository()
        let tool = try repository.createTool(name: "Firefly")
        let experiment = try repository.createExperiment(title: "Compare tools", toolID: tool.id)
        experiment.prompt = "natural product realism"
        let first = try repository.createRunFromSetup(experiment: experiment)
        first.outputData = Data("result".utf8)
        try repository.updateExperimentRun(first)
        try repository.setBestRun(first, for: experiment)

        XCTAssertEqual(experiment.bestRunID, first.id)
        XCTAssertEqual(first.evaluation, .best)

        let recipe = try repository.saveBestRunAsRecipe(experiment)
        XCTAssertEqual(recipe.kind, .recipe)
        XCTAssertEqual(repository.recipePayload(recipe)?.prompt, "natural product realism")
        XCTAssertTrue(recipe.metadataJSON.contains(first.id.uuidString))
    }

    func testConclusionAndRecipeUseRunToolWhenExperimentToolChanges() throws {
        let repository = try repository()
        let experimentTool = try repository.createTool(name: "Krea")
        let runTool = try repository.createTool(name: "Midjourney")
        let experiment = try repository.createExperiment(title: "Tool comparison", toolID: experimentTool.id)
        let run = try repository.createExperimentRun(experimentID: experiment.id, title: "Run 01", toolID: runTool.id, snapshotToolName: runTool.name)
        experiment.bestRunID = run.id
        experiment.conclusion = "Midjourney held the silhouette better."

        let learning = try repository.saveExperimentConclusionAsLearning(experiment)
        let recipe = try repository.saveBestRunAsRecipe(experiment)

        XCTAssertEqual(learning.toolID, experimentTool.id)
        XCTAssertEqual(recipe.toolID, runTool.id)
    }

    func testGlobalSearchIncludesExperiments() throws {
        let repository = try repository()
        _ = try repository.createExperiment(title: "Hard directional light", goal: "Compare honest shadows")

        let results = repository.search(query: "directional light")

        XCTAssertTrue(results.contains { $0.entityType == "experiment" && $0.kind == "Experiment" })
    }
}
