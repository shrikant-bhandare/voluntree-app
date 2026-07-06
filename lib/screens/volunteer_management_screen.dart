import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../widgets/animated_button.dart';
import 'direct_chat_screen.dart';
import 'create_event_screen.dart';

class VolunteerManagementScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const VolunteerManagementScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<VolunteerManagementScreen> createState() => _VolunteerManagementScreenState();
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

    final apps = await eventService.fetchEventApplications(auth.token!, widget.eventId);

    setState(() {
      _applications = apps;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(String applicationId, String status) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final eventService = Provider.of<EventService>(context, listen: false);

    if (auth.token == null) return;

    // Show inline loading or overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await eventService.updateApplicationStatus(auth.token!, applicationId, status);

    if (mounted) {
      Navigator.of(context).pop(); // dismiss loading dialog

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Application $status successfully.')),
        );
        _loadApplications(); // reload
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to update application status.')),
        );
      }
    }
  }

  Future<void> _confirmDeleteEvent(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to permanently delete this event? This will also delete all related applications and attendance data. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final auth = Provider.of<AuthService>(context, listen: false);
      final eventService = Provider.of<EventService>(context, listen: false);

      if (auth.token == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await eventService.deleteEvent(auth.token!, widget.eventId);

      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading spinner

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully.')),
          );
          // Go back to the dashboard and trigger events list refresh
          eventService.fetchEvents();
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to delete event.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pending = _applications.where((app) => app['status'] == 'PENDING').toList();
    final confirmed = _applications.where((app) => app['status'] == 'APPROVED').toList();

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
              final eventService = Provider.of<EventService>(context, listen: false);
              try {
                final event = eventService.events.firstWhere((e) => e.id == widget.eventId);
                
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateEventScreen(eventToEdit: event),
                  ),
                );
                
                if (result == true) {
                  _loadApplications();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error: Could not retrieve event details for editing.')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete Event',
            onPressed: () => _confirmDeleteEvent(context),
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
          labelStyle: GoogleFonts.plusJakartaSans(textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Confirmed (${confirmed.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildApplicationsList(pending, true, theme),
                _buildApplicationsList(confirmed, false, theme),
              ],
            ),
    );
  }

  Widget _buildApplicationsList(List<Map<String, dynamic>> items, bool isPending, ThemeData theme) {
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
                isPending ? 'No pending applications' : 'No confirmed volunteers yet',
                style: const TextStyle(color: Color(0xFF012D1D), fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'New registrations will show up here immediately.',
                style: TextStyle(color: Color(0xFF717973), fontSize: 12),
                textAlign: TextAlign.center,
              )
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
        final userObj = app['user'] ?? {};
        final profile = userObj['profile'] ?? {};
        final name = userObj['fullName'] ?? 'Anonymous Volunteer';
        final email = userObj['email'] ?? '';
        final role = app['roleRequested'] ?? 'Helper';
        final message = app['message'] ?? 'Eager to contribute and support the team!';
        final repScore = profile['reputationScore'] ?? 100;
        final repLevel = profile['reputationLevel'] ?? 'BRONZE';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EFF1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
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
                      name[0].toUpperCase(),
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
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
                              style: const TextStyle(color: Color(0xFF161D1F), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (!isPending) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle, color: Color(0xFF006C48), size: 14),
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
                              child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF0e6c4a), size: 14),
                            ),
                          ],
                        ),
                        Text(
                          email,
                          style: const TextStyle(color: Color(0xFF717973), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4FAFD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$repScore pts',
                          style: const TextStyle(color: Color(0xFF0e6c4a), fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        repLevel.replaceAll('_', ' '),
                        style: const TextStyle(color: Color(0xFF717973), fontSize: 8, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE8EFF1), height: 1),
              const SizedBox(height: 12),

              // Position / Role details
              Row(
                children: [
                  const Text('ROLE REQUESTED: ', style: TextStyle(color: Color(0xFF717973), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(color: theme.colorScheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),

              // Candidate note / message statement
              const Text('STATEMENT / NOTES:', style: TextStyle(color: Color(0xFF717973), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(
                '"$message"',
                style: const TextStyle(color: Color(0xFF414844), fontStyle: FontStyle.italic, fontSize: 12, height: 1.4),
              ),

              // Action buttons if pending
              if (isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PremiumAnimatedButton(
                        onTap: () => _updateStatus(app['id'], 'REJECTED'),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red[200]!),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[700])),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PremiumAnimatedButton(
                        onTap: () => _updateStatus(app['id'], 'APPROVED'),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0e6c4a),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
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
