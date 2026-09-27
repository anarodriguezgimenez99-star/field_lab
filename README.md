# FIELD LAB

FIELD LAB is a local-first creative memory for macOS: Collect references,
test ideas in Lab, and keep reusable knowledge in Learn. Existing tools,
projects, workflows and MCP capabilities remain available as context and
Settings rather than competing top-level sections.

> **Availability:** FIELD LAB currently supports Apple silicon Macs running macOS 14 or later.
> There is no iPhone app or iCloud sync yet. Data is stored locally on the Mac.

## Install on Mac

Download the latest `.dmg` from GitHub Releases, open it and drag `FIELD LAB`
to Applications. Intel Macs are not supported.

The current preview is unsigned and not notarized. macOS may ask you to
authorize it in **System Settings → Privacy & Security** the first time you
open it. Only do this for a build downloaded from the official repository that
you trust. See [installation notes](docs/INSTALLATION.md).

## Run

Open [`Apps/FIELD.xcodeproj`](Apps/FIELD.xcodeproj) in Xcode. Use the
`FIELDDesktop` scheme to build the Mac app. The repository also contains an
iPhone app and Share Extension prototype as groundwork for a future companion;
they are not part of the current release. The legacy Swift Package `FIELD`
executable remains available for local development:

```sh
swift run FIELD
```

The current Mac release stores data locally; iPhone support and iCloud sync
are future work. The prototype's CloudKit and Share Extension setup notes are
in [docs/ICLOUD_SETUP.md](docs/ICLOUD_SETUP.md). The MCP server runs only in the
macOS app and stays stopped by default.

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
