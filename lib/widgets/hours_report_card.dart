import 'package:flutter/material.dart';
import '../theme/brand.dart';

/// Top of the Completed tab: a PDF of hours recorded with a QR check-in that colleges accept
/// for community-engagement credits, with a link anyone can verify.
class HoursReportCard extends StatelessWidget {
  final Future<void> Function() onDownload;
  final bool busy;

  const HoursReportCard({
    super.key,
    required this.onDownload,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Brand.mintWash,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Brand.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hours report for your college',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Brand.forest,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'A PDF of your hours recorded with a QR check-in, with a link your college can '
              'open to check it.',
              style: TextStyle(color: Brand.inkMuted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onDownload,
              icon: const Icon(Icons.download),
              label: const Text('Download report'),
              style: FilledButton.styleFrom(
                backgroundColor: Brand.forest,
                minimumSize: const Size(0, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
