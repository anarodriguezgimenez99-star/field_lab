# FIELD LAB

FIELD LAB is a local-first creative memory for macOS: Collect references,
test ideas in Lab, and keep reusable knowledge in Learn. Existing tools,
projects, workflows and MCP capabilities remain available as context and
Settings rather than competing top-level sections.

## Run

Open the folder as a Swift Package in Xcode and run the `FIELD` executable target. The first launch creates an empty local store; use Quick Capture or the Add buttons to start building the Field LAB library.

The repository is pinned to MCP Swift SDK `0.12.1`. The macOS app uses native system controls, a restrained editorial surface and a single interaction accent. The MCP server is stopped by default; its toolbar button starts it on an available loopback port and opens the connection settings. Client header helpers read the bearer token from Keychain when needed.

Every future user-facing capability that is useful to an agent should be exposed through MCP when privacy and approval rules allow it. Add each MCP feature as one capability declaration containing its input schema, write effect and handler; the registry publishes and routes it automatically. See [docs/MCP.md](docs/MCP.md) for the feature contract and security boundary.

## Test

```sh
swift test
```

The core and MCP tests use in-memory stores/transports. The active Command Line Tools installation on this host does not include the `SwiftDataMacros` plugin, so `swift test` cannot compile the `FieldCore` SwiftData models. Run the suite with a matching full Xcode toolchain selected through `xcode-select`.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/MCP.md](docs/MCP.md) and [PRIVACY.md](PRIVACY.md) for the product and security decisions.

## Working with Codex

Keep each Codex task in its own local Git worktree. At the start of a FIELD conversation, Codex should recommend opening the task in a Codex-managed worktree. The local resource manager assigns a separate MCP port and SwiftData store to each checkout. Codex creates and tracks the worktrees from `main`, and completed task branches are merged into local `main`. When more capacity is needed, archive a completed task in Codex so Codex can reclaim its worktree. See [docs/WORKTREES.md](docs/WORKTREES.md).
