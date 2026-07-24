import 'package:flutter/material.dart';

/// Ekipa color tokens — the "dusk" direction.
///
/// A deliberate single dark world: a near-black forest-floor ground, glass
/// surfaces with real depth, a living green that can actually glow, and one
/// warm ember accent used sparingly for the handful of moments that are
/// genuinely a human decision (arrival, commitment). This is a considered
/// choice, not an omission of light mode — the whole visual thesis is warmth
/// found in the dark, which a light inversion would undermine.
class EkipaColors extends ThemeExtension<EkipaColors> {
  const EkipaColors({
    required this.bg,
    required this.bgGradientTop,
    required this.bgGradientBottom,
    required this.glass,
    required this.glassStrong,
    required this.line,
    required this.lineSoft,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.textOnBrand,
    required this.moss,
    required this.mossDeep,
    required this.mossGlow,
    required this.ember,
    required this.emberSoft,
    required this.danger,
  });

  /// Base page/scaffold ground.
  final Color bg;
  final Color bgGradientTop;
  final Color bgGradientBottom;

  /// Translucent glass-card fill and its stronger (emphasis) variant.
  final Color glass;
  final Color glassStrong;

  /// Hairline borders on glass surfaces.
  final Color line;
  final Color lineSoft;

  final Color ink;
  final Color inkSoft;
  final Color inkFaint;

  /// Text drawn on top of the solid moss gradient button.
  final Color textOnBrand;

  /// The living green — owns the app.
  final Color moss;
  final Color mossDeep;

  /// Pure glow color — shadows, particles, connecting threads. Never a fill.
  final Color mossGlow;

  /// The one warm accent. Appears exactly twice: the arrival pulse, and the
  /// single real commitment button. Scarcity is what makes it read as
  /// intentional.
  final Color ember;
  final Color emberSoft;

  final Color danger;

  // ── The "paper" world ──────────────────────────────────────────────────
  // Ink colors for text drawn on the warm cream ticket/paper cards. These
  // never vary (single theme), so they live as constants rather than in the
  // ThemeExtension. Dark, warm, and readable on cream.
  static const paperInk = Color(0xFF2E2519);
  static const paperInkSoft = Color(0xFF6B5F4C);
  static const paperMoss = Color(0xFF3F5D3A); // section labels on paper
  static const paperEmber = Color(0xFF9A6A2E); // warm accent on paper
  static const paperLine = Color(0x33564A38); // perforation / hairline on paper

  static const dusk = EkipaColors(
    bg: Color(0xFF0A0F0A),
    bgGradientTop: Color(0xFF0A0F0A),
    bgGradientBottom: Color(0xFF0F150E),
    glass: Color(0x0BF3EEDF),
    glassStrong: Color(0x14F3EEDF),
    line: Color(0x17F3EEDF),
    lineSoft: Color(0x0DF3EEDF),
    ink: Color(0xFFF3EEDF),
    inkSoft: Color(0xFFC3CBB4),
    inkFaint: Color(0xFF77826B),
    textOnBrand: Color(0xFF0B1207),
    moss: Color(0xFF7FB077),
    mossDeep: Color(0xFF3E5A3C),
    mossGlow: Color(0xFF9FE08C),
    ember: Color(0xFFE8AC5D),
    emberSoft: Color(0xFF7A5A34),
    danger: Color(0xFFD97862),
  );

  @override
  EkipaColors copyWith({
    Color? bg,
    Color? bgGradientTop,
    Color? bgGradientBottom,
    Color? glass,
    Color? glassStrong,
    Color? line,
    Color? lineSoft,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? textOnBrand,
    Color? moss,
    Color? mossDeep,
    Color? mossGlow,
    Color? ember,
    Color? emberSoft,
    Color? danger,
  }) {
    return EkipaColors(
      bg: bg ?? this.bg,
      bgGradientTop: bgGradientTop ?? this.bgGradientTop,
      bgGradientBottom: bgGradientBottom ?? this.bgGradientBottom,
      glass: glass ?? this.glass,
      glassStrong: glassStrong ?? this.glassStrong,
      line: line ?? this.line,
      lineSoft: lineSoft ?? this.lineSoft,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkFaint: inkFaint ?? this.inkFaint,
      textOnBrand: textOnBrand ?? this.textOnBrand,
      moss: moss ?? this.moss,
      mossDeep: mossDeep ?? this.mossDeep,
      mossGlow: mossGlow ?? this.mossGlow,
      ember: ember ?? this.ember,
      emberSoft: emberSoft ?? this.emberSoft,
      danger: danger ?? this.danger,
    );
  }

  @override
  EkipaColors lerp(ThemeExtension<EkipaColors>? other, double t) {
    if (other is! EkipaColors) return this;
    return EkipaColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bgGradientTop: Color.lerp(bgGradientTop, other.bgGradientTop, t)!,
      bgGradientBottom: Color.lerp(bgGradientBottom, other.bgGradientBottom, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineSoft: Color.lerp(lineSoft, other.lineSoft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      textOnBrand: Color.lerp(textOnBrand, other.textOnBrand, t)!,
      moss: Color.lerp(moss, other.moss, t)!,
      mossDeep: Color.lerp(mossDeep, other.mossDeep, t)!,
      mossGlow: Color.lerp(mossGlow, other.mossGlow, t)!,
      ember: Color.lerp(ember, other.ember, t)!,
      emberSoft: Color.lerp(emberSoft, other.emberSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension EkipaColorsContext on BuildContext {
  EkipaColors get colors => Theme.of(this).extension<EkipaColors>()!;
}
