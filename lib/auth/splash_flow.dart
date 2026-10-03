import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../customer/theme/app_theme.dart';
import 'auth_gate.dart';

const String _kSeenOnboarding = 'seen_onboarding';

// ════════════════════════════════════════════════════════════════
//  1) Animated logo splash  (SplashScreen 01 → 02 → 03)
// ════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  }

  Future<void> _next() async {
    if (!mounted) return;
    bool seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(_kSeenOnboarding) ?? false;
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) =>
            seen ? const AuthGate() : const WelcomeScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final bgT = ((t - 0.5) / 0.18).clamp(0.0, 1.0);
        final bg = Color.lerp(Colors.white, C.primary, bgT)!;
        final scale = (0.65 + (t / 0.5) * 0.35).clamp(0.65, 1.0);
        final fade = (t / 0.25).clamp(0.0, 1.0);
        final white = bgT > 0.5;
        return Scaffold(
          backgroundColor: bg,
          body: Center(
            child: Opacity(
              opacity: fade,
              child: Transform.scale(
                scale: scale,
                child: Image.asset(
                  white
                      ? 'assets/images/logo_lexnland_white.png'
                      : 'assets/images/logo_lexnland.png',
                  width: 160,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  2) Welcome  (SplashScreen 04)
// ════════════════════════════════════════════════════════════════
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _next(BuildContext context) {
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // maroon header strip with white logo
          Container(
            width: double.infinity,
            color: C.primary,
            padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 12),
            child: Image.asset('assets/images/logo_lexnland_white.png',
                height: 46),
          ),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome,',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: C.primary)),
                const SizedBox(height: 4),
                const Text('Find Your\nPerfect Plot..!',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: C.textDark,
                        height: 1.15)),
                const SizedBox(height: 10),
                const Text("We'll Help You Buy & Sell Verified Plots.",
                    style: TextStyle(
                        fontSize: 13, color: C.textMuted, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/onboard_building.png',
                    fit: BoxFit.cover, alignment: Alignment.topCenter),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 20 + MediaQuery.of(context).padding.bottom,
                  child: _PrimaryButton(
                      label: 'Next', onTap: () => _next(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  3) Onboarding  (SplashScreen 05 — two pages)
// ════════════════════════════════════════════════════════════════
class _OnbData {
  final String leftImg, rightImg, title, subtitle;
  const _OnbData(this.leftImg, this.rightImg, this.title, this.subtitle);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    _OnbData(
        'assets/images/onboard_living.png',
        'assets/images/onboard_handshake.png',
        'Direct Contact with\nquick response',
        'Simplify the property booking process\nunder One Roof'),
    _OnbData(
        'assets/images/onboard_bedroom.png',
        'assets/images/onboard_building.png',
        'Verified listings with\nreal Photos',
        'Just search and select your\nfavorite property you want to locate'),
  ];

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSeenOnboarding, true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      _finish();
    } else {
      _pc.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                child: OutlinedButton(
                  onPressed: _finish,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.primary,
                    side: const BorderSide(color: C.primary),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Skip',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _OnbPage(data: _pages[i]),
              ),
            ),
            // dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? C.primary : C.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: _PrimaryButton(label: 'Next', onTap: _next),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnbPage extends StatelessWidget {
  final _OnbData data;
  const _OnbPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _OvalPair(left: data.leftImg, right: data.rightImg),
          const SizedBox(height: 40),
          Text(data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: C.textDark,
                  height: 1.25)),
          const SizedBox(height: 12),
          Text(data.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5, color: C.textMuted, height: 1.5)),
        ],
      ),
    );
  }
}

/// Two overlapping vertical-ellipse images (the duo-oval hero in the mockup).
class _OvalPair extends StatelessWidget {
  final String left, right;
  const _OvalPair({required this.left, required this.right});

  Widget _oval(String path) => ClipOval(
        child: Image.asset(path, width: 150, height: 224, fit: BoxFit.cover),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(offset: const Offset(-58, 0), child: _oval(left)),
          Transform.translate(offset: const Offset(58, 0), child: _oval(right)),
        ],
      ),
    );
  }
}

// ── shared maroon button ────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: C.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );
}
