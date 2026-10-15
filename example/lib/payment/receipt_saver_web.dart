// The web implementation of the receipt saver. The web has no writable
// filesystem for a Flutter app, so saving is declined and the caller falls back
// to Share.

/// Always returns `null`: saving to a file is not supported on the web.
Future<String?> saveReceiptFile({
  required String fileName,
  required String contents,
}) async =>
    null;
