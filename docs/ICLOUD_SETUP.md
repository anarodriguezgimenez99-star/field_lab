# iCloud / CloudKit setup

**Availability:** iCloud sync is not available in the current release. There is
no iPhone app or CloudKit configuration yet, and the Mac app uses a local
SwiftData store. This document is a future implementation checklist.

CloudKit is intentionally not enabled in the first local development slice. The app must work without it.

When enabling sync:

1. Open the generated Field LAB package in Xcode and select the macOS and iOS app targets.
2. Add the iCloud capability and enable CloudKit for the chosen container.
3. Add the same container identifier to both platform targets and their entitlements.
4. Keep the SwiftData schema CloudKit-compatible: optional relationships where required, raw string enum fields and no unsupported uniqueness constraints.
5. Run the app once with a development container to initialize the schema.
6. Exercise create/update/delete on both a Mac and an iPhone simulator signed into the same iCloud account.
7. Promote the tested schema only after checking conflict behavior and offline recovery.

The current `FieldModelContainer` is the single place to add the CloudKit configuration, so the rest of the repository and UI do not need to change.

References follow the same boundary. Their portable metadata, source
provenance, manual/automatic classifications, collection definitions and UUID
relationships are model fields. Image data uses external storage; temporary
import queue files, thumbnails that can be regenerated and analysis caches stay
local. Validate reference conflict behavior by saving the same record offline on
Mac and iPhone before promoting the container schema.
