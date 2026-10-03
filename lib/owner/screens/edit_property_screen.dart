import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/platform/file_picker_helper.dart';

/// Edit screen for PG, Guest Room, and Plot properties.
///
/// Photo & Document lock rules:
///  ──────────────────────────────────────────────────────────
///  Status = SUSPENDED or REJECTED  → Everything UNLOCKED.
///    Owner MUST update photos/docs and save to trigger
///    an admin re-review notification.
///
///  Status = anything else (under_review, active, etc.)
///    Photos    → locked once uploaded
///    Documents → locked once uploaded
///  ──────────────────────────────────────────────────────────
class EditPropertyScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  const EditPropertyScreen({super.key, required this.property});
  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  late final String _type;
  late final String _id;
  late final String _status;
  bool _saving = false;

  // Existing media
  late List<String> _existingPhotos;
  late bool _hasRegistry;
  late bool _hasNoc;

  // New uploads
  final List<Uint8List> _newPhotoBytes = [];
  final List<String> _newPhotoNames = [];
  Uint8List? _newRegistryBytes;
  String? _newRegistryName;
  Uint8List? _newNocBytes;
  String? _newNocName;
  late bool _hasIdFront;
  late bool _hasIdBack;
  Uint8List? _newIdFrontBytes;
  String? _newIdFrontName;
  Uint8List? _newIdBackBytes;
  String? _newIdBackName;
  // ignore: unused_field
  bool _replacePhotos = false;

  // Common fields
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _mapCtrl = TextEditingController();

  // Plot fields
  final _plotIdCtrl = TextEditingController();
  final _plotSizeCtrl = TextEditingController();
  final _plotLengthCtrl = TextEditingController();
  final _plotWidthCtrl = TextEditingController();
  final _totalPriceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _plotType, _facing, _ownershipType;
  final List<String> _facilities = [];

  // PG fields
  final _totalRoomsCtrl = TextEditingController();
  final _acRoomsCtrl = TextEditingController();
  final _nonAcCtrl = TextEditingController();
  final _singlePriceCtrl = TextEditingController();
  final _singleDepCtrl = TextEditingController();
  final _doublePriceCtrl = TextEditingController();
  final _doubleDepCtrl = TextEditingController();
  String _occupancy = 'any', _roomType = 'sharing';
  bool _commonKitchen = false, _privateKitchen = false;
  final List<String> _pgAvailFor = [];

  // Guest fields
  final _gSinglePriceCtrl = TextEditingController();
  final _gSingleDepCtrl = TextEditingController();
  final _gDoublePriceCtrl = TextEditingController();
  final _gDoubleDepCtrl = TextEditingController();
  final _gFamilyPriceCtrl = TextEditingController();
  final _gFamilyDepCtrl = TextEditingController();

  // ── whether the property was suspended/rejected ──
  bool get _isSuspendedOrRejected =>
      _status == 'suspended' || _status == 'rejected';

  // ── lock rules ──
  bool get _photosLocked =>
      !_isSuspendedOrRejected && _existingPhotos.isNotEmpty;
  bool get _registryLocked => !_isSuspendedOrRejected && _hasRegistry;
  bool get _nocLocked => !_isSuspendedOrRejected && _hasNoc;
  bool get _idFrontLocked => !_isSuspendedOrRejected && _hasIdFront;
  bool get _idBackLocked => !_isSuspendedOrRejected && _hasIdBack;

  // ── completion check ──
  bool get _photosComplete =>
      _existingPhotos.isNotEmpty || _newPhotoBytes.isNotEmpty;
  bool get _registryComplete => _hasRegistry || _newRegistryBytes != null;
  bool get _nocComplete => _hasNoc || _newNocBytes != null;
  bool get _allComplete => _photosComplete && _registryComplete && _nocComplete;

  @override
  void initState() {
    super.initState();
    final p = widget.property;
    _type = p['propertyType'] as String? ?? '';
    _id = p['_id'] as String? ?? '';
    _status = p['status'] as String? ?? 'under_review';

    _existingPhotos = List<String>.from(p['photos'] as List? ?? []);
    _hasRegistry = (p['registryDocument'] as String?)?.isNotEmpty == true;
    _hasNoc = (p['nocDocument'] as String?)?.isNotEmpty == true;
    _hasIdFront = (p['idProofFront'] as String?)?.isNotEmpty == true;
    _hasIdBack = (p['idProofBack'] as String?)?.isNotEmpty == true;

    _nameCtrl.text = p['propertyName'] ?? '';
    _locationCtrl.text = p['location'] ?? '';
    _landmarkCtrl.text = p['localLandmark'] ?? '';
    _mapCtrl.text = p['mapLink'] ?? '';

    if (_type == 'plot') {
      final d = (p['plotDetails'] as Map<String, dynamic>?) ?? {};
      _plotIdCtrl.text = d['plotId'] ?? '';
      _plotSizeCtrl.text = '${d['plotSize'] ?? ''}';
      _plotLengthCtrl.text = '${d['plotDimensions']?['length'] ?? ''}';
      _plotWidthCtrl.text = '${d['plotDimensions']?['width'] ?? ''}';
      _totalPriceCtrl.text = '${d['totalPrice'] ?? ''}';
      _descCtrl.text = d['description'] ?? '';
      _plotType = d['plotType'] as String?;
      _facing = d['facing'] as String?;
      _ownershipType = d['ownershipType'] as String?;
      final f = d['facilities'];
      if (f is List) {
        _facilities.addAll(f.map((e) => e.toString()));
      }
    } else if (_type == 'pg') {
      final d = (p['pgDetails'] as Map<String, dynamic>?) ?? {};
      _totalRoomsCtrl.text = '${d['totalRooms'] ?? ''}';
      _acRoomsCtrl.text = '${d['acRooms'] ?? ''}';
      _nonAcCtrl.text = '${d['nonAcRooms'] ?? ''}';
      _singlePriceCtrl.text =
          '${d['sharingPricing']?['singleRoom']?['price'] ?? ''}';
      _singleDepCtrl.text =
          '${d['sharingPricing']?['singleRoom']?['deposit'] ?? ''}';
      _doublePriceCtrl.text =
          '${d['sharingPricing']?['doubleRoom']?['price'] ?? ''}';
      _doubleDepCtrl.text =
          '${d['sharingPricing']?['doubleRoom']?['deposit'] ?? ''}';
      _descCtrl.text = d['description'] ?? '';
      _occupancy = d['occupancyType'] as String? ?? 'any';
      _roomType = d['roomType'] as String? ?? 'sharing';
      _commonKitchen = d['commonKitchen'] as bool? ?? false;
      _privateKitchen = d['privateKitchen'] as bool? ?? false;
      final av = d['availableFor'];
      if (av is List) {
        _pgAvailFor.addAll(av.map((e) => e.toString()));
      }
      final f = d['facilities'];
      if (f is List) {
        _facilities.addAll(f.map((e) => e.toString()));
      }
    } else if (_type == 'guest') {
      final d = (p['guestRoomDetails'] as Map<String, dynamic>?) ?? {};
      _totalRoomsCtrl.text = '${d['totalRooms'] ?? ''}';
      _acRoomsCtrl.text = '${d['acRooms'] ?? ''}';
      _nonAcCtrl.text = '${d['nonAcRooms'] ?? ''}';
      _gSinglePriceCtrl.text = '${d['pricing']?['singleRoom']?['price'] ?? ''}';
      _gSingleDepCtrl.text = '${d['pricing']?['singleRoom']?['deposit'] ?? ''}';
      _gDoublePriceCtrl.text = '${d['pricing']?['doubleRoom']?['price'] ?? ''}';
      _gDoubleDepCtrl.text = '${d['pricing']?['doubleRoom']?['deposit'] ?? ''}';
      _gFamilyPriceCtrl.text = '${d['pricing']?['familyRoom']?['price'] ?? ''}';
      _gFamilyDepCtrl.text = '${d['pricing']?['familyRoom']?['deposit'] ?? ''}';
      _descCtrl.text = d['description'] ?? '';
      _commonKitchen = d['commonKitchen'] as bool? ?? false;
      _privateKitchen = d['privateKitchen'] as bool? ?? false;
      final f = d['facilities'];
      if (f is List) {
        _facilities.addAll(f.map((e) => e.toString()));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _locationCtrl,
      _landmarkCtrl,
      _mapCtrl,
      _plotIdCtrl,
      _plotSizeCtrl,
      _plotLengthCtrl,
      _plotWidthCtrl,
      _totalPriceCtrl,
      _descCtrl,
      _totalRoomsCtrl,
      _acRoomsCtrl,
      _nonAcCtrl,
      _singlePriceCtrl,
      _singleDepCtrl,
      _doublePriceCtrl,
      _doubleDepCtrl,
      _gSinglePriceCtrl,
      _gSingleDepCtrl,
      _gDoublePriceCtrl,
      _gDoubleDepCtrl,
      _gFamilyPriceCtrl,
      _gFamilyDepCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Pick photos ───────────────────────────────────────────────
  Future<void> _pickPhotos() async {
    final picked = await pickImages(multiple: true);
    if (picked.isEmpty) return;
    if (mounted) {
      setState(() {
        for (final f in picked) {
          _newPhotoBytes.add(f.bytes);
          _newPhotoNames.add(f.name);
        }
        if (_isSuspendedOrRejected) _replacePhotos = true;
      });
    }
  }

  // ── Pick a document ───────────────────────────────────────────
  Future<void> _pickDocument(String docType) async {
    // Web: images + PDF. Mobile: images only (image_picker has no PDF).
    final picked = await pickDocument();
    if (picked == null) return;
    if (mounted) {
      setState(() {
        if (docType == 'registry') {
          _newRegistryBytes = picked.bytes;
          _newRegistryName = picked.name;
        } else if (docType == 'noc') {
          _newNocBytes = picked.bytes;
          _newNocName = picked.name;
        } else if (docType == 'idFront') {
          _newIdFrontBytes = picked.bytes;
          _newIdFrontName = picked.name;
        } else {
          _newIdBackBytes = picked.bytes;
          _newIdBackName = picked.name;
        }
      });
    }
  }

  // ── Save ──────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_allComplete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Please add all required photos and documents first'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    // For suspended/rejected, require at least something new to be uploaded
    if (_isSuspendedOrRejected &&
        _newPhotoBytes.isEmpty &&
        _newRegistryBytes == null &&
        _newNocBytes == null &&
        _newIdFrontBytes == null &&
        _newIdBackBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Please update at least one photo or document before saving'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      // 1. Save details
      final body = <String, dynamic>{
        'propertyName': _nameCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'localLandmark': _landmarkCtrl.text.trim(),
        'mapLink': _mapCtrl.text.trim(),
      };

      if (_type == 'plot') {
        body.addAll({
          'plotId': _plotIdCtrl.text.trim(),
          'plotType': _plotType,
          'facing': _facing,
          'plotSize': _plotSizeCtrl.text,
          'plotLength': _plotLengthCtrl.text,
          'plotWidth': _plotWidthCtrl.text,
          'totalPrice': _totalPriceCtrl.text,
          'ownershipType': _ownershipType,
          'facilities': _facilities,
          'description': _descCtrl.text.trim(),
        });
      } else if (_type == 'pg') {
        body.addAll({
          'totalRooms': _totalRoomsCtrl.text,
          'acRooms': _acRoomsCtrl.text,
          'nonAcRooms': _nonAcCtrl.text,
          'occupancyType': _occupancy,
          'roomType': _roomType,
          'singlePrice': _singlePriceCtrl.text,
          'singleDeposit': _singleDepCtrl.text,
          'doublePrice': _doublePriceCtrl.text,
          'doubleDeposit': _doubleDepCtrl.text,
          'availableFor': _pgAvailFor,
          'facilities': _facilities,
          'commonKitchen': _commonKitchen,
          'privateKitchen': _privateKitchen,
          'description': _descCtrl.text.trim(),
        });
      } else if (_type == 'guest') {
        body.addAll({
          'totalRooms': _totalRoomsCtrl.text,
          'acRooms': _acRoomsCtrl.text,
          'nonAcRooms': _nonAcCtrl.text,
          'singlePrice': _gSinglePriceCtrl.text,
          'singleDeposit': _gSingleDepCtrl.text,
          'doublePrice': _gDoublePriceCtrl.text,
          'doubleDeposit': _gDoubleDepCtrl.text,
          'familyPrice': _gFamilyPriceCtrl.text,
          'familyDeposit': _gFamilyDepCtrl.text,
          'facilities': _facilities,
          'commonKitchen': _commonKitchen,
          'privateKitchen': _privateKitchen,
          'description': _descCtrl.text.trim(),
        });
      }

      await ApiService.updateProperty(_id, body);

      // 2. Upload photos (replaces all if suspended/rejected)
      if (_newPhotoBytes.isNotEmpty) {
        await ApiService.uploadPropertyPhotos(
          propertyId: _id,
          imageBytes: _newPhotoBytes,
          fileNames: _newPhotoNames,
        );
      }

      // 3. Upload documents
      if (_newRegistryBytes != null ||
          _newNocBytes != null ||
          _newIdFrontBytes != null ||
          _newIdBackBytes != null) {
        await ApiService.uploadDocuments(
          propertyId: _id,
          registryBytes: _newRegistryBytes,
          registryFileName: _newRegistryName,
          nocBytes: _newNocBytes,
          nocFileName: _newNocName,
          idFrontBytes: _newIdFrontBytes,
          idFrontFileName: _newIdFrontName,
          idBackBytes: _newIdBackBytes,
          idBackFileName: _newIdBackName,
        );
      }

      if (mounted) {
        final msg = _isSuspendedOrRejected
            ? '✅ Updated! Admin has been notified to re-review your property.'
            : '✅ Property updated successfully.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = _type == 'pg'
        ? '🛏️ PG Room'
        : _type == 'guest'
            ? '🏨 Guest Room'
            : 'Plot';
    final pendingCount = (_photosComplete ? 0 : 1) +
        (_registryComplete ? 0 : 1) +
        (_nocComplete ? 0 : 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit $typeLabel',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.textDark)),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _saving ? null : _save,
              style: TextButton.styleFrom(
                backgroundColor:
                    _allComplete ? AppColors.primary : AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      _allComplete
                          ? (_isSuspendedOrRejected
                              ? 'Save & Notify Admin'
                              : 'Save')
                          : 'Save ($pendingCount missing)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Suspension/Rejection banner ──────────────────
            if (_isSuspendedOrRejected) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _status == 'suspended'
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _status == 'suspended'
                        ? const Color(0xFFE65100)
                        : AppColors.error,
                    width: 1.5,
                  ),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          _status == 'suspended'
                              ? Icons.warning_amber_rounded
                              : Icons.cancel_outlined,
                          color: _status == 'suspended'
                              ? const Color(0xFFE65100)
                              : AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _status == 'suspended'
                              ? 'Property Suspended'
                              : 'Property Rejected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _status == 'suspended'
                                ? const Color(0xFFE65100)
                                : AppColors.error,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        'Please update your photos and/or documents below to address the admin\'s concerns, then tap "Save & Notify Admin". The admin will be notified to re-review your listing.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _status == 'suspended'
                              ? const Color(0xFFBF360C)
                              : const Color(0xFFB71C1C),
                          height: 1.4,
                        ),
                      ),
                      // Show admin reason if available
                      if ((widget.property['rejectionNote'] as String?)
                              ?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Admin reason: ${widget.property['rejectionNote']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Missing uploads banner (non-suspended) ───────
            if (!_isSuspendedOrRejected && !_allComplete) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE65100).withValues(alpha: 0.4)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFE65100), size: 18),
                        SizedBox(width: 8),
                        Text('Required uploads missing',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100))),
                      ]),
                      const SizedBox(height: 6),
                      if (!_photosComplete)
                        const Text('• Property photos (at least 1)',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFBF360C))),
                      if (!_registryComplete)
                        const Text('• Registry / ownership document',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFBF360C))),
                      if (!_nocComplete)
                        const Text('• NOC document',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFBF360C))),
                    ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Photos section ───────────────────────────────
            _PhotosSection(
              existingPhotos: _existingPhotos,
              newPhotoBytes: _newPhotoBytes,
              isLocked: _photosLocked,
              isSuspended: _isSuspendedOrRejected,
              onAdd: _pickPhotos,
              onRemoveNew: (i) => setState(() {
                _newPhotoBytes.removeAt(i);
                _newPhotoNames.removeAt(i);
              }),
            ),
            const SizedBox(height: 16),

            // ── Documents section ────────────────────────────
            _DocumentsSection(
              hasRegistry: _hasRegistry,
              hasNoc: _hasNoc,
              isRegistryLocked: _registryLocked,
              isNocLocked: _nocLocked,
              isSuspended: _isSuspendedOrRejected,
              newRegistryPicked: _newRegistryBytes != null,
              newRegistryName: _newRegistryName,
              newNocPicked: _newNocBytes != null,
              newNocName: _newNocName,
              onPickRegistry: () => _pickDocument('registry'),
              onPickNoc: () => _pickDocument('noc'),
              onClearRegistry: () => setState(() {
                _newRegistryBytes = null;
                _newRegistryName = null;
              }),
              onClearNoc: () => setState(() {
                _newNocBytes = null;
                _newNocName = null;
              }),
              hasIdFront: _hasIdFront,
              hasIdBack: _hasIdBack,
              isIdFrontLocked: _idFrontLocked,
              isIdBackLocked: _idBackLocked,
              newIdFrontPicked: _newIdFrontBytes != null,
              newIdBackPicked: _newIdBackBytes != null,
              newIdFrontName: _newIdFrontName,
              newIdBackName: _newIdBackName,
              onPickIdFront: () => _pickDocument('idFront'),
              onPickIdBack: () => _pickDocument('idBack'),
              onClearIdFront: () => setState(() {
                _newIdFrontBytes = null;
                _newIdFrontName = null;
              }),
              onClearIdBack: () => setState(() {
                _newIdBackBytes = null;
                _newIdBackName = null;
              }),
            ),
            const SizedBox(height: 20),

            // ── Property Details ─────────────────────────────
            _Section(title: 'Basic Info', children: [
              _Field(label: 'Property Name', ctrl: _nameCtrl),
              _Field(label: 'Location', ctrl: _locationCtrl),
              _Field(label: 'Local Landmark (optional)', ctrl: _landmarkCtrl),
              _Field(
                  label: 'Google Maps Location (optional)', ctrl: _mapCtrl),
            ]),
            const SizedBox(height: 16),

            if (_type == 'plot') ...[
              ..._plotFields(),
              const SizedBox(height: 16)
            ],
            if (_type == 'pg') ...[..._pgFields(), const SizedBox(height: 16)],
            if (_type == 'guest') ...[
              ..._guestFields(),
              const SizedBox(height: 16)
            ],

            _Section(title: 'Description', children: [
              _Field(
                  label: 'Description (optional)',
                  ctrl: _descCtrl,
                  maxLines: 3),
            ]),
            const SizedBox(height: 16),

            _FacilitiesEditor(
              selected: _facilities,
              type: _type,
              onChange: (v) => setState(() {
                _facilities
                  ..clear()
                  ..addAll(v);
              }),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _allComplete ? AppColors.primary : AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : Text(
                        _allComplete
                            ? (_isSuspendedOrRejected
                                ? 'Save & Notify Admin'
                                : 'Save Changes')
                            : 'Add missing uploads to save',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _plotFields() => [
        _Section(title: 'Plot Details', children: [
          _Field(label: 'Plot ID (optional)', ctrl: _plotIdCtrl),
          _DropdownField(
              label: 'Plot Type',
              value: _plotType,
              options: const [
                'Agricultural',
                'Residential',
                'Commercial',
                'Industrial'
              ],
              onChanged: (v) => setState(() => _plotType = v)),
          _DropdownField(
              label: 'Facing',
              value: _facing,
              options: const [
                'North',
                'South',
                'East',
                'West',
                'North-East',
                'North-West',
                'South-East',
                'South-West'
              ],
              onChanged: (v) => setState(() => _facing = v)),
          _Field(
              label: 'Plot Size (sq ft)', ctrl: _plotSizeCtrl, numeric: true),
          Row(children: [
            Expanded(
                child: _Field(
                    label: 'Length (ft)',
                    ctrl: _plotLengthCtrl,
                    numeric: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _Field(
                    label: 'Width (ft)', ctrl: _plotWidthCtrl, numeric: true)),
          ]),
          _Field(
              label: 'Total Price (₹)', ctrl: _totalPriceCtrl, numeric: true),
          _DropdownField(
              label: 'Ownership Type',
              value: _ownershipType,
              options: const ['Freehold', 'Leasehold', 'Cooperative'],
              onChanged: (v) => setState(() => _ownershipType = v)),
        ]),
      ];

  List<Widget> _pgFields() => [
        _Section(title: 'Room Details', children: [
          Row(children: [
            Expanded(
                child: _Field(
                    label: 'Total Rooms',
                    ctrl: _totalRoomsCtrl,
                    numeric: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _Field(
                    label: 'AC Rooms', ctrl: _acRoomsCtrl, numeric: true)),
            const SizedBox(width: 12),
            Expanded(
                child:
                    _Field(label: 'Non-AC', ctrl: _nonAcCtrl, numeric: true)),
          ]),
          _DropdownField(
              label: 'Occupancy Type',
              value: _occupancy,
              options: const ['any', 'male', 'female'],
              onChanged: (v) => setState(() => _occupancy = v ?? 'any')),
          _DropdownField(
              label: 'Room Type',
              value: _roomType,
              options: const ['sharing', 'private'],
              onChanged: (v) => setState(() => _roomType = v ?? 'sharing')),
        ]),
        const SizedBox(height: 16),
        _Section(title: 'Pricing', children: [
          const _SubLabel('Single Room'),
          Row(children: [
            Expanded(
                child: _Field(
                    label: 'Price/mo (₹)',
                    ctrl: _singlePriceCtrl,
                    numeric: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _Field(
                    label: 'Deposit (₹)', ctrl: _singleDepCtrl, numeric: true)),
          ]),
          const SizedBox(height: 4),
          const _SubLabel('Double Room'),
          Row(children: [
            Expanded(
                child: _Field(
                    label: 'Price/mo (₹)',
                    ctrl: _doublePriceCtrl,
                    numeric: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _Field(
                    label: 'Deposit (₹)', ctrl: _doubleDepCtrl, numeric: true)),
          ]),
          const SizedBox(height: 4),
          _SwitchRow(
              label: 'Common Kitchen',
              value: _commonKitchen,
              onChanged: (v) => setState(() => _commonKitchen = v)),
          _SwitchRow(
              label: 'Private Kitchen',
              value: _privateKitchen,
              onChanged: (v) => setState(() => _privateKitchen = v)),
        ]),
      ];

  List<Widget> _guestFields() => [
        _Section(title: 'Room Details', children: [
          Row(children: [
            Expanded(
                child: _Field(
                    label: 'Total Rooms',
                    ctrl: _totalRoomsCtrl,
                    numeric: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _Field(
                    label: 'AC Rooms', ctrl: _acRoomsCtrl, numeric: true)),
            const SizedBox(width: 12),
            Expanded(
                child:
                    _Field(label: 'Non-AC', ctrl: _nonAcCtrl, numeric: true)),
          ]),
        ]),
        const SizedBox(height: 16),
        _Section(title: 'Pricing per Night', children: [
          _PricingRow(
              label: 'Single Room',
              priceCtrl: _gSinglePriceCtrl,
              depCtrl: _gSingleDepCtrl),
          const SizedBox(height: 10),
          _PricingRow(
              label: 'Double Room',
              priceCtrl: _gDoublePriceCtrl,
              depCtrl: _gDoubleDepCtrl),
          const SizedBox(height: 10),
          _PricingRow(
              label: 'Family Room',
              priceCtrl: _gFamilyPriceCtrl,
              depCtrl: _gFamilyDepCtrl),
          const SizedBox(height: 4),
          _SwitchRow(
              label: 'Common Kitchen',
              value: _commonKitchen,
              onChanged: (v) => setState(() => _commonKitchen = v)),
          _SwitchRow(
              label: 'Private Kitchen',
              value: _privateKitchen,
              onChanged: (v) => setState(() => _privateKitchen = v)),
        ]),
      ];
}

// ── Photos Section ─────────────────────────────────────────────
class _PhotosSection extends StatelessWidget {
  final List<String> existingPhotos;
  final List<Uint8List> newPhotoBytes;
  final bool isLocked;
  final bool isSuspended;
  final VoidCallback onAdd;
  final void Function(int) onRemoveNew;

  const _PhotosSection({
    required this.existingPhotos,
    required this.newPhotoBytes,
    required this.isLocked,
    required this.isSuspended,
    required this.onAdd,
    required this.onRemoveNew,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasAny = existingPhotos.isNotEmpty || newPhotoBytes.isNotEmpty;
    final Color borderColor = isLocked
        ? AppColors.success.withValues(alpha: 0.4)
        : hasAny
            ? AppColors.primary.withValues(alpha: 0.4)
            : AppColors.error.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            isLocked
                ? Icons.photo_library_rounded
                : Icons.add_photo_alternate_outlined,
            color: isLocked
                ? AppColors.success
                : hasAny
                    ? AppColors.primary
                    : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  'Property Photos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isLocked
                        ? AppColors.textDark
                        : hasAny
                            ? AppColors.textDark
                            : AppColors.error,
                  ),
                ),
                if (isSuspended && !isLocked)
                  const Text(
                    'Replace your photos to address admin concerns',
                    style: TextStyle(fontSize: 11, color: Color(0xFFE65100)),
                  ),
              ])),
          if (isLocked)
            _LockedBadge()
          else
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                existingPhotos.isNotEmpty ? 'Add More' : 'Add Photos',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ]),

        if (!hasAny) ...[
          const SizedBox(height: 10),
          const Text('At least 1 photo is required',
              style: TextStyle(fontSize: 12, color: AppColors.error)),
        ],

        // Existing photos
        if (existingPhotos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: existingPhotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    existingPhotos[i].startsWith('http')
                        ? existingPhotos[i]
                        : '${ApiService.mediaBase}${existingPhotos[i]}',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.textLight),
                    ),
                  ),
                ),
                if (isLocked)
                  Positioned.fill(
                      child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black.withValues(alpha: 0.22),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 18),
                  )),
              ]),
            ),
          ),
        ],

        // New photos (pending upload)
        if (newPhotoBytes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Text('New photos to upload:',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
            if (isSuspended)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('(will replace existing)',
                    style: TextStyle(fontSize: 11, color: Color(0xFFE65100))),
              ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: newPhotoBytes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(newPhotoBytes[i],
                      width: 80, height: 80, fit: BoxFit.cover),
                ),
                Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => onRemoveNew(i),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: AppColors.error, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 12, color: Colors.white),
                      ),
                    )),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.successBg, borderRadius: BorderRadius.circular(6)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_rounded, size: 11, color: AppColors.success),
          SizedBox(width: 3),
          Text('Uploaded',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success)),
        ]),
      );
}

// ── Documents Section ──────────────────────────────────────────
class _DocumentsSection extends StatelessWidget {
  final bool hasRegistry, hasNoc;
  final bool isRegistryLocked, isNocLocked;
  final bool isSuspended;
  final bool newRegistryPicked, newNocPicked;
  final String? newRegistryName, newNocName;
  final VoidCallback onPickRegistry, onPickNoc, onClearRegistry, onClearNoc;
  final bool hasIdFront, hasIdBack;
  final bool isIdFrontLocked, isIdBackLocked;
  final bool newIdFrontPicked, newIdBackPicked;
  final String? newIdFrontName, newIdBackName;
  final VoidCallback onPickIdFront, onPickIdBack, onClearIdFront, onClearIdBack;

  const _DocumentsSection({
    required this.hasRegistry,
    required this.hasNoc,
    required this.isRegistryLocked,
    required this.isNocLocked,
    required this.isSuspended,
    required this.newRegistryPicked,
    required this.newRegistryName,
    required this.newNocPicked,
    required this.newNocName,
    required this.onPickRegistry,
    required this.onPickNoc,
    required this.onClearRegistry,
    required this.onClearNoc,
    required this.hasIdFront,
    required this.hasIdBack,
    required this.isIdFrontLocked,
    required this.isIdBackLocked,
    required this.newIdFrontPicked,
    required this.newIdBackPicked,
    required this.newIdFrontName,
    required this.newIdBackName,
    required this.onPickIdFront,
    required this.onPickIdBack,
    required this.onClearIdFront,
    required this.onClearIdBack,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = hasRegistry && hasNoc;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: allDone && !isSuspended
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.error.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.description_outlined,
              color:
                  allDone && !isSuspended ? AppColors.success : AppColors.error,
              size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Legal Documents',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: allDone && !isSuspended
                            ? AppColors.textDark
                            : AppColors.error)),
                if (isSuspended)
                  const Text('You can update these documents',
                      style: TextStyle(fontSize: 11, color: Color(0xFFE65100))),
              ])),
        ]),
        const SizedBox(height: 14),
        _DocRow(
          label: 'Registry / Ownership Document',
          isUploaded: hasRegistry,
          isLocked: isRegistryLocked,
          isPicked: newRegistryPicked,
          pickedName: newRegistryName,
          isSuspended: isSuspended,
          onPick: onPickRegistry,
          onClear: onClearRegistry,
        ),
        const SizedBox(height: 10),
        _DocRow(
          label: 'NOC Document',
          isUploaded: hasNoc,
          isLocked: isNocLocked,
          isPicked: newNocPicked,
          pickedName: newNocName,
          isSuspended: isSuspended,
          onPick: onPickNoc,
          onClear: onClearNoc,
        ),
        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Row(children: const [
          Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
          SizedBox(width: 8),
          Text('Identity Verification (Aadhaar)',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
        ]),
        const SizedBox(height: 14),
        _DocRow(
          label: 'Aadhaar Card — Front',
          isUploaded: hasIdFront,
          isLocked: isIdFrontLocked,
          isPicked: newIdFrontPicked,
          pickedName: newIdFrontName,
          isSuspended: isSuspended,
          onPick: onPickIdFront,
          onClear: onClearIdFront,
        ),
        const SizedBox(height: 10),
        _DocRow(
          label: 'Aadhaar Card — Back',
          isUploaded: hasIdBack,
          isLocked: isIdBackLocked,
          isPicked: newIdBackPicked,
          pickedName: newIdBackName,
          isSuspended: isSuspended,
          onPick: onPickIdBack,
          onClear: onClearIdBack,
        ),
      ]),
    );
  }
}

class _DocRow extends StatelessWidget {
  final String label;
  final bool isUploaded, isLocked, isPicked, isSuspended;
  final String? pickedName;
  final VoidCallback onPick, onClear;

  const _DocRow({
    required this.label,
    required this.isUploaded,
    required this.isLocked,
    required this.isPicked,
    required this.pickedName,
    required this.isSuspended,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (isLocked) {
      bg = AppColors.successBg;
    } else if (isPicked) {
      bg = AppColors.primaryLight;
    } else if (isSuspended && isUploaded) {
      bg = const Color(0xFFFFF3E0);
    } else {
      bg = AppColors.background;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLocked
              ? AppColors.success.withValues(alpha: 0.4)
              : isPicked
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : isSuspended && isUploaded
                      ? const Color(0xFFE65100).withValues(alpha: 0.4)
                      : AppColors.border,
        ),
      ),
      child: Row(children: [
        Icon(
          isLocked
              ? Icons.check_circle_rounded
              : isPicked
                  ? Icons.file_present_rounded
                  : isSuspended && isUploaded
                      ? Icons.warning_amber_rounded
                      : Icons.upload_file_rounded,
          color: isLocked
              ? AppColors.success
              : isPicked
                  ? AppColors.primary
                  : isSuspended && isUploaded
                      ? const Color(0xFFE65100)
                      : AppColors.textLight,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          if (isLocked)
            const Text('✅ Uploaded — cannot be changed',
                style: TextStyle(fontSize: 11, color: AppColors.success))
          else if (isPicked)
            Text(pickedName ?? 'File selected',
                style: const TextStyle(fontSize: 11, color: AppColors.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)
          else if (isSuspended && isUploaded)
            const Text('Previously uploaded — tap to replace',
                style: TextStyle(fontSize: 11, color: Color(0xFFE65100)))
          else
            const Text('Required — tap to upload',
                style: TextStyle(fontSize: 11, color: AppColors.error)),
        ])),
        if (isLocked)
          const Icon(Icons.lock_rounded, color: AppColors.success, size: 18)
        else if (isPicked)
          GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, color: AppColors.error, size: 18))
        else
          TextButton(
            onPressed: onPick,
            style: TextButton.styleFrom(
              backgroundColor: isSuspended && isUploaded
                  ? const Color(0xFFE65100)
                  : AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isSuspended && isUploaded ? 'Replace' : 'Upload',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ]),
    );
  }
}

// ── Shared form widgets ────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i < children.length - 1) {
        spaced.add(const SizedBox(height: 10));
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 14),
        ...spaced,
      ]),
    );
  }
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool numeric;
  final int maxLines;
  const _Field(
      {required this.label,
      required this.ctrl,
      this.numeric = false,
      this.maxLines = 1});
  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: AppColors.background,
        ),
      );
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final void Function(String?) onChanged;
  const _DropdownField(
      {required this.label,
      required this.value,
      required this.options,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        value: options.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: AppColors.background,
        ),
        items: options
            .map((o) => DropdownMenuItem(
                value: o, child: Text(o, style: const TextStyle(fontSize: 14))))
            .toList(),
        onChanged: onChanged,
      );
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _SwitchRow(
      {required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary),
        ],
      );
}

class _PricingRow extends StatelessWidget {
  final String label;
  final TextEditingController priceCtrl, depCtrl;
  const _PricingRow(
      {required this.label, required this.priceCtrl, required this.depCtrl});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child:
                  _Field(label: 'Price (₹)', ctrl: priceCtrl, numeric: true)),
          const SizedBox(width: 12),
          Expanded(
              child:
                  _Field(label: 'Deposit (₹)', ctrl: depCtrl, numeric: true)),
        ]),
      ]);
}

class _FacilitiesEditor extends StatelessWidget {
  final List<String> selected;
  final String type;
  final void Function(List<String>) onChange;
  const _FacilitiesEditor(
      {required this.selected, required this.type, required this.onChange});
  @override
  Widget build(BuildContext context) {
    final all = type == 'plot'
        ? [
            'Road Access',
            'Water Supply',
            'Electricity',
            'Sewage',
            'Boundary Wall',
            'Gated Community',
            'Parking'
          ]
        : [
            'WiFi',
            'Parking',
            'AC',
            'Laundry',
            'CCTV',
            'Security',
            'Power Backup',
            'Water Supply',
            'Gym',
            'Common Room'
          ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Facilities',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: all.map((f) {
              final on = selected.contains(f);
              return GestureDetector(
                onTap: () {
                  final updated = List<String>.from(selected);
                  if (on) {
                    updated.remove(f);
                  } else {
                    updated.add(f);
                  }
                  onChange(updated);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: on ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: on ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(f,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: on ? Colors.white : AppColors.textDark,
                      )),
                ),
              );
            }).toList()),
      ]),
    );
  }
}
