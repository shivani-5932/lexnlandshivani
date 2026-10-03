import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Plot-only upload, as a 4-step wizard:
///   1/4  Property details (name, location, landmark)
///   2/4  Plot specifics (id, type, facing, size, dimensions, price)
///   3/4  Verification (registry, NOC, Aadhaar front/back)
///   4/4  Photos
/// Submit → createProperty → uploadPropertyPhotos → uploadDocuments → success.
class UploadPropertyScreen extends StatefulWidget {
  const UploadPropertyScreen({super.key});
  @override
  State<UploadPropertyScreen> createState() => _UploadPropertyScreenState();
}

class _UploadPropertyScreenState extends State<UploadPropertyScreen> {
  static const _type = 'plot';
  int _step = 0;
  bool _saving = false;
  bool _done = false;

  // Map pin captured silently — owner never sees coordinates.
  double? _lat;
  double? _lng;
  bool _gettingLoc = false;

  // ── Fields ──
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _mapCtrl = TextEditingController();
  final _plotIdCtrl = TextEditingController();
  final _plotSizeCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _totalPriceCtrl = TextEditingController();
  String? _plotType;
  String? _facing;

  static const _plotTypes = ['Residential', 'Commercial', 'Agricultural', 'Industrial'];
  static const _facings = ['East', 'West', 'North', 'South', 'North-East', 'North-West', 'South-East', 'South-West'];

  // ── Uploads ──
  final List<Uint8List> _photoBytes = [];
  final List<String> _photoNames = [];
  Uint8List? _registryBytes;
  String? _registryName;
  Uint8List? _nocBytes;
  String? _nocName;
  final String _idType = 'aadhaar';
  Uint8List? _idFrontBytes;
  String? _idFrontName;
  Uint8List? _idBackBytes;
  String? _idBackName;

  bool get _photosComplete => _photoBytes.isNotEmpty;
  bool get _registryComplete => _registryBytes != null;
  bool get _nocComplete => _nocBytes != null;
  bool get _idComplete => _idFrontBytes != null && _idBackBytes != null;

  double get _plotSize => double.tryParse(_plotSizeCtrl.text.trim()) ?? 0;
  double get _totalPrice => double.tryParse(_totalPriceCtrl.text.trim()) ?? 0;
  double get _pricePerSqft => _plotSize > 0 ? _totalPrice / _plotSize : 0;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _locationCtrl, _landmarkCtrl, _plotIdCtrl, _mapCtrl,
      _plotSizeCtrl, _lengthCtrl, _widthCtrl, _totalPriceCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _pickPhotos() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 80);
      if (picked.isEmpty) return;
      for (final xf in picked) {
        final bytes = await xf.readAsBytes();
        if (mounted) {
          setState(() {
            _photoBytes.add(bytes);
            _photoNames.add(xf.name);
          });
        }
      }
    } catch (e) {
      _snack('Could not pick photos: $e', AppColors.error);
    }
  }

  Map<String, dynamic> _buildDetails() => {
        'plotId': _plotIdCtrl.text.trim(),
        'plotType': _plotType,
        'facing': _facing,
        'plotSize': _plotSizeCtrl.text.trim(),
        'plotLength': _lengthCtrl.text.trim(),
        'plotWidth': _widthCtrl.text.trim(),
        'totalPrice': _totalPriceCtrl.text.trim(),
        'pricePerSqft': _pricePerSqft.round().toString(),
        'facilities': <String>[],
      };

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_nameCtrl.text.trim().isEmpty || _locationCtrl.text.trim().isEmpty) {
          _snack('Please enter the plot name and location', AppColors.error);
          return false;
        }
        return true;
      case 1:
        if (_plotSize <= 0 || _totalPrice <= 0) {
          _snack('Please enter a valid plot size and total price', AppColors.error);
          return false;
        }
        return true;
      case 2:
        if (!_registryComplete || !_nocComplete || !_idComplete) {
          _snack('Please upload the Registry, NOC and both sides of your Aadhaar', AppColors.error);
          return false;
        }
        return true;
      case 3:
        if (!_photosComplete) {
          _snack('Please add at least one plot photo', AppColors.error);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _gettingLoc = true);
    try {
      bool service = await Geolocator.isLocationServiceEnabled();
      if (!service) {
        _toast('Please turn on location/GPS and try again');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _toast('Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _toast('Location captured ✓');
    } catch (_) {
      _toast('Could not get your location. Try the Google Maps link instead.');
    } finally {
      if (mounted) setState(() => _gettingLoc = false);
    }
  }

  // When the owner pastes a Google Maps link, resolve it to a pin via backend.
  Future<void> _resolveFromLink() async {
    final link = _mapCtrl.text.trim();
    if (link.isEmpty) {
      _toast('Paste a Google Maps link first');
      return;
    }
    setState(() => _gettingLoc = true);
    try {
      final res = await ApiService.resolveLocation(link);
      final lat = (res['latitude'] as num?)?.toDouble();
      final lng = (res['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() {
          _lat = lat;
          _lng = lng;
        });
        _toast('Location found from link ✓');
      } else {
        _toast('Could not read that link');
      }
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _gettingLoc = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final res = await ApiService.createProperty(
        propertyType: _type,
        propertyName: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        localLandmark: _landmarkCtrl.text.trim(),
        mapLink: _mapCtrl.text.trim(),
        latitude: _lat,
        longitude: _lng,
        details: _buildDetails(),
      );
      final propertyId =
          (res['property']?['_id'] ?? res['property']?['id']) as String?;
      if (propertyId == null) {
        throw Exception('Property created but no ID was returned');
      }
      if (_photoBytes.isNotEmpty) {
        await ApiService.uploadPropertyPhotos(
          propertyId: propertyId,
          imageBytes: _photoBytes,
          fileNames: _photoNames,
        );
      }
      await ApiService.uploadDocuments(
        propertyId: propertyId,
        registryBytes: _registryBytes,
        registryFileName: _registryName,
        nocBytes: _nocBytes,
        nocFileName: _nocName,
        idType: _idType,
        idFrontBytes: _idFrontBytes,
        idFrontFileName: _idFrontName,
        idBackBytes: _idBackBytes,
        idBackFileName: _idBackName,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      _snack('Error: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _SuccessView(onFinish: () => Navigator.pop(context, true));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: _saving ? null : _back),
        title: const Text('Enter Property Details',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / 4,
                      minHeight: 6,
                      backgroundColor: AppColors.primaryLight,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${_step + 1}/4',
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: _buildStep(),
              ),
            ),
            // ── Bottom action ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : Text(_step < 3 ? 'Next' : 'Done',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _stepDetails();
      case 1:
        return _stepPlot();
      case 2:
        return _stepVerification();
      default:
        return _stepPhotos();
    }
  }

  // ── Step 1: details ──
  Widget _stepDetails() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Image.asset('assets/images/add_property.png',
                  height: 170, fit: BoxFit.contain)),
          const SizedBox(height: 12),
          _label('Plot Name 🏡'),
          _field(_nameCtrl, 'Enter name of your plot'),
          const SizedBox(height: 16),
          _label('Location 📍'),
          _field(_locationCtrl, 'Enter location of property'),
          const SizedBox(height: 16),
          _label('Local Landmark (optional)'),
          _field(_landmarkCtrl, 'Enter local landmark'),
          const SizedBox(height: 16),
          _label('Plot Location on Map 📍'),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Pin the plot so buyers can find it on the in-app map. Tap "Use Current Location" if you are at the plot, or paste a Google Maps link.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _gettingLoc ? null : _useCurrentLocation,
              icon: _gettingLoc
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('Use Current Location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Divider()),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('or',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12))),
              Expanded(child: Divider()),
            ]),
          ),
          _field(_mapCtrl, 'Paste the Google Maps link of the plot'),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _gettingLoc ? null : _resolveFromLink,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Find location from link'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 2, left: 4),
            child: Text(
              'Tip: in Google Maps → tap the spot → Share → Copy link, then paste it here.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
          if (_lat != null && _lng != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Location pinned — this plot will show on the map once verified.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600))),
              ]),
            ),
        ],
      );

  // ── Step 2: plot specifics ──
  Widget _stepPlot() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rowField('Plot ID (optional)', _plotIdCtrl, 'e.g. 10'),
          const SizedBox(height: 12),
          _dropdown('Plot Type', _plotType, _plotTypes,
              (v) => setState(() => _plotType = v)),
          const SizedBox(height: 12),
          _dropdown('Facing', _facing, _facings,
              (v) => setState(() => _facing = v)),
          const SizedBox(height: 20),
          _rowField('Plot Size (sq ft)', _plotSizeCtrl, 'e.g. 1500',
              number: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _rowField('Length (ft)', _lengthCtrl, '30', number: true)),
            const SizedBox(width: 12),
            Expanded(child: _rowField('Width (ft)', _widthCtrl, '50', number: true)),
          ]),
          const SizedBox(height: 20),
          _rowField('Total Plot Price (₹)', _totalPriceCtrl, 'e.g. 75000',
              number: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _kv('Price Per sq ft',
                  _pricePerSqft > 0 ? '₹ ${_pricePerSqft.round()}' : '—'),
              if (_plotSize > 0) ...[
                const SizedBox(height: 8),
                Text(
                    '${_plotSize.toStringAsFixed(0)} sq ft  =  '
                    '${(_plotSize * 0.112).toStringAsFixed(1)} Gaj  ·  '
                    '${(_plotSize * 0.0036).toStringAsFixed(2)} Marla',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ]),
          ),
        ],
      );

  // ── Step 3: verification hub ──
  Widget _stepVerification() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: Image.asset('assets/images/verification_hub.png',
                  height: 180, fit: BoxFit.contain)),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'To ensure safety and trust, please\nfill the following details',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 13.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 22),
          _verifyCard(
            icon: Icons.apartment_rounded,
            title: 'Property Documents',
            subtitle: 'Registry & NOC',
            done: _registryComplete && _nocComplete,
            onTap: _openPropertyDocs,
          ),
          const SizedBox(height: 14),
          _verifyCard(
            icon: Icons.verified_user_rounded,
            title: 'Verify Yourself',
            subtitle: 'Aadhaar card — front & back',
            done: _idComplete,
            onTap: _openSelfVerification,
          ),
        ],
      );

  // Opens the Property-documents upload sub-screen and stores the result.
  Future<void> _openPropertyDocs() async {
    final result = await Navigator.push<Map<String, _Pick>>(
      context,
      MaterialPageRoute(
        builder: (_) => _DocUploadScreen(
          appBarTitle: 'Property Documents',
          headerPlain: 'Upload Vet Documents For ',
          headerAccent: 'Verification',
          groups: const [
            _DocGroup('Upload Registry Documents', [_DocBox('registry', 'Upload Document')]),
            _DocGroup('Upload NOC Documents', [_DocBox('noc', 'Upload Document')]),
          ],
          initial: {
            if (_registryBytes != null)
              'registry': _Pick(_registryBytes!, _registryName ?? 'registry.jpg'),
            if (_nocBytes != null)
              'noc': _Pick(_nocBytes!, _nocName ?? 'noc.jpg'),
          },
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final r = result['registry'];
        final n = result['noc'];
        if (r != null) {
          _registryBytes = r.bytes;
          _registryName = r.name;
        }
        if (n != null) {
          _nocBytes = n.bytes;
          _nocName = n.name;
        }
      });
    }
  }

  // Opens the Aadhaar (self) verification sub-screen and stores the result.
  Future<void> _openSelfVerification() async {
    final result = await Navigator.push<Map<String, _Pick>>(
      context,
      MaterialPageRoute(
        builder: (_) => _DocUploadScreen(
          appBarTitle: 'Self Verification',
          headerPlain: 'Aadhaar Card ',
          headerAccent: 'Verification',
          headerShield: true,
          groups: const [
            _DocGroup('Upload Aadhaar Card', [
              _DocBox('idFront', 'Front'),
              _DocBox('idBack', 'Back'),
            ]),
          ],
          initial: {
            if (_idFrontBytes != null)
              'idFront': _Pick(_idFrontBytes!, _idFrontName ?? 'aadhaar_front.jpg'),
            if (_idBackBytes != null)
              'idBack': _Pick(_idBackBytes!, _idBackName ?? 'aadhaar_back.jpg'),
          },
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final f = result['idFront'];
        final b = result['idBack'];
        if (f != null) {
          _idFrontBytes = f.bytes;
          _idFrontName = f.name;
        }
        if (b != null) {
          _idBackBytes = b.bytes;
          _idBackName = b.name;
        }
      });
    }
  }

  Widget _verifyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool done,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: done ? AppColors.success : AppColors.border,
                width: done ? 1.4 : 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(done ? 'Uploaded ✓' : subtitle,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: done ? AppColors.success : AppColors.textMuted)),
                ],
              ),
            ),
            Icon(done ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: done ? AppColors.success : AppColors.textMuted),
          ]),
        ),
      );

  // ── Step 4: photos ──
  Widget _stepPhotos() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickPhotos,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add, color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 16),
                const Text('Upload Plot Photos',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          if (_photoBytes.isNotEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(_photoBytes.length, (i) {
                return Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_photoBytes[i],
                        width: 90, height: 90, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _photoBytes.removeAt(i);
                        _photoNames.removeAt(i);
                      }),
                      child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white)),
                    ),
                  ),
                ]);
              }),
            ),
        ],
      );

  // ── small helpers ──
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
      );

  Widget _field(TextEditingController c, String hint) => TextField(
        controller: c,
        decoration: _dec(hint),
      );

  Widget _rowField(String label, TextEditingController c, String hint,
      {bool number = false, ValueChanged<String>? onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
        onChanged: onChanged,
        decoration: _dec(hint),
      ),
    ]);
  }

  Widget _dropdown(String label, String? value, List<String> items,
      ValueChanged<String?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: _dec('Select $label'),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    ]);
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      );

  Widget _kv(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
        ],
      );
}

// ── Congratulations / finish ──
class _SuccessView extends StatelessWidget {
  final VoidCallback onFinish;
  const _SuccessView({required this.onFinish});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text('Congratulations your Property has been Uploaded',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Successfully !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.success,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 28),
              Image.asset('assets/images/property_uploaded.png',
                  width: 260, fit: BoxFit.contain),
              const SizedBox(height: 12),
              const Text('It is now under review by our team.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Finish',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Document upload sub-screen (Property Documents / Self Verification)
// ════════════════════════════════════════════════════════════════

/// A single picked file held in memory.
class _Pick {
  final Uint8List bytes;
  final String name;
  const _Pick(this.bytes, this.name);
}

/// One upload box: a unique [key] and the label shown on its footer.
class _DocBox {
  final String key;
  final String label;
  const _DocBox(this.key, this.label);
}

/// A titled group of one or more upload boxes.
class _DocGroup {
  final String title;
  final List<_DocBox> boxes;
  const _DocGroup(this.title, this.boxes);
}

/// Reusable upload screen used for both Property Documents (Registry + NOC)
/// and Self Verification (Aadhaar front + back). Returns a map of
/// box-key → picked file when the user submits, or null if they back out.
class _DocUploadScreen extends StatefulWidget {
  final String appBarTitle;
  final String headerPlain;
  final String headerAccent;
  final bool headerShield;
  final List<_DocGroup> groups;
  final Map<String, _Pick> initial;

  const _DocUploadScreen({
    required this.appBarTitle,
    required this.headerPlain,
    required this.headerAccent,
    required this.groups,
    required this.initial,
    this.headerShield = false,
  });

  @override
  State<_DocUploadScreen> createState() => _DocUploadScreenState();
}

class _DocUploadScreenState extends State<_DocUploadScreen> {
  late final Map<String, _Pick> _picks = {...widget.initial};

  List<String> get _allKeys =>
      widget.groups.expand((g) => g.boxes).map((b) => b.key).toList();

  Future<void> _pick(String key) async {
    try {
      final xf = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (xf == null) return;
      final bytes = await xf.readAsBytes();
      if (mounted) setState(() => _picks[key] = _Pick(bytes, xf.name));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not pick file: $e'),
            backgroundColor: AppColors.error),
      );
    }
  }

  void _submit() {
    final missing = _allKeys.where((k) => _picks[k] == null).isNotEmpty;
    if (missing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all documents to submit')),
      );
      return;
    }
    Navigator.pop(context, _picks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context)),
        title: Text(widget.appBarTitle,
            style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header (optional shield + accented title)
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.headerShield) ...[
                            Image.asset('assets/images/verified_shield.png',
                                height: 26),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text: widget.headerPlain,
                                    style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18)),
                                TextSpan(
                                    text: widget.headerAccent,
                                    style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18)),
                              ]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    for (final g in widget.groups) ...[
                      Center(
                        child: Text(g.title,
                            style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5)),
                      ),
                      const SizedBox(height: 12),
                      if (g.boxes.length == 1)
                        _UploadBox(
                          label: g.boxes.first.label,
                          pick: _picks[g.boxes.first.key],
                          onTap: () => _pick(g.boxes.first.key),
                        )
                      else
                        Row(
                          children: [
                            for (int i = 0; i < g.boxes.length; i++) ...[
                              if (i > 0) const SizedBox(width: 14),
                              Expanded(
                                child: _UploadBox(
                                  label: g.boxes[i].label,
                                  pick: _picks[g.boxes[i].key],
                                  onTap: () => _pick(g.boxes[i].key),
                                ),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "+" upload box with a maroon footer label (matches the mockup).
class _UploadBox extends StatelessWidget {
  final String label;
  final _Pick? pick;
  final VoidCallback onTap;
  const _UploadBox(
      {required this.label, required this.pick, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: pick == null
                  ? Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.4))),
                        child:
                            const Icon(Icons.add, color: AppColors.primary, size: 30),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(pick!.bytes, fit: BoxFit.cover),
                        const Positioned(
                          right: 6,
                          top: 6,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.success,
                            child: Icon(Icons.check,
                                size: 15, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
            ),
          ],
        ),
      ),
    );
  }
}
