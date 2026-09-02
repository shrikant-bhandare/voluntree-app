import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Shared breakpoints for adaptive layouts. Widths at or above [desktop]
/// switch the home shell to a navigation rail; [tablet] is for intermediate
/// tweaks (grid columns, padding).
class Breakpoints {
  static const double tablet = 720;
  static const double desktop = 1000;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}

/// Centers [child] and caps its width so phone-designed screens stay readable
/// in desktop-sized windows while remaining edge-to-edge on phones.
class ResponsiveCenter extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ResponsiveCenter({super.key, this.maxWidth = 840, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Web/desktop users scroll with a mouse or trackpad; the default Material
/// behavior only accepts touch drags, which makes lists feel dead on web.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
