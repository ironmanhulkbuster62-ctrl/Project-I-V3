# Build the unsigned iOS IPA

The workflow in `.github/workflows/build-ios-ipa.yml` creates an unsigned,
device-targeted IPA on a GitHub-hosted macOS runner. It does not need Apple
Developer credentials or repository secrets.

## Run it

1. Open the repository's **Actions** tab.
2. Select **Build unsigned iOS IPA**.
3. Choose **Run workflow**.
4. Download the `project-istiqamah-ios-unsigned` artifact when the job passes.

Pushing a tag whose name starts with `v` also runs the workflow.

## What the workflow does

The job installs XcodeGen, generates the Xcode project from the checked-in
`project.json`, and builds the SwiftUI app and ActivityKit widget extension for
the physical-device SDK with code signing disabled. It then places the app
inside `Payload/`, creates `ProjectIstiqamah-unsigned.ipa`, verifies the native
Live Activity extension is embedded, checks the archive, and uploads it for 14
days. Expo, React Native, Node.js, and CocoaPods are not part of this build.

## Installing it

An unsigned IPA cannot be installed directly by tapping it. A sideloading tool
must sign it with an Apple ID or certificate before iOS will install it. The
workflow intentionally does not store or use signing credentials.

The app uses the bundle identifier `com.projectistiqamah.app`. If a signing tool
requires a different identifier, configure that in the signing tool or update
`PRODUCT_BUNDLE_IDENTIFIER` in `artifacts/project-istiqamah/project.json` before
building.
