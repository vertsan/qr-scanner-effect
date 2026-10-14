import 'scan_fx_idle_modifier.dart';

/// No ambient motion.
///
/// The calmest option, the fallback under reduce-motion, and the right choice
/// when the overlay sits over a busy camera feed or a screenshot for a store
/// listing.
class StillIdle extends ScanFxIdleModifier {
  /// Creates the modifier.
  const StillIdle();

  @override
  ScanFxIdleTransform transform(double ambientSeconds) =>
      ScanFxIdleTransform.none;
}
