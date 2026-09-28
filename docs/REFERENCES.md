# References

References is Field LAB's visual library: **what I see**. It stores the image, the
original source and the user's reason for keeping it as one local-first record
that can later be classified, filtered, connected to Projects and queried by
MCP. Field LAB does not replace Pinterest, Cosmos, Instagram or the other places
where discovery happens.

## Architecture

The vertical slice follows:

`External app → import/share staging → FieldRepository → SwiftData → search, filters and MCP`

`FieldReference` is a dedicated model rather than a generic `KnowledgeItem`.
The legacy generic reference kind remains readable for compatibility, while new
References use the dedicated model. `FieldRepository` remains the single domain
entry point for SwiftUI and MCP.

## Data model

`FieldReference` stores optional title, note, timestamps, pinned/archive state,
image and thumbnail data, dimensions/orientation, source provenance, OCR and
analysis state, tags, visual attributes and UUID-list relationships to Projects,
Tools and Collections. UUID lists follow Field LAB's current CloudKit-safe strategy:
they avoid required relationship cycles and keep enum values as raw strings.

Visual attributes are encoded as portable JSON values with explicit category,
origin (`manual`, `automatic`, `agentProposal`) and optional confidence. Manual
values take precedence over later suggestions. Free-form manual tags and
automatic tags are stored separately.

`ReferenceCollection` supports manual collections and smart collections. Manual
collections store UUIDs; smart collections store a serializable `ReferenceFilter`
and evaluate it at query time. References are never copied into a collection.

## Sources

`ReferenceSourceResolver` normalizes URLs, removes common tracking parameters and
detects known providers by domain. Pinterest, Cosmos, LinkedIn, Instagram,
Behance and Dribbble have display names; all other URLs resolve to `Web`. Native
and manual sources remain extensible through the stable `sourceKind` plus free
`sourceName`, `sourceDomain` and metadata fields.

The original URL is preserved and the detail view offers **Open original**. No
scraping, OAuth or provider API access is performed in V1.

## Import pipeline

`ReferenceImportQueue` is a small App Group-compatible staging queue. An
extension can write a JSON record and an optional asset file without opening the
main SwiftData store. Field LAB can process records into `FieldReference`, then
remove the record and staged asset. Queue IDs make the operation inspectable and
idempotent. The current macOS surface also supports file import, drag and drop,
URL entry and manual notes.

The iPhone Share Extension flow is:

`Share → Save to Field LAB → App Group staging → Field LAB import → local SwiftData → CloudKit when configured`

The extension stages the share to the App Group without opening SwiftData or
waiting for CloudKit. The main app imports it on launch or when returning to
the foreground, then the reference is available in its local store. Configured
Xcode app targets synchronize that store through CloudKit.

## Classification, filters and search

The References library exposes All, Unclassified, Pinned and source filters.
`ReferenceFilter` and `ReferenceQuery` combine style, medium, subject, lighting,
composition, mood, color, source, tags and project constraints outside Views.
Source counts are derived from stored records.

Global `SearchService` now includes reference title, note, OCR text, source,
tags, visual attributes and project names. Search results identify the record as
`reference` and carry the source and original URL without embedding large image
blobs.

Objective image analysis is intentionally staged after the V1 vertical slice.
The model already carries orientation, dimensions, dominant colors, OCR and
analysis state so a local Vision/ImageIO service can populate them asynchronously
without changing the library UI. No external service receives reference images.

## Projects and context

References relate to multiple Projects by UUID. Project detail can add/remove
existing library references without duplication. `get_project_context` includes a
bounded summary of important project references (ID, title, source, note and
attributes); agents can request full records with `search_references` or
`get_reference`.

## MCP

The server adds:

- `search_references` with text, source, project, collection, tags and structured
  attribute filters;
- `get_reference` with source, note, attributes, OCR summary, colors and
  relationships;
- `add_reference_note`, which writes working memory only;
- `propose_reference_tags`, which creates an `AgentProposal` for AI Inbox.

MCP returns metadata and IDs, not large base64 images or arbitrary local paths.
Approving a tag proposal applies attributes through the repository and preserves
manual classifications.

## Sync, privacy and performance

Canonical metadata, user notes, source provenance, classifications, collection
definitions and Project relationships are SwiftData fields. The maintained
Xcode app targets synchronize them through CloudKit when team-owned identifiers,
signing and schema are configured; the public DMG remains local-only.
Temporary imports, regenerable thumbnails/caches and MCP tokens are local-only.
Large image fields use external storage; the UI uses lazy grids and does not
load all originals at once.

The first analysis pass is local-only. Field LAB does not send images to OpenAI,
Anthropic, Google, Pinterest or any other external service. Any future remote
classification must be explicit opt-in.

## Future connectors

V1 is native capture: iOS Share Extension, macOS drag/drop, file import and URL
entry. Future `ReferenceSourceAdapter` implementations may normalize official
provider imports, but the `FieldReference` model must remain provider-agnostic.
Safari Extension support and provider OAuth/API connectors are post-V1 work.
