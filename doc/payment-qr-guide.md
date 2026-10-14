# Using `qr_scan_fx` with payment QR codes

This guide is for teams shipping a payment or fintech scanner. It covers what the
package does, what it deliberately refuses to do, and how to wire the two together
so that neither the security model nor the calm UX is an afterthought.

---

## The one rule

> **The host decodes. The package receives geometry and returns pixels.**

Everything below follows from that sentence. `qr_scan_fx` never sees the payload,
so it cannot leak it, log it, transmit it, or act on it. Your app is the only
place that knows what the code *says*, and therefore the only place that can decide
what it *means*.

---

## Who does what

| Concern | Owner | Why |
|---|---|---|
| Camera, torch, gallery | **host** (e.g. `mobile_scanner`) | the package owns no camera and no platform channel |
| Detecting and decoding | **host** | decoding means reading content, which the package refuses to do |
| Turning content into meaning | **host** (your backend) | only you can validate a merchant, a signature, an amount |
| Drawing the focus effect | **qr_scan_fx** | geometry in, pixels out |
| Announcing the state to a screen reader | **qr_scan_fx** | the overlay knows which state it is in |
| Saying "paid" | **host**, and only the host | the package does not know, so it must not imply |

---

## The recommended flow

1. **Detect.** Your camera plugin reports a code and its corners.
2. **Acquire.** Hand the overlay *geometry only* and let it animate the lock:

   ```dart
   controller.lockOn(
     ScanFxTarget.corners(
       barcode.corners!,            // List<Offset>
       normalized: true,            // plugin coordinates are 0..1
       quarterTurns: rotation,      // if the sensor is mounted sideways
     ),
   );
   ```

   `detected → locked` advances on its own after a short hold. You do not drive
   it; the hold is what makes the lock read as *focus* rather than *snap*.

3. **Decode.** Read `barcode.displayValue` **in your app**. Do not pass it to any
   `qr_scan_fx` API — there is not one that accepts it.
4. **Validate.** Send it to your backend. Validate the merchant, the amount, the
   signature, the expiry. Do this off the UI thread; the overlay keeps drawing.
5. **Confirm or reject.**

   ```dart
   // Accepted — the *code* was scanned. Your confirmation slot states the outcome.
   controller.success();

   // Rejected — say why, in the host's words, and offer a retry.
   controller.invalid('This merchant code is not supported');
   ```

6. **Reset** when the user is done, or after a timeout:

   ```dart
   controller.reset();
   ```

`pause()` / `resume()` are for backgrounding; they mute the ticker so a screen the
user cannot see costs nothing.

---

## What `success` means — and what it must not

`controller.success()` means **a code was scanned**. It does not mean a payment
succeeded, was authorised, or was even attempted. The package has no idea, and
nothing it renders will ever suggest otherwise.

Use the `confirmationBuilder` seat to state *your* outcome, in *your* words:

```dart
QrScanFx.banking(
  controller: controller,
  onRetry: () => controller.reset(),
  confirmationBuilder: (context) => switch (state) {
    _Result.authorised => const Text('Payment authorised'),
    _Result.declined   => const Text('Payment declined'),
    _Result.pending    => const Text('Awaiting confirmation…'),
  },
)
```

The builder is invoked with only a `BuildContext`. No payload, no amount, no
outcome is threaded through the package — those are yours to hold.

**Do not** put the decoded string into the confirmation, the invalid message, or
any hint text. `messageBuilder` copy is for humans ("This code is not supported"),
not for the code itself. A payload echoed into the UI ends up in screenshots,
crash reports and accessibility trees.

---

## Showing an amount

The package cannot display an amount, and that is a feature: an amount it never
received cannot be mis-rendered, mis-localised, or spoofed by a crafted code.
Render the amount in your own confirmation UI, from the value *your backend*
validated — never from the raw payload text.

If you want the overlay to visually agree with that UI, tune the palette so the
confirmation sits on the same surface:

```dart
QrScanFx.banking(
  controller: controller,
  theme: QrScanFxTheme.bankingBlue.copyWith(
    successColor: yourBrandGreen,     // keep 4.5:1 against the backdrop
  ),
)
```

If you change the colours, keep the calm *styles* from `bankingBlue` — that is
what makes the mode predictable. `ScanFxPalette.contrastRatio` is exported so you
can check any pair you introduce.

---

## Failure: `invalid` vs `error`

| State | Means | Typical trigger |
|---|---|---|
| `invalid` | the code is well-formed but *rejected* — a business outcome | unsupported merchant, expired, below minimum |
| `error` | the read *failed* — a technical outcome | blurred frame, unsupported symbology, timeout |

Both share the `messageBuilder` seat. In banking mode the default is a
`ScanFxStatusNotice`, which renders `controller.message` and, when `onRetry` is
set, a "Try again" button:

```dart
QrScanFx.banking(
  controller: controller,
  onRetry: () {
    controller.reset();
    restartScanner();
  },
)
```

Prefer `invalid` for anything the user can act on, and `error` for anything they
cannot. Never shake, never flash red-on-white, never spend more than 400 ms on a
failure — banking mode enforces the timing for you, but the *tone* is your copy.

---

## A complete example

```dart
class PaymentScanner extends StatefulWidget {
  const PaymentScanner({super.key, required this.onAuthorised});
  final void Function(String payload) onAuthorised;

  @override
  State<PaymentScanner> createState() => _PaymentScannerState();
}

class _PaymentScannerState extends State<PaymentScanner> {
  final _controller = QrScanFxController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.firstOrNull;
    if (code?.corners == null || _busy) return;

    _controller.lockOn(
      ScanFxTarget.corners(code!.corners!, normalized: true),
    );

    _busy = true; // one in-flight validation at a time
    final payload = code.displayValue;   // stays inside *this* app
    try {
      final result = await api.validate(payload);
      if (!mounted) return;
      if (result.ok) {
        _controller.success();
        widget.onAuthorised(payload);   // the host decides what happens next
      } else {
        _controller.invalid(result.reason);
      }
    } on TimeoutException {
      if (mounted) _controller.error('Could not reach the payment service');
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(onDetect: _onDetect),   // your camera, your decoding
        QrScanFx.banking(
          controller: _controller,
          onRetry: _controller.reset,
          confirmationBuilder: (context) => const Padding(
            padding: EdgeInsets.only(bottom: 96),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text('Code captured'),
            ),
          ),
          controlsBuilder: (context) => Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => torch.value = !torch.value,
                    icon: const Icon(Icons.flashlight_on),
                  ),
                  IconButton(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

`onAuthorised(payload)` is the hand-off point: the overlay's job ended at
`success()`, and everything from there is the host's.

---

## Security checklist

- [ ] The payload never enters a `qr_scan_fx` call. It cannot — but make sure it
      does not leak into `confirmationBuilder` or `messageBuilder` copy either.
- [ ] Validation happens on your backend, not on the client from the raw text.
- [ ] Nothing logs `displayValue`. (The package does not, but your host might.)
- [ ] The amount shown to the user comes from your validated result, not the code.
- [ ] `success()` is called only after *your* validation has accepted the code.
- [ ] `pause()` is called when the scanner is backgrounded.
- [ ] You have run `flutter test` — `test/scan_fx_security_test.dart` fails if the
      package ever grows an I/O import, a platform channel or a payload concept.

---

## What the package guarantees you

- **It cannot leak what it never receives.** Enforced against the source, not
  promised: see `test/scan_fx_security_test.dart` and `doc/architecture.md` §11.
- **One runtime dependency, the Flutter SDK.** No networking, no persistence, no
  analytics, no platform channel.
- **A calm, predictable failure.** Durations under 400 ms, no shake, no red-on-white,
  read-and-retry.
- **Text the user can actually read.** 4.5:1 contrast and 2.0 text scale are
  measured in CI, not assumed.

---

## FAQ

**Can the package tell me whether the payment succeeded?**
No. It only knows a code was scanned. If you need the answer, you already have it
— you called `success()` or `invalid()` based on your own result.

**Can I show the amount inside the overlay?**
Put it in `confirmationBuilder`. The package will not receive or render a number.

**Does `success()` trigger anything?**
Only the overlay's own animation and the semantics announcement. No payment, no
network call, no callback beyond `onStateChanged`. It has no API that could.

**What if my detector fires thirty times a second?**
`lockOn` while already tracking refreshes the geometry without restarting the
hold, so the lock-on still completes. Filter in the host if you want to ignore
repeat detections entirely.

**Which state should a blurry frame be?**
`error` — a failed read, not a rejected code. Reserve `invalid` for business
outcomes.
