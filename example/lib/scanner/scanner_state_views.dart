// The two non-preview states the camera card can show: the camera is still
// starting, and the camera could not be started.
//
// Both are full-bleed and opaque, so they read cleanly with no overlay painted
// over them.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme.dart';
import 'scanner_style.dart';

/// Shown while the camera is being initialised.
class ScannerLoadingState extends StatelessWidget {
  /// Creates the loading view.
  const ScannerLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ScannerMessage(
      icon: Icons.qr_code_scanner,
      title: 'Starting camera',
      message: 'This can take a moment on the first run.',
      busy: true,
    );
  }
}

/// Shown when the camera could not be started — most often because camera
/// permission was refused.
class ScannerErrorState extends StatelessWidget {
  /// Creates an error view for [error].
  const ScannerErrorState({super.key, required this.error, this.onRetry});

  /// The failure reported by the camera plugin.
  final MobileScannerException error;

  /// Called when the retry button is tapped.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final bool denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final String? detail = error.errorDetails?.message;

    return _ScannerMessage(
      icon: denied ? Icons.no_photography : Icons.videocam_off_outlined,
      title: denied ? 'Camera access needed' : 'Camera unavailable',
      message: denied
          ? 'Allow camera access to scan a code, or upload one from your '
              'gallery instead.'
          : (detail == null || detail.isEmpty
              ? 'The camera could not be started. Try again, or upload a code '
                  'from your gallery instead.'
              : 'The camera could not be started. $detail'),
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

/// The shared layout for the loading and error views.
class _ScannerMessage extends StatelessWidget {
  const _ScannerMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final String? label = actionLabel;
    final VoidCallback? action = onAction;

    return ColoredBox(
      color: ScannerStyle.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: ScannerStyle.pill,
                  shape: BoxShape.circle,
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: ScannerStyle.onPill,
                        ),
                      )
                    : Icon(icon, color: ScannerStyle.onPill, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ),
              if (label != null && action != null) ...<Widget>[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: action,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(label),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    minimumSize: const Size(120, 48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
