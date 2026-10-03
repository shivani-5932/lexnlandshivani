import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'customer/theme/app_theme.dart';
import 'auth/splash_flow.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const LexNLandApp());
}

class LexNLandApp extends StatelessWidget {
  const LexNLandApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LexNLand',
      debugShowCheckedModeBanner: false,
      theme: customerTheme(), // one maroon theme for the whole app
      home: const SplashScreen(),
    );
  }
}
