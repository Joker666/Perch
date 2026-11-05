# iCloud sync

Perch syncs the todos through the person's private iCloud database with
SwiftData and CloudKit. There is no server and no account of Perch's own.

The app syncs only when it has the iCloud entitlement. `build.sh` adds the
entitlement only when it finds a provisioning profile with iCloud for
`com.rafi.perch`. Without the profile, the build works as before and keeps the
todos on one Mac. A test store (`APP_STORE`) never syncs.
`perch status --json` shows `"iCloud": "on"` or `"off"`.

## One-time setup in the Apple Developer portal

1. Identifiers > iCloud Containers: add `iCloud.com.rafi.perch`.
2. Identifiers > App IDs > `com.rafi.perch`: turn on iCloud (CloudKit, with
   the container above) and Push Notifications.
3. Profiles: make two macOS profiles for `com.rafi.perch`.
   - Development, with your Apple Development certificate and this Mac.
   - Developer ID, with your Developer ID Application certificate.
4. Put the Development profile at
   `~/Library/Developer/Perch/Perch.provisionprofile`. `./build.sh` then
   prints "iCloud sync on (Production)".
5. Add the Developer ID profile to the repository secrets as
   `MACOS_PROVISION_PROFILE`: `base64 -i Perch.provisionprofile | pbcopy`.

## The CloudKit schema

The Developer ID build can use only the Production environment, and
Production gets record types only from a schema deploy.

1. Build once with the Development environment and add a todo:
   `ICLOUD_ENV=Development ./build.sh --open`. CloudKit makes the record
   types in Development.
2. CloudKit Console > `iCloud.com.rafi.perch` > Schema: deploy the schema to
   Production.
3. Build again without `ICLOUD_ENV`. Local builds then use Production, so
   they show the same todos as the release app.

Deploy the schema again before a release that adds a property to `Todo`.
CloudKit accepts only added properties with default values. Never rename or
remove a property after the first deploy.

## How the code handles sync

- `Store.makeContainer` uses `.private(container)` when the app has the
  entitlement and the store is the real one, and `.none` otherwise. Never
  `.automatic`, which syncs any store.
- `AppModel.reloadOnSync` reloads the List when iCloud merges a change.
- Undo puts back only the todos its change touched, so it never takes back a
  change from another Mac.
- Two Macs can give two todos the same order value. Ties sort by creation
  time and then id, so every Mac shows the same order, and the next save
  renumbers them.
