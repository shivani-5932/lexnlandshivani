import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ContactUsScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const ContactUsScreen({super.key, this.user});
  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _city;
  late final TextEditingController _state;
  final TextEditingController _message = TextEditingController();

  bool _agree = false;
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user ?? const {};
    _name = TextEditingController(text: (u['name'] ?? '').toString());
    _mobile = TextEditingController(text: (u['phone'] ?? '').toString());
    _city = TextEditingController(text: (u['city'] ?? '').toString());
    _state = TextEditingController(text: (u['state'] ?? '').toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _city.dispose();
    _state.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final msg = _message.text.trim();
    if (_name.text.trim().isEmpty ||
        _mobile.text.trim().isEmpty ||
        msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in name, mobile and message'),
          backgroundColor: C.error));
      return;
    }
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please accept the terms to continue'),
          backgroundColor: C.error));
      return;
    }
    setState(() => _sending = true);

    // Composed so it lands in the same support-ticket / admin problem inbox.
    final composed = 'Contact request\n\n'
        'Name: ${_name.text.trim()}\n'
        'Mobile: ${_mobile.text.trim()}\n'
        'City: ${_city.text.trim().isEmpty ? "-" : _city.text.trim()}\n'
        'State: ${_state.text.trim().isEmpty ? "-" : _state.text.trim()}\n\n'
        'Message:\n$msg';

    try {
      await Api.submitProblem(composed);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: C.error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: const Text('Contact Us')),
      body: SafeArea(child: _sent ? _success() : _form()),
    );
  }

  Widget _success() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.primaryLight,
                border: Border.all(
                    color: C.primary.withValues(alpha: 0.22), width: 7),
              ),
              child: const Center(
                child: Icon(Icons.verified_user_rounded,
                    color: C.primary, size: 58),
              ),
            ),
            const SizedBox(height: 22),
            const Text('Connection Request Sent',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: C.textDark)),
            const SizedBox(height: 8),
            const Text('Our team will contact you soon !',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.textMuted, height: 1.4)),
            const SizedBox(height: 28),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'))),
          ]),
        ),
      );

  Widget _form() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Get in touch',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: C.textDark)),
          const SizedBox(height: 4),
          const Text("Send us your query and we'll reply to your email.",
              style: TextStyle(color: C.textMuted)),
          const SizedBox(height: 20),
          _field(_name, 'Full Name', Icons.person_outline),
          _field(_mobile, 'Mobile number', Icons.phone_outlined,
              keyboard: TextInputType.phone),
          _field(_city, 'City', Icons.location_city_outlined),
          _field(_state, 'State', Icons.map_outlined),
          _field(_message, 'Message', Icons.message_outlined, maxLines: 5),
          const SizedBox(height: 4),
          Row(children: [
            Checkbox(
                value: _agree,
                activeColor: C.primary,
                onChanged: (v) => setState(() => _agree = v ?? false)),
            const Expanded(
                child: Text('I agree to be contacted regarding my query.',
                    style: TextStyle(fontSize: 13, color: C.textMuted))),
          ]),
          const SizedBox(height: 10),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_sending ? 'Sending…' : 'Submit'),
              )),
        ]),
      );

  Widget _field(TextEditingController c, String hint, IconData icon,
          {TextInputType? keyboard, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon:
                maxLines == 1 ? Icon(icon, size: 20, color: C.textMuted) : null,
          ),
        ),
      );
}
