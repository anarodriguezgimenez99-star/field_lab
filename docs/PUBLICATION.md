# Public repository release

Publish only the reviewed public/preparar-publicacion branch as the remote
main branch. It must be refreshed from the latest local main and audited after
each change. It is a sanitized single-commit snapshot; do not publish the full
local development history, task branches, worktree metadata, user data,
signing credentials, or application stores.

The project code and original documentation use the MIT License in LICENSE.
It does not grant rights to third-party material. Preview photographs whose
only recorded source was Cosmos had no recoverable original source URLs,
license terms, or complete attribution. They were removed from the public
snapshot; the review is recorded in THIRD_PARTY_NOTICES.md. Do not re-add them
unless redistribution rights and attribution requirements are documented.
The current snapshot tree contains no reference photographs.

Before publishing:

- Refresh the public snapshot from the latest reviewed main.
- Check its complete tree and single-commit history for private content.
- Keep environment files, credentials, signing keys, and application stores
  out of Git. The repository .gitignore covers common local files.
- Use a hosting-provider privacy email for any future public commits.
- Share a repository link; do not package the entire worktree directory.

## macOS builds

The macOS CI workflow runs Swift Package tests and creates an unsigned,
Apple-silicon-only DMG for macOS 14 or later. Its packaging script builds the
Swift Package FIELD executable and wraps it in a Mac app bundle; it does not
build the Xcode FIELDDesktop, iPhone, or Share Extension targets. The packaged
DMG uses local storage and does not enable CloudKit.

After the workflow has been published to GitHub, pushes to main create a
downloadable CI artifact. A version tag such as v0.1.0 creates a GitHub
Release with the DMG and its SHA-256 checksum. If no release appears in
GitHub Releases, a prebuilt public DMG is not available yet.

These builds are unsigned and not notarized. macOS may require a manual Open
Anyway approval. Do not describe them as signed or as a frictionless installer.

The iPhone app and Share Extension remain maintained Xcode targets; they have
no public installer and are not built by this workflow. CloudKit sync
requires team-owned identifiers, signing, and schema setup for these targets. See the
[installation notes](INSTALLATION.md) and [CloudKit setup guide](ICLOUD_SETUP.md).
