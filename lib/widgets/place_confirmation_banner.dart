import 'package:flutter/material.dart';
import '../theme/brand.dart';
import '../utils/place_status.dart';

/// An approved place on the "My drives" card: "Still coming?" in the last 48
/// hours before the drive, the answer once given, and before that the start
/// time with "Can't make it" (see [placePromptFor]).
///
/// Organizers plan food, kits and transport from this answer, and a quiet
/// no-show is the most common reason a drive runs short. A volunteer who
/// knows a week ahead that they cannot come must be able to say so then.
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
    final message = switch (prompt) {
      PlacePrompt.confirmed => "You're coming — starts $startsLabel",
      PlacePrompt.askToConfirm => 'Starts $startsLabel. Still coming?',
      PlacePrompt.cancelOnly || PlacePrompt.none => 'Starts $startsLabel',
    };

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
                  message,
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
              if (prompt == PlacePrompt.askToConfirm)
                FilledButton(
                  onPressed: busy ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.forest,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text("Yes, I'll be there"),
                ),
              TextButton(
                onPressed: busy ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Brand.error,
                  minimumSize: const Size(0, 48),
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
