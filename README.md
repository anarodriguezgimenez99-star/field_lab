# FIELD LAB

FIELD LAB is a local-first creative memory for macOS: Collect references,
test ideas in Lab, and keep reusable knowledge in Learn. Existing tools,
projects, workflows and MCP capabilities remain available as context and
Settings rather than competing top-level sections.

## Run

Open the folder as a Swift Package in Xcode and run the `FIELD` executable target. The first launch creates an empty local store; use Quick Capture or the Add buttons to start building the Field LAB library.

The repository is pinned to MCP Swift SDK `0.12.1`. The macOS app uses native system controls, a restrained editorial surface and a single interaction accent. The MCP server is stopped by default; its toolbar button starts it on an available loopback port and opens the connection settings. Client header helpers read the bearer token from Keychain when needed.

Every future user-facing capability that is useful to an agent should be exposed through MCP when privacy and approval rules allow it. Add each MCP feature as one capability declaration containing its input schema, write effect and handler; the registry publishes and routes it automatically. See [docs/MCP.md](docs/MCP.md) for the feature contract and security boundary.

## Verification

```sh
swift test
```

The core and MCP tests use in-memory stores and transports. Run them with a full Xcode toolchain selected through `xcode-select`; Command Line Tools alone may not include the SwiftData macros needed by the models.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/MCP.md](docs/MCP.md), [PRIVACY.md](PRIVACY.md) and [docs/PUBLICATION.md](docs/PUBLICATION.md) for product, security and release notes.

## License

The original FIELD LAB code and documentation are licensed under [MIT](LICENSE). The license does not cover third-party works; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). No reference photographs are included in this public snapshot.
