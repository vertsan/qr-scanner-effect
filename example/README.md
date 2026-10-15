# qr_scan_fx examples

Runnable examples for the [`qr_scan_fx`](../) overlay package.

```
lib/
  main.dart                  # a chooser for the three demos below
  banking_demo.dart          # a calm payment flow, camera-free and deterministic
  banking_camera_demo.dart   # the same flow with a real camera, torch + gallery
  style_studio.dart          # every style, live
  payment/                   # the host-side payment flow (see below)
```

## Running

```bash
flutter pub get
flutter run
```

If `flutter run` reports that no platform is configured, scaffold one for your
target first — for example `flutter create --platforms=android .` from this
directory — then run again. The camera-free demo needs no permission and also
runs on desktop and the web.

## banking_demo — no camera

Drives a real `QrScanFxController` with scripted detections, so it needs no
device and no permission:

- **Scan a code** — `idle → detected → locked → success`, with the confirmation
  seat appearing.
- **Reject** — moves to `invalid` and shows the default `ScanFxStatusNotice` with
  its retry button.
- **Reset** — clears the state and resumes scanning.
- **Intensity / Speed** — live tunables; drag them mid-animation and the effect
  re-scales without resetting.

## banking_camera_demo — the real thing

The integration a payment app actually ships, on top of `QrScanFx.banking()`:

- the camera is the **host's** (`mobile_scanner`); the overlay receives geometry
  only, never the decoded value;
- **torch is on by default**, and its icon tracks the plugin's own torch state;
- **gallery** picks an image with `image_picker`, hands it to
  `MobileScannerController.analyzeImage`, and feeds the resulting corners into the
  overlay the same way a live detection would;
- the **confirmation seat** is where the app states its own outcome — it never
  says "paid", because the overlay cannot know that.

On iOS, add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to
`Info.plist`. Android merges the camera permission in from the plugin.

## The payment flow — `lib/payment/`

After a scan is accepted, both banking demos hand off to a real host-side payment
flow. None of it touches the overlay: `qr_scan_fx` finished the moment it drew
the success state, and the app owns everything after that.

```
banking_camera_demo ─┐
                     ├─▶ PaymentConfirmationPage ─▶ (biometric gate) ─▶ ReceiptPage
banking_demo ────────┘                                                            │
                                                                                  ▼
                                                       ReceiptStore (last 20) ─▶ RecentScansPage
```

- **`khqr.dart`** — a small EMVCo/KHQR parser. It reads the merchant name (tag
  59), currency (tag 53) and amount (tag 54) from a code, and returns `null` for
  anything that is not EMVCo — a URL, a vCard. It also holds the fixed demo
  rate (1 USD = 4,100 KHR) and the money formatting.
- **`payment_confirmation_page.dart`** — the amount (pre-filled and editable when
  the code carried one, entered by the payer when it did not), a USD/KHR toggle
  with a live `≈` conversion, and a source-account picker.
- **`biometric_gate.dart`** — `local_auth` for the device prompt, with a demo-PIN
  fallback so the flow still runs on a desktop, the web or an unconfigured
  emulator.
- **`receipt_page.dart`** — transaction id, timestamp, both currencies, and
  Share / Save buttons.
- **`receipt_saver.dart`** — writes the receipt to the app documents directory
  via `path_provider`; on the web it declines and the UI offers Share instead.
- **`receipt_store.dart`** — keeps the last 20 receipts in `shared_preferences`
  so the history survives a restart. `recent_scans_page.dart` lists them, and
  each row reopens its receipt.

### Trying it

- **Camera-free:** tap **Scan a code**, wait for the success state, then
  **Continue to payment**. Enter an amount and confirm.
- **Camera:** point at a KHQR code. The flow opens on its own once the code is
  accepted. A non-KHQR code still opens the flow, as an unverified merchant.
- **Recent scans:** tap the **Recent** button in either banking demo, the history
  icon in the camera demo, or the **Recent scans** tile in the chooser. Confirm a
  payment and it appears there, newest first.
- **The parser** has unit tests: `flutter test`.

### Platform notes

The biometric prompt and file saving are native, so they need a real platform:

- **Android:** the activity must be a `FlutterFragmentActivity`, and the app
  needs `USE_BIOMETRIC`. Scaffold the project, then in
  `android/app/src/main/kotlin/.../MainActivity.kt` change the superclass from
  `FlutterActivity` to `FlutterFragmentActivity`. `local_auth` documents the rest.
- **iOS:** add `NSFaceIDUsageDescription` to `Info.plist`.
- The **demo-PIN fallback** means the flow still demonstrates end to end without
  any of that — which is also why the camera-free demo works on desktop and web.


## style_studio — the whole vocabulary, live

A playground for every layer. The scene is painted and the detection is
scripted, so it needs no camera and no permission.

- Pick any **frame shape, corner, beam, backdrop, lock-on, success, fault and
  idle** style from chip rows — all 60 of them, across 8 families.
- Start from a **recipe** (`cyberpunk`, `appleVision`, `minimalBank`,
  `retroLaser`, `playfulPop`) or a named theme, then change anything.
- Drive the **lifecycle** by hand — lock on, succeed, reject, error, reset — or
  leave the live loop running.
- Drag **intensity, speed, glow and radius** mid-animation: nothing resets.
- **Read the theme back** at the bottom of the panel to see exactly what the
  overlay is rendering.

```bash
flutter run -t lib/style_studio.dart
```

For the full narrative — the boundary, the confirmation slot, failure and retry,
and a security checklist — see
[`doc/payment-qr-guide.md`](../doc/payment-qr-guide.md).
