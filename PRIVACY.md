# Privacy

FIELD LAB is designed to keep creative memory on the user's devices.

- No FIELD LAB account is required.
- No analytics or external telemetry is included.
- FIELD LAB does not call third-party AI APIs.
- The local MCP server binds to loopback only and is stopped by default.
- The MCP token is stored in macOS Keychain, is never logged, and is not synced
  to iCloud.
- Agent Activity records actions in FIELD LAB; it does not store prompts,
  secrets, or private chain-of-thought.
- The DMG and Swift Package executable use a local store. The maintained Xcode
  iPhone and Mac targets include CloudKit support, but public sync is not
  configured or distributed. CloudKit requires team-owned identifiers,
  signing, and a deployed schema.
- Reference image analysis is local-only in the initial implementation.
  Images are not sent to OpenAI, Anthropic, Google, Pinterest, or other
  external services.
- Original source URLs are preserved for attribution. FIELD LAB does not
  scrape sites or authenticate to provider accounts in V1.

Users should treat any agent connected to the local MCP endpoint as having the
permissions shown in FIELD LAB Settings.
