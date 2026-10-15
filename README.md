# Countdown Together

Countdown Together is an iPhone app for a shared countdown. You and someone else pick a trip, a date, an anniversary, or anything else you're waiting on. Each countdown has a theme and an optional photo. Both of you can watch the time run down on the Home Screen, on the Lock Screen, and in a Live Activity on the last day.

It is a SwiftUI app with a widget extension. The Xcode project is already generated, so you can open it and run it. A free personal Apple ID is enough to install it on your own iPhone. Capabilities that need a paid developer account are left off the default build and documented below.

## What you can do

- Create a countdown with a name, date and time, kind, theme, note, and photo.
- See a live countdown. On the last day it ticks in hours, minutes, and seconds.
- Share an 8-character invite code, a QR code, or a `.countdown` file.
- Join someone else's countdown with a code, or by opening the file they sent.
- Pin a countdown to a Home Screen widget (small, medium, large) or a Lock Screen widget (circular, rectangular, inline).
- Start a Live Activity for the last 24 hours, or keep one on the Lock Screen until you turn it off.
- Get a local notification when the moment arrives. Nothing is sent through Apple Push Notification service.

The app asks for your name on first launch. That name is what the other person sees after they join.

## Requirements

- A Mac with Xcode 15 or later. Xcode 16 is a comfortable match for this project.
- An iPhone running iOS 17 or later. The app is iPhone only.
- A free Apple ID. You do not need the paid Apple Developer Program to install it from Xcode onto your own phone.

The iOS Simulator works too, if you only want to click around. Widgets, Live Activities, and a second phone are more convincing on a device.

## Install it on your iPhone with a free Apple ID

1. Install Xcode from the Mac App Store and open it once so it can finish installing the platform tools.
2. Plug in the iPhone, unlock it, and tap Trust if the phone asks about the computer.
3. In Xcode, open Settings → Accounts and sign in with your Apple ID. Xcode creates a Personal Team for you. That team is free.
4. Open `CountdownTogether.xcodeproj` (not just the folder).
5. In the toolbar, set the run destination to your iPhone.
6. Select the project in the navigator, then the **CountdownTogether** target, then Signing & Capabilities.
   - Turn on **Automatically manage signing**.
   - Set Team to your Personal Team.
   - Change the bundle identifier to something unique, for example `com.yourname.countdowntogether`. The sample id `com.countdowntogether.app` may already be registered to someone else, and signing will fail until yours is unique.
7. Select the **CountdownWidget** target and do the same. Use the same team. Set its bundle identifier to your app id plus `.widget`, for example `com.yourname.countdowntogether.widget`. The widget id has to start with the app id.
8. Do not add capabilities on either target. App Groups, iCloud, Push Notifications, and Associated Domains are not in the default build because a free account cannot sign them. Adding one makes the install fail.
9. Press Run. The first build takes a while.
10. If the phone says developer mode is off: on the iPhone open Settings → Privacy & Security → Developer Mode, turn it on, restart, and confirm the prompt. Then press Run again. iOS 16 and later require Developer Mode for apps installed from Xcode.
11. If the app icon is there but it will not open: on the iPhone open Settings → General → VPN & Device Management, find your Apple ID under Developer App, and tap Trust.

A free provisioning profile expires after 7 days. When the app stops opening, plug the phone back in and press Run again. You can only have a few apps installed this way at once, and there is no TestFlight or App Store distribution on a free account.

The same steps work for the Simulator. Skip Developer Mode and the trust dialog. For the sync server, the Simulator can use `http://127.0.0.1:8787`. A real iPhone cannot. `127.0.0.1` on the phone is the phone itself.

## What works on a free account

| Feature | Free Apple ID | Paid Developer Program |
| --- | --- | --- |
| The app, photos, themes, editing | Yes | Yes |
| Local notifications | Yes | Yes |
| Countdown file via Messages, AirDrop, or the share sheet | Yes | Yes |
| Live Activity started on the device | Yes | Yes |
| Widget extension installs | Yes | Yes |
| Widget shows your real countdowns | No, until the App Group is enabled | Yes |
| Invite codes between two phones | Yes, if you run the sync server | Yes, with the server or iCloud |
| iCloud / CloudKit sync | No | Yes, after you add the capability |
| Push-updated Live Activities | Not used by this app | Not used by this app |
| TestFlight and the App Store | No | Yes |

Live Activities do not need the App Group. The app hands the title and the target time to the system, and the Lock Screen draws a timer from that. Widgets are different: the extension is a separate process and can only read the countdown file if both targets share an App Group container. Without that, the widget installs and tells you to turn the App Group on.

## Sharing

Open Settings and choose one of three modes, then tap **Save sync settings**.

### This iPhone

This is the default. Countdowns stay on the phone. Invite codes are still created, but another phone cannot look them up until you turn on a server or iCloud.

You can still share. On a countdown, tap **Invite code**, then **Send a countdown file**. The other person opens that `.countdown` file on their phone (or uses **Open a countdown file** on the Join sheet). The file includes the photo. It is a copy, not a live link. Later edits do not travel unless you send a new file or turn on sync.

### Sync server

`tools/sync_server.py` is a small Python server with no accounts and no API keys. On a computer both phones can reach:

```bash
python3 tools/sync_server.py
```

It listens on port 8787 and stores rooms in `tools/.sync-data/`. Find the computer's LAN address in System Settings → Network, then in the app set the server URL to:

```text
http://192.168.1.20:8787
```

Use the address of the computer running the server, not `localhost`, when the app is on a phone. The app allows plain HTTP on the local network and asks for local network permission the first time it connects.

Create a countdown, tap Invite code, and read the code to the other person. They tap Join and enter it. Edits sync when either phone opens the app or pulls to refresh. If both people edit, the newer `updatedAt` wins. A stale write gets HTTP 409 and the app keeps the newer copy.

Optional token:

```bash
SYNC_TOKEN=something-secret PORT=8787 python3 tools/sync_server.py
```

Put the same token in the API key field. Leave the token unset on a trusted home network. Do not put this server on the public internet without a token. It is a development tool, not a hosted backend.

The HTTP API, if you want to replace the script with your own server or a Cloud Function:

| Method | Path | Body |
| --- | --- | --- |
| GET | `/health` | `{ "ok": true }` |
| GET | `/v1/rooms/{CODE}` | The saved payload, or 404 |
| PUT | `/v1/rooms/{CODE}` | JSON payload. 409 with the saved payload if the server copy is newer |
| DELETE | `/v1/rooms/{CODE}` | Empty 204 |

`CODE` is the uppercase invite code. The payload is:

```json
{
  "version": 1,
  "countdown": { "title": "Lisbon", "inviteCode": "WEEKAWAY", "updatedAt": "2026-06-01T18:00:00Z" },
  "photoBase64": null
}
```

Dates are ISO-8601. `photoBase64` is optional JPEG data. If `SYNC_TOKEN` is set, send `Authorization: Bearer <token>`.

A Firebase project fits behind this same API: a Cloud Function or a tiny worker that reads and writes the JSON. The app does not ship the Firebase SDK or a `GoogleService-Info.plist`, so there is nothing to configure until you want that.

### iCloud

CloudKit sync is implemented and turned off in the signature. It needs the paid Apple Developer Program because the iCloud entitlement will not sign with a Personal Team. When you have a paid account, follow [App Group and iCloud](#app-group-and-icloud) and then choose iCloud in Settings.

Records live in the public CloudKit database so the other person can fetch them with the code. The record type is `Countdown`. The record name is the invite code. Anyone who has the code can read that countdown, so treat the code like a link. The alphabet skips 0, O, 1, and I. Eight characters from the remaining 32 is a large space, but it is not a private database.

The container id in code is `iCloud.com.countdowntogether.app`. Change `CloudKitContainer.identifier` in `Shared/Support/AppGroup.swift` if you register a different container, and use the same id in the entitlements file.

Both people need to be signed into iCloud. The first save in Development creates the schema. Before anyone outside your developer account can use it, deploy the schema to Production in the CloudKit console.

## Widgets

After the app is installed, long-press the Home Screen, tap +, and search for Countdown Together. Lock Screen widgets are added from the Lock Screen customizer.

Edit the widget to choose which countdown it shows. If you don't pick one, it shows the next upcoming countdown, or the one you marked in Settings → Widget.

Until the App Group is enabled, every widget size says that it cannot see your countdowns. That is expected on a free account. The countdown inside the app is unaffected.

The widget text uses a system timer where it can, and the timeline refreshes on the hour, or every 15 minutes on the last day.

## Live Activity

On a countdown, under Lock Screen:

- **Final day** starts a Live Activity during the last 24 hours, and leaves it up for about an hour after. This is the default. Open the app at least once during that day so it can start. iOS does not keep running the app in the background to start it for you.
- **Keep on Lock Screen** starts it immediately and leaves it up.
- **Off** removes it.

The timer on the Lock Screen and in the Dynamic Island updates on its own. The app does not use push tokens or frequent push updates, which is why this works without a paid account.

If nothing appears, check that Live Activities are allowed for the app in iOS Settings, and that the phone is not in a Focus mode that hides them.

## App Group and iCloud

Skip this section on a free account. Adding these entitlements will make the free profile refuse to sign.

When you have a paid team:

1. In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources), register an App Group. The id in the sample entitlements is `group.com.countdowntogether.app`. If you change it, edit `AppGroup.identifier` in `Shared/Support/AppGroup.swift` to match.
2. For iCloud, register a CloudKit container, default `iCloud.com.countdowntogether.app`, and edit `CloudKitContainer.identifier` the same way.
3. On the **CountdownTogether** and **CountdownWidget** targets, set **Code Signing Entitlements**:
   - Widget: `Entitlements/AppGroup.entitlements`
   - App, widgets only: `Entitlements/AppGroup.entitlements`
   - App, widgets and iCloud: `Entitlements/AppGroupCloudKit.entitlements`
4. The App Group id inside the file has to be the same on both targets. The widget should not get the iCloud entitlement. Only the app talks to CloudKit.
5. Clean the build folder and run again on the phone. The note on the home screen goes away once the app can see the shared container, and the widget picks up the countdown file.

`Entitlements/AppGroup.entitlements` and `Entitlements/AppGroupCloudKit.entitlements` are already in the repo. They are not wired into the target, on purpose.

## TestFlight, later

TestFlight needs the paid Apple Developer Program. A free Apple ID cannot upload a build.

1. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs). Approval is not instant.
2. In Xcode, switch both targets from your Personal Team to the paid team. Keep the bundle ids you want to ship, and keep the widget id prefixed with the app id.
3. Turn on the App Group, and iCloud if you want it, using the steps above. Do that before you archive if widgets should show real countdowns for testers.
4. In App Store Connect, create an app record with the same bundle id. The name can be Countdown Together.
5. In Xcode, set the destination to Any iOS Device, then Product → Archive.
6. In the Organizer, Distribute App → App Store Connect → Upload.
7. Export compliance: the app sets `ITSAppUsesNonExemptEncryption` to false. It only uses the system HTTPS stack and local networking. You should be able to answer that it does not use non-exempt encryption.
8. When the build finishes processing, open TestFlight. Internal testers (App Store Connect users on your team) can install without beta review. External testers need a short beta review, a description of what to test, and usually a privacy policy URL.
9. TestFlight builds last 90 days, which is the practical reason to move off the 7-day free profile.

For the privacy nutrition labels, photos are optional and chosen by the person using the app. They stay on device unless a sync server or CloudKit is turned on. The app does not track anyone and does not use advertising identifiers. There is no account. If you enable the public CloudKit database, say that countdown content is stored in iCloud and can be read by someone who has the invite code.

The app stores its database in a JSON file rather than UserDefaults, so it does not trip the UserDefaults required-reason API. If App Store Connect later asks for a privacy manifest, you should not need a UserDefaults reason.

## Project layout

```text
CountdownTogether.xcodeproj   Open this in Xcode
project.yml                   XcodeGen manifest, if you want to regenerate
App/                          SwiftUI app
Shared/                       Models, storage, and Live Activity attributes
Widget/                       Home Screen, Lock Screen, and Live Activity UI
Entitlements/                 Optional paid-account entitlements, not linked
Tests/                        Unit tests for codes, date math, and the JSON file
tools/sync_server.py          Local sync server
tools/generate_xcodeproj.py   Rebuilds the Xcode project without XcodeGen
```

Shared Swift files are compiled into both the app and the widget. There is no extra framework target, so you are not signing a third bundle on a free account.

The on-disk database is `database.json` plus a `photos` folder. If the App Group entitlement is signed in, that folder is the shared container. Otherwise it is the app's Documents directory, which the widget cannot read.

## Regenerating the Xcode project

You do not have to. The project in the repo opens as-is.

If you add files and you have [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed:

```bash
brew install xcodegen
xcodegen generate
```

`project.yml` describes the same two targets, the test target, the iOS 17 deployment target, and no entitlements. Alternatively:

```bash
python3 tools/generate_xcodeproj.py
```

## Tests

On a Mac, with the project open: Product → Test, or Command-U. The tests cover invite codes, countdown math, and a save/load round trip of the JSON database. They need the iOS test host, so they run in Xcode rather than on Linux.

The sync server tests are plain Python:

```bash
python3 tools/test_dev_sync_server.py
```
