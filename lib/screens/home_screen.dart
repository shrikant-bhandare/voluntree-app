import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../widgets/animated_button.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';
import '../services/attendance_service.dart';
import 'discover_events_screen.dart';
import 'qr_scanner_screen.dart';
import 'leaderboard_screen.dart';
import 'create_event_screen.dart';
import 'volunteer_management_screen.dart';
import 'impact_analytics_screen.dart';
import 'notifications_screen.dart';
import 'completions_screen.dart';
import 'payments_screen.dart';
import 'event_detail_screen.dart';
import 'direct_chat_screen.dart';
import 'volunteer_events_screen.dart';
import 'edit_profile_screen.dart';
import 'event_feed_screen.dart';
import '../widgets/in_app_notification.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.token != null) {
        final notif = Provider.of<NotificationService>(context, listen: false);
        notif.fetchNotifications(authService.token!);
        notif.initSocket(authService.token!);
        
        // Listen for new notifications to show in-app banner
        notif.onNotificationReceived = (newNotif) {
          InAppNotification.show(
            context,
            title: newNotif.title,
            body: newNotif.body,
            icon: Icons.notifications_active_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          );
        };

        final chatService = Provider.of<ChatService>(context, listen: false);
        chatService.initSocket(authService.token!);
        chatService.fetchConversations(authService.token!);

        // Listen for incoming chat messages to show in-app banner
        chatService.onMessageReceived = (message) {
          if (chatService.activeChatUserId == message.senderId) return;

          InAppNotification.show(
            context,
            title: 'Message from ${message.senderName}',
            body: message.content,
            icon: Icons.chat_bubble_outline,
            iconColor: const Color(0xFFA0F4C8),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DirectChatScreen(
                    targetUserId: message.senderId,
                    targetUserName: message.senderName,
                  ),
                ),
              );
            },
          );
        };

        Provider.of<AttendanceService>(context, listen: false).fetchHistory(authService.token!);

        final isOrganizer = authService.currentUser?.userType == 'ORGANIZER' || authService.currentUser?.userType == 'ADMIN';
        if (isOrganizer) {
          Provider.of<EventService>(context, listen: false).fetchOrganizerApplications(authService.token!);
          Provider.of<EventService>(context, listen: false).fetchOrganizerAnalytics(authService.token!);
        }
      }
      // Load events globally
      Provider.of<EventService>(context, listen: false).fetchEvents();
    });
  }

  @override
  void dispose() {
    // Clean up callbacks to prevent memory leaks or context issues
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      chatService.onMessageReceived = null;
      chatService.disconnectSocket();
    } catch (_) {}
    try {
      final notif = Provider.of<NotificationService>(context, listen: false);
      notif.onNotificationReceived = null;
      notif.disconnectSocket();
    } catch (_) {}
    super.dispose();
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final theme = Theme.of(context);
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : const Color(0xFF717973),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.colorScheme.primary : const Color(0xFF717973),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final isOrganizer = user?.userType == 'ORGANIZER' || user?.userType == 'ADMIN';

    // Tabs List
    final List<Widget> tabs = isOrganizer
        ? [
            const OrganizerDashboardTab(),
            const CreateEventScreen(),
            const ChatListScreen(),
            const ImpactAnalyticsScreen(),
          ]
        : [
            const VolunteerDashboardTab(),
            const DiscoverEventsScreen(isEmbedded: true),
            const ChatListScreen(),
            const VolunteerProfileTab(),
          ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const Icon(Icons.volunteer_activism, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              isOrganizer ? 'Voluntree Hub' : 'Voluntree',
              style: GoogleFonts.plusJakartaSans(
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Notifications Bell
          Consumer<NotificationService>(
            builder: (context, notif, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                  if (notif.hasUnread)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFBA1A1A),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context, isOrganizer, user),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: isOrganizer
              ? [
                  _buildNavItem(0, Icons.dashboard_customize, 'Home'),
                  _buildNavItem(1, Icons.add_box, 'Create'),
                  _buildNavItem(2, Icons.chat, 'Chat'),
                  _buildNavItem(3, Icons.analytics, 'Analytics'),
                ]
              : [
                  _buildNavItem(0, Icons.home, 'Home'),
                  _buildNavItem(1, Icons.explore, 'Events'),
                  _buildNavItem(2, Icons.chat, 'Chat'),
                  _buildNavItem(3, Icons.person, 'Profile'),
                ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, bool isOrganizer, dynamic user) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final profile = user?.profile;
    
    // Initials for avatar fallback
    final initials = user?.fullName != null && user!.fullName.isNotEmpty 
        ? user.fullName[0].toUpperCase() 
        : (isOrganizer ? 'O' : 'V');

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Drawer Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isOrganizer 
                  ? [const Color(0xFF012D1D), const Color(0xFF1B4332)] 
                  : [const Color(0xFF1B4332), const Color(0xFF0E6C4A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white24,
              backgroundImage: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            accountName: Text(
              user?.fullName ?? (isOrganizer ? 'NGO Organizer' : 'Volunteer'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                // Pill Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isOrganizer ? 'NGO ORGANIZER' : 'VOLUNTEER',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Drawer Body Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: isOrganizer
                  ? [
                      // ORGANIZER OPTIONS
                      ListTile(
                        leading: const Icon(Icons.dashboard_customize, color: Color(0xFF012D1D)),
                        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentIndex = 0;
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.add_box, color: Color(0xFF012D1D)),
                        title: const Text('Publish New Event', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CreateEventScreen()),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF012D1D)),
                        title: const Text('Scan QR Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.analytics, color: Color(0xFF012D1D)),
                        title: const Text('Impact Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentIndex = 3; // Switch to Analytics tab
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library, color: Color(0xFF012D1D)),
                        title: const Text('Event Moments Feed', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EventFeedScreen()),
                          );
                        },
                      ),
                      if (user?.isVerified == true)
                        ListTile(
                          leading: const Icon(Icons.payment, color: Color(0xFF012D1D)),
                          title: const Text('NGO Subscriptions', style: TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PaymentsScreen()),
                            );
                          },
                        ),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          user?.isVerified == true ? Icons.verified_user : Icons.gpp_maybe,
                          color: user?.isVerified == true ? const Color(0xFF006C48) : const Color(0xFFBA1A1A),
                        ),
                        title: const Text('NGO Verification Details', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          _showNgoVerificationDialog(context, user);
                        },
                      ),
                    ]
                  : [
                      // VOLUNTEER OPTIONS
                      ListTile(
                        leading: const Icon(Icons.home, color: Color(0xFF0E6C4A)),
                        title: const Text('Home Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentIndex = 0;
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.event_available, color: Color(0xFF0E6C4A)),
                        title: const Text('My Drives & Passes', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const VolunteerEventsScreen()),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.leaderboard, color: Color(0xFF0E6C4A)),
                        title: const Text('Rankings & Leaderboard', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.check_circle_outline, color: Color(0xFF0E6C4A)),
                        title: const Text('Completions & Certificates', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CompletionsScreen()),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library, color: Color(0xFF0E6C4A)),
                        title: const Text('Event Moments Feed', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EventFeedScreen()),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.payment, color: Color(0xFF0E6C4A)),
                        title: const Text('Sponsor & Donate', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PaymentsScreen()),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person, color: Color(0xFF0E6C4A)),
                        title: const Text('View Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentIndex = 3; // Switch to profile tab
                          });
                        },
                      ),
                      const Divider(),
                      if (profile != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reputation Level: ${profile.reputationLevel.toString().replaceAll('_', ' ')}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0E6C4A)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Score: ${profile.reputationScore} Points',
                                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
            ),
          ),

          // Drawer Footer Logout Option
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFBA1A1A)),
            title: const Text('Logout', style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.of(context).pop();
              authService.logout();
              Provider.of<ChatService>(context, listen: false).disconnectSocket();
              Provider.of<NotificationService>(context, listen: false).disconnectSocket();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showNgoVerificationDialog(BuildContext context, dynamic user) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isVerified = user?.isVerified == true;

    final nameController = TextEditingController(text: isVerified ? user?.fullName : '');
    final contactController = TextEditingController(text: isVerified ? 'VERIFIED-REG' : '');
    final docsController = TextEditingController(text: isVerified ? 'http://docs.served/ngo_reg.pdf' : '');
    final idController = TextEditingController(text: isVerified ? 'http://docs.served/ngo_id.pdf' : '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                'NGO Verification Status',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF012D1D),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isVerified ? Icons.verified : Icons.pending_actions,
                          color: isVerified ? const Color(0xFF006C48) : const Color(0xFFBA1A1A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVerified ? 'Verified NGO Account' : 'Verification Required',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: isVerified ? const Color(0xFF006C48) : const Color(0xFFBA1A1A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isVerified) ...[
                      Text('Organization: ${user?.fullName ?? "NGO Admin"}', style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937))),
                      const SizedBox(height: 6),
                      const Text('Status: APPROVED', style: TextStyle(fontSize: 13, color: Color(0xFF006C48), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Identity Proof: VERIFIED', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ] else ...[
                      const Text(
                        '⚠️ Financial Features Suspended\nYour host account must be verified by the administrator. Option to collect donations and purchase premium features will be locked until approval.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFBA1A1A), height: 1.4, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Submit Verification Request',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF012D1D),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'NGO Legal Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: contactController,
                        decoration: const InputDecoration(
                          labelText: 'Registration Contact ID',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: docsController,
                        decoration: const InputDecoration(
                          labelText: 'Registration Docs URL',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: idController,
                        decoration: const InputDecoration(
                          labelText: 'Identity Proof URL',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                if (!isVerified)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF012D1D),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          contactController.text.isEmpty ||
                          docsController.text.isEmpty ||
                          idController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all verification details.')),
                        );
                        return;
                      }

                      try {
                        final res = await http.post(
                          Uri.parse('${AppConfig.baseUrl}/ngos/verify-request'),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer ${authService.token}',
                          },
                          body: jsonEncode({
                            'ngoName': nameController.text,
                            'contactDetails': contactController.text,
                            'registrationDocs': docsController.text,
                            'identityProof': idController.text,
                          }),
                        );

                        if (res.statusCode == 201 || res.statusCode == 200) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('NGO Verification Request submitted successfully! Please await administrator review.')),
                          );
                        } else {
                          final err = jsonDecode(res.body)['message'] ?? 'Submission failed';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err)),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    child: const Text('Submit'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ==========================================
// VOLUNTEER DASHBOARD TAB
// ==========================================
class VolunteerDashboardTab extends StatelessWidget {
  const VolunteerDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final eventService = Provider.of<EventService>(context);
    final attService = Provider.of<AttendanceService>(context);
    
    final user = authService.currentUser;
    final profile = user?.profile;
    final events = eventService.events;

    // Calculate actual logged hours fromCompleted Drives
    final completedDrives = attService.history;
    final double loggedHours = completedDrives.fold(0.0, (sum, drive) => sum + drive.hoursLogged);
    
    final double goalHours = 20.0;
    final double progress = (loggedHours / goalHours).clamp(0.0, 1.0);
    final double remainingHours = (goalHours - loggedHours).clamp(0.0, goalHours);
    final int progressPct = (progress * 100).round();

    // Use actual served metrics instead of reputation-based estimations
    final double hours = loggedHours;
    final int eventsCount = completedDrives.length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Profile Bar
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.secondaryContainer,
                backgroundImage: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty
                    ? Text(
                        user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'V',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  Text(
                    user?.fullName ?? 'Volunteer',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bento Stats Grid (Impact Card + Monthly Goal)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Your Impact Card
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B4332), Color(0xFF012D1D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF012D1D).withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Impact',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Top 5% contributors!",
                            style: TextStyle(color: Color(0xFFA0F4C8), fontSize: 10),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(hours.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1)),
                              const Text('Hours Served', style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$eventsCount', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1)),
                              const Text('Events', style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          // Badges Row overlapping
                          SizedBox(
                            width: 44,
                            height: 24,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: CircleAvatar(
                                    radius: 11,
                                    backgroundColor: const Color(0xFFF59E0B),
                                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 12),
                                  ),
                                ),
                                Positioned(
                                  left: 10,
                                  child: CircleAvatar(
                                    radius: 11,
                                    backgroundColor: const Color(0xFF10B981),
                                    child: const Icon(Icons.eco, color: Colors.white, size: 12),
                                  ),
                                ),
                                Positioned(
                                  left: 20,
                                  child: CircleAvatar(
                                    radius: 11,
                                    backgroundColor: const Color(0xFFEF4444),
                                    child: const Icon(Icons.favorite, color: Colors.white, size: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Right: Monthly Goal
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE8EFF1)),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly Goal',
                            style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const Icon(Icons.trending_up, color: Color(0xFF006C48), size: 16),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$progressPct%',
                            style: const TextStyle(color: Color(0xFF012D1D), fontSize: 26, fontWeight: FontWeight.bold, height: 1),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${loggedHours.toStringAsFixed(1)} / ${goalHours.toStringAsFixed(0)} hours',
                            style: TextStyle(color: Colors.grey[600], fontSize: 10),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: const Color(0xFFE8EFF1),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006C48)),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            remainingHours > 0 ? '${remainingHours.toStringAsFixed(1)} hrs left to goal!' : 'Goal achieved!',
                            style: const TextStyle(color: Colors.grey, fontSize: 8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Horizontal Quick Links / Action Panel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickAction(context, Icons.leaderboard, 'Rankings', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen()));
              }),
              _buildQuickAction(context, Icons.qr_code_2, 'My Passes', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VolunteerEventsScreen()));
              }),
              _buildQuickAction(context, Icons.check_circle_outline, 'Completions', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CompletionsScreen()));
              }),
              _buildQuickAction(context, Icons.payment, 'Sponsor', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentsScreen()));
              }),
            ],
          ),
          const SizedBox(height: 28),

          // Section Header: Featured Drives
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Featured Drives',
                style: GoogleFonts.plusJakartaSans(
                  textStyle: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.arrow_forward, size: 18, color: Color(0xFF006C48)),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Scrolling featured events list
          SizedBox(
            height: 220,
            child: events.isEmpty
                ? Center(child: Text('No featured drives available.', style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: events.take(5).length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Container(
                        width: 260,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE8EFF1)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EventDetailScreen(eventId: event.id)),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top half: image & category overlay
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      (event.bannerUrl != null && event.bannerUrl!.isNotEmpty)
                                          ? event.bannerUrl!
                                          : 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500',
                                      height: 100,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(color: Colors.green[100], height: 100);
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        event.category,
                                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              // Bottom details
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            event.address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${event.volunteersNeeded} spots left',
                                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('Join', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 28),

          // Section Header: Near You
          Text(
            'Events Near You',
            style: GoogleFonts.plusJakartaSans(
              textStyle: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // Vertical Near You List
          events.isEmpty
              ? Center(child: Text('No events nearby.', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    
                    // Simple dynamic left border colors based on indexes
                    Color leftBorderColor = theme.colorScheme.secondary;
                    if (index % 3 == 1) leftBorderColor = const Color(0xFFFD8704);
                    if (index % 3 == 2) leftBorderColor = theme.colorScheme.secondaryContainer;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE8EFF1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: leftBorderColor, width: 4)),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => EventDetailScreen(eventId: event.id)),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Left image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      (event.bannerUrl != null && event.bannerUrl!.isNotEmpty)
                                          ? event.bannerUrl!
                                          : 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(color: Colors.green[500], width: 60, height: 60);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${event.distance != null ? event.distance!.toStringAsFixed(1) : '2.4'} miles away',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.people_outline, size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${event.volunteersNeeded} volunteers needed',
                                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return PremiumAnimatedButton(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFF4FAFD),
              child: Icon(icon, color: const Color(0xFF006C48), size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF161D1F)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ORGANIZER DASHBOARD TAB
// ==========================================
class OrganizerDashboardTab extends StatelessWidget {
  const OrganizerDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final eventService = Provider.of<EventService>(context);

    final user = authService.currentUser;
    final events = eventService.events.where((e) => e.organizerId == user?.id).toList();

    final apps = eventService.organizerApplications;
    final pendingCount = apps.where((app) => app['status'] == 'PENDING').length;
    final confirmedCount = apps.where((app) => app['status'] == 'APPROVED').length;
    
    final impactScoreRaw = events.length * 200 + confirmedCount * 100;
    final impactScore = impactScoreRaw >= 1000 ? '${(impactScoreRaw / 1000).toStringAsFixed(1)}k' : '$impactScoreRaw';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Profile
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'O',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Organizer Portal', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(
                    user?.fullName ?? 'NGO Admin',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              // Total Events
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Events', style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${events.length}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Pending Apps
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pending Apps', style: TextStyle(color: Color(0xFF005235), fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('$pendingCount', style: const TextStyle(color: Color(0xFF005235), fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Impact Score
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE8EFF1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Impact Score', style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(impactScore, style: const TextStyle(color: Color(0xFF012D1D), fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Horizontal Quick Links / Action Panel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAction(context, Icons.add_box, 'Create Event', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateEventScreen()));
              }),
              _buildAction(context, Icons.qr_code_scanner, 'Scan QR', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const QrScannerScreen()));
              }),
              _buildAction(context, Icons.analytics, 'Analytics', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ImpactAnalyticsScreen()));
              }),
            ],
          ),
          const SizedBox(height: 28),

          // Events header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Events',
                style: GoogleFonts.plusJakartaSans(
                  textStyle: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF006C48)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateEventScreen()));
                },
              )
            ],
          ),
          const SizedBox(height: 12),

          // Organizer Events List
          events.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.event_note, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('No active events published.', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8EFF1)),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VolunteerManagementScreen(
                                eventId: event.id,
                                eventTitle: event.title,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                              child: Image.network(
                                (event.bannerUrl != null && event.bannerUrl!.isNotEmpty) ? event.bannerUrl! : 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500',
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(color: Colors.green[100], height: 120),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          event.title,
                                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Builder(
                                        builder: (context) {
                                          final newAppsCount = apps.where((app) => app['eventId'] == event.id && app['status'] == 'PENDING').length;
                                          if (newAppsCount == 0) return const SizedBox.shrink();
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text('$newAppsCount New Apps', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                          );
                                        }
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    event.startTime.toString().split(' ')[0],
                                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(
                                    builder: (context) {
                                      final filledCount = apps.where((app) => app['eventId'] == event.id && app['status'] == 'APPROVED').length;
                                      final double fillRatio = event.volunteersNeeded > 0 
                                          ? (filledCount / event.volunteersNeeded) 
                                          : 0.0;
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: fillRatio.clamp(0.0, 1.0),
                                              backgroundColor: const Color(0xFFE8EFF1),
                                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006C48)),
                                              minHeight: 6,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('$filledCount/${event.volunteersNeeded} spots filled', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                                              Text('Click to review applications', style: TextStyle(color: theme.colorScheme.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ],
                                      );
                                    }
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }



  Widget _buildAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return PremiumAnimatedButton(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFF4FAFD),
              child: Icon(icon, color: const Color(0xFF006C48), size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF161D1F)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 3: INBOX CHAT LIST SCREEN
// ==========================================
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.token != null) {
        Provider.of<ChatService>(context, listen: false).fetchConversations(auth.token!);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatService = Provider.of<ChatService>(context);
    final chats = chatService.conversations;

    String formatTime(String? dateStr) {
      if (dateStr == null) return '';
      try {
        final date = DateTime.parse(dateStr).toLocal();
        final now = DateTime.now();
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
          final minute = date.minute.toString().padLeft(2, '0');
          final ampm = date.hour >= 12 ? 'PM' : 'AM';
          return '$hour:$minute $ampm';
        } else {
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return '${months[date.month - 1]} ${date.day}';
        }
      } catch (_) {
        return '';
      }
    }

    final query = _searchController.text.trim().toLowerCase();
    final filteredChats = chats.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final lastMsg = (c['lastMsg'] ?? '').toString().toLowerCase();
      final event = (c['event'] ?? '').toString().toLowerCase();
      
      final matchesSearch = name.contains(query) || lastMsg.contains(query) || event.contains(query);
      if (!matchesSearch) return false;

      if (_selectedFilter == 'Unread') return c['unread'] == true;
      if (_selectedFilter == 'Active Events') return c['event'] != 'Voluntree Anniversary';
      return true;
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search conversations...',
              hintStyle: const TextStyle(color: Color(0xFF717973)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF717973)),
              filled: true,
              fillColor: const Color(0xFFF3F4F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Filter Pills Row
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildFilterPill('All Messages'),
              const SizedBox(width: 8),
              _buildFilterPill('Unread'),
              const SizedBox(width: 8),
              _buildFilterPill('Active Events'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Vertical List of message conversations
        Expanded(
          child: filteredChats.isEmpty
              ? Center(child: Text('No conversations matching criteria.', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE8EFF1)),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              child: Text(
                                (chat['name'] as String)[0],
                                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            if (chat['unread'] == true)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF006C48),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              )
                          ],
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              chat['name'] as String,
                              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              formatTime(chat['time'] as String?),
                              style: TextStyle(color: Colors.grey[500], fontSize: 10),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              chat['event'] as String,
                              style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w600, fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chat['lastMsg'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DirectChatScreen(
                                targetUserId: chat['id'] as String,
                                targetUserName: chat['name'] as String,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }

  Widget _buildFilterPill(String filter) {
    final isSelected = _selectedFilter == (filter == 'All Messages' ? 'All' : filter);
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filter == 'All Messages' ? 'All' : filter;
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : const Color(0xFFE8EFF1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          filter,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF414844),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TAB 4: VOLUNTEER PROFILE TAB
// ==========================================
class VolunteerProfileTab extends StatelessWidget {
  const VolunteerProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final attService = Provider.of<AttendanceService>(context);
    
    final user = authService.currentUser;
    final profile = user?.profile;

    final completedDrives = attService.history;
    final double actualHours = completedDrives.fold(0.0, (sum, drive) => sum + drive.hoursLogged);
    final int actualEventsCount = completedDrives.length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Profile Photo & Name
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: theme.colorScheme.secondary,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty
                            ? Text(
                                user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'V',
                                style: TextStyle(color: theme.colorScheme.primary, fontSize: 32, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Icons.verified, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user?.fullName ?? 'Alex Chen',
                  style: GoogleFonts.plusJakartaSans(
                    textStyle: TextStyle(color: theme.colorScheme.primary, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email_outlined, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600),
                    )
                  ],
                ),
                if (profile?.bio != null && profile!.bio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '"${profile.bio!}"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        textStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Message, Edit & Share buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    // Start self chat room as test
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DirectChatScreen(
                          targetUserId: 'self-chat-agent',
                          targetUserName: 'Voluntree Guide',
                        ),
                      ),
                    );
                  },
                  child: const Text('Message Agent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                  },
                  child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE8EFF1),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Color(0xFF414844), size: 18),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              _buildProfileStatCard(actualHours.toStringAsFixed(1), 'Hours', theme),
              const SizedBox(width: 12),
              _buildProfileStatCard('$actualEventsCount', 'Events', theme),
              const SizedBox(width: 12),
              _buildProfileStatCard('${profile?.reputationScore ?? 0}', 'Points', theme),
            ],
          ),
          const SizedBox(height: 20),

          // Level progress card
          Builder(
            builder: (context) {
              final score = profile?.reputationScore ?? 0;
              
              String levelLabel = 'BRONZE';
              String nextLevelLabel = 'SILVER';
              int minScore = 0;
              int maxScore = 500;
              
              if (score <= 500) {
                levelLabel = 'BRONZE';
                nextLevelLabel = 'SILVER';
                minScore = 0;
                maxScore = 500;
              } else if (score <= 1500) {
                levelLabel = 'SILVER';
                nextLevelLabel = 'GOLD';
                minScore = 500;
                maxScore = 1500;
              } else if (score <= 3000) {
                levelLabel = 'GOLD';
                nextLevelLabel = 'PLATINUM';
                minScore = 1500;
                maxScore = 3000;
              } else if (score <= 5000) {
                levelLabel = 'PLATINUM';
                nextLevelLabel = 'DIAMOND';
                minScore = 3000;
                maxScore = 5000;
              } else {
                levelLabel = 'DIAMOND';
                nextLevelLabel = 'MAX LEVEL';
                minScore = 5000;
                maxScore = 10000;
              }
              
              final int range = maxScore - minScore;
              final int currentProgress = (score - minScore).clamp(0, range);
              final double progressPct = range > 0 ? (currentProgress / range) : 1.0;
              final int pointsLeft = (maxScore - score).clamp(0, maxScore);

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('LEVEL: $levelLabel', style: const TextStyle(color: Color(0xFFA0F4C8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        Text('Next: $nextLevelLabel', style: TextStyle(color: Colors.grey[300], fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${profile?.reputationLevel.toString().replaceAll('_', ' ') ?? 'BRONZE TIER'}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progressPct.clamp(0.0, 1.0),
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA0F4C8)),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pointsLeft > 0 
                          ? '$pointsLeft points until next milestone'
                          : 'Max level achieved!',
                      style: TextStyle(color: Colors.grey[300], fontSize: 11),
                    ),
                  ],
                ),
              );
            }
          ),
          const SizedBox(height: 24),

          // Additional Profile Details Card
          if ((profile?.location != null && profile!.location!.isNotEmpty) ||
              (profile?.educationOrJob != null && profile!.educationOrJob!.isNotEmpty) ||
              (profile?.socialGithub != null && profile!.socialGithub!.isNotEmpty) ||
              (profile?.socialLinkedin != null && profile!.socialLinkedin!.isNotEmpty)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE8EFF1)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Me & Details',
                    style: GoogleFonts.plusJakartaSans(
                      textStyle: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (profile?.location != null && profile!.location!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: theme.colorScheme.secondary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          profile.location!,
                          style: const TextStyle(color: Color(0xFF161D1F), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (profile?.educationOrJob != null && profile!.educationOrJob!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.school_outlined, color: theme.colorScheme.secondary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          profile.educationOrJob!,
                          style: const TextStyle(color: Color(0xFF161D1F), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Socials
                  if ((profile?.socialGithub != null && profile!.socialGithub!.isNotEmpty) ||
                      (profile?.socialLinkedin != null && profile!.socialLinkedin!.isNotEmpty)) ...[
                    const Divider(height: 1, color: Color(0xFFE8EFF1)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (profile?.socialGithub != null && profile!.socialGithub!.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () {
                              // Github clicked
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4FAFD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE8EFF1)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.code, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  const Text('GitHub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF161D1F))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (profile?.socialLinkedin != null && profile!.socialLinkedin!.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () {
                              // Linkedin clicked
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4FAFD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE8EFF1)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  const Text('LinkedIn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF161D1F))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Emergency Contact card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE8EFF1)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Emergency Contact',
                      style: GoogleFonts.plusJakartaSans(
                        textStyle: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Icon(Icons.security, color: theme.colorScheme.secondary, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                if (profile?.emergencyName != null && profile!.emergencyName!.isNotEmpty &&
                    profile.emergencyContact != null && profile.emergencyContact!.isNotEmpty) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Icon(Icons.person, color: theme.colorScheme.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.emergencyName!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF161D1F)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.emergencyContact!,
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'No emergency contact setup yet. Please update in Edit Profile to be cleared for offline drives.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Earned Badges scrollable row
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Earned Badges',
              style: GoogleFonts.plusJakartaSans(
                textStyle: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildBadgeItem('Eco Warrior', Icons.eco, theme.colorScheme.secondaryContainer, theme.colorScheme.primary),
                const SizedBox(width: 16),
                _buildBadgeItem('Social Hero', Icons.groups, const Color(0xFFFFDCC4), const Color(0xFFFD8704)),
                const SizedBox(width: 16),
                _buildBadgeItem('Care Giver', Icons.volunteer_activism, theme.colorScheme.primaryContainer, Colors.white),
                const SizedBox(width: 16),
                _buildBadgeItem('Tree Planter', Icons.lock, Colors.grey[200]!, Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recognition Recommendation Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDCC4),
              borderRadius: BorderRadius.circular(20),
              border: const Border(left: BorderSide(color: Color(0xFFFD8704), width: 8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote, color: Color(0xFFFD8704), size: 36),
                const Text(
                  '"Alex is a dedicated leader who always brings positive energy. His ability to mobilize other volunteers during the food bank drive was truly inspiring."',
                  style: TextStyle(color: Color(0xFF301400), fontStyle: FontStyle.italic, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFFD8704).withOpacity(0.2),
                      child: const Icon(Icons.person, color: Color(0xFFFD8704), size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sarah Jenkins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF301400))),
                        Text('Community Organizer', style: TextStyle(color: Color(0xFF703800), fontSize: 10)),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Past Impact Drives List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Past Impact',
                style: GoogleFonts.plusJakartaSans(
                  textStyle: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (completedDrives.isNotEmpty)
                Text(
                  'View All',
                  style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (completedDrives.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                'No completed drives yet.',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            )
          else
            ...completedDrives.map((drive) {
              final title = drive.eventTitle;
              final hours = '${drive.hoursLogged.toStringAsFixed(1)} hours';
              
              String dateStr = '';
              try {
                if (drive.checkOut != null) {
                  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  dateStr = '${months[drive.checkOut!.month - 1]} ${drive.checkOut!.day.toString().padLeft(2, '0')}, ${drive.checkOut!.year}';
                }
              } catch (_) {}
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPastImpactCard(title, dateStr, hours, 'Volunteer', theme),
              );
            }).toList(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileStatCard(String val, String label, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE8EFF1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(color: theme.colorScheme.secondary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFF414844), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeItem(String name, IconData icon, Color bg, Color iconColor) {
    final opacity = icon == Icons.lock ? 0.5 : 1.0;
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 80,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: bg,
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF161D1F)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastImpactCard(String title, String date, String duration, String role, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8EFF1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('$date • $duration', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(role, style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
