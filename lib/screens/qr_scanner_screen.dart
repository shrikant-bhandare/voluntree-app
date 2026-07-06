import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _tokenController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isVerifying = false;
  bool _isProcessingCode = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _submitToken(String tokenValue) async {
    if (tokenValue.trim().isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(context, listen: false);

    if (authService.token == null) return;

    setState(() {
      _isVerifying = true;
    });

    final result = await attendanceService.verifyScannedPass(
      authService.token!,
      tokenValue.trim(),
    );

    if (mounted) {
      setState(() {
        _isVerifying = false;
      });

      if (result['success']) {
        final scanType = result['type']; // CHECK_IN or CHECK_OUT
        final message = result['message'];
        final timeStr = result['time'] != null ? DateTime.parse(result['time']).toLocal().toString().split('.')[0] : '';
        final hours = result['hoursLogged'];
        final points = result['pointsAwarded'];

        // Pause scanner while showing results modal
        _scannerController.stop();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Row(
                children: [
                  Icon(
                    scanType == 'CHECK_IN' ? Icons.check_circle : Icons.exit_to_app,
                    color: scanType == 'CHECK_IN' ? const Color(0xFF10B981) : const Color(0xFFEC4899),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    scanType == 'CHECK_IN' ? 'Check-In Success' : 'Check-Out Success',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Time: $timeStr',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  if (scanType == 'CHECK_OUT') ...[
                    const SizedBox(height: 8),
                    Text(
                      'Hours Logged: $hours hrs',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Reputation Points Emailed: +$points pts',
                      style: const TextStyle(color: Color(0xFFEAB308), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Resume scanner
                    _scannerController.start();
                    setState(() {
                      _isProcessingCode = false;
                    });
                  },
                  child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
        _tokenController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.redAccent,
          ),
        );
        // Resume scan processing after error
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isProcessingCode = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Attendance Scanner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Real Camera scanner boundary box
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          if (_isProcessingCode) return;
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null) {
                              setState(() {
                                _isProcessingCode = true;
                              });
                              _submitToken(barcode.rawValue!);
                              break;
                            }
                          }
                        },
                      ),
                      // Overlay scan boundary line
                      Positioned(
                        top: 40,
                        left: 40,
                        right: 40,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC4899),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEC4899).withOpacity(0.6),
                                blurRadius: 8,
                              )
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Text(
                            'Align QR Pass within the frame',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Manual token input panel
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Development Verification Panel',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Paste the signed pass token below to simulate scanning.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _tokenController,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Paste token (e.g. app-id|volunteer-id|...)',
                        hintStyle: const TextStyle(color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isVerifying
                          ? null
                          : () => _submitToken(_tokenController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Verify Scanned Token'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
