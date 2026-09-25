# Field LAB MCP server

Field LAB uses the official Swift MCP SDK, pinned to `0.12.1`. The SDK documents Swift 6+, the `MCP` product, and the Streamable HTTP server transports. The first adapter uses `StatelessHTTPServerTransport` behind a tiny Network.framework listener because the V1 operations are request/response tools; the transport can be upgraded to `StatefulHTTPServerTransport` when server-initiated events are needed.

## Endpoint and security

- Preferred endpoint: `http://127.0.0.1:8765/mcp`. The toolbar connection button starts the server and opens MCP Settings.
- The listener defaults to port `8765` and tries the remainder of `8765` through `8800` if needed. A worktree can set `FIELD_MCP_PORT` to its reserved preferred port in that range. The server publishes the actual endpoint, and the client snippets update to match. If the whole range is occupied, the UI explains the failure.
- The listener is explicitly bound to loopback; it is not exposed to LAN.
- Every request requires `Authorization: Bearer <token>`.
- The token is stored in macOS Keychain and is never logged or synced.
- `FIELD_MCP_TOKEN` is only a fallback for MCP clients that cannot use the Keychain header helper. Do not put a token in a worktree env file.
- The server is stopped by default. The toolbar button starts it and opens MCP Settings; the Settings page can also start or stop it.
- On launch, the app installs a private executable at `~/Library/Application Support/Field LAB/MCP/auth-headers`. Codex and Claude Code can call it to read the bearer token from Keychain only when connecting.

## Tools

- `search_knowledge`
- `get_project_context`
- `get_constraints`
- `get_tool_knowledge`
- `get_decisions`
- `get_recipe`
- `get_experiment`
- `list_experiment_runs`
- `compare_runs_metadata`
- `search_experiments`
- `get_best_run`
- `get_workflow`
- `add_working_note`
- `propose_learning`
- `propose_decision`
- `save_session_summary`
- `search_references`
- `get_reference`
- `add_reference_note`
- `propose_reference_tags`

All reads and writes pass through `FieldRepository`. Read/search calls are recorded in Activity; permanent agent knowledge is represented as a proposal and never silently becomes canonical memory.

## Adding app capabilities

Expose each user-facing action through MCP when it gives an agent useful access
and can follow the product's privacy and approval rules. Implement a feature as
`MCPToolFeature` and keep each tool's schema, effect and handler together in one
`MCPToolCapability`. Add the feature once to `LocalMCPServer.toolFeatures`.
Startup then includes its tools in `tools/list` and routes `tools/call` through
`MCPToolRegistry`; a new feature does not need a second entry in the built-in
schema catalog or its dispatch switch.

Choose an effect deliberately:

- `readOnly` for information retrieval;
- `workingWrite` for reversible or temporary agent notes;
- `proposalWrite` when a human must approve a persistent change.

The registry forwards these effects as MCP annotations, which are advisory
metadata. A handler must still validate its inputs and enforce the real
repository write/approval boundary. Do not expose a SwiftUI action or repository
method by reflection: UI implementation details do not reveal whether an action
is safe or meaningful for an agent. Swift also cannot discover new features at
runtime in a reliable, type-safe way, so adding a feature still requires its
single declaration and provider registration; after that, MCP listing and
dispatch update automatically.

Reference reads return compact metadata: IDs, titles, notes, sources, structured
attributes, relationships and safe original URLs. They do not expose arbitrary
filesystem paths or embed full-size image data. `add_reference_note` creates
working memory; `propose_reference_tags` creates an AI Inbox proposal and never
changes canonical classification until approved by the user.

The existing `search_knowledge` path also returns Experiment results when the
query matches an experiment title, goal, prompt, model, conclusion, project or
tool. The dedicated experiment tools expose Workbench setup and immutable Run
snapshots, including structured settings and parent/child deltas. Agents may
propose a Learning, but no MCP tool can select or overwrite Best Run; that
decision remains human-owned in LAB.

## Client setup

The UI copies the active endpoint and client configuration snippets. Codex uses its local HTTP header helper:

```toml
[mcp_servers.field]
url = "http://127.0.0.1:8765/mcp"
http_headers_helper = "'/Users/<user>/Library/Application Support/Field LAB/MCP/auth-headers'"
```

Claude Code uses its `headersHelper` field:

```sh
claude mcp add-json field '{"type":"http","url":"http://127.0.0.1:8765/mcp","headersHelper":"'\''/Users/<user>/Library/Application Support/Field LAB/MCP/auth-headers'\''"}' --scope user
```

The snippets in Settings contain the actual helper path and active endpoint. The app keeps the token in macOS Keychain; it never includes the token in a copied configuration or setup prompt. If the helper cannot be installed, Settings falls back to `FIELD_MCP_TOKEN` and tells the user to provide it through the client process environment.

The app does not edit `~/.codex/config.toml` automatically.
