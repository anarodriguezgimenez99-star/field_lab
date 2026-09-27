# macOS installation

FIELD LAB currently supports Apple silicon Macs running macOS 14 or later.
Intel Macs are not supported. The iPhone app and automatic iCloud sync are not
available yet. The app keeps its data in a local store on the Mac.

## Install from a DMG

1. Download the `.dmg` from the repository's GitHub Releases page.
2. Open the disk image and drag `FIELD LAB` to `Applications`.
3. Eject the mounted disk image, then open `FIELD LAB` from `Applications`.

Opening the app while it is still inside the mounted disk image only runs it
from there; it does not install or copy it to `Applications`. A locally built
app also runs from its build folder until you move it to `Applications`. To
find FIELD LAB in Finder's Applications folder and keep it installed there,
drag `FIELD LAB.app` into `Applications` first.

Current preview builds are unsigned and not notarized. If macOS blocks the
first launch, first confirm that the DMG came from the official repository and
that you trust the project. Then try opening the app once, open **System
Settings → Privacy & Security**, and choose **Open Anyway** for FIELD LAB.
macOS may show a second confirmation. Do not disable Gatekeeper globally.

The DMG contains an Apple silicon build. GitHub Releases also includes a
SHA-256 checksum file for each DMG.

## Build locally

Building from source requires Xcode with its command-line tools selected and
Swift 6. From the repository root:

```sh
swift test
scripts/package-macos-dmg.sh
```

The DMG is written to `dist/`. The packaging script is macOS-only because it
uses Apple's `hdiutil` and `iconutil` tools.
