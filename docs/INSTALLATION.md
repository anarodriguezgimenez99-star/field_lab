# macOS installation

FIELD LAB targets Apple silicon Macs running macOS 14 or later. Intel Macs are
not supported. The repository maintains iPhone app and Share Extension source
targets, but does not distribute a mobile installer. CloudKit sync is not
enabled in the DMG; the DMG stores data locally.

## Install from a DMG

Check GitHub Releases for a published DMG. If no release is listed, there is
no prebuilt public download yet.

1. Download the DMG from a published release.
2. Open the disk image and drag FIELD LAB to Applications.
3. Eject the mounted disk image, then open FIELD LAB from Applications.

Opening the app while it is still inside the mounted disk image only runs it
from there; it does not install or copy it to Applications. A locally built
app also runs from its build folder until you move it to Applications.

Preview builds are unsigned and not notarized. If macOS blocks the first
launch, first confirm that the DMG came from the official repository and that
you trust the project. Then open the app once, go to **System Settings →
Privacy & Security**, and choose **Open Anyway** for FIELD LAB. macOS may show
a second confirmation. Do not disable Gatekeeper globally.

The DMG contains an Apple silicon build. A published GitHub Release includes
the DMG and its SHA-256 checksum.

## What the DMG contains

The packaging script builds the Swift Package FIELD executable and wraps it
in a Mac app bundle. This packaged app uses local storage; it is not the
FIELDDesktop target from the Xcode project. The mobile targets are not part
of the DMG.

## Build locally

Building from source requires macOS, Swift 6, and a full Xcode installation
selected with `xcode-select`; Command Line Tools alone may not include the
SwiftData macros plugin. From the repository root:

    swift test
    scripts/package-macos-dmg.sh

The DMG is written to `dist/`. The packaging script requires macOS because it
uses Apple's `hdiutil` and `iconutil` tools.
