import 'package:flutter/material.dart';

import 'screens/role_selection_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SaarthiApp());
}

class SaarthiApp extends StatelessWidget {
  const SaarthiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saarthi.AI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const RoleSelectionScreen(),
    );
  }
}