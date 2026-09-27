# Privacy

Field LAB is designed to keep creative memory on the user's devices.

- No Field LAB account is required.
- No analytics or external telemetry is included.
- No third-party AI API is called by Field LAB.
- The local MCP server binds to loopback only.
- The MCP token is stored in Keychain and is not sent to iCloud.
- Agent activity records actions on Field LAB, not prompts, secrets or private chain-of-thought.
- iCloud sync is not available yet. The current Mac app stores data locally.
- Reference image analysis is local-only in the initial implementation. Images are not sent to OpenAI, Anthropic, Google, Pinterest or other external services.
- Original source URLs are preserved for attribution; Field LAB does not scrape or authenticate to provider accounts in V1.

Users should treat any agent connected to the local MCP endpoint as having the permissions shown in Field LAB Settings.
