import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../widgets/animated_button.dart';
import '../widgets/responsive.dart';
import 'direct_chat_screen.dart';
import 'create_event_screen.dart';
import '../utils/text_utils.dart';
import '../widgets/confirm_dialog.dart';

class VolunteerManagementScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const VolunteerManagementScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<VolunteerManagementScreen> createState() =>
      _VolunteerManagementScreenState();
}

class _VolunteerManagementScreenState extends State<VolunteerManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadApplications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final eventService = Provider.of<EventService>(context, listen: false);

    if (auth.token == null) return;

    setState(() {
      _isLoading = true;
    });

    final apps = await eventService.fetchEventApplications(
      auth.token!,
      widget.eventId,
    );

    if (!mounted) return;
    setState(() {
      _applications = apps;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(
    String applicationId,
    String status,
    String volunteerName,
  ) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final eventService = Provider.of<EventService>(context, listen: false);

    if (auth.token == null) return;

    final approving = status == 'APPROVED';
    final ok = await confirmAction(
      context,
      title: approving ? 'Approve $volunteerName?' : 'Decline $volunteerName?',
      message: approving
          ? 'They will be notified and receive an entry pass for this drive.'
          : 'They will be notified that their application was not accepted.',
      confirmLabel: approving ? 'Approve' : 'Decline',
      destructive: !approving,
    );
    if (!ok || !mounted) return;

    // Show inline loading or overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await eventService.updateApplicationStatus(
      auth.token!,
      applicationId,
      status,
    );

    if (mounted) {
      Navigator.of(context).pop(); // dismiss loading dialog

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approving ? 'Application approved.' : 'Application declined.',
            ),
          ),
        );
        _loadApplications(); // reload
        // The dashboard counts and the event's FULL/ACTIVE state come from
        // separate feeds — refresh them too, or they go stale until restart.
        eventService.fetchOrganizerApplications(auth.token!);
        eventService.fetchMyEvents(auth.token!);
        eventService.fetchEvents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Failed to update application status.',
            ),
          ),
        );
      }
    }
  }

  /// The drive's current status, from the organizer's own list.
  String? get _eventStatus {
    final eventService = Provider.of<EventService>(context, listen: false);
    for (final e in eventService.myEvents) {
      if (e.id == widget.eventId) return e.status;
    }
    return null;
  }

  Future<void> _confirmCancelDrive() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final eventService = Provider.of<EventService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (auth.token == null) return;

    final ok = await confirmAction(
      context,
      title: 'Cancel this drive?',
      message: 'Everyone who applied will be notified. This cannot be undone.',
      confirmLabel: 'Cancel drive',
      cancelLabel: 'Keep drive',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final result = await eventService.updateEventStatus(
      auth.token!,
      widget.eventId,
      'CANCELLED',
    );
    if (!mounted) return;
    if (result['success'] == true) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Drive cancelled. Applicants have been notified.'),
        ),
      );
      eventService.fetchMyEvents(auth.token!);
      eventService.fetchOrganizerApplications(auth.token!);
      eventService.fetchEvents();
      navigator.pop(true);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Could not cancel the drive.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteEvent() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final eventService = Provider.of<EventService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (auth.token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete drive'),
        content: const Text(
          'Nobody has applied yet, so this drive can be deleted permanently. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await eventService.deleteEvent(
        auth.token!,
        widget.eventId,
      );

      if (mounted) {
        navigator.pop(); // dismiss loading spinner

        if (result['success']) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Event deleted successfully.')),
          );
          // Go back to the dashboard and trigger events list refresh
          eventService.fetchEvents();
          eventService.fetchMyEvents(auth.token!);
          navigator.pop(true);
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete event.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pending = _applications
        .where((app) => app['status'] == 'PENDING')
        .toList();
    final confirmed = _applications
        .where((app) => app['status'] == 'APPROVED')
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF0e6c4a)),
            tooltip: 'Edit Event',
            onPressed: () async {
              final eventService = Provider.of<EventService>(
                context,
                listen: false,
              );
              // Captured before the async gaps below.
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              // FULL/COMPLETED events are absent from the public list, so
              // look in the organizer's own list first and fall back to the
              // API before giving up.
              EventModel? event;
              for (final source in [
                eventService.myEvents,
                eventService.events,
              ]) {
                try {
                  event = source.firstWhere((e) => e.id == widget.eventId);
                  break;
                } catch (_) {
                  event = null;
                }
              }
              event ??= await eventService.fetchEventById(widget.eventId);
              if (!mounted) return;
              if (event == null) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Error: Could not retrieve event details for editing.',
                    ),
                  ),
                );
                return;
              }

              final result = await navigator.push(
                MaterialPageRoute(
                  builder: (context) => CreateEventScreen(eventToEdit: event),
                ),
              );

              if (result == true && mounted) {
                _loadApplications();
              }
            },
          ),
          // Cancel keeps every application, pass and logged hour; delete is
          // only offered for a drive nobody has applied to (the server
          // refuses otherwise, and its message is shown).
          if (!_isLoading &&
              !const {'CANCELLED', 'COMPLETED'}.contains(_eventStatus))
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert, color: theme.colorScheme.primary),
              onSelected: (value) {
                if (value == 'cancel') _confirmCancelDrive();
                if (value == 'delete') _confirmDeleteEvent();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel drive'),
                ),
                if (_applications.isEmpty)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete drive'),
                  ),
              ],
            ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Applications',
              style: GoogleFonts.plusJakartaSans(
                textStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              widget.eventTitle,
              style: const TextStyle(color: Color(0xFF717973), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: const Color(0xFF717973),
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Confirmed (${confirmed.length})'),
          ],
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 1000,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildApplicationsList(pending, true, theme),
                  _buildApplicationsList(confirmed, false, theme),
                ],
              ),
      ),
    );
  }

  Widget _buildApplicationsList(
    List<Map<String, dynamic>> items,
    bool isPending,
    ThemeData theme,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.group_outlined, size: 64, color: Colors.grey[350]),
              const SizedBox(height: 16),
              Text(
                isPending
                    ? 'No pending applications'
                    : 'No confirmed volunteers yet',
                style: const TextStyle(
                  color: Color(0xFF012D1D),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'New registrations will show up here immediately.',
                style: TextStyle(color: Color(0xFF717973), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final app = items[index];
        // The API names the relation `volunteer`; `user` was always empty.
        final userObj = app['volunteer'] ?? {};
        final profile = userObj['profile'] ?? {};
        final rawName = (userObj['fullName'] as String?)?.trim() ?? '';
        final name = rawName.isEmpty ? 'Volunteer' : rawName;
        // Contact details are only sent for APPROVED applicants (the API
        // strips them from pending rows), so never assume they exist.
        final email = (userObj['email'] as String?)?.trim() ?? '';
        final phone = (userObj['phoneNumber'] as String?)?.trim() ?? '';
        final contactLine = [
          email,
          phone,
        ].where((v) => v.isNotEmpty).join(' · ');
        final role = (app['roleRequested'] as String?)?.trim() ?? '';
        final message = (app['message'] as String?)?.trim() ?? '';
        final repScore = profile['reputationScore'] ?? 0;
        final repLevel = profile['reputationLevel'] ?? 'BRONZE';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EFF1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header volunteer identity
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Text(
                      initialOf(name),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Color(0xFF161D1F),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (!isPending) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF006C48),
                                size: 14,
                              ),
                            ],
                            const SizedBox(width: 8),
                            PremiumAnimatedButton(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DirectChatScreen(
                                      targetUserId: userObj['id'] ?? '',
                                      targetUserName: name,
                                    ),
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                color: Color(0xFF0e6c4a),
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                        if (contactLine.isNotEmpty)
                          Text(
                            contactLine,
                            style: const TextStyle(
                              color: Color(0xFF717973),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4FAFD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$repScore pts',
                          style: const TextStyle(
                            color: Color(0xFF0e6c4a),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        repLevel.replaceAll('_', ' '),
                        style: const TextStyle(
                          color: Color(0xFF717973),
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE8EFF1), height: 1),
              const SizedBox(height: 12),

              // Only what the volunteer actually sent.
              if (role.isNotEmpty) ...[
                Row(
                  children: [
                    const Text(
                      'ROLE REQUESTED: ',
                      style: TextStyle(
                        color: Color(0xFF717973),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (message.isNotEmpty) ...[
                const Text(
                  'MESSAGE FROM VOLUNTEER',
                  style: TextStyle(
                    color: Color(0xFF717973),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF414844),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],

              // Action buttons if pending
              if (isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PremiumAnimatedButton(
                        onTap: () => _updateStatus(app['id'], 'REJECTED', name),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red[200]!),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Reject',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PremiumAnimatedButton(
                        onTap: () => _updateStatus(app['id'], 'APPROVED', name),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0e6c4a),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Approve',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
