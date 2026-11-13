import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Saarthi's face. Shows the VRoid PNG for the current emotion
/// (assets/avatar/neutral.png, happy.png, concerned.png). If a PNG is
/// missing, a simple expression icon is shown instead.
class SaarthiAvatar extends StatelessWidget {
  const SaarthiAvatar({super.key, required this.emotion, this.size = 120});

  final String emotion;
  final double size;

  String get _state => switch (emotion) {
        'happy' => 'happy',
        'concerned' => 'concerned',
        _ => 'neutral',
      };

  IconData get _icon => switch (_state) {
        'happy' => Icons.sentiment_very_satisfied_rounded,
        'concerned' => Icons.sentiment_dissatisfied_rounded,
        _ => Icons.sentiment_neutral_rounded,
      };

  Color get _color => switch (_state) {
        'happy' => AppColors.success,
        'concerned' => AppColors.primary,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Saarthi looks $_state',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(_state),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _color, width: 3),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/avatar/$_state.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  Icon(_icon, size: size * 0.7, color: _color),
            ),
          ),
        ),
      ),
    );
  }
} 