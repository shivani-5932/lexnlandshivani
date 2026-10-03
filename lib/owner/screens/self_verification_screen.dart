import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class SelfVerificationScreen extends StatefulWidget {
  const SelfVerificationScreen({super.key});
  @override
  State<SelfVerificationScreen> createState() => _SelfVerificationScreenState();
}

class _SelfVerificationScreenState extends State<SelfVerificationScreen> {
  Uint8List? _frontBytes;
  String?    _frontName;
  Uint8List? _backBytes;
  String?    _backName;

  bool _uploading = false;
  bool _done      = false;

  // ── Pick image (web + mobile) ─────────────────────────────────
  Future<void> _pick(String side) async {
    if (kIsWeb) {
      final completer = Completer<html.File?>();

      final input = html.FileUploadInputElement()
        ..accept = 'image/*,application/pdf'
        ..multiple = false
        ..style.display = 'none';

      input.addEventListener('change', (event) {
        final files = input.files;
        completer.complete(
            files != null && files.isNotEmpty ? files.first : null);
      });

      html.window.addEventListener('focus', (event) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!completer.isCompleted) completer.complete(null);
        });
      });

      html.document.body!.children.add(input);
      input.click();

      final file = await completer.future;
      input.remove();
      if (file == null) return;

      final readerCompleter = Completer<void>();
      final reader = html.FileReader();
      reader.addEventListener('load', (e) {
        if (!readerCompleter.isCompleted) readerCompleter.complete();
      });
      reader.readAsArrayBuffer(file);
      await readerCompleter.future;

      final bytes = Uint8List.view(reader.result as ByteBuffer);
      if (mounted) {
        setState(() {
          if (side == 'front') {
            _frontBytes = bytes;
            _frontName  = file.name;
          } else {
            _backBytes = bytes;
            _backName  = file.name;
          }
        });
      }
    }
    // Mobile: add image_picker support if needed
  }

  // ── Upload both sides ─────────────────────────────────────────
  Future<void> _upload() async {
    if (_frontBytes == null || _backBytes == null) {
      _snack('Please upload both front and back of your Aadhaar card');
      return;
    }
    setState(() => _uploading = true);
    try {
      await ApiService.uploadAadhaar(
        frontBytes: _frontBytes!,
        frontName:  _frontName ?? 'aadhaar_front.jpg',
        backBytes:  _backBytes!,
        backName:   _backName  ?? 'aadhaar_back.jpg',
      );
      if (mounted) setState(() { _uploading = false; _done = true; });
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        title: const Text('ID Verification',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.textDark)),
      ),
      body: _done ? _SuccessView() : _FormView(
        frontBytes:  _frontBytes,
        frontName:   _frontName,
        backBytes:   _backBytes,
        backName:    _backName,
        uploading:   _uploading,
        onPickFront: () => _pick('front'),
        onPickBack:  () => _pick('back'),
        onUpload:    _upload,
      ),
    );
  }
}

// ── Form ───────────────────────────────────────────────────────
class _FormView extends StatelessWidget {
  final Uint8List? frontBytes;
  final String?    frontName;
  final Uint8List? backBytes;
  final String?    backName;
  final bool       uploading;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback onUpload;

  const _FormView({
    required this.frontBytes,
    required this.frontName,
    required this.backBytes,
    required this.backName,
    required this.uploading,
    required this.onPickFront,
    required this.onPickBack,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded,
                color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Upload a clear photo of your Aadhaar card.\n'
              'Both front and back sides are required.',
              style: TextStyle(fontSize: 13, color: AppColors.primary, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 24),

        // Front
        const Text('Front Side',
            style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 10),
        _DocCard(
          label:    'Front of Aadhaar',
          bytes:    frontBytes,
          fileName: frontName,
          onPick:   onPickFront,
        ),
        const SizedBox(height: 16),

        // Back
        const Text('Back Side',
            style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 10),
        _DocCard(
          label:    'Back of Aadhaar',
          bytes:    backBytes,
          fileName: backName,
          onPick:   onPickBack,
        ),
        const SizedBox(height: 32),

        // Submit
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: uploading ? null : onUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: uploading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Submit for Verification',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ── Document upload card ───────────────────────────────────────
class _DocCard extends StatelessWidget {
  final String    label;
  final Uint8List? bytes;
  final String?   fileName;
  final VoidCallback onPick;

  const _DocCard({
    required this.label,
    required this.bytes,
    required this.fileName,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final picked = bytes != null;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: picked
              ? AppColors.successBg
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: picked
                ? AppColors.success.withValues(alpha: 0.5)
                : AppColors.border,
            width: picked ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: picked
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              picked
                  ? Icons.check_circle_rounded
                  : Icons.upload_file_rounded,
              color: picked ? AppColors.success : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 3),
              Text(
                picked
                    ? (fileName ?? 'File selected')
                    : 'Tap to upload — JPG, PNG or PDF',
                style: TextStyle(
                  fontSize: 12,
                  color: picked
                      ? AppColors.success
                      : AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )),
          if (!picked)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Upload',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}

// ── Success view ───────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.successBg,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                    width: 2),
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: AppColors.success, size: 52),
            ),
            const SizedBox(height: 24),
            const Text('Uploaded Successfully!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
            const SizedBox(height: 10),
            const Text(
              'Your Aadhaar card has been submitted for verification.\n'
              'We will update your status shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
