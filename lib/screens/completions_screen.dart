import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';
import '../widgets/responsive.dart';
import '../utils/file_save.dart';
import '../theme/brand.dart';

/// Hands the PDF to the user: the system "Save to…" picker on Android/iOS
/// (the old app-private documents folder was invisible in Files) and a
/// browser download on the web build. Returns the message to show, or null
/// when the user cancelled.
Future<String?> _saveCertificate(Uint8List bytes, String attendanceId) async {
  final outcome = await saveBytesForUser(
    bytes: bytes,
    fileName: 'voluntree_certificate_$attendanceId.pdf',
    mimeType: 'application/pdf',
    dialogTitle: 'Save certificate',
  );
  switch (outcome) {
    case SaveOutcome.saved:
      return 'Certificate saved.';
    case SaveOutcome.cancelled:
      return null;
    case SaveOutcome.failed:
      return 'Could not save the certificate. Please try again.';
  }
}

class CompletionsScreen extends StatefulWidget {
  const CompletionsScreen({super.key});

  @override
  State<CompletionsScreen> createState() => _CompletionsScreenState();
}

class _CompletionsScreenState extends State<CompletionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.token != null) {
        Provider.of<AttendanceService>(
          context,
          listen: false,
        ).fetchHistory(auth.token!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final attService = Provider.of<AttendanceService>(context);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Completed Drives')),
      body: ResponsiveCenter(
        maxWidth: 840,
        child: attService.isLoading
            ? const Center(child: CircularProgressIndicator())
            : attService.history.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: Brand.goldContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events_outlined,
                          size: 40,
                          color: Brand.goldDeep,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No completed drives yet',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete drives and check-out to earn certificates.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Brand.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: attService.history.length,
                itemBuilder: (context, index) {
                  final item = attService.history[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: Brand.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Brand.mintWash,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item.eventCategory,
                                style: const TextStyle(
                                  color: Brand.mintText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: Brand.sage,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${item.hoursLogged.toStringAsFixed(1)} hrs',
                                  style: const TextStyle(
                                    color: Brand.ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.eventTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Brand.forest,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Completed on: ${item.checkOut != null ? "${item.checkOut!.day.toString().padLeft(2, '0')} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][item.checkOut!.month - 1]} ${item.checkOut!.year}" : "N/A"}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Brand.sage,
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Brand.gold,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Verified Completion',
                                  style: const TextStyle(
                                    color: Brand.goldDeep,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (auth.token == null) return;

                                // Show progress indicator
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                final bytes = await attService
                                    .downloadCertificate(auth.token!, item.id);

                                if (!context.mounted) return;
                                Navigator.pop(context); // Dismiss dialog

                                if (bytes != null && bytes.isNotEmpty) {
                                  final saved = await _saveCertificate(
                                    bytes,
                                    item.id,
                                  );
                                  if (!context.mounted || saved == null) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(saved),
                                      duration: const Duration(seconds: 6),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to download certificate. Please try again.',
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.file_download_outlined,
                                size: 16,
                              ),
                              label: const Text('Certificate'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
