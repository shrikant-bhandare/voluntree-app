import 'package:flutter/material.dart';
import '../theme/brand.dart';

/// Round, high-contrast action for app bars over photos. A 48x48 dp circle
/// (the minimum touch target) with a tooltip.
class AppBarCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const AppBarCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        child: IconButton(
          icon: Icon(icon, color: Brand.forest),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
