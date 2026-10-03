// Cross-platform image/document picking:
//   • Flutter Web  → dart:html file input (images + PDF)
//   • Android/iOS  → image_picker (images only for documents)
export 'file_data.dart';
export 'file_picker_stub.dart'
    if (dart.library.html) 'file_picker_web.dart'
    if (dart.library.io) 'file_picker_mobile.dart';
