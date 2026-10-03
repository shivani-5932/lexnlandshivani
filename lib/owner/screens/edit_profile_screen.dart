import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/state_city_picker.dart';
import '../utils/validators.dart';
import 'main_shell.dart';
import 'onboarding_payment_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> owner;
  final bool isOnboarding;
  const EditProfileScreen(
      {super.key, required this.owner, this.isOnboarding = false});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _occupationCtrl;
  late final TextEditingController _businessCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _altPhoneCtrl;
  late final TextEditingController _gstCtrl;
  String _gender = '';
  bool _saving = false;

  static const _genders = ['male', 'female', 'other'];

  @override
  void initState() {
    super.initState();
    final o = widget.owner;
    _nameCtrl = TextEditingController(text: o['name'] ?? '');
    _phoneCtrl = TextEditingController(text: o['phone'] ?? '');
    _occupationCtrl = TextEditingController(text: o['occupation'] ?? '');
    _businessCtrl = TextEditingController(text: o['businessName'] ?? '');
    _addressCtrl = TextEditingController(text: o['address'] ?? '');
    _cityCtrl = TextEditingController(text: o['city'] ?? '');
    _stateCtrl = TextEditingController(text: o['state'] ?? '');
    _pincodeCtrl = TextEditingController(text: o['pincode'] ?? '');
    _altPhoneCtrl = TextEditingController(text: o['altPhone'] ?? '');
    _gstCtrl = TextEditingController(text: o['gstNumber'] ?? '');
    _gender = (o['gender'] ?? '') as String;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _occupationCtrl,
      _businessCtrl,
      _addressCtrl,
      _cityCtrl,
      _stateCtrl,
      _pincodeCtrl,
      _altPhoneCtrl,
      _gstCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final missing = <String>[];
    if (_nameCtrl.text.trim().isEmpty) missing.add('Name');
    if (_gender.isEmpty) missing.add('Gender');
    if (_occupationCtrl.text.trim().isEmpty)
      missing.add('Occupation / Business type');
    if (_businessCtrl.text.trim().isEmpty)
      missing.add('Business / Individual name');
    if (_addressCtrl.text.trim().isEmpty) missing.add('Address');
    if (_cityCtrl.text.trim().isEmpty) missing.add('City');
    if (_stateCtrl.text.trim().isEmpty) missing.add('State');
    if (_pincodeCtrl.text.trim().isEmpty) missing.add('PIN code');
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill: ${missing.join(', ')}'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (!isValidName(_nameCtrl.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter a valid name (letters only)'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiService.updateProfile({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'gender': _gender,
        'occupation': _occupationCtrl.text.trim(),
        'businessName': _businessCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'altPhone': _altPhoneCtrl.text.trim(),
        'gstNumber': _gstCtrl.text.trim(),
      });
      if (mounted) {
        if (widget.isOnboarding) {
          // PAYMENT DISABLED — registration is free, go straight to the app.
          // (was: route to const OnboardingPaymentScreen())
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
              (_) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Profile updated'),
              backgroundColor: AppColors.success));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isOnboarding,
        title: Text(
            widget.isOnboarding ? 'Complete your profile' : 'Edit Profile'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section('Basic Details'),
            _field('Full Name', _nameCtrl),
            _field('Phone', _phoneCtrl, keyboard: TextInputType.phone),
            const Text('Gender',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                children: _genders
                    .map((g) => ChoiceChip(
                          label: Text(g[0].toUpperCase() + g.substring(1)),
                          selected: _gender == g,
                          onSelected: (_) => setState(() => _gender = g),
                          selectedColor: AppColors.primaryLight,
                          labelStyle: TextStyle(
                              color: _gender == g
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600),
                        ))
                    .toList()),
            const SizedBox(height: 16),
            _field('Occupation / Business type', _occupationCtrl),
            _section('Business & Address'),
            _field('Business / Individual name', _businessCtrl),
            _field('Full Address', _addressCtrl, maxLines: 2),
            StateCityPicker(
              state: _stateCtrl.text,
              city: _cityCtrl.text,
              accent: AppColors.primary,
              citySearch: ApiService.searchCities,
              onStateChanged: (s) => setState(() => _stateCtrl.text = s),
              onCityChanged: (c) => setState(() => _cityCtrl.text = c),
            ),
            const SizedBox(height: 14),
            _field('PIN code', _pincodeCtrl, keyboard: TextInputType.number),
            _section('Optional'),
            _field('Alternate / WhatsApp number', _altPhoneCtrl,
                keyboard: TextInputType.phone),
            _field('GST number (if business)', _gstCtrl),
            const SizedBox(height: 24),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Profile',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.primary)),
      );

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary)),
        ),
      ),
    );
  }
}
