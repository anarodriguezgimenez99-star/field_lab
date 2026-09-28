# FIELD LAB

FIELD LAB is a local-first creative memory for macOS: collect references, test
ideas in Lab, and keep reusable knowledge in Learn.

> **Availability:** The distributable Mac package targets Apple silicon Macs
> running macOS 14 or later. Intel Macs are not supported. The iPhone app and
> Share Extension are maintained as source targets in this repository,
> but are not distributed. Their CloudKit setup requires team-owned Apple
> identifiers and a configured CloudKit schema. The DMG uses a local store
> only.

## Install on Mac

Look for a DMG in GitHub Releases. If no release is listed, a prebuilt download
has not been published yet; see the
[local build instructions](docs/INSTALLATION.md#build-locally). When a release
is available, open its DMG and drag FIELD LAB to Applications. See the
[installation notes](docs/INSTALLATION.md).

Preview builds are unsigned and not notarized. macOS may require a one-time
approval in **System Settings → Privacy & Security** before the app opens.

## Run from source

Open [Apps/FIELD.xcodeproj](Apps/FIELD.xcodeproj) in Xcode and choose the
FIELDDesktop scheme to build the native Mac target. The project also contains
the maintained iPhone app and Share Extension targets; neither is included in
the DMG or built by the current CI workflow.

The Swift Package executable remains available for local development:

    swift run FIELD

The DMG packaging script builds this Swift Package executable and wraps it as
a Mac app. It uses local storage and is not the Xcode FIELDDesktop target.
CloudKit setup for the Xcode app targets is documented in
[docs/ICLOUD_SETUP.md](docs/ICLOUD_SETUP.md).

The MCP server runs only in the macOS app, binds to loopback, and stays stopped
by default. See [docs/MCP.md](docs/MCP.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md),
[PRIVACY.md](PRIVACY.md), and [docs/PUBLICATION.md](docs/PUBLICATION.md).

## Documentation

- [Product overview](docs/PRODUCT.md), [roadmap](docs/ROADMAP.md), and
  [design principles](DESIGN.md).
- [Architecture](docs/ARCHITECTURE.md), [data model](docs/DATA_MODEL.md), and
  [UX model](docs/UX_MODEL.md).
- [References](docs/REFERENCES.md), [MCP integration](docs/MCP.md), and
  [CloudKit setup for the maintained Xcode targets](docs/ICLOUD_SETUP.md).
- [Privacy](PRIVACY.md), [third-party notices](THIRD_PARTY_NOTICES.md), and
  [public release guidance](docs/PUBLICATION.md).

## Verification and CI

Run the Swift Package test suite with:

    swift test

The core and MCP tests use in-memory stores and transports. SwiftData models
require the full Xcode toolchain; a Command Line Tools-only installation may
not include the SwiftDataMacros plugin.

The repository includes a GitHub Actions workflow at
[.github/workflows/macos.yml](.github/workflows/macos.yml). Once published to
GitHub, it runs the Swift Package tests and builds an Apple silicon DMG for
pushes to main, version tags, and pull requests targeting main. A version tag
such as v0.1.0 creates a GitHub Release with the DMG and its SHA-256 checksum.
The workflow does not build or test the iPhone Xcode target.

## License

Original FIELD LAB code and documentation use the [MIT License](LICENSE).
The license does not cover third-party works; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). No reference photographs are
included in the reviewed public snapshot.
