import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The security model is a *shape* guarantee, not a promise.
///
/// The package cannot leak a payload it never receives, cannot phone home from a
/// package that has no network dependency, and cannot reach a platform channel
/// from a package that never imports the library that exposes them. This suite
/// proves all three by reading the source rather than trusting a comment.
///
/// `lib/main.dart` is excluded on purpose: it is the dev-only demo *host*, the
/// one place allowed to own a camera and read a decoded value. Nothing in
/// `lib/src/` or the barrel may ever join it there.
void main() {
  final List<File> core = <File>[
    File('lib/qr_scan_fx.dart'),
    ...Directory('lib/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart')),
  ];

  /// Strips `//` and `/* */` comments so a forbidden *word* in prose is not a
  /// false positive. Crude but sufficient: the package has no string literal
  /// containing `//` inside a code line that matters.
  String codeOf(File file) {
    final buffer = StringBuffer();
    var inBlock = false;
    for (final String line in file.readAsLinesSync()) {
      var text = line;
      if (inBlock) {
        final end = text.indexOf('*/');
        if (end == -1) continue;
        text = text.substring(end + 2);
        inBlock = false;
      }
      final block = text.indexOf('/*');
      if (block != -1 && text.indexOf('*/', block) == -1) {
        text = text.substring(0, block);
        inBlock = true;
      }
      final lineComment = text.indexOf('//');
      if (lineComment != -1) text = text.substring(0, lineComment);
      buffer.writeln(text);
    }
    return buffer.toString();
  }

  group('security model (enforced against the source)', () {
    test('the core imports no I/O, network or platform-channel library', () {
      const List<String> forbidden = <String>[
        'dart:io',
        'dart:isolate',
        'dart:ffi',
        'dart:html',
        'dart:js',
        'package:flutter/services.dart',
        'package:http/',
        'package:dio/',
        'package:url_launcher/',
        'package:webview_flutter/',
        'package:mobile_scanner/',
        'package:path_provider/',
        'package:shared_preferences/',
        'package:cloud_firestore/',
        'package:firebase_',
      ];

      for (final File file in core) {
        final String code = codeOf(file);
        for (final String needle in forbidden) {
          expect(
            code.contains(needle),
            isFalse,
            reason: '${file.path} must not reference "$needle"',
          );
        }
      }
    });

    test('the core never opens a platform channel or writes to a log', () {
      const List<String> forbidden = <String>[
        'MethodChannel',
        'EventChannel',
        'BasicMessageChannel',
        'BinaryMessenger',
        'HttpClient',
        'WebSocket',
        'Process.run',
        'Process.start',
        'debugPrint(',
        'developer.log',
        'File(',
        'Directory(',
      ];

      for (final File file in core) {
        final String code = codeOf(file);
        for (final String needle in forbidden) {
          expect(
            code.contains(needle),
            isFalse,
            reason: '${file.path} must not reference "$needle"',
          );
        }
        expect(
          RegExp(r'(?<![A-Za-z_])print\s*\(').hasMatch(code),
          isFalse,
          reason: '${file.path} must not call print()',
        );
      }
    });

    test('the core has no concept of QR content', () {
      // If the word never appears, no field, parameter or local can hold it.
      final RegExp content = RegExp(
        r'displayValue|rawValue|barcode|decodedText|decodeText|payloadText|'
        r'qrContent',
      );

      for (final File file in core) {
        expect(
          content.hasMatch(codeOf(file)),
          isFalse,
          reason: '${file.path} must not name decoded QR content',
        );
      }
    });

    test('the published package declares no runtime dependency at all', () {
      final List<String> lines = File('pubspec.yaml').readAsLinesSync();
      final int start = lines.indexWhere(
        (String line) => line.startsWith('dependencies:'),
      );
      expect(start, isNonNegative, reason: 'pubspec must declare dependencies');

      final List<String> runtime = <String>[];
      for (final String line in lines.skip(start + 1)) {
        // A new top-level key ends the runtime dependency block.
        if (line.isNotEmpty && !line.startsWith(' ')) {
          break;
        }
        final RegExpMatch? key =
            RegExp(r'^  ([a-zA-Z0-9_]+):').firstMatch(line);
        if (key != null) runtime.add(key.group(1)!);
      }

      expect(
        runtime,
        <String>['flutter'],
        reason: 'the only dependency may be the Flutter SDK itself',
      );
    });

    test('only the dev entrypoint is allowed near a camera', () {
      // Nothing importable from the barrel may pull in the camera plugin.
      final List<File> barrel = <File>[
        File('lib/qr_scan_fx.dart'),
        ...core.where((File file) => file.path != 'lib/main.dart'),
      ];
      for (final File file in barrel) {
        expect(
          file.readAsLinesSync().any(
                (String line) => line.contains('mobile_scanner'),
              ),
          isFalse,
          reason: '${file.path} must not reach the camera plugin',
        );
      }
    });
  });
}
