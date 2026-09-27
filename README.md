# FIELD LAB

FIELD LAB is a local-first creative memory for macOS: Collect references,
test ideas in Lab, and keep reusable knowledge in Learn. Existing tools,
projects, workflows and MCP capabilities remain available as context and
Settings rather than competing top-level sections.

## Run

Open [`Apps/FIELD.xcodeproj`](Apps/FIELD.xcodeproj) in Xcode. Use the
`FIELDDesktop` scheme for the Mac app and `FIELDMobile` for iPhone; both use the shared
`FieldCore` package and can share a private CloudKit library after you configure
your Apple Developer team and container. The iPhone app also includes a Share
Extension that stages URLs, images and text from other apps. The legacy Swift
Package `FIELD` executable remains available for local development without
iCloud:

```sh
swift run FIELD
```

Before running the Xcode apps on a device with CloudKit, add your team-owned
bundle IDs, CloudKit container and App Group to the ignored
`Apps/Config/FieldICloud.local.xcconfig`, then select your signing team for all
three targets. See
[docs/ICLOUD_SETUP.md](docs/ICLOUD_SETUP.md).

The repository is pinned to MCP Swift SDK `0.12.1`. Both Apple apps share the
same SwiftData schema and private CloudKit container. The iPhone app is a
capture-and-consult surface with three native tabs; the macOS app remains the
full workspace. The MCP server runs only in the macOS app and stays stopped by
default.

Every future user-facing capability that is useful to an agent should be exposed through MCP when privacy and approval rules allow it. Add each MCP feature as one capability declaration containing its input schema, write effect and handler; the registry publishes and routes it automatically. See [docs/MCP.md](docs/MCP.md) for the feature contract and security boundary.

## Verification

```sh
swift test
```

The core and MCP tests use in-memory stores/transports. SwiftData models require
the full Xcode toolchain and its accepted license; a Command Line Tools-only
selection may not include the `SwiftDataMacros` plugin. Select the installed
Xcode developer directory with `xcode-select` before building or running the
suite.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/MCP.md](docs/MCP.md), [PRIVACY.md](PRIVACY.md) and [docs/PUBLICATION.md](docs/PUBLICATION.md) for product, security and release notes.

## License

The original FIELD LAB code and documentation are licensed under [MIT](LICENSE). The license does not cover third-party works; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). No reference photographs are included in this public snapshot.
