# Field LAB progress

## Current milestone

Functional macOS-first MVP — local knowledge system, visual references, recipes, workflows and MCP.

## Completed

- Product truth captured in `PRODUCT.md`.
- Swift Package manifest with Swift 6, macOS 14/iOS 17 declarations and official MCP SDK dependency.
- SwiftData models for projects, tools, knowledge, tags, proposals and activity.
- SwiftData models and repository support for editable flows and ordered flow steps.
- `FieldRepository` for CRUD, deterministic search access, project context, proposal approval, working notes and deduplicated session summaries.
- `SearchService` and Prompt Deck stack composition.
- Initial macOS SwiftUI NavigationSplitView, library browsers, quick capture, projects, tools, AI Inbox, Activity and MCP settings.
- Local MCP adapter with Keychain token, loopback listener and V1 tools.
- Simplified product navigation to Collect → Lab → Learn with Lab selected by default; advanced capabilities remain available through contextual views and Settings.
- Added persisted Experiment and Experiment Run models, repository CRUD, ordering, comparison-ready provenance and conclusion-to-Learning conversion.
- Separated `FieldMCP` tool catalog with official in-memory transport integration tests.
- MCP tool schemas are emitted as valid JSON Schema objects, including typed integer limits; workflow/constraint reads and resource reads are recorded in Activity.
- Visual References board with image/URL attachments, Prompt Deck recipes and guided workflow steps.
- Dedicated `FieldReference` model with source resolver, local import staging queue, structured manual attributes, source/pinned/unclassified filters, Project relationships and global search/MCP integration.
- References detail/library UI with image grid, drag/drop and file import, original-source links and Project reference picker.
- MCP tools for reference search/detail, working notes and approval-gated tag proposals.
- Core XCTest coverage for CRUD, search, context depth, approval, prompt stacking and duplicate session summaries.
- Product/architecture/data model/MCP/roadmap/iCloud/privacy documentation.
- Dark-mode native Apple visual system documented in `DESIGN.md`; local preview updated to match the SwiftUI shell.

## Current work

- Resolve the compiler/toolchain mismatch and run the full build/test suite.
- Validate the new three-surface macOS/iPhone shell and complete the remaining contextual entry points for all existing capabilities.
- Exercise authenticated/unauthenticated HTTP adapter behavior after the package builds.
- Add export and iPhone/iCloud slices after the macOS-first core is validated.
- Validate the References slice with an Xcode-backed macOS/iOS build; add the actual Share Extension target and local Vision/ImageIO analysis in V1.1.

## Known issues

- This host currently has Command Line Tools active, not Xcode. `xcodebuild` is unavailable and the installed Swift 6.3.3 compiler does not match the Command Line Tools Swift SDK 6.3.2 module version.
- SwiftUI rendering and macOS runtime behavior cannot be captured until an Xcode-backed build is available.
- The current MCP HTTP adapter intentionally uses stateless request/response transport; stateful SSE can be added when agent clients require server-initiated events.
- The current Swift Package has no Xcode Share Extension target, so `ReferenceImportQueue` is the safe staging contract and macOS file/drag/URL import is the shipped entry point for this pass.

## Verification commands

```sh
swift package resolve
swift test
swift build
xcodebuild -scheme FIELD -destination 'platform=macOS' build
```

## Last verification

`swift package resolve` succeeded on 2026-09-20 and pinned the official MCP SDK at `0.12.1`. `swift test` reached package compilation but is blocked on this host because Command Line Tools does not provide the `SwiftDataMacros` plugin required by `@Model`; a matching Xcode installation/selection is still required for the real test run.

The full source and test sets pass `swiftc -frontend -parse` on 2026-09-22 for the macOS and iOS branches. `swift test` still stops during manifest planning before source compilation because this host has no Xcode/SwiftDataMacros and its Swift 6.3.3 compiler does not match the active Command Line Tools Swift 6.3.2 SDK.
