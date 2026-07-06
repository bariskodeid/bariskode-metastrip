import 'package:flutter/material.dart';

/// Typography system for MetaStrip app
/// Fonts: Bebas Neue (display), Space Mono (headings), IBM Plex Mono (body)
/// NOTE: Using system fonts temporarily until custom fonts are added
class AppTypography {
  AppTypography._();

  // Font families - using system fonts as fallback
  static const String bebasNeue = 'sans-serif'; // Will use system sans-serif
  static const String spaceMono = 'monospace'; // Will use system monospace
  static const String ibmPlexMono = 'monospace'; // Will use system monospace

  /// Display style - Bebas Neue 48sp
  static TextStyle display(Color color) => TextStyle(
        fontFamily: bebasNeue,
        fontSize: 48,
        fontWeight: FontWeight.w400,
        height: 1.0,
        letterSpacing: -0.5,
        color: color,
      );

  /// H1 - Space Mono Bold 20sp UPPERCASE
  static TextStyle h1(Color color) => TextStyle(
        fontFamily: spaceMono,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 0.5,
        color: color,
      );

  /// H2 - Space Mono Bold 16sp
  static TextStyle h2(Color color) => TextStyle(
        fontFamily: spaceMono,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 0.5,
        color: color,
      );

  /// H3 - Space Mono 14sp
  static TextStyle h3(Color color) => TextStyle(
        fontFamily: spaceMono,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.3,
        color: color,
      );

  /// Body - IBM Plex Mono 14sp
  static TextStyle body(Color color) => TextStyle(
        fontFamily: ibmPlexMono,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0,
        color: color,
      );

  /// Body Emphasis - IBM Plex Mono SemiBold 14sp
  static TextStyle bodyEmphasis(Color color) => TextStyle(
        fontFamily: ibmPlexMono,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.6,
        letterSpacing: 0,
        color: color,
      );

  /// Caption - IBM Plex Mono 12sp
  static TextStyle caption(Color color) => TextStyle(
        fontFamily: ibmPlexMono,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.2,
        color: color,
      );

  /// Monospace Data - IBM Plex Mono 12sp
  static TextStyle monospaceData(Color color) => TextStyle(
        fontFamily: ibmPlexMono,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0,
        color: color,
      );

  /// Button Label - Space Mono Bold 13sp UPPERCASE
  static TextStyle button(Color color) => TextStyle(
        fontFamily: spaceMono,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: 1.5,
        color: color,
      );

  /// Metadata Value - IBM Plex Mono 13sp
  static TextStyle metadataValue(Color color) => TextStyle(
        fontFamily: ibmPlexMono,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0,
        color: color,
      );

  /// Metadata Key - IBM Plex Mono 12sp
  static TextStyle metadataKey(Color color) => TextStyle(
        fontFamily: ibmPlexMono,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0,
        color: color,
      );

  /// Overline - IBM Plex Mono 10sp UPPERCASE
  static TextStyle overline(Color color) => TextStyle(
        fontFamily: ibmPlexMono,
        fontSize: 10,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 1.5,
        color: color,
      );
}
