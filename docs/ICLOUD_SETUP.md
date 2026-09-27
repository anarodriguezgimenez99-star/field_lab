# iCloud / CloudKit setup

This guide is for development of the maintained iPhone and macOS Xcode
targets. They can share a private CloudKit database when configured
with identifiers and signing settings owned by an Apple Developer team. This
setup is not included in the public DMG: the DMG packages the Swift Package
executable and uses local storage only. The maintained iPhone app and Share
Extension have no public installer.

Each configured app keeps a local store, so capture and reading continue
offline. CloudKit synchronization is asynchronous. The plain Swift Package
executable remains local-only.

## Configure the Apple account

1. Open Apps/FIELD.xcodeproj in Xcode and select all three targets.
2. Copy Apps/Config/FieldICloud.local.xcconfig.example to
   Apps/Config/FieldICloud.local.xcconfig (ignored by Git), then replace the
   sample identifiers with values owned by your Apple Developer team. The
   checked-in FieldICloud.xcconfig provides simulator-safe placeholders; the
   local file overrides them without committing account-specific settings.
3. Select that developer team for all targets. Enable iCloud with CloudKit for
   the iPhone and Mac apps, and enable the same App Group for the iPhone app
   and Share Extension. The mobile app also enables remote notifications so
   CloudKit can deliver background changes.
4. Sign into iCloud on a development iPhone running iOS 26. Select the
   FIELDMobileInitializeCloudKitSchema scheme in Xcode and run it once. That
   development-only scheme sets FIELD_INITIALIZE_CLOUDKIT_SCHEMA=1 and
   initializes the CloudKit development schema from the app's SwiftData model.
   Confirm the record types in CloudKit Console, then switch back to
   FIELDMobile for normal development. Devices on older OS versions can sync
   after the development schema has been initialized and deployed. Apple's
   [SwiftData sync guide](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
   describes the development schema flow.
5. Run the iPhone app normally and use “Guardar en FIELD” from another app's
   Share menu to stage a reference; open FIELD to import it into the library.

Until these account-owned identifiers and signing settings are in place, the
apps use local stores, sharing is unavailable, and the iPhone Settings screen
reports that iCloud needs configuration. The example identifiers in the
checked-in xcconfig are placeholders and cannot sync or share data.

## Verify before release

Create or edit references and learnings on each device, take one device
offline, make additional changes, then reconnect and confirm both libraries
converge. Also check deletion and image attachments. After the development
behavior is acceptable, use CloudKit Console to
[deploy the development schema to production](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)
before distributing an Xcode-target release. CloudKit sync is asynchronous;
the app does not promise immediate propagation.

The schema avoids uniqueness constraints and required relationships. Every
non-optional persisted property has a default, enum values stay as raw strings,
and links between records use UUID values. Reference and experiment images use
external storage. Temporary share staging stays in the device's App Group;
canonical image and thumbnail fields stored in SwiftData are included in
CloudKit sync whenever they are populated.
