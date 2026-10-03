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
import 'verification_screen.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final String propertyType;
  const PropertyDetailsScreen({super.key, required this.propertyType});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  // ── Common ──
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();

  // ── PG fields ──
  final _totalRoomsPgCtrl = TextEditingController(text: '12');
  String _occupancyType = 'single';
  final Set<String> _availableFor = {'boys_girls'};

  // ── Guest Room fields ──
  final _totalRoomsCtrl = TextEditingController(text: '10');
  final _acRoomsCtrl = TextEditingController(text: '5');
  final _nonAcRoomsCtrl = TextEditingController(text: '5');
  final _singlePriceCtrl = TextEditingController(text: '1999');
  final _singleDepositCtrl = TextEditingController(text: '499');
  final _doublePriceCtrl = TextEditingController(text: '3999');
  final _doubleDepositCtrl = TextEditingController(text: '999');
  final _familyPriceCtrl = TextEditingController(text: '4999');
  final _familyDepositCtrl = TextEditingController(text: '1999');
  final _guestDescCtrl = TextEditingController();
  bool _commonKitchen = true;
  bool _privateKitchen = true;
  final List<Uint8List> _guestPhotoBytes = [];
  final List<String> _guestPhotoNames = [];
  final List<Uint8List> _pgPhotoBytes = [];
  final List<String> _pgPhotoNames = [];
  final Map<String, bool> _guestFacilities = {
    'Attached Balcony': true,
    'Parking': false,
    'Attached Bathroom': true,
    'Free Wifi': true,
    '24 hour water supply': false,
  };
  final List<String> _guestExtraFacilities = [];

  // ── Plot fields ──
  final _plotIdCtrl = TextEditingController();
  final _plotSizeCtrl = TextEditingController();
  final _plotDimLCtrl = TextEditingController();
  final _plotDimWCtrl = TextEditingController();
  final _totalPriceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String? _plotType;
  String? _facing;
  final List<Uint8List> _photoBytes = [];
  final List<String> _photoNames = [];
  final Map<String, bool> _plotFacilities = {
    'Road Access': true,
    'Electricity': false,
    'Water Supply': true,
    'Parking': true,
    'Gated Community': false,
  };
  final List<String> _plotExtraFacilities = [];

  final _extraCtrl = TextEditingController();

  final List<String> _plotTypes = [
    'Residential',
    'Agricultural',
    'Commercial',
    'Industrial',
    'Mixed Use'
  ];
  final List<String> _facingList = [
    'East',
    'West',
    'North',
    'South',
    'North-East',
    'North-West',
    'South-East',
    'South-West'
  ];

  String get pricePerSqft {
    final size = double.tryParse(_plotSizeCtrl.text);
    final price = double.tryParse(_totalPriceCtrl.text);
    if (size != null && price != null && size > 0) {
      return 'Rs ${(price / size).toStringAsFixed(0)}';
    }
    return 'Rs —';
  }

  String get typeLabel {
    if (widget.propertyType == 'pg') return 'PG Room';
    if (widget.propertyType == 'guest') return 'Guest Room';
    return 'Plot';
  }

  IconData get typeIcon {
    if (widget.propertyType == 'pg') return Icons.bed_rounded;
    if (widget.propertyType == 'guest') return Icons.hotel_rounded;
    return Icons.landscape_rounded;
  }

  // ── API Save ─────────────────────────────────────────────
  bool _isSaving = false;

  Future<void> _pickPhotos(
      List<Uint8List> bytesList, List<String> namesList) async {
    if (kIsWeb) {
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..multiple = true;
      input.click();
      await input.onChange.first;
      if (input.files == null) return;
      for (final file in input.files!) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;
        final bytes = (reader.result as html.ByteBuffer).asUint8List();
        setState(() {
          bytesList.add(bytes);
          namesList.add(file.name);
        });
      }
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 85);
      for (final p in picked) {
        final bytes = await p.readAsBytes();
        setState(() {
          bytesList.add(bytes);
          namesList.add(p.name);
        });
      }
    }
  }

  Future<void> _saveProperty() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack('Please enter property name', isError: true);
      return;
    }
    if (_locationCtrl.text.trim().isEmpty) {
      _showSnack('Please enter location', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      Map<String, dynamic> details = {};

      if (widget.propertyType == 'plot') {
        details = {
          'plotId':
              _plotIdCtrl.text.trim().isEmpty ? null : _plotIdCtrl.text.trim(),
          'plotType': _plotType,
          'facing': _facing,
          'plotSize': double.tryParse(_plotSizeCtrl.text) ?? 0,
          'plotLength': double.tryParse(_plotDimLCtrl.text) ?? 0,
          'plotWidth': double.tryParse(_plotDimWCtrl.text) ?? 0,
          'totalPrice': double.tryParse(_totalPriceCtrl.text) ?? 0,
          'description': _descriptionCtrl.text.trim(),
          'facilities': [
            ..._plotFacilities.entries.where((e) => e.value).map((e) => e.key),
            ..._plotExtraFacilities,
          ],
        };
      } else if (widget.propertyType == 'guest') {
        details = {
          'totalRooms': int.tryParse(_totalRoomsCtrl.text) ?? 0,
          'acRooms': int.tryParse(_acRoomsCtrl.text) ?? 0,
          'nonAcRooms': int.tryParse(_nonAcRoomsCtrl.text) ?? 0,
          'singlePrice':
              double.tryParse(_singlePriceCtrl.text.replaceAll(',', '')) ?? 0,
          'singleDeposit':
              double.tryParse(_singleDepositCtrl.text.replaceAll(',', '')) ?? 0,
          'doublePrice':
              double.tryParse(_doublePriceCtrl.text.replaceAll(',', '')) ?? 0,
          'doubleDeposit':
              double.tryParse(_doubleDepositCtrl.text.replaceAll(',', '')) ?? 0,
          'familyPrice':
              double.tryParse(_familyPriceCtrl.text.replaceAll(',', '')) ?? 0,
          'familyDeposit':
              double.tryParse(_familyDepositCtrl.text.replaceAll(',', '')) ?? 0,
          'commonKitchen': _commonKitchen,
          'privateKitchen': _privateKitchen,
          'description': _guestDescCtrl.text.trim(),
          'facilities': [
            ..._guestFacilities.entries.where((e) => e.value).map((e) => e.key),
            ..._guestExtraFacilities,
          ],
        };
      } else {
        // PG
        details = {
          'availableFor': _availableFor.toList(),
          'totalRooms': int.tryParse(_totalRoomsPgCtrl.text) ?? 0,
          'occupancyType': _occupancyType,
          'roomType': 'sharing',
        };
      }

      final res = await ApiService.createProperty(
        propertyType: widget.propertyType,
        propertyName: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        localLandmark: _landmarkCtrl.text.trim(),
        details: details,
      );

      final propertyId = res['property']['_id'] as String;

      // Upload actual photos
      final bytes = widget.propertyType == 'guest'
          ? _guestPhotoBytes
          : widget.propertyType == 'pg'
              ? _pgPhotoBytes
              : _photoBytes;
      final names = widget.propertyType == 'guest'
          ? _guestPhotoNames
          : widget.propertyType == 'pg'
              ? _pgPhotoNames
              : _photoNames;
      if (bytes.isNotEmpty) {
        await ApiService.uploadPropertyPhotos(
          propertyId: propertyId,
          imageBytes: bytes,
          fileNames: names,
        );
      }

      if (!mounted) return;
      _showSnack('✅ Property saved!', isError: false);
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VerificationScreen(propertyId: propertyId)));
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
  // ─────────────────────────────────────────────────────────

  // ── Reusable: card row ──
  Widget _cardRow(
      {required String label,
      String? sublabel,
      required Widget trailing,
      bool showBorder = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.8))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500)),
                if (sublabel != null)
                  Text(sublabel,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  // ── Reusable: white card wrapper ──
  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  // ── Reusable: editable number row ──
  Widget _editableRow(String label, TextEditingController ctrl,
      {bool showBorder = true, String prefix = '', String suffix = ''}) {
    return _cardRow(
      label: label,
      showBorder: showBorder,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefix.isNotEmpty)
            Text(prefix,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          SizedBox(
            width: 80,
            child: TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (suffix.isNotEmpty)
            Text(suffix,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // ── Reusable: section title ──
  Widget _section(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark)),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  // ── Reusable: facility checkbox ──
  Widget _facilityCheck(String label, bool checked, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: checked ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: checked ? AppColors.primary : AppColors.border,
                  width: 1.5),
            ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: checked ? AppColors.textDark : AppColors.textMuted,
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }

  // ── Reusable: Yes/No radio ──
  Widget _yesNo(
      String label, String sublabel, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                Text(sublabel,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => onChanged(true)),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: value ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: value ? AppColors.primary : AppColors.border,
                            width: 1.5),
                      ),
                      child: value
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 5),
                    Text('Yes',
                        style: TextStyle(
                            fontSize: 13,
                            color:
                                value ? AppColors.primary : AppColors.textMuted,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => setState(() => onChanged(false)),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: !value ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color:
                                !value ? AppColors.primary : AppColors.border,
                            width: 1.5),
                      ),
                      child: !value
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 5),
                    Text('No',
                        style: TextStyle(
                            fontSize: 13,
                            color: !value
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Reusable: photo upload button ──
  Widget _photoButton(String label, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withOpacity(0.5), width: 1.5),
              ),
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                if (count > 0)
                  Text('$count photo${count > 1 ? 's' : ''} selected',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white.withOpacity(0.85))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Add facility dialog ──
  void _showAddFacility(List<String> extraList) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Facility',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: TextField(
            controller: _extraCtrl,
            autofocus: true,
            decoration:
                const InputDecoration(hintText: 'e.g. CCTV, Swimming Pool')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (_extraCtrl.text.trim().isNotEmpty) {
                setState(() {
                  extraList.add(_extraCtrl.text.trim());
                  _extraCtrl.clear();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════
  // PLOT SECTION
  // ════════════════════════════════════
  Widget _buildPlotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Plot Information'),
        _card([
          _cardRow(
            label: 'Plot ID  (optional)',
            trailing: SizedBox(
              width: 80,
              child: TextFormField(
                controller: _plotIdCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: '10',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          _cardRow(
            label: 'Plot Type',
            trailing: DropdownButton<String>(
              value: _plotType,
              hint: const Text('Select',
                  style: TextStyle(fontSize: 14, color: AppColors.textLight)),
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted, size: 20),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
              items: _plotTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _plotType = val),
            ),
          ),
          _cardRow(
            label: 'Facing',
            showBorder: false,
            trailing: DropdownButton<String>(
              value: _facing,
              hint: const Text('Select',
                  style: TextStyle(fontSize: 14, color: AppColors.textLight)),
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted, size: 20),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
              items: _facingList
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (val) => setState(() => _facing = val),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _card([
          _editableRow('Plot Size', _plotSizeCtrl, suffix: ' sq ft'),
          _cardRow(
            label: 'Plot Dimensions',
            showBorder: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    width: 40,
                    child: TextFormField(
                        controller: _plotDimLCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                            hintText: '30',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero))),
                const Text(' x ',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
                SizedBox(
                    width: 40,
                    child: TextFormField(
                        controller: _plotDimWCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                            hintText: '50',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero))),
                const Text(' ft',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _card([
          _editableRow('Total Plot Price', _totalPriceCtrl, prefix: 'Rs '),
          _cardRow(
            label: 'Price Per sq ft',
            showBorder: false,
            trailing: Text(pricePerSqft,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ]),
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border)),
          child: const Text('1 Sq ft = 0.112 Gaj  and\n1 Sq ft = 0.0036 Marla',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMuted, height: 1.6)),
        ),
        _section('Facilities'),
        _buildFacilityGrid(_plotFacilities, _plotExtraFacilities),
        const SizedBox(height: 24),
        _photoButton('Upload Plot Photos', _photoBytes.length,
            () => _pickPhotos(_photoBytes, _photoNames)),
        if (_photoBytes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                  _photoBytes.length,
                  (i) => Stack(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(_photoBytes[i],
                                width: 64, height: 64, fit: BoxFit.cover)),
                        Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _photoBytes.removeAt(i);
                                _photoNames.removeAt(i);
                              }),
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 12)),
                            )),
                      ]))),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
              hintText: 'Enter more description about Plot',
              alignLabelWithHint: true),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ════════════════════════════════════
  // GUEST ROOM SECTION
  // ════════════════════════════════════
  Widget _buildGuestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Guest Room Details'),
        _card([
          _editableRow('Total Rooms', _totalRoomsCtrl),
          _editableRow('Ac Rooms', _acRoomsCtrl),
          _editableRow('Non Ac Rooms', _nonAcRoomsCtrl, showBorder: false),
        ]),

        _section('Stay Pricing', subtitle: '( Per Night )'),

        // Single Room
        _card([
          _editableRow('For  Single Room', _singlePriceCtrl, prefix: 'Rs '),
          _cardRow(
            label: 'Advance Deposit',
            sublabel: '(Reserve / Booking Fee)',
            showBorder: false,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Rs ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(
                  width: 70,
                  child: TextFormField(
                      controller: _singleDepositCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero))),
            ]),
          ),
        ]),
        const SizedBox(height: 10),

        // Double Room
        _card([
          _editableRow('For  Double Room', _doublePriceCtrl, prefix: 'Rs '),
          _cardRow(
            label: 'Advance Deposit',
            showBorder: false,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Rs  ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(
                  width: 70,
                  child: TextFormField(
                      controller: _doubleDepositCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero))),
            ]),
          ),
        ]),
        const SizedBox(height: 10),

        // Family Room
        _card([
          _editableRow('For  Family Room', _familyPriceCtrl, prefix: 'Rs '),
          _cardRow(
            label: 'Advance Deposit',
            showBorder: false,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Rs ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(
                  width: 70,
                  child: TextFormField(
                      controller: _familyDepositCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero))),
            ]),
          ),
        ]),

        _section('Facilities'),
        _buildFacilityGrid(_guestFacilities, _guestExtraFacilities),
        const SizedBox(height: 24),

        _photoButton('Upload Room Photos', _guestPhotoBytes.length,
            () => _pickPhotos(_guestPhotoBytes, _guestPhotoNames)),
        if (_guestPhotoBytes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                  _guestPhotoBytes.length,
                  (i) => Stack(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(_guestPhotoBytes[i],
                                width: 64, height: 64, fit: BoxFit.cover)),
                        Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _guestPhotoBytes.removeAt(i);
                                _guestPhotoNames.removeAt(i);
                              }),
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 12)),
                            )),
                      ]))),
        ],
        const SizedBox(height: 16),

        TextFormField(
          controller: _guestDescCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
              hintText: 'Enter more description about house and rules',
              alignLabelWithHint: true),
        ),
        const SizedBox(height: 20),

        // Kitchen questions
        _yesNo('Kitchen is available ?', '(Common Kitchen)', _commonKitchen,
            (val) => _commonKitchen = val),
        _yesNo('Kitchen is available ?', '(Private Kitchens)', _privateKitchen,
            (val) => _privateKitchen = val),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Facility grid (2 columns) ──
  Widget _buildFacilityGrid(Map<String, bool> facilities, List<String> extras) {
    final keys = facilities.keys.toList();
    final allItems = [...keys, ...extras];
    final rows = <Widget>[];

    for (int i = 0; i < allItems.length; i += 2) {
      final isExtra1 = i >= keys.length;
      final label1 = allItems[i];
      final checked1 = isExtra1 ? true : facilities[label1]!;

      Widget left = _facilityCheck(
          label1,
          checked1,
          isExtra1
              ? () {}
              : () =>
                  setState(() => facilities[label1] = !facilities[label1]!));

      Widget right;
      if (i + 1 < allItems.length) {
        final isExtra2 = (i + 1) >= keys.length;
        final label2 = allItems[i + 1];
        final checked2 = isExtra2 ? true : facilities[label2]!;
        right = _facilityCheck(
            label2,
            checked2,
            isExtra2
                ? () {}
                : () =>
                    setState(() => facilities[label2] = !facilities[label2]!));
      } else {
        // Last item alone — show Add More in second column
        right = GestureDetector(
          onTap: () => _showAddFacility(extras),
          child: const Text('Add More',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline)),
        );
      }

      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [Expanded(child: left), Expanded(child: right)]),
      ));
    }

    // If even count, Add More goes on its own row
    if (allItems.length.isEven) {
      rows.add(GestureDetector(
        onTap: () => _showAddFacility(extras),
        child: const Text('Add More',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                decoration: TextDecoration.underline)),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  // ════════════════════════════════════
  // PG SECTION
  // ════════════════════════════════════
  Widget _buildPgSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Room Details'),
        const FieldLabel('Available for'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _CheckChip(
                label: 'Boys',
                selected: _availableFor.contains('boys'),
                onTap: () => setState(() => _availableFor.contains('boys')
                    ? _availableFor.remove('boys')
                    : _availableFor.add('boys'))),
            _CheckChip(
                label: 'Girls',
                selected: _availableFor.contains('girls'),
                onTap: () => setState(() => _availableFor.contains('girls')
                    ? _availableFor.remove('girls')
                    : _availableFor.add('girls'))),
            _CheckChip(
                label: 'Boys & Girls',
                selected: _availableFor.contains('boys_girls'),
                onTap: () => setState(() => _availableFor.contains('boys_girls')
                    ? _availableFor.remove('boys_girls')
                    : _availableFor.add('boys_girls'))),
            _CheckChip(
                label: 'Family',
                selected: _availableFor.contains('family'),
                onTap: () => setState(() => _availableFor.contains('family')
                    ? _availableFor.remove('family')
                    : _availableFor.add('family'))),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: FieldLabel('Total Rooms')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border)),
              child: Text(_totalRoomsPgCtrl.text,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ),
            const SizedBox(width: 6),
            Column(children: [
              GestureDetector(
                onTap: () => setState(() {
                  int v = int.tryParse(_totalRoomsPgCtrl.text) ?? 12;
                  _totalRoomsPgCtrl.text = (v + 1).toString();
                }),
                child: const Icon(Icons.keyboard_arrow_up_rounded,
                    color: AppColors.primary, size: 28),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  int v = int.tryParse(_totalRoomsPgCtrl.text) ?? 12;
                  if (v > 1) _totalRoomsPgCtrl.text = (v - 1).toString();
                }),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary, size: 28),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 20),
        const FieldLabel('Select Room Occupancy Type'),
        const SizedBox(height: 10),
        ...[
          {'value': 'single', 'label': 'Single Occupancy'},
          {'value': 'double', 'label': 'Double Occupancy'},
          {'value': 'triple', 'label': 'Triple Occupancy'},
          {'value': 'any', 'label': 'Any'},
        ].map((item) => GestureDetector(
              onTap: () => setState(() => _occupancyType = item['value']!),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: _occupancyType == item['value']
                      ? AppColors.primaryLight
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _occupancyType == item['value']
                          ? AppColors.primary
                          : AppColors.border,
                      width: 1.5),
                ),
                child: Row(children: [
                  Icon(
                      _occupancyType == item['value']
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _occupancyType == item['value']
                          ? AppColors.primary
                          : AppColors.textLight,
                      size: 20),
                  const SizedBox(width: 10),
                  Text(item['label']!,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _occupancyType == item['value']
                              ? AppColors.primary
                              : AppColors.textDark)),
                ]),
              ),
            )),
        const SizedBox(height: 12),
        const SizedBox(height: 8),
        _photoButton('Upload Room Photos', _pgPhotoBytes.length,
            () => _pickPhotos(_pgPhotoBytes, _pgPhotoNames)),
        if (_pgPhotoBytes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                  _pgPhotoBytes.length,
                  (i) => Stack(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(_pgPhotoBytes[i],
                                width: 64, height: 64, fit: BoxFit.cover)),
                        Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _pgPhotoBytes.removeAt(i);
                                _pgPhotoNames.removeAt(i);
                              }),
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 12)),
                            )),
                      ]))),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: AppColors.textDark),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  widget.propertyType == 'plot'
                      ? 'Enter Plot Details'
                      : 'Enter Property Details',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark),
                ),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Type Badge ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(typeIcon, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(typeLabel,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // ── Property Name ──
                    const FieldLabel('Property Name'),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: widget.propertyType == 'plot'
                            ? 'Enter Name of your Plot'
                            : 'Name of your Property',
                        prefixIcon: const Icon(Icons.home_outlined,
                            color: AppColors.textLight, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Location ──
                    const FieldLabel('Location'),
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: InputDecoration(
                        hintText: widget.propertyType == 'plot'
                            ? 'Enter Location of Plot'
                            : 'Enter Location of Property',
                        prefixIcon: const Icon(Icons.location_on_outlined,
                            color: AppColors.primary, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Landmark ──
                    const FieldLabel('Local Landmark (optional)'),
                    TextFormField(
                      controller: _landmarkCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Enter Local Landmark',
                        prefixIcon: Icon(Icons.place_outlined,
                            color: AppColors.textLight, size: 20),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Type-specific section ──
                    Builder(builder: (_) {
                      if (widget.propertyType == 'plot')
                        return _buildPlotSection();
                      if (widget.propertyType == 'guest')
                        return _buildGuestSection();
                      return _buildPgSection();
                    }),
                  ],
                ),
              ),
            ),

            // ── Bottom Button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: PrimaryButton(
                label: (widget.propertyType == 'plot' ||
                        widget.propertyType == 'guest')
                    ? 'Done'
                    : 'Next',
                isLoading: _isSaving,
                onPressed: _saveProperty,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CheckChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected)
            const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_rounded,
                    size: 14, color: AppColors.primary)),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textMuted)),
        ]),
      ),
    );
  }
}
