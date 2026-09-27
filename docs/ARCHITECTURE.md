# Architecture

## Current shape

Field LAB is a shared Swift Package with three production targets and two test targets, plus an Xcode project containing the macOS and iPhone app targets:

- `FieldCore`: SwiftData models, repository, search and prompt composition. It has no UI or MCP dependency.
- `FieldMCP`: the protocol-facing tool catalog. It depends on `FieldCore`, but not on SwiftUI or the localhost listener.
- `FIELD`: SwiftUI macOS application sources and platform integrations, including the localhost HTTP adapter.
- `FIELDMobile`: SwiftUI iPhone app in `Apps/FIELD.xcodeproj`; uses `FieldCore` for capture and reading.
- `FIELDShare`: iOS Share Extension in the same project; stages shared URLs, images and text in the App Group queue.
- Xcode `FIELD`: macOS app target over the existing app sources; enables the same CloudKit container as iPhone.
- `FieldCoreTests`: in-memory SwiftData tests for core behavior.
- `FieldMCPTests`: official MCP in-memory transport integration tests.

References use the same layers through a dedicated `FieldReference` model,
`ReferenceSourceResolver`, `ReferenceFilter`/`ReferenceQuery`, and repository
methods. `ReferenceImportQueue` stages share/import payloads in the App Group
outside the main SwiftData store. The iPhone Share Extension writes to this
queue; the mobile app imports records into the CloudKit-backed store when it
becomes active.

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

The schema stores enum values as raw strings to keep migrations explicit and avoid fragile persisted enum representations. Cross-model references use UUID values rather than required SwiftData relationships.

`FieldModelContainer.make(inMemory:cloudKitContainerIdentifier:)` is the single construction point. The desktop and iPhone Xcode targets use the same private CloudKit container when configured; each keeps a local store for offline use. The plain Swift Package executable explicitly uses a local-only store.

CloudKit compatibility is part of the shared schema: persistent model fields have defaults, enum values are stored as strings, there are no uniqueness constraints, and cross-model references remain UUID values rather than required SwiftData relationships.

## Search

`SearchService` is deterministic and local. It scores title matches above body, tags, project and tool matches. Embeddings, vector indexes and external model calls are deliberately out of scope.

## Concurrency

`FieldRepository` is `@MainActor` because its `ModelContext` belongs to the app's main container. MCP handlers are asynchronous and hop to `MainActor` only for repository operations; the HTTP listener and MCP transport never block SwiftUI rendering.

## UI direction

The macOS app is Operate-mode native UI: NavigationSplitView, a three-item
sidebar (Collect, Lab, Learn) plus Settings, system controls, keyboard commands
and content-first detail panes. iPhone uses the same three conceptual areas as
native tabs, with capture sheets, in-tab search, and Settings in the toolbar.
The visual language is restrained, editorial and calm; hierarchy comes from
typography, spacing and the data itself rather than dashboard cards.

Experiments and Experiment Runs are persisted in FieldCore and accessed through
FieldRepository, alongside the existing knowledge and reference models. The UI
does not create a parallel store for the Lab workspace.
