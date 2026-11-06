import 'package:flutter/material.dart';

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
      home: const PlaceholderHome(),
    );
  }
}

/// Temporary screen to check fonts and colors. Replaced by the role screen next.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Saarthi.AI',
                  style: textTheme.headlineLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Always here for you',
                  style: AppTextStyles.tagline, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Text('Body text in Nunito looks like this.',
                  style: textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: () {}, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}