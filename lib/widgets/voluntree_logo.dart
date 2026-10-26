import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/brand.dart';

/// Colours for one rendering of the mark.
class MarkPalette {
  final Color leaf;
  final Color leafInner;
  final Color heart;
  final Color trunk;

  const MarkPalette({
    required this.leaf,
    required this.leafInner,
    required this.heart,
    required this.trunk,
  });

  /// For the forest badge and other dark surfaces.
  static const onForest = MarkPalette(
    leaf: Color(0xFF6FCF9E),
    leafInner: Brand.mint,
    heart: Brand.gold,
    trunk: Brand.mintWash,
  );

  /// For white and mist surfaces.
  static const onLight = MarkPalette(
    leaf: Brand.growth,
    leafInner: Color(0xFF2E8A62),
    heart: Brand.gold,
    trunk: Brand.forest,
  );
}

/// The Voluntree mark: a tree whose canopy is five raised leaves, like
/// hands lifted together, rising from one trunk. The centre leaf is gold:
/// the verified heart of the community.
class VoluntreeMarkPainter extends CustomPainter {
  final MarkPalette palette;

  const VoluntreeMarkPainter({this.palette = MarkPalette.onLight});

  // Leaves, outer to centre: angle from vertical (deg), length, width.
  static const _leaves = [
    (-74.0, 27.0, 12.5),
    (74.0, 27.0, 12.5),
    (-37.0, 33.0, 13.5),
    (37.0, 33.0, 13.5),
    (0.0, 37.0, 14.5),
  ];

  static const _hub = Offset(50, 54);

  Path _leaf(double angleDeg, double length, double width) {
    // A raised-palm teardrop pointing up from the origin: narrow at the
    // wrist, broad and round at the tip.
    final l = length, w = width;
    final p = Path()
      ..moveTo(0, 0)
      ..cubicTo(w * 0.10, -l * 0.18, w * 0.56, -l * 0.40, w * 0.52, -l * 0.68)
      ..cubicTo(w * 0.48, -l * 0.93, w * 0.20, -l, 0, -l)
      ..cubicTo(-w * 0.20, -l, -w * 0.48, -l * 0.93, -w * 0.52, -l * 0.68)
      ..cubicTo(-w * 0.56, -l * 0.40, -w * 0.10, -l * 0.18, 0, 0)
      ..close();
    final a = angleDeg * math.pi / 180;
    // Start each leaf a little away from the hub so the five read apart.
    final start = _hub + Offset(math.sin(a), -math.cos(a)) * 3.5;
    final m = Matrix4.identity()
      ..translateByDouble(start.dx, start.dy, 0, 1)
      ..rotateZ(a);
    return p.transform(m.storage);
  }

  // Rises to a point inside the canopy hub so leaves and trunk read as one
  // tree, then flares into roots.
  Path _trunk() => Path()
    ..moveTo(50, 52)
    ..cubicTo(51.4, 60, 52.2, 70, 53.6, 77)
    ..cubicTo(55, 83.5, 59.5, 88.6, 66, 90)
    ..lineTo(34, 90)
    ..cubicTo(40.5, 88.6, 45, 83.5, 46.4, 77)
    ..cubicTo(47.8, 70, 48.6, 60, 50, 52)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    canvas.drawPath(_trunk(), Paint()..color = palette.trunk);

    for (var i = 0; i < _leaves.length; i++) {
      final (angle, length, width) = _leaves[i];
      final color = i == _leaves.length - 1
          ? palette.heart
          : (i < 2 ? palette.leaf : palette.leafInner);
      canvas.drawPath(
        _leaf(angle, length, width),
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(VoluntreeMarkPainter old) => old.palette != palette;
}

/// The bare mark at [size].
class VoluntreeMark extends StatelessWidget {
  final double size;
  final MarkPalette palette;

  const VoluntreeMark({
    super.key,
    this.size = 40,
    this.palette = MarkPalette.onLight,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: VoluntreeMarkPainter(palette: palette)),
  );
}

/// Paints the app-icon badge: forest rounded square with the light mark.
/// [inset] is the fraction of the side kept clear around the mark; adaptive
/// and maskable icons need more room than a plain launcher icon.
class VoluntreeBadgePainter extends CustomPainter {
  final double inset;
  final bool rounded;

  const VoluntreeBadgePainter({this.inset = 0.07, this.rounded = true});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..shader = Brand.forestGradient.createShader(rect);
    if (rounded) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.235)),
        paint,
      );
    } else {
      canvas.drawRect(rect, paint);
    }
    // A soft light from the top-left, like sun through canopy.
    canvas.drawCircle(
      Offset(size.width * 0.28, size.height * 0.18),
      size.width * 0.75,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.28, size.height * 0.18),
                radius: size.width * 0.75,
              ),
            ),
    );
    final markSide = size.width * (1 - inset * 2);
    canvas.save();
    canvas.translate(size.width * inset, size.height * inset);
    const VoluntreeMarkPainter(
      palette: MarkPalette.onForest,
    ).paint(canvas, Size.square(markSide));
    canvas.restore();
  }

  @override
  bool shouldRepaint(VoluntreeBadgePainter old) =>
      old.inset != inset || old.rounded != rounded;
}

/// The app-icon badge as a widget, with a forest-tinted lift.
class VoluntreeBadge extends StatelessWidget {
  final double size;
  final bool shadow;

  const VoluntreeBadge({super.key, this.size = 72, this.shadow = true});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.235),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: Brand.canopy.withValues(alpha: 0.28),
                blurRadius: size * 0.4,
                offset: Offset(0, size * 0.16),
              ),
            ]
          : null,
    ),
    child: CustomPaint(painter: const VoluntreeBadgePainter()),
  );
}

/// The "Voluntree" wordmark in the brand face.
class VoluntreeWordmark extends StatelessWidget {
  final double fontSize;
  final Color color;

  const VoluntreeWordmark({
    super.key,
    this.fontSize = 28,
    this.color = Brand.forest,
  });

  @override
  Widget build(BuildContext context) => Text(
    'Voluntree',
    style: GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -fontSize * 0.03,
      color: color,
      height: 1.1,
    ),
  );
}

/// Mark and wordmark side by side, for app bars and headers.
class VoluntreeLockup extends StatelessWidget {
  final double height;
  final bool onDark;

  const VoluntreeLockup({super.key, this.height = 28, this.onDark = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      VoluntreeMark(
        size: height * 1.15,
        palette: onDark ? MarkPalette.onForest : MarkPalette.onLight,
      ),
      SizedBox(width: height * 0.3),
      VoluntreeWordmark(
        fontSize: height * 0.72,
        color: onDark ? Colors.white : Brand.forest,
      ),
    ],
  );
}
