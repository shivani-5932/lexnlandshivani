import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';
import 'self_verification_screen.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String? propertyId;
  const DocumentUploadScreen({super.key, this.propertyId});
  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  Uint8List? _registryBytes;
  String? _registryName;
  Uint8List? _nocBytes;
  String? _nocName;
  bool _uploading = false;

  Future<void> _pick(String docType) async {
    Uint8List? bytes;
    String? name;
    if (kIsWeb) {
      final input = html.FileUploadInputElement()
        ..accept = 'image/jpeg,image/png,image/webp,application/pdf'
        ..multiple = false;
      input.click();
      await input.onChange.first;
      if (input.files == null || input.files!.isEmpty) return;
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      bytes = (reader.result as html.ByteBuffer).asUint8List();
      name = file.name;
    } else {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;
      bytes = await picked.readAsBytes();
      name = picked.name;
    }
    setState(() {
      if (docType == 'registry') {
        _registryBytes = bytes;
        _registryName = name;
      } else {
        _nocBytes = bytes;
        _nocName = name;
      }
    });
    _snack('$docType selected: $name', isError: false);
  }

  Future<void> _submit() async {
    if (widget.propertyId == null) {
      _snack('Property ID missing', isError: true);
      return;
    }
    if (_registryBytes == null && _nocBytes == null) {
      _snack('Please upload at least one document', isError: true);
      return;
    }
    setState(() => _uploading = true);
    try {
      await ApiService.uploadDocuments(
        propertyId: widget.propertyId!,
        registryBytes: _registryBytes,
        registryFileName: _registryName,
        nocBytes: _nocBytes,
        nocFileName: _nocName,
      );
      _snack('✅ Documents uploaded!', isError: false);
      if (mounted)
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SelfVerificationScreen()));
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String msg, {required bool isError}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
            child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
              ),
              const Text('Property Documents',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ]),
          ),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary)),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('Upload Property Documents For Verification',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary))),
                ]),
              ),
              const SizedBox(height: 28),
              const FieldLabel('Upload Registry Documents'),
              const SizedBox(height: 8),
              _DocUploadBox(
                label: _registryName != null
                    ? '✓ $_registryName'
                    : 'Tap to Upload Registry',
                uploaded: _registryBytes != null,
                onTap: () => _pick('registry'),
              ),
              const SizedBox(height: 24),
              const FieldLabel('Upload NOC Documents'),
              const SizedBox(height: 8),
              _DocUploadBox(
                label: _nocName != null ? '✓ $_nocName' : 'Tap to Upload NOC',
                uploaded: _nocBytes != null,
                onTap: () => _pick('noc'),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBDD6F5)),
                ),
                child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tips for uploading',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1565C0))),
                      SizedBox(height: 6),
                      Text(
                          '• Use clear, well-lit photos\n• Ensure all text is readable\n• File size must be under 5MB\n• Supported: JPG, PNG, PDF',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1565C0),
                              height: 1.6)),
                    ]),
              ),
              const SizedBox(height: 20),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: PrimaryButton(
              label: 'Submit & Continue',
              isLoading: _uploading,
              onPressed: _submit,
            ),
          ),
        ])),
      );
}

class _DocUploadBox extends StatelessWidget {
  final String label;
  final bool uploaded;
  final VoidCallback onTap;
  const _DocUploadBox(
      {required this.label, required this.uploaded, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: uploaded ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: uploaded ? AppColors.primary : AppColors.border,
              width: uploaded ? 1.5 : 1,
              style: uploaded ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: Column(children: [
            Icon(
                uploaded
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                size: 36,
                color: uploaded ? AppColors.primary : AppColors.textLight),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: uploaded ? AppColors.primary : AppColors.textMuted)),
            if (!uploaded) ...[
              const SizedBox(height: 4),
              const Text('JPG, PNG, PDF — max 5MB',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight)),
            ],
          ]),
        ),
      );
}
