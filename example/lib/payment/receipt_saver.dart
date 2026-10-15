// Saves a receipt as a text file, where the platform allows it.
//
// The real implementation lives in `receipt_saver_io.dart`; on the web there is
// no writable filesystem, so `receipt_saver_web.dart` declines. The conditional
// import keeps `dart:io` out of a web build entirely.

import 'receipt_saver_io.dart'
    if (dart.library.js_interop) 'receipt_saver_web.dart' as impl;

/// Saves [contents] as [fileName] in the app's documents directory.
///
/// Returns the saved path, or `null` when the platform cannot save files (the
/// web). Callers should offer Share as the fallback.
Future<String?> saveReceiptFile({
  required String fileName,
  required String contents,
}) =>
    impl.saveReceiptFile(fileName: fileName, contents: contents);
