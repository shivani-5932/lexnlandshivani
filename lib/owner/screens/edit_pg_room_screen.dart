import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
class EditPgRoomScreen extends StatelessWidget {
  const EditPgRoomScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Rooms'), backgroundColor: AppColors.background, elevation: 0),
    body: const Center(child: Text('Edit rooms coming soon')));
}
