// The example's entrypoint: pick a demo.
//
// * Banking (no camera) — drives the overlay with scripted detections. Runs on
//   any device, desktop or the web, with no camera permission.
// * Banking (camera)    — the real integration: camera, torch and gallery.

import 'package:flutter/material.dart';

import 'banking_camera_demo.dart';
import 'banking_demo.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  /// Creates the example chooser.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'qr_scan_fx examples',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const _Chooser(),
    );
  }
}

class _Chooser extends StatelessWidget {
  const _Chooser();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('qr_scan_fx examples')),
      body: ListView(
        children: <Widget>[
          _DemoTile(
            title: 'Banking mode',
            subtitle: 'Scripted flow · no camera needed',
            icon: Icons.qr_code_2,
            builder: (BuildContext context) => const BankingDemoPage(),
          ),
          _DemoTile(
            title: 'Banking mode with a camera',
            subtitle: 'Real camera · torch and gallery',
            icon: Icons.photo_camera_outlined,
            builder: (BuildContext context) => const BankingCameraPage(),
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
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
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: builder),
      ),
    );
  }
}
