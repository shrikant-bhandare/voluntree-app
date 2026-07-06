import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';

class QrPassScreen extends StatefulWidget {
  final String applicationId;

  const QrPassScreen({super.key, required this.applicationId});

  @override
  State<QrPassScreen> createState() => _QrPassScreenState();
}

class _QrPassScreenState extends State<QrPassScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPass();
    });
  }

  void _loadPass() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final attendanceService = Provider.of<AttendanceService>(context, listen: false);

    if (authService.token != null) {
      attendanceService.fetchPassDetails(authService.token!, widget.applicationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final attendanceService = Provider.of<AttendanceService>(context);
    final pass = attendanceService.activePass;
    final isLoading = attendanceService.isLoading;
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Digital Entry Pass',
          style: GoogleFonts.plusJakartaSans(
            textStyle: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pass == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load entry pass',
                          style: TextStyle(color: Color(0xFF012D1D), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadPass,
                          style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Confirmed Volunteer',
                                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              pass.eventTitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                textStyle: TextStyle(color: theme.colorScheme.primary, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Your entry pass is ready for check-in',
                              style: TextStyle(color: Color(0xFF717973), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Main Ticket Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE8EFF1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            // Card Top Image Banner
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                                  child: Image.network(
                                    'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=600',
                                    height: 110,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  bottom: 12,
                                  left: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Garden Helper',
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              ],
                            ),

                            // Ticket Details Grid
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Color(0xFFF4FAFD)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('DATE', style: TextStyle(color: Color(0xFF717973), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${pass.startTime.day}/${pass.startTime.month}/${pass.startTime.year}',
                                              style: TextStyle(color: theme.colorScheme.primary, fontSize: 15, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('TIME', style: TextStyle(color: Color(0xFF717973), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${pass.startTime.hour.toString().padLeft(2, '0')}:${pass.startTime.minute.toString().padLeft(2, '0')} AM',
                                              style: TextStyle(color: theme.colorScheme.primary, fontSize: 15, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on, color: Color(0xFF006C48), size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('LOCATION', style: TextStyle(color: Color(0xFF717973), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                            const SizedBox(height: 2),
                                            Text(
                                              pass.address,
                                              style: const TextStyle(color: Color(0xFF161D1F), fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Dashed Perforation Line
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: List.generate(
                                  30,
                                  (index) => Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      height: 1,
                                      color: const Color(0xFFC1C8C2),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // QR Section
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE8EFF1)),
                                    ),
                                    child: QrImageView(
                                      data: pass.passToken,
                                      version: QrVersions.auto,
                                      size: 160.0,
                                      gapless: false,
                                      foregroundColor: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Scan at North Gate for entry',
                                    style: TextStyle(color: Color(0xFF717973), fontSize: 11),
                                  )
                                ],
                              ),
                            ),

                            // Ticket Footer
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: theme.colorScheme.primaryContainer,
                                    child: Text(
                                      user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'V',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Volunteer', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                                        Text(
                                          user?.fullName ?? 'Alex Chen',
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('TICKET ID', style: TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold)),
                                      Text(
                                        '#VT-${widget.applicationId.substring(0, 4).toUpperCase()}-GC',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Instructions Box
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF717973), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Instructions',
                            style: GoogleFonts.plusJakartaSans(
                              textStyle: const TextStyle(color: Color(0xFF717973), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4FAFD),
                          border: const Border(left: BorderSide(color: Color(0xFF006C48), width: 4)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '"Please arrive 15 minutes early and show this pass at the gate. Gardening tools and gloves will be provided by the organizers."',
                          style: TextStyle(color: Color(0xFF414844), fontStyle: FontStyle.italic, fontSize: 12, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Add to wallet and action buttons
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () {},
                        icon: const Icon(Icons.wallet, size: 20),
                        label: const Text('Add to Apple Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8EFF1),
                                foregroundColor: const Color(0xFF012D1D),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              onPressed: () {},
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('PDF', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8EFF1),
                                foregroundColor: const Color(0xFF012D1D),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              onPressed: () {},
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}
