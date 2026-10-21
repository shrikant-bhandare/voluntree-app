import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/api_helpers.dart';
import '../widgets/animated_button.dart';
import '../widgets/responsive.dart';
import '../services/report_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'direct_chat_screen.dart';
import 'qr_pass_screen.dart';
import 'edit_profile_screen.dart';
import '../utils/drive_cta.dart';
import '../utils/event_time.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel? event;
  final String? eventId;

  const EventDetailScreen({super.key, this.event, this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Future<void> _openExternalMap(
    BuildContext context,
    double? lat,
    double? lng,
    String address,
  ) async {
    String url;
    if (lat != null && lng != null) {
      url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    } else {
      url =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    }
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open a maps app.')),
        );
      }
    }
  }

  final _messageController = TextEditingController();
  EventModel? _event;
  bool _fetching = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _resolveEvent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final eventService = Provider.of<EventService>(context, listen: false);
      if (authService.token != null &&
          authService.currentUser?.userType == 'VOLUNTEER') {
        eventService.fetchUserApplications(authService.token!);
      }
      _refreshFromApi();
    });
  }

  /// Seed from whatever is cached so the screen paints immediately; the API
  /// record (with approvedCount) replaces it in [_refreshFromApi]. The old
  /// version substituted the first cached event — or a hard-coded fake —
  /// when the id was not cached, showing a *different* drive.
  void _resolveEvent() {
    if (widget.event != null) {
      _event ??= widget.event;
      return;
    }
    if (widget.eventId == null || _event != null) return;
    final eventService = Provider.of<EventService>(context, listen: false);
    for (final source in [eventService.events, eventService.myEvents]) {
      for (final evt in source) {
        if (evt.id == widget.eventId) {
          _event = evt;
          return;
        }
      }
    }
  }

  Future<void> _refreshFromApi() async {
    final id = widget.eventId ?? widget.event?.id;
    if (id == null || _fetching) return;
    _fetching = true;
    final eventService = Provider.of<EventService>(context, listen: false);
    final fresh = await eventService.fetchEventById(id);
    if (!mounted) return;
    setState(() {
      _fetching = false;
      if (fresh != null) {
        _event = fresh;
        _loadFailed = false;
      } else if (_event == null) {
        _loadFailed = true;
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Returns true when the application was accepted (the sheet is popped).
  Future<bool> _apply(String? position) async {
    if (_event == null) return false;

    final authService = Provider.of<AuthService>(context, listen: false);
    final eventService = Provider.of<EventService>(context, listen: false);

    if (authService.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first to apply for this event.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    // Local overlap check
    final isVolunteer = authService.currentUser?.userType == 'VOLUNTEER';
    if (isVolunteer) {
      final newStart = _event!.startTime;
      final newEnd = _event!.endTime;

      final overlapping = eventService.userApplications.firstWhere((app) {
        if (app['status'] != 'APPROVED') return false;
        final evt = app['event'];
        if (evt == null) return false;
        final start = parseServerDateOrNull(evt['startTime']);
        final end = parseServerDateOrNull(evt['endTime']);
        if (start == null || end == null) return false;

        return start.isBefore(newEnd) && end.isAfter(newStart);
      }, orElse: () => null);

      if (overlapping != null) {
        final title = overlapping['event']['title'] ?? 'another event';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Time Conflict: You are already confirmed for "$title" at this time.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return false;
      }
    }

    final result = await eventService.applyForEvent(
      token: authService.token!,
      eventId: _event!.id,
      roleRequested: position,
      message: _messageController.text.trim(),
    );

    if (!mounted) return false;
    if (result['success']) {
      Navigator.of(context).pop(); // Dismiss sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            position == null
                ? 'Applied to "${_event!.title}". The organizer will review your application.'
                : 'Applied to "${_event!.title}" as $position. The organizer will review your application.',
          ),
          backgroundColor: const Color(0xFF006C48),
        ),
      );
      _refreshFromApi();
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: Colors.redAccent,
      ),
    );
    return false;
  }

  void _showApplyBottomSheet(String? position) {
    if (_event == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // Owned by the sheet's own StatefulBuilder: a flag on the screen's
        // State never re-rendered this route, so the button stayed enabled
        // and a double tap sent two applications.
        bool submitting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        position == null
                            ? 'Apply to this drive'
                            : 'Apply for Position',
                        style: GoogleFonts.plusJakartaSans(
                          textStyle: const TextStyle(
                            color: Color(0xFF012D1D),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF717973)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (position != null)
                    Text(
                      'Role: $position',
                      style: const TextStyle(
                        color: Color(0xFF006C48),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    style: const TextStyle(color: Color(0xFF161D1F)),
                    decoration: InputDecoration(
                      hintText:
                          'Introduce yourself or add an optional message for the organizer...',
                      hintStyle: const TextStyle(color: Color(0xFF717973)),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            setModalState(() => submitting = true);
                            final ok = await _apply(position);
                            // On success the sheet has already been popped.
                            if (!ok && context.mounted) {
                              setModalState(() => submitting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF012D1D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Submit Application',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = _event;

    if (e == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: _loadFailed
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 56,
                        color: Color(0xFFBA1A1A),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This event could not be loaded.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'It may have been removed, or you may be offline.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF717973)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshFromApi,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final authService = Provider.of<AuthService>(context);
    final eventService = Provider.of<EventService>(context);
    final isVolunteer = authService.currentUser?.userType == 'VOLUNTEER';

    Map<String, dynamic>? myApp;
    if (isVolunteer) {
      try {
        final match = eventService.userApplications.firstWhere(
          (app) => app['eventId'] == e.id,
          orElse: () => null,
        );
        if (match != null) {
          myApp = Map<String, dynamic>.from(match);
        }
      } catch (_) {}
    }

    final cta = detailCtaFor(
      status: e.status,
      endTime: e.endTime,
      minAge: e.minAge,
      dateOfBirth: authService.currentUser?.dateOfBirth,
      applicationStatus: myApp?['status'] as String?,
    );

    final dateStr = formatLocalDate(e.startTime);
    final timeStr = formatLocalTime(e.startTime);
    final endTimeStr = formatLocalTime(e.endTime);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ResponsiveCenter(
        maxWidth: 900,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // High Fidelity Banner Image App Bar
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: theme.colorScheme.primary,
                  leading: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          (e.bannerUrl != null && e.bannerUrl!.isNotEmpty)
                              ? e.bannerUrl!
                              : 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=1000',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.green[100]),
                        ),
                        // Dark gradient overlay bottom matching web details
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Scroll Body
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      100,
                    ), // Extra bottom padding for floating bar
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Tags & Title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                e.category,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (e.isPaid)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Paid Stipend',
                                  style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          e.title,
                          style: GoogleFonts.plusJakartaSans(
                            textStyle: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildMetaChip(
                              icon: Icons.flag_outlined,
                              label: driveStatusLabel(e.status, e.endTime),
                              highlight:
                                  openDriveStatuses.contains(e.status) &&
                                  e.endTime.isAfter(DateTime.now()),
                            ),
                            _buildMetaChip(
                              icon: Icons.cake_outlined,
                              label: 'Ages ${e.minAge}+',
                            ),
                            if (e.isOnline)
                              _buildMetaChip(
                                icon: Icons.videocam_outlined,
                                label: 'Online drive',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Spots countdown badge status progress
                        Builder(
                          builder: (context) {
                            final double filledPct = e.volunteersNeeded > 0
                                ? (e.approvedCount / e.volunteersNeeded)
                                : 0.0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.people_outline,
                                      size: 16,
                                      color: Color(0xFF006C48),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${e.volunteersNeeded} slots requested',
                                      style: const TextStyle(
                                        color: Color(0xFF006C48),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${(filledPct * 100).round()}% filled',
                                      style: const TextStyle(
                                        color: Color(0xFF717973),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: filledPct.clamp(0.0, 1.0),
                                    backgroundColor: const Color(0xFFE8EFF1),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF006C48),
                                        ),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 32),

                        // Hosted By Organizer Section
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primary
                                  .withOpacity(0.1),
                              child: Icon(
                                Icons.domain,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        e.organizerName,
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      if (e.isOrganizerVerified)
                                        const Icon(
                                          Icons.verified,
                                          color: Color(0xFF006C48),
                                          size: 14,
                                        ),
                                    ],
                                  ),
                                  Text(
                                    e.isOrganizerVerified
                                        ? 'Verified NGO Organizer'
                                        : 'Pending Verification Host',
                                    style: TextStyle(
                                      color: e.isOrganizerVerified
                                          ? const Color(0xFF717973)
                                          : const Color(0xFFBA1A1A),
                                      fontSize: 11,
                                      fontWeight: e.isOrganizerVerified
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                color: Color(0xFF006C48),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DirectChatScreen(
                                      targetUserId: e.organizerId,
                                      targetUserName: e.organizerName,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        // About / Description Mission
                        Text(
                          'About the Mission',
                          style: GoogleFonts.plusJakartaSans(
                            textStyle: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.description,
                          style: const TextStyle(
                            color: Color(0xFF414844),
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                        if (e.isPaid && e.compensationDetails != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Compensation: ${e.compensationDetails!}',
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const Divider(height: 32),

                        // Date & Time Cards
                        _buildInfoCard(
                          icon: Icons.calendar_today_outlined,
                          title: 'Date & Time',
                          value: dateStr,
                          subtitle: 'Starts: $timeStr - Ends: $endTimeStr',
                        ),
                        const SizedBox(height: 12),
                        // Interactive Location Map Card with Redirection
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4FAFD),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8EFF1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFF006C48),
                                    radius: 18,
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Venue & Location',
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          e.address,
                                          style: const TextStyle(
                                            color: Color(0xFF414844),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (e.latitude != null &&
                                  e.longitude != null) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    Chip(
                                      label: Text(
                                        'Lat: ${e.latitude!.toStringAsFixed(4)}',
                                      ),
                                      backgroundColor: Colors.white,
                                      labelStyle: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF012D1D),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      avatar: const Icon(
                                        Icons.my_location,
                                        size: 14,
                                        color: Color(0xFF006C48),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Chip(
                                      label: Text(
                                        'Lng: ${e.longitude!.toStringAsFixed(4)}',
                                      ),
                                      backgroundColor: Colors.white,
                                      labelStyle: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF012D1D),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      avatar: const Icon(
                                        Icons.explore,
                                        size: 14,
                                        color: Color(0xFF006C48),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _openExternalMap(
                                  context,
                                  e.latitude,
                                  e.longitude,
                                  e.address,
                                ),
                                icon: const Icon(Icons.map, size: 18),
                                label: const Text(
                                  'Open & Navigate in Google / Apple Maps 🗺️',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF006C48),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 32),

                        // Positions: only what the organizer listed. No
                        // invented roles, spot counts or experience badges.
                        if (e.openPositions.isNotEmpty) ...[
                          Text(
                            'Open Positions',
                            style: GoogleFonts.plusJakartaSans(
                              textStyle: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: e.openPositions
                                .map(
                                  (pos) => SizedBox(
                                    width: 200,
                                    child: _buildPositionCard(
                                      title: pos,
                                      onTap: cta.kind == DetailCtaKind.apply
                                          ? () => _showApplyBottomSheet(pos)
                                          : null,
                                      buttonText:
                                          cta.kind == DetailCtaKind.apply
                                          ? 'Apply'
                                          : cta.label,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const Divider(height: 32),
                        ],

                        // Perks: only what the organizer listed.
                        if (e.perks.isNotEmpty) ...[
                          Text(
                            'Perks & Benefits',
                            style: GoogleFonts.plusJakartaSans(
                              textStyle: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: e.perks
                                .map(
                                  (perk) => _buildPerkChip(perk, Icons.check),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 30),
                        ],

                        // Spam Flag Warning Report Link
                        Align(
                          child: TextButton.icon(
                            onPressed: _showReportBottomSheet,
                            icon: const Icon(
                              Icons.flag_outlined,
                              color: Color(0xFFBA1A1A),
                              size: 16,
                            ),
                            label: const Text(
                              'Report spam, fraud, or abuse',
                              style: TextStyle(
                                color: Color(0xFFBA1A1A),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Floating bottom action details drawer sticky block
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Chat button
                      PremiumAnimatedButton(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DirectChatScreen(
                                targetUserId: e.organizerId,
                                targetUserName: e.organizerName,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE8EFF1)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Color(0xFF012D1D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Primary call to action
                      Expanded(
                        child: PremiumAnimatedButton(
                          onTap: switch (cta.kind) {
                            DetailCtaKind.viewPass => () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      QrPassScreen(applicationId: myApp!['id']),
                                ),
                              );
                            },
                            DetailCtaKind.apply => () => _showApplyBottomSheet(
                              null,
                            ),
                            DetailCtaKind.addDateOfBirth => () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EditProfileScreen(),
                                ),
                              );
                            },
                            DetailCtaKind.none => null,
                          },
                          child: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cta.enabled
                                  ? const Color(0xFF012D1D)
                                  : const Color(0xFFE8EFF1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              cta.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: cta.enabled
                                    ? Colors.white
                                    : const Color(0xFF414844),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8EFF1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF006C48), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF717973),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF161D1F),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF717973),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFA0F4C8) : const Color(0xFFE8EFF1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF012D1D)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF012D1D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard({
    required String title,
    required VoidCallback? onTap,
    required String buttonText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8EFF1)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF012D1D),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF4FAFD),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onTap,
              child: Text(
                buttonText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: onTap == null
                      ? const Color(0xFF717973)
                      : const Color(0xFF012D1D),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerkChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAFD),
        border: Border.all(color: const Color(0xFFE8EFF1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF006C48)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF414844),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportBottomSheet() {
    if (_event == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final reportService = Provider.of<ReportService>(context, listen: false);

    if (authService.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first to report this event.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    String selectedCategory = 'SPAM';
    final reasonController = TextEditingController();
    bool isSubmittingReport = false;
    String? reportError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Report Event',
                        style: TextStyle(
                          color: Color(0xFF012D1D),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Help us keep the community safe. Please select a reason for reporting "${_event!.title}":',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF161D1F)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF3F4F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'SPAM',
                        child: Text('Spam or Repetitive'),
                      ),
                      DropdownMenuItem(
                        value: 'FAKE_EVENT',
                        child: Text('Fake Event or Scam'),
                      ),
                      DropdownMenuItem(
                        value: 'HARASSMENT',
                        child: Text('Harassment or Hate Speech'),
                      ),
                      DropdownMenuItem(
                        value: 'FRAUD',
                        child: Text('Fraud or Illegal Activity'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedCategory = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: const TextStyle(color: Color(0xFF161D1F)),
                    decoration: InputDecoration(
                      hintText:
                          'What happened? (at least $minReportReasonLength characters)',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (reportError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      reportError!,
                      style: const TextStyle(
                        color: Color(0xFFBA1A1A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmittingReport
                        ? null
                        : () async {
                            final reason = reasonController.text.trim();
                            if (reason.length < minReportReasonLength) {
                              setModalState(() {
                                reportError =
                                    'Please describe the problem in at least $minReportReasonLength characters.';
                              });
                              return;
                            }

                            setModalState(() {
                              isSubmittingReport = true;
                              reportError = null;
                            });

                            final error = await reportService.submitReport(
                              token: authService.token!,
                              eventId: _event!.id,
                              category: selectedCategory,
                              reason: reason,
                            );

                            if (!mounted || !context.mounted) return;

                            if (error == null) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Thank you. The report has been sent to administrators.',
                                  ),
                                  backgroundColor: Color(0xFF0E6C4A),
                                ),
                              );
                            } else {
                              // Shown inside the sheet: a SnackBar would sit
                              // behind the modal and go unseen.
                              setModalState(() {
                                isSubmittingReport = false;
                                reportError = error;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBA1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: isSubmittingReport
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Submit Report',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      reasonController.dispose();
    });
  }
}
