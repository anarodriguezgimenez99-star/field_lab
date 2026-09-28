# Development workflow

- `main` is the local integration branch. Do task work on a branch named `task/<task-slug>` (or a tool-specific prefix such as `claude/`), not directly on `main`. Codex and Claude Code may each use their own tool-managed checkout; nothing in this repository creates, registers or removes them.
- Merge finished branches locally with `git merge --no-ff <branch>` so each task stays visible in history.
- Keep all work local. Do not add a remote or push unless the user explicitly asks.
- To run two copies of the app side by side, set `FIELD_MCP_PORT` and `FIELD_DATA_DIR` (see [docs/MCP.md](docs/MCP.md)) so they do not share a port or database.

# Visual snapshots (macOS, DEBUG only)

Run a debug build with `FIELD_SNAPSHOT_DIR=<dir>` (plus `FIELD_DATA_DIR` and `FIELD_MCP_PORT` to stay isolated) to seed sample data, write one PNG per primary route and quit. It renders from the view's own backing store, so it needs no Screen Recording permission. See `Sources/FIELD/SnapshotMode.swift`.
