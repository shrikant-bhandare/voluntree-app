import 'package:flutter/material.dart';
import '../theme/brand.dart';
import '../utils/place_status.dart';

/// The organizer's headcount for a drive: who said they are coming, who has
/// not answered the reminder yet, who cancelled, and who is waiting.
class RosterSummaryBar extends StatelessWidget {
  final RosterSummary summary;

  const RosterSummaryBar({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    Widget chip(String text, Color background, Color foreground) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Brand.radiusLg),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('${summary.confirmed} coming', Brand.mintWash, Brand.mintText),
          chip(
            '${summary.notReplied} not replied',
            Brand.mistContainer,
            Brand.inkMuted,
          ),
          if (summary.cancelled > 0)
            chip(
              '${summary.cancelled} cancelled',
              Brand.errorContainer,
              Brand.onErrorContainer,
            ),
          if (summary.waitlisted > 0)
            chip(
              '${summary.waitlisted} waiting',
              Brand.mistContainerHigh,
              Brand.canopy,
            ),
        ],
      ),
    );
  }
}
