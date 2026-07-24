import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
export '../theme/text_styles.dart' show EkipaTextVariant;

enum EkipaTone { normal, soft, faint, moss, mossGlow, ember, onBrand, danger }

Color _toneColor(EkipaTone tone, EkipaColors c) {
  return switch (tone) {
    EkipaTone.soft => c.inkSoft,
    EkipaTone.faint => c.inkFaint,
    EkipaTone.moss => c.moss,
    EkipaTone.mossGlow => c.mossGlow,
    EkipaTone.ember => c.ember,
    EkipaTone.onBrand => c.textOnBrand,
    EkipaTone.danger => c.danger,
    EkipaTone.normal => c.ink,
  };
}

/// The single typographic primitive. Every piece of text in the app should
/// go through this so type scale and tone stay consistent.
class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.variant = EkipaTextVariant.body,
    this.tone = EkipaTone.normal,
    this.center = false,
    this.style,
  });

  final String text;
  final EkipaTextVariant variant;
  final EkipaTone tone;
  final bool center;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text,
      textAlign: center ? TextAlign.center : null,
      style: variant.style.copyWith(color: _toneColor(tone, c)).merge(style),
    );
  }
}
