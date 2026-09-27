import XCTest
import SwiftData
@testable import FieldCore

@MainActor
final class FieldCoreTests: XCTestCase {
    private var modelContainer: ModelContainer?

    private func repository() throws -> FieldRepository {
        let container = try FieldModelContainer.make(inMemory: true)
        modelContainer = container
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
        XCTAssertTrue(results.contains { $0.kind == KnowledgeKind.promptBlock.displayName })
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

    func testProjectContextIncludesToolsLinkedThroughExperimentsAndReferences() throws {
        let repository = try repository()
        let project = try repository.createProject(title: "Material study")
        let tool = try repository.createTool(name: "Krea")
        _ = try repository.createExperiment(title: "Ceramic light", toolID: tool.id, projectID: project.id)
        _ = try repository.createReference(title: "Glaze study", projectIDs: [project.id], toolIDs: [tool.id])

        let context = try XCTUnwrap(repository.projectContext(projectID: project.id))

        XCTAssertEqual(context.tools, ["Krea"])
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

    func testProposalCannotBeApprovedOrRejectedMoreThanOnce() throws {
        let repository = try repository()
        let approved = try repository.propose(
            agent: "Codex",
            type: .learning,
            title: "Preserve material texture",
            content: "Keep the original surface texture."
        )
        _ = try repository.approve(approved)

        XCTAssertThrowsError(try repository.approve(approved)) {
            XCTAssertEqual($0 as? ProposalRepositoryError, .proposalNotPending)
        }
        XCTAssertThrowsError(try repository.reject(approved)) {
            XCTAssertEqual($0 as? ProposalRepositoryError, .proposalNotPending)
        }
        XCTAssertEqual(repository.knowledge(kind: .learning).count, 1)
        XCTAssertEqual(approved.status, .approved)

        let rejected = try repository.propose(
            agent: "Codex",
            type: .decision,
            title: "Use square master",
            content: "Choose a square master format."
        )
        try repository.reject(rejected)
        XCTAssertThrowsError(try repository.approve(rejected)) {
            XCTAssertEqual($0 as? ProposalRepositoryError, .proposalNotPending)
        }
        XCTAssertTrue(repository.knowledge(kind: .decision).isEmpty)
        XCTAssertEqual(rejected.status, .rejected)

        let reference = try repository.createReference(title: "Tag proposal target")
        let tagProposal = try repository.proposeReferenceTags(
            agent: "Codex",
            referenceID: reference.id,
            attributes: [VisualAttribute(category: .mood, name: "Quiet")]
        )
        XCTAssertThrowsError(try repository.approve(tagProposal)) {
            XCTAssertEqual($0 as? ProposalRepositoryError, .invalidProposalType)
        }
        _ = try repository.approveReferenceTags(tagProposal)
        XCTAssertThrowsError(try repository.approveReferenceTags(tagProposal)) {
            XCTAssertEqual($0 as? ProposalRepositoryError, .proposalNotPending)
        }
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

    func testFutureDatedSummaryDoesNotDeduplicateANewCall() throws {
        let repository = try repository()
        let first = try repository.saveSessionSummary(agent: "Codex", projectID: nil, content: "Same summary.")
        first.createdAt = .now.addingTimeInterval(3600)
        try repository.save()

        let second = try repository.saveSessionSummary(agent: "Codex", projectID: nil, content: "Same summary.")

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(repository.knowledge(kind: .sessionSummary).count, 2)
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
        let preset = try repository.createToolPreset(name: "Product light", toolID: tool.id, model: "Flux")
        let item = try repository.createKnowledge(kind: .learning, title: "Learning", scope: .project, projectID: project.id, toolID: tool.id)
        let experiment = try repository.createExperiment(title: "Recipe source", toolID: tool.id, projectID: project.id)
        let run = try repository.createRunFromSetup(experiment: experiment)
        try repository.setBestRun(run, for: experiment)
        let recipe = try repository.saveBestRunAsRecipe(experiment)

        try repository.deleteTool(tool)
        XCTAssertNil(item.toolID)
        XCTAssertNil(run.toolID)
        XCTAssertEqual(run.snapshotToolName, tool.name)
        XCTAssertNil(recipe.toolID)
        XCTAssertNil(repository.recipePayload(recipe)?.toolID)
        XCTAssertEqual(repository.toolPresets().first?.id, preset.id)
        XCTAssertNil(repository.toolPresets().first?.toolID)

        try repository.deleteProject(project)
        XCTAssertEqual(repository.knowledge().first(where: { $0.id == item.id })?.id, item.id)
        XCTAssertNil(item.projectID)
        XCTAssertEqual(item.scope, .global)
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

    func testKnowledgeSearchRespectsToolFilterForReferences() throws {
        let repository = try repository()
        let selectedTool = try repository.createTool(name: "Krea")
        let otherTool = try repository.createTool(name: "Firefly")
        let selected = try repository.createReference(title: "Ceramic material study", toolIDs: [selectedTool.id])
        _ = try repository.createReference(title: "Ceramic material variant", toolIDs: [otherTool.id])

        let results = repository.search(
            query: "ceramic",
            filter: SearchFilter(kind: .reference, toolID: selectedTool.id)
        )

        XCTAssertEqual(results.map(\.id), [selected.id])
        XCTAssertTrue(repository.search(
            query: "ceramic",
            filter: SearchFilter(kind: .reference, status: .works)
        ).isEmpty)
        XCTAssertTrue(repository.search(
            query: "ceramic",
            filter: SearchFilter(kind: .reference, scope: .project)
        ).isEmpty)
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

    func testDeletingReferenceCleansLiveLinksButKeepsRunSnapshot() throws {
        let repository = try repository()
        let reference = try repository.createReference(title: "Material reference")
        let experiment = try repository.createExperiment(title: "Material test")
        experiment.referenceIDs = [reference.id]
        try repository.updateExperiment(experiment)
        let run = try repository.createRunFromSetup(experiment: experiment)
        let collection = try repository.createReferenceCollection(title: "Material shortlist", kind: .manual, referenceIDs: [reference.id])
        let proposal = try repository.proposeReferenceTags(
            agent: "Claude",
            referenceID: reference.id,
            attributes: [VisualAttribute(category: .mood, name: "Quiet")]
        )

        try repository.deleteReference(reference)

        XCTAssertTrue(experiment.referenceIDs.isEmpty)
        XCTAssertTrue(collection.referenceIDs.isEmpty)
        XCTAssertEqual(run.inputReferenceIDs, [reference.id])
        XCTAssertEqual(proposal.status, .rejected)
        XCTAssertTrue(repository.references(filter: ReferenceFilter(includeArchived: true)).isEmpty)
    }

    func testDeletingPromptBlocksReferencesAndRecipesDetachesReusableLinksButPreservesRunSnapshots() throws {
        let repository = try repository()
        let block = try repository.createKnowledge(kind: .promptBlock, title: "Light", body: "Soft side light")
        let reference = try repository.createReference(title: "Clay reference")
        let experiment = try repository.createExperiment(title: "Ceramic test")
        experiment.promptBlockIDs = [block.id]
        experiment.referenceIDs = [reference.id]
        try repository.updateExperiment(experiment)
        let run = try repository.createRunFromSetup(experiment: experiment)
        try repository.setBestRun(run, for: experiment)
        let recipe = try repository.saveBestRunAsRecipe(experiment)
        let flow = try repository.createFlow(title: "Ceramic process")
        let step = try repository.createFlowStep(flowID: flow.id, title: "Apply recipe", recipeID: recipe.id)

        try repository.delete(block)
        try repository.deleteReference(reference)

        XCTAssertTrue(experiment.promptBlockIDs.isEmpty)
        XCTAssertTrue(experiment.referenceIDs.isEmpty)
        XCTAssertEqual(run.snapshotPromptBlockIDs, [block.id])
        XCTAssertEqual(run.inputReferenceIDs, [reference.id])
        XCTAssertTrue(try XCTUnwrap(repository.recipePayload(recipe)).promptBlockIDs.isEmpty)
        XCTAssertTrue(try XCTUnwrap(repository.recipePayload(recipe)).references.isEmpty)

        try repository.delete(recipe)

        XCTAssertNil(step.recipeID)
    }

    func testProposingReferenceTagsForMissingReferenceFailsWithoutCreatingProposal() throws {
        let repository = try repository()

        XCTAssertThrowsError(try repository.proposeReferenceTags(
            agent: "Codex",
            referenceID: UUID(),
            attributes: [VisualAttribute(category: .mood, name: "Quiet")]
        )) {
            XCTAssertEqual($0 as? ReferenceRepositoryError, .referenceNotFound)
        }
        XCTAssertTrue(repository.proposals(status: .pending).isEmpty)
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
        _ = try repository.duplicateRunSetup(first)
        experiment.settingsEntries = [SettingEntry(key: "Strength", value: "0.30")]
        let second = try repository.createRunFromSetup(experiment: experiment, parentRunID: first.id)

        XCTAssertEqual(second.parentRunID, first.id)
        XCTAssertEqual(repository.runDelta(from: first, to: second).first?.label, "Strength")
        XCTAssertEqual(repository.experimentSetup(experiment).settings.first?.value, "0.30")
    }

    func testRunDeltaHandlesRepeatedSettingKeysWithoutTrapping() throws {
        let repository = try repository()
        let experiment = try repository.createExperiment(title: "Repeated settings")
        let parent = try repository.createExperimentRun(
            experimentID: experiment.id,
            title: "Parent",
            settingsEntries: [
                SettingEntry(key: "Control", value: "A"),
                SettingEntry(key: "Control", value: "B")
            ]
        )
        let child = try repository.createExperimentRun(
            experimentID: experiment.id,
            title: "Child",
            settingsEntries: [
                SettingEntry(key: "Control", value: "A"),
                SettingEntry(key: "Control", value: "C")
            ]
        )

        let delta = repository.runDelta(from: parent, to: child)
        XCTAssertEqual(delta.map(\.label), ["Control"])
        XCTAssertEqual(delta.first?.detail, "A, B → A, C")
    }

    func testRunDeltaIncludesSettingUnitChanges() throws {
        let repository = try repository()
        let experiment = try repository.createExperiment(title: "Setting units")
        let parent = try repository.createExperimentRun(
            experimentID: experiment.id,
            title: "Parent",
            settingsEntries: [SettingEntry(key: "Strength", value: "0.45")]
        )
        let child = try repository.createExperimentRun(
            experimentID: experiment.id,
            title: "Child",
            settingsEntries: [SettingEntry(key: "Strength", value: "0.45", unit: "%")]
        )

        XCTAssertEqual(repository.runDelta(from: parent, to: child).first?.detail, "0.45 → 0.45 %")
    }

    func testSetBestRunRejectsRunFromAnotherExperiment() throws {
        let repository = try repository()
        let experiment = try repository.createExperiment(title: "Target")
        let otherExperiment = try repository.createExperiment(title: "Other")
        let foreignRun = try repository.createExperimentRun(experimentID: otherExperiment.id, title: "Foreign run")

        XCTAssertThrowsError(try repository.setBestRun(foreignRun, for: experiment)) {
            XCTAssertEqual($0 as? ExperimentRepositoryError, .runNotFound)
        }
        XCTAssertNil(experiment.bestRunID)
        XCTAssertNotEqual(foreignRun.evaluation, .best)
    }

    func testDeletingBestRunClearsSelection() throws {
        let repository = try repository()
        let experiment = try repository.createExperiment(title: "Delete best")
        let bestRun = try repository.createExperimentRun(experimentID: experiment.id, title: "Best")
        _ = try repository.createExperimentRun(experimentID: experiment.id, title: "Other")
        try repository.setBestRun(bestRun, for: experiment)

        try repository.deleteExperimentRun(bestRun)

        XCTAssertNil(experiment.bestRunID)
        XCTAssertEqual(repository.experimentRuns(experimentID: experiment.id).map(\.order), [1])
    }

    func testDeletingParentRunClearsChildLineage() throws {
        let repository = try repository()
        let experiment = try repository.createExperiment(title: "Delete parent")
        let parent = try repository.createExperimentRun(experimentID: experiment.id, title: "Parent")
        let child = try repository.createExperimentRun(experimentID: experiment.id, title: "Child", parentRunID: parent.id)

        try repository.deleteExperimentRun(parent)

        XCTAssertNil(child.parentRunID)
        XCTAssertEqual(child.order, 1)
    }

    func testCreatingRunRequiresAnExistingExperimentAndSameExperimentParent() throws {
        let repository = try repository()
        let experiment = try repository.createExperiment(title: "Target")
        let otherExperiment = try repository.createExperiment(title: "Other")
        let foreignRun = try repository.createExperimentRun(experimentID: otherExperiment.id, title: "Foreign run")

        XCTAssertThrowsError(try repository.createExperimentRun(experimentID: UUID(), title: "Orphan")) {
            XCTAssertEqual($0 as? ExperimentRepositoryError, .experimentNotFound)
        }
        XCTAssertThrowsError(try repository.createExperimentRun(experimentID: experiment.id, title: "Cross-linked", parentRunID: foreignRun.id)) {
            XCTAssertEqual($0 as? ExperimentRepositoryError, .runNotFound)
        }
        XCTAssertTrue(repository.experimentRuns(experimentID: experiment.id).isEmpty)
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
