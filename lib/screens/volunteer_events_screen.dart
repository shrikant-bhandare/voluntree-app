import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/attendance_service.dart';
import '../widgets/responsive.dart';
import 'event_detail_screen.dart';
import 'qr_pass_screen.dart';

class VolunteerEventsScreen extends StatefulWidget {
  const VolunteerEventsScreen({super.key});

  @override
  State<VolunteerEventsScreen> createState() => _VolunteerEventsScreenState();
}

class _VolunteerEventsScreenState extends State<VolunteerEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshData() {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token != null) {
      Provider.of<EventService>(
        context,
        listen: false,
      ).fetchUserApplications(auth.token!);
      Provider.of<AttendanceService>(
        context,
        listen: false,
      ).fetchHistory(auth.token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventService = Provider.of<EventService>(context);
    final attService = Provider.of<AttendanceService>(context);

    // Filter applications
    final applications = eventService.userApplications;
    final upcomingApps = applications
        .where((app) => app['status'] == 'APPROVED')
        .toList();
    final appliedApps = applications
        .where((app) => app['status'] != 'APPROVED')
        .toList();
    final completedHistory = attService.history;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'My Drives & Passes',
          style: GoogleFonts.plusJakartaSans(
            textStyle: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
            onPressed: _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: const Color(0xFF717973),
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Applied'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: TabBarView(
          controller: _tabController,
          children: [
            // 1. Upcoming approved drives tab
            _buildUpcomingTab(upcomingApps, theme),
            // 2. Applied drives tab
            _buildAppliedTab(appliedApps, theme),
            // 3. Completed drives tab
            _buildCompletedTab(completedHistory, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingTab(List<dynamic> upcoming, ThemeData theme) {
    if (upcoming.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available,
        title: 'No upcoming drives',
        subtitle: 'Apply for events in the Discover tab to start your journey.',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: upcoming.length,
      itemBuilder: (context, index) {
        final app = upcoming[index];
        final event = app['event'] ?? {};
        final eventId = event['id'] ?? '';
        final title = event['title'] ?? 'Drive Title';
        final address = event['address'] ?? 'Online';
        final category = event['category'] ?? 'General';
        final banner = event['bannerUrl'];
        final startTimeStr = event['startTime'] != null
            ? DateTime.parse(
                event['startTime'],
              ).toLocal().toString().substring(0, 16)
            : 'Unknown';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event banner/color top
              Stack(
                children: [
                  Image.network(
                    (banner != null && banner.toString().isNotEmpty)
                        ? banner
                        : 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=600',
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: const Color(0xFF0E6C4A), height: 110),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E6C4A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'APPROVED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF012D1D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          startTimeStr,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EventDetailScreen(eventId: eventId),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: theme.colorScheme.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text('Event Details'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      QrPassScreen(applicationId: app['id']),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF012D1D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: const Icon(Icons.qr_code_2, size: 16),
                            label: const Text('QR Entry Pass'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppliedTab(List<dynamic> applied, ThemeData theme) {
    if (applied.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No pending applications',
        subtitle: 'Your active and reviewed applications will appear here.',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: applied.length,
      itemBuilder: (context, index) {
        final app = applied[index];
        final event = app['event'] ?? {};
        final eventId = event['id'] ?? '';
        final title = event['title'] ?? 'Drive Title';
        final category = event['category'] ?? 'General';
        final status = app['status'] ?? 'PENDING';
        // The application's own timestamp — this row used to print the
        // event's start time as "Applied on".
        final appliedOnStr = app['createdAt'] != null
            ? (DateTime.tryParse(
                    app['createdAt'].toString(),
                  )?.toLocal().toString().substring(0, 16) ??
                  'Unknown')
            : 'Unknown';

        Color statusColor = const Color(0xFFEAB308); // Yellow
        if (status == 'REJECTED') {
          statusColor = const Color(0xFFBA1A1A); // Red
        } else if (status == 'WAITLISTED') {
          statusColor = const Color(0xFF3B82F6); // Blue
        } else if (status == 'UNDER_REVIEW') {
          statusColor = const Color(0xFFFD8704); // Orange
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(eventId: eventId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF012D1D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Applied on: $appliedOnStr',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedTab(List<dynamic> history, ThemeData theme) {
    if (history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.workspace_premium_outlined,
        title: 'No completed drives',
        subtitle: 'Your completed check-ins and hours will show here.',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        final eventTitle = item.eventTitle;
        final checkIn = item.checkIn.toLocal().toString().substring(0, 16);
        final checkOut = item.checkOut != null
            ? item.checkOut!.toLocal().toString().substring(11, 16)
            : '--:--';
        final hours = item.hoursLogged;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF012D1D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Check In: $checkIn | Check Out: $checkOut',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E6C4A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check,
                              size: 10,
                              color: Color(0xFF0E6C4A),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified Hours',
                              style: TextStyle(
                                color: Color(0xFF0E6C4A),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${hours.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0E6C4A),
                      ),
                    ),
                    const Text(
                      'Hours Logged',
                      style: TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: const Color(0xFF717973).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF012D1D),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF717973), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
