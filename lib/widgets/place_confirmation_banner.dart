import 'package:flutter/material.dart';
import '../theme/brand.dart';
import '../utils/place_status.dart';

/// "Still coming?" on an approved place in the last 48 hours before a drive.
///
/// Organizers plan food, kits and transport from this answer, and a quiet
/// no-show is the most common reason a drive runs short.
class PlaceConfirmationBanner extends StatelessWidget {
  final PlacePrompt prompt;

  /// e.g. "tomorrow at 09:30" (see [placeStartsLabel]).
  final String startsLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool busy;

  const PlaceConfirmationBanner({
    super.key,
    required this.prompt,
    required this.startsLabel,
    required this.onConfirm,
    required this.onCancel,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    if (prompt == PlacePrompt.none) return const SizedBox.shrink();
    final confirmed = prompt == PlacePrompt.confirmed;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: confirmed ? Brand.mintWash : Brand.mistContainerLow,
        borderRadius: BorderRadius.circular(Brand.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                confirmed ? Icons.check_circle : Icons.event_available,
                size: 20,
                color: confirmed ? Brand.growth : Brand.forest,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  confirmed
                      ? "You're coming — starts $startsLabel"
                      : 'Starts $startsLabel. Still coming?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (!confirmed)
                FilledButton(
                  onPressed: busy ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.forest,
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text("Yes, I'll be there"),
                ),
              TextButton(
                onPressed: busy ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Brand.error,
                  minimumSize: const Size(0, 44),
                ),
                child: const Text("Can't make it"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
