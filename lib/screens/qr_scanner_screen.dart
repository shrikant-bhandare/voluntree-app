import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';
import '../services/api_helpers.dart';
import '../services/event_service.dart';
import '../utils/drive_cta.dart';
import '../utils/event_time.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _codeController = TextEditingController();
  String? _selectedEventId;
  String? _codeError;
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isVerifying = false;
  bool _isProcessingCode = false;

  /// Set when the camera cannot run at all — notably every browser, where
  /// mobile_scanner reports `unsupported`. Without a fallback the organizer
  /// has no way to check anyone in, which matters while the app ships as a
  /// web build.
  bool _scannerUnavailable = false;
  PermissionStatus? _cameraPermissionStatus;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
    // Manual entry needs the organizer's own drives to pick from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthService>(context, listen: false);
      final events = Provider.of<EventService>(context, listen: false);
      if (auth.token != null && !events.hasLoadedMyEvents) {
        events.fetchMyEvents(auth.token!);
      }
    });
  }

  /// Drives that can take check-ins right now: the organizer's own
  /// ACTIVE/FEATURED/FULL drives.
  List<EventModel> _checkInDrives(EventService events) {
    return events.myEvents
        .where((e) => liveDriveStatuses.contains(e.status))
        .toList();
  }

  Future<void> _submitPassCode(List<EventModel> drives) async {
    final eventId =
        _selectedEventId ?? (drives.length == 1 ? drives.first.id : null);
    final code = normalizePassCode(_codeController.text);
    if (eventId == null) {
      setState(() => _codeError = 'Choose the drive you are checking in for.');
      return;
    }
    if (code.length != 8) {
      setState(
        () => _codeError =
            'Enter the 8-character code shown under the QR pass, e.g. K7QM-2XPA.',
      );
      return;
    }
    final authService = Provider.of<AuthService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(
      context,
      listen: false,
    );
    if (authService.token == null) return;
    setState(() {
      _codeError = null;
      _isVerifying = true;
    });
    final result = await attendanceService.verifyPassCode(
      authService.token!,
      eventId: eventId,
      passCode: code,
    );
    if (!mounted) return;
    setState(() => _isVerifying = false);
    if (result['success'] == true) {
      _codeController.clear();
      _showResultDialog(result);
    } else {
      setState(() => _codeError = result['message']);
    }
  }

  /// Readable copy for a scanner failure. The raw enum
  /// ("MobileScannerErrorCode.unsupported") was being shown to organizers.
  String _scannerMessage(MobileScannerException error) {
    if (kIsWeb || error.errorCode == MobileScannerErrorCode.unsupported) {
      return "Camera scanning is not available in this browser. Enter the volunteer's pass code below instead.";
    }
    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
      return "Camera access was denied. Allow the camera, or enter the pass code below.";
    }
    return "The camera could not be started. Enter the volunteer's pass code below instead.";
  }

  Future<void> _checkCameraPermission() async {
    if (kIsWeb) {
      // The browser prompts for camera access itself when the scanner
      // starts; permission_handler has no meaningful web implementation.
      setState(() {
        _cameraPermissionStatus = PermissionStatus.granted;
      });
      return;
    }

    final status = await Permission.camera.status;
    if (mounted) {
      setState(() {
        _cameraPermissionStatus = status;
      });
    }

    if (status != PermissionStatus.granted) {
      final requestStatus = await Permission.camera.request();
      if (mounted) {
        setState(() {
          _cameraPermissionStatus = requestStatus;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _submitToken(String tokenValue) async {
    if (tokenValue.trim().isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(
      context,
      listen: false,
    );

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
        _showResultDialog(result);
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

  void _showResultDialog(Map<String, dynamic> result) {
    final scanType = result['type']; // CHECK_IN or CHECK_OUT
    final message = result['message'];
    final time = parseServerDateOrNull(result['time']);
    final timeStr = time == null
        ? ''
        : '${formatLocalDate(time)} ${formatLocalTime(time)}';
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
                color: scanType == 'CHECK_IN'
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEC4899),
              ),
              const SizedBox(width: 8),
              Text(
                scanType == 'CHECK_IN'
                    ? 'Check-In Success'
                    : 'Check-Out Success',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Reputation points awarded: +$points',
                  style: const TextStyle(
                    color: Color(0xFFEAB308),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
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
        title: const Text(
          'Attendance Scanner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
                      if (_cameraPermissionStatus == null)
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF6366F1),
                            ),
                          ),
                        )
                      else if (_cameraPermissionStatus ==
                          PermissionStatus.granted)
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
                          errorBuilder: (context, error) {
                            // Flip to the manual fallback once we know the
                            // camera will never start. Scheduled out of build.
                            if (!_scannerUnavailable) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() => _scannerUnavailable = true);
                                }
                              });
                            }
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.redAccent,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _scannerMessage(error),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      else
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Color(0xFF94A3B8),
                                  size: 44,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Camera Access Required',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Please enable camera access to scan QR passes.',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (_cameraPermissionStatus ==
                                        PermissionStatus.permanentlyDenied) {
                                      await openAppSettings();
                                    } else {
                                      _checkCameraPermission();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    _cameraPermissionStatus ==
                                            PermissionStatus.permanentlyDenied
                                        ? 'Open Settings'
                                        : 'Grant Access',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Text(
                            'Align QR Pass within the frame',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Manual entry. Hidden while the camera works so the normal
              // path stays uncluttered, but shown whenever scanning is
              // impossible (every browser) so the screen is never a dead end.
              // The code is short-lived and checked server-side against the
              // chosen drive, so it is as trustworthy as a scan.
              if (kDebugMode || _scannerUnavailable)
                Consumer<EventService>(
                  builder: (context, events, _) {
                    final drives = _checkInDrives(events);
                    final selected = drives.any((d) => d.id == _selectedEventId)
                        ? _selectedEventId
                        : (drives.length == 1 ? drives.first.id : null);
                    return Container(
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
                            'Enter pass code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Choose the drive, then type the 8-character code shown under the volunteer's QR pass.",
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!events.hasLoadedMyEvents)
                            const Center(child: CircularProgressIndicator())
                          else if (drives.isEmpty)
                            const Text(
                              'You have no open drives to check volunteers in to.',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 13,
                              ),
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                              key: ValueKey(selected),
                              initialValue: selected,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Drive',
                                labelStyle: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: [
                                for (final d in drives)
                                  DropdownMenuItem(
                                    value: d.id,
                                    child: Text(
                                      '${d.title} · ${formatLocalDate(d.startTime)}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _selectedEventId = v),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              autocorrect: false,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontFamily: 'monospace',
                                letterSpacing: 3,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Pass code',
                                labelStyle: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                ),
                                hintText: 'XXXX-XXXX',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                                errorText: _codeError,
                                errorMaxLines: 3,
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _submitPassCode(drives),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isVerifying
                                  ? null
                                  : () => _submitPassCode(drives),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0E6C4A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isVerifying
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text('Check in or out'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
