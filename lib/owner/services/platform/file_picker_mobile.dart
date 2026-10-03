import 'package:image_picker/image_picker.dart';

import 'file_data.dart';

Future<List<PickedFileData>> pickImages({bool multiple = true}) async {
  final picker = ImagePicker();
  final out = <PickedFileData>[];
  if (multiple) {
    final picked = await picker.pickMultiImage(imageQuality: 80);
    for (final xf in picked) {
      out.add(PickedFileData(await xf.readAsBytes(), xf.name));
    }
  } else {
    final xf = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xf != null) out.add(PickedFileData(await xf.readAsBytes(), xf.name));
  }
  return out;
}

// image_picker can't pick PDFs on mobile — documents are images for now.
Future<PickedFileData?> pickDocument() async {
  final picker = ImagePicker();
  final xf = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
  if (xf == null) return null;
  return PickedFileData(await xf.readAsBytes(), xf.name);
}
