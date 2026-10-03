import 'dart:typed_data';

/// A picked file's bytes + original filename, platform-agnostic.
class PickedFileData {
  final Uint8List bytes;
  final String name;
  const PickedFileData(this.bytes, this.name);
}
