# Data model

## First slice models

- `FieldProject`: project context, brief, direction, constraints and Always Remember.
- `FieldTool`: personal notes about a tool, its uses, strengths and weaknesses.
- `KnowledgeItem`: flexible knowledge entity with `kindRaw`, `statusRaw`, scope, provenance, optional project/tool UUIDs, tags, URL and metadata.
- `FieldTag`: future normalized tag vocabulary; first-slice knowledge keeps a compact tag string for low-friction capture.
- `AgentProposal`: pending/approved/rejected permanent-memory proposal.
- `AgentActivity`: audit entry for an action made through Field LAB.
- `FieldFlow`: a repeatable creative workflow.
- `FieldFlowStep`: an ordered step with instructions, optional tool/recipe links and an optional prompt template.
- `FieldReference`: a visual reference with image/thumbnail, source provenance, notes, tags, structured visual attributes, analysis metadata and UUID-list relationships.
- `FieldExperiment`: the editable Workbench setup (`references`, `prompt`, `tool`, `model`, structured settings, Prompt Blocks and execution mode) plus conclusion and project provenance.
- `FieldExperimentRun`: an ordered, historical Run. It snapshots the setup values at creation time, including tool metadata, references, prompt, Prompt Blocks and settings. Result status, human evaluation, observation, output attachment and optional `parentRunID` are stored separately.
- `ToolPreset`: an optional reusable model/settings combination scoped to a Tool.
- `ReferenceCollection`: manual UUID membership or a serializable smart-filter definition.

## Knowledge kinds

`learning`, `reference`, `promptBlock`, `style`, `recipe`, `experiment`, `decision`, `note`, `resource`, `idea`, `workingMemory`, `canonicalMemory`, `sessionSummary`, `flow`.

## Memory policy

- User-created items are approved immediately.
- Agent working notes and session summaries can be written directly.
- Agent learnings and decisions enter `AgentProposal` and require human approval.
- Direct canonical writes and deletes are not exposed through MCP.

## Future migration notes

The Xcode app targets contain a CloudKit-compatible schema, but sync is only a prototype until team-owned identifiers, signing, and a production schema are configured. The public DMG and Swift Package executable remain local-only. Preserve raw-string enum fields, avoid required relationship cycles, and add schema versions for any normalization of tags or attachments. Non-optional attributes need defaults; large attachment data should use external storage and should not be included in context packs.

References follow those constraints deliberately: provider/source kinds, analysis
state, collection kinds and attribute origins are raw strings; project/tool/
collection relationships are portable UUID lists; image fields use external
storage; temporary import staging and local analysis caches are not sync data.

Experiment relationships use UUIDs and serializable UUID lists for the same
CloudKit-safe reason. `SettingEntry` is deliberately flexible (`key`, `value`,
optional `unit` and `type`) instead of hardcoding platform-specific settings.
Saving a conclusion as a Learning and a Best Run as a Recipe stores source
Experiment/Run provenance plus the reusable setup payload in
`KnowledgeItem.metadataJSON`; no existing model is deleted or migrated
destructively.
