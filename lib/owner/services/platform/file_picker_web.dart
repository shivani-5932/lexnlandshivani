import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'file_data.dart';

Future<List<PickedFileData>> pickImages({bool multiple = true}) async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = multiple;
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return [];
  final out = <PickedFileData>[];
  for (final file in files) {
    final bytes = await _readBytes(file);
    if (bytes != null) out.add(PickedFileData(bytes, file.name));
  }
  return out;
}

Future<PickedFileData?> pickDocument() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*,application/pdf'
    ..multiple = false;
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final file = files.first;
  final bytes = await _readBytes(file);
  if (bytes == null) return null;
  return PickedFileData(bytes, file.name);
}

Future<Uint8List?> _readBytes(html.File file) async {
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;
  final result = reader.result;
  if (result is ByteBuffer) return result.asUint8List();
  if (result is Uint8List) return result;
  if (result is List<int>) return Uint8List.fromList(result);
  return null;
}
