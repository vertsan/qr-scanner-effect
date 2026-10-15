// The example's entrypoint: pick a demo.
//
// * Banking (no camera) — drives the overlay with scripted detections. Runs on
//   any device, desktop or the web, with no camera permission.
// * Banking (camera)    — the real integration: camera, torch, gallery, history.
// * Style Studio        — every frame, corner, beam, lock-on and effect, live.
// * Recent scans        — the receipts the banking demos saved on this device.
//
// All copy is English.

import 'package:flutter/material.dart';

import 'banking_camera_demo.dart';
import 'banking_demo.dart';
import 'payment/recent_scans_page.dart';
import 'style_studio.dart';
import 'theme.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  /// Creates the example chooser.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'qr_scan_fx examples',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data(),
      home: const _Chooser(),
    );
  }
}

class _Chooser extends StatelessWidget {
  const _Chooser();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: <Widget>[
            const _Header(),
            const SizedBox(height: 24),
            _DemoCard(
              title: 'Banking mode',
              subtitle: 'Scripted flow · no camera needed',
              icon: Icons.qr_code_2,
              builder: (BuildContext context) => const BankingDemoPage(),
            ),
            _DemoCard(
              title: 'Banking mode with a camera',
              subtitle: 'Real camera · torch, gallery and history',
              icon: Icons.photo_camera_outlined,
              builder: (BuildContext context) => const BankingCameraPage(),
            ),
            _DemoCard(
              title: 'Style Studio',
              subtitle: 'Every frame, corner, beam and effect · live',
              icon: Icons.auto_awesome_outlined,
              builder: (BuildContext context) => const StyleStudioPage(),
            ),
            _DemoCard(
              title: 'Recent scans',
              subtitle: 'Receipts saved on this device',
              icon: Icons.history,
              builder: (BuildContext context) => const RecentScansPage(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.accentContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.qr_code_scanner,
            color: AppTheme.onAccentContainer,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'qr_scan_fx',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A calm QR-scanner overlay. The package draws pixels; the host '
          'decodes. These demos wire it to a camera, a payment flow and a live '
          'style editor.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: builder),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.outline.withValues(alpha: 0.7),
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.onAccentContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
