import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Shared layout for static info pages.
class _InfoPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoPage({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
        ),
      );
}

Widget _h(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(t,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark)),
    );

Widget _p(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(t,
          style: const TextStyle(
              fontSize: 14, color: AppColors.textMuted, height: 1.55)),
    );

// ─────────────────────────────────────────────────────────────
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});
  @override
  Widget build(BuildContext context) => _InfoPage(title: 'About Us', children: [
        _p('LexNLand helps plot owners list their land and reach genuine buyers directly. As an owner, you can publish verified plot listings, manage them, and chat with interested buyers — all from one app.'),
        _h('What you can do'),
        _p('• List your plots with photos, pricing and location.\n'
            '• Get your listings verified for buyer trust.\n'
            '• Chat directly with interested buyers.\n'
            '• Track your listings and account status.'),
        _h('Our Mission'),
        _p('To give plot owners a safe, direct and easy way to sell, without depending on middlemen.'),
        _h('Get in touch'),
        _p('Have a question or feedback? Use the Contact Us option in your profile and our team will be happy to help.'),
      ]);
}

// ─────────────────────────────────────────────────────────────
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _InfoPage(title: 'Terms & Conditions', children: [
        _p('By using the LexNLand owner app, you agree to the terms below. Please read them carefully.'),
        _h('1. Your account'),
        _p('You agree to provide accurate information about yourself and your business, and to keep your account details up to date.'),
        _h('2. Listings'),
        _p('You are responsible for the plots you list and the accuracy of their details. Listings are reviewed before going live, and may be rejected or suspended if they break our guidelines or the law.'),
        _h('3. Communication'),
        _p('The app lets you communicate directly with buyers. You are responsible for your own conversations and any agreements you reach.'),
        _h('4. Fees & payments'),
        _p('Registration or service fees, where charged, are shown at the time of payment and are non-refundable unless stated otherwise.'),
        _h('5. Changes'),
        _p('We may update these terms from time to time. Continued use of the app after changes means you accept the updated terms.'),
      ]);
}

// ─────────────────────────────────────────────────────────────
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _InfoPage(title: 'Privacy Policy', children: [
        _p('Your privacy matters to us. This policy explains what we collect and how we use it.'),
        _h('What we collect'),
        _p('We collect the details you provide — such as your name, business details, email, phone number, address and listing information — and information about how you use the app.'),
        _h('How we use it'),
        _p('We use your information to run the app, publish and verify your listings, let buyers contact you, respond to your support requests, and improve our service.'),
        _h('Sharing'),
        _p('We do not sell your personal data. Relevant listing and contact details are shown to buyers so they can reach you, and limited data may be shared with service providers who help us operate the app.'),
        _h('Your choices'),
        _p('You can update your profile details at any time, or contact us to request changes to your information.'),
        _h('Contact'),
        _p('For any privacy questions, reach us through the Contact Us option in your profile.'),
      ]);
}
