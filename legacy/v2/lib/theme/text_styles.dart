import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The type scale. Fraunces — a soft, natural serif — carries the wordmark,
/// titles, and the italic "thesis" moments, given real room to be the hero
/// rather than a polite heading. Inter carries everything functional.
class EkipaTextStyles {
  static TextStyle get display => GoogleFonts.fraunces(
        fontSize: 64,
        height: 0.98,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
      );

  static TextStyle get title => GoogleFonts.fraunces(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      );

  /// The italic, editorial "thesis" line — used sparingly for the one
  /// emotional beat per screen.
  static TextStyle get thesis => GoogleFonts.fraunces(
        fontSize: 21,
        height: 1.35,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
      );

  static TextStyle get heading => GoogleFonts.fraunces(
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyStrong => GoogleFonts.inter(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get callout => GoogleFonts.inter(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get calloutStrong => GoogleFonts.inter(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 11.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w400,
      );
}

enum EkipaTextVariant {
  display,
  title,
  thesis,
  heading,
  body,
  bodyStrong,
  callout,
  calloutStrong,
  label,
  caption,
}

extension EkipaTextVariantStyle on EkipaTextVariant {
  TextStyle get style => switch (this) {
        EkipaTextVariant.display => EkipaTextStyles.display,
        EkipaTextVariant.title => EkipaTextStyles.title,
        EkipaTextVariant.thesis => EkipaTextStyles.thesis,
        EkipaTextVariant.heading => EkipaTextStyles.heading,
        EkipaTextVariant.body => EkipaTextStyles.body,
        EkipaTextVariant.bodyStrong => EkipaTextStyles.bodyStrong,
        EkipaTextVariant.callout => EkipaTextStyles.callout,
        EkipaTextVariant.calloutStrong => EkipaTextStyles.calloutStrong,
        EkipaTextVariant.label => EkipaTextStyles.label,
        EkipaTextVariant.caption => EkipaTextStyles.caption,
      };
}
