import 'package:flutter/material.dart';

/// Voluntree brand tokens. DESIGN.md is the authority; this file is its
/// Flutter mirror. Screens should read these (or the Material roles that
/// [AppTheme] derives from them) instead of inventing hex values.
abstract final class Brand {
  // Forest: authority, commitment, structure.
  static const forest = Color(0xFF012D1D);
  static const canopy = Color(0xFF1B4332);
  static const canopyText = Color(0xFF86AF99);

  // Night tones for the camera scanner and chat, which stay dark on purpose.
  static const canopyHigh = Color(0xFF24543F);
  static const canopyMuted = Color(0xFF5E8271);
  static const leaf = Color(0xFF6FCF9E);

  // Growth: success, progress, confirmation.
  static const growth = Color(0xFF0E6C4A);
  static const mint = Color(0xFFA0F4C8);
  static const mintText = Color(0xFF19724F);
  static const mintWash = Color(0xFFE4F4EC);

  // Gold: verified trust and earned achievement only (verified NGO badges,
  // certificates, reputation levels, the top of the leaderboard). Never
  // decoration, never a second primary.
  static const gold = Color(0xFFC9A24A);
  static const goldDeep = Color(0xFF7A5A12);
  static const goldContainer = Color(0xFFF6ECD2);
  static const onGoldContainer = Color(0xFF4A3508);

  // Neutrals: mist canvas, white surfaces, pine ink.
  static const mist = Color(0xFFF4FAFD);
  static const surface = Color(0xFFFFFFFF);
  static const mistContainerLow = Color(0xFFEEF5F7);
  static const mistContainer = Color(0xFFE8EFF1);
  static const mistContainerHigh = Color(0xFFDDE4E6);
  static const ink = Color(0xFF161D1F);
  static const inkMuted = Color(0xFF414844);
  static const sage = Color(0xFF717973);
  static const sageLight = Color(0xFFC1C8C2);

  // Error: genuine errors and destructive actions only.
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Shape scale.
  static const radiusSm = 8.0;
  static const radius = 12.0;
  static const radiusLg = 20.0;
  static const radiusXl = 28.0;

  /// Resting cards: a forest-tinted whisper, offset and soft.
  static const cardShadow = [
    BoxShadow(color: Color(0x0D1B4332), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x081B4332), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Temporary surfaces: sheets, popovers, floating banners.
  static const overlayShadow = [
    BoxShadow(color: Color(0x1F1B4332), blurRadius: 32, offset: Offset(0, 12)),
  ];

  /// White content surface on the mist canvas.
  static final cardDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: mistContainer),
    boxShadow: cardShadow,
  );

  /// The forest gradient used on hero surfaces (impact card, drawer header,
  /// app icon). Two forest steps only: depth, not colour.
  static const forestGradient = LinearGradient(
    colors: [Color(0xFF0A3D29), forest],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
