# qr_scan_fx examples

Runnable examples for the [`qr_scan_fx`](../) overlay package.

```
lib/
  main.dart                  # a chooser for the two demos below
  banking_demo.dart          # a calm payment flow, camera-free and deterministic
  banking_camera_demo.dart   # the same flow with a real camera, torch + gallery
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

For the full narrative — the boundary, the confirmation slot, failure and retry,
and a security checklist — see
[`doc/payment-qr-guide.md`](../doc/payment-qr-guide.md).
