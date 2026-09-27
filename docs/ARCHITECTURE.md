# Architecture

## Current shape

Field LAB is a Swift Package with three production targets and two test targets:

- `FieldCore`: SwiftData models, repository, search and prompt composition. It has no UI or MCP dependency.
- `FieldMCP`: the protocol-facing tool catalog. It depends on `FieldCore`, but not on SwiftUI or the localhost listener.
- `FIELD`: SwiftUI macOS application target and platform integrations, including the localhost HTTP adapter.
- `FieldCoreTests`: in-memory SwiftData tests for core behavior.
- `FieldMCPTests`: official MCP in-memory transport integration tests.

References use the same layers through a dedicated `FieldReference` model,
`ReferenceSourceResolver`, `ReferenceFilter`/`ReferenceQuery`, and repository
methods. `ReferenceImportQueue` stages share/import payloads outside the main
SwiftData store so a future App Group extension never opens the CloudKit-backed
container directly.

The normal data path is:

`SwiftUI → FieldRepository → ModelContext → SwiftData`

and:

`MCP transport → MCPToolCatalog → FieldRepository → ModelContext → SwiftData`

The UI and MCP server must not access SwiftData models through separate business logic.

## MCP feature exposure

Every user-facing capability that is useful to an agent should have a local MCP
entry when its privacy and approval rules allow it. The owning feature implements
`MCPToolFeature` and declares each `MCPToolCapability` once, with its MCP schema,
effect (`readOnly`, `workingWrite` or `proposalWrite`) and handler together. The
MCP registry builds `tools/list` and routes `tools/call` from those declarations;
feature authors do not also edit the HTTP listener, built-in tool schema list or
its dispatch switch. The feature provider is added once to
`LocalMCPServer.toolFeatures` so app startup composes the feature set.

The registry intentionally does not reflect over SwiftUI views, repository
methods or model properties. Swift has no safe way to infer which UI actions are
appropriate for agents, what arguments they need, or which writes require human
approval. Each capability therefore needs one explicit declaration and provider
registration. MCP annotations expose the declared behavior as protocol hints;
the handler and repository remain responsible for enforcing it. Agent changes
to canonical knowledge, reference classification or other human-owned decisions
must continue to use the proposal/approval path.

Reference MCP tools (`search_references`, `get_reference`,
`add_reference_note` and `propose_reference_tags`) use this same path. Agents
receive compact metadata and cannot read arbitrary local paths.

## Persistence

The schema stores enum values as raw strings to keep migrations explicit and avoid fragile persisted enum representations. Relationships use UUID references in the first slice; this keeps the local model simple and gives CloudKit migration room without relationship cycles.

`FieldModelContainer.make(inMemory:)` is the single construction point. The production app uses a local store. CloudKit configuration is intentionally not assumed until entitlements and a container exist.

## Search

`SearchService` is deterministic and local. It scores title matches above body, tags, project and tool matches. Embeddings, vector indexes and external model calls are deliberately out of scope.

## Concurrency

`FieldRepository` is `@MainActor` because its `ModelContext` belongs to the app's main container. MCP handlers are asynchronous and hop to `MainActor` only for repository operations; the HTTP listener and MCP transport never block SwiftUI rendering.

## UI direction

The available UI is Operate-mode native macOS UI: NavigationSplitView, a
three-item sidebar (Collect, Lab, Learn) plus Settings, system controls,
keyboard commands and content-first detail panes. A future iPhone app is
planned around the same three conceptual areas as tabs. The visual language is
restrained, editorial and calm; hierarchy comes from typography, spacing and
the data itself rather than dashboard cards.

Experiments and Experiment Runs are persisted in FieldCore and accessed through
FieldRepository, alongside the existing knowledge and reference models. The UI
does not create a parallel store for the Lab workspace.
