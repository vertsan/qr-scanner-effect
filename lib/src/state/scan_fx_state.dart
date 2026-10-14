/// The lifecycle states of a [QrScanFx] overlay.
///
/// The overlay moves through these states as detection events arrive from the
/// host application's camera or decoding source. The package never derives a
/// state from QR *content* — only from geometry and explicit calls.
enum ScanFxState {
  /// No scan session has started. Ambient motion is idle and no scan area is
  /// emphasised.
  idle,

  /// A scan session is active and no target is currently tracked. The overlay
  /// shows the default scan area with an active beam.
  scanning,

  /// A target has been located and the focus animation is running. With
  /// `autoLock` enabled this state is transient (see `ScanFxStateMachine`).
  detected,

  /// The focus animation has settled on a target. This is the steady "target
  /// acquired" state that succeeds, errors, or is invalidated.
  locked,

  /// A successful read. In banking mode this carries the neutral meaning
  /// "code scanned" and never implies a completed payment.
  success,

  /// A read failed (unreadable, network, verification). Rendered as a fault.
  error,

  /// The code was read but is not acceptable to the host (for example an
  /// unsupported QR schema). Distinct from [error] so hosts can show retry copy.
  invalid;

  /// Whether this state is final until the host calls `reset` or locks a new
  /// target.
  bool get isTerminal =>
      this == ScanFxState.success ||
      this == ScanFxState.error ||
      this == ScanFxState.invalid;

  /// Whether a target quad is being tracked or held in this state.
  bool get hasTarget =>
      this == ScanFxState.detected || this == ScanFxState.locked || isTerminal;

  /// Whether the scan beam should be drawn in this state.
  bool get showsBeam =>
      this == ScanFxState.idle ||
      this == ScanFxState.scanning ||
      this == ScanFxState.detected;

  /// Whether the host-facing hint belongs on screen in this state.
  ///
  /// The hint is a prompt to *find* a code, so it disappears the moment one is
  /// detected and never competes with a result.
  bool get showsHint =>
      this == ScanFxState.idle || this == ScanFxState.scanning;
}
