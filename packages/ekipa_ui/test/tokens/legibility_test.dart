import 'dart:ui';

import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 contrast ratio between two opaque colours.
double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // Legibility is a product requirement here, not a preference. It was reported
  // twice during the proof rounds as physically uncomfortable to read, so it is
  // held to the same standard as any other invariant in this repository: a
  // machine checks it on every commit, and a palette change that breaks it
  // fails the build rather than shipping and being noticed by the one person it
  // hurts.
  //
  // AA is 4.5:1 for normal text and 3:1 for large text (>=18.66px bold or
  // >=24px). Everything below is held to 4.5 regardless of size, because the
  // large-text allowance exists for headlines and this product's headlines are
  // read by someone walking to meet four strangers.
  const aa = 4.5;

  group('text on the ground', () {
    const ground = ZarColors.ground;

    test(
      'primary ink',
      () => expect(contrast(ZarColors.ink, ground), greaterThanOrEqualTo(aa)),
    );
    test(
      'muted ink',
      () => expect(
        contrast(ZarColors.inkMuted, ground),
        greaterThanOrEqualTo(aa),
      ),
    );

    test('faint ink — the disabled state — is still readable', () {
      // The usual treatment is to drop a disabled control to 30% opacity. That
      // is wrong here: a disabled primary button is showing someone *what the
      // decision would be* at the exact moment they are working out why they
      // cannot make it yet. Losing the fill is enough; losing the words is not.
      expect(contrast(ZarColors.inkFaint, ground), greaterThanOrEqualTo(aa));
    });

    test(
      'the accent',
      () => expect(contrast(ZarColors.ember, ground), greaterThanOrEqualTo(aa)),
    );
    test(
      'sand — the register reserved for people and places',
      () => expect(contrast(ZarColors.sand, ground), greaterThanOrEqualTo(aa)),
    );
    test(
      'sand, muted',
      () => expect(
        contrast(ZarColors.sandMuted, ground),
        greaterThanOrEqualTo(aa),
      ),
    );

    test('every state colour', () {
      for (final (name, colour) in <(String, Color)>[
        ('mint', ZarColors.mint),
        ('amber', ZarColors.amber),
        ('rose', ZarColors.rose),
      ]) {
        expect(
          contrast(colour, ground),
          greaterThanOrEqualTo(aa),
          reason: '$name on the ground',
        );
      }
    });
  });

  group('text on a card', () {
    test('holds on both raised surfaces', () {
      for (final surface in [ZarColors.surface, ZarColors.surfaceRaised]) {
        for (final ink in [
          ZarColors.ink,
          ZarColors.inkMuted,
          ZarColors.inkFaint,
          ZarColors.sand,
          ZarColors.ember,
        ]) {
          expect(contrast(ink, surface), greaterThanOrEqualTo(aa));
        }
      }
    });
  });

  test('the label on a filled primary button', () {
    // The one place ink sits on the accent rather than beside it.
    expect(
      contrast(ZarColors.emberInk, ZarColors.ember),
      greaterThanOrEqualTo(aa),
    );
  });

  test('the ground and its surfaces are distinguishable without a border', () {
    // Not a legibility rule — a layering one. The design has no shadows, so
    // value is the only thing separating a card from the page. If these ever
    // converge, every card silently becomes invisible.
    expect(
      ZarColors.surface.computeLuminance(),
      greaterThan(ZarColors.ground.computeLuminance()),
    );
    expect(
      ZarColors.surfaceRaised.computeLuminance(),
      greaterThan(ZarColors.surface.computeLuminance()),
    );
  });
}
