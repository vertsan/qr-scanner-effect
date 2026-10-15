// The IO implementation of the receipt saver. Selected by the conditional
// import in `receipt_saver.dart` on every platform with `dart:io`.

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes [contents] to `<documents>/<fileName>` and returns the full path.
Future<String?> saveReceiptFile({
  required String fileName,
  required String contents,
}) async {
  final Directory dir = await getApplicationDocumentsDirectory();
  final File file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(contents);
  return file.path;
}
