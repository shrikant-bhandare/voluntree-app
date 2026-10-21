import 'package:flutter/material.dart';
import '../utils/drive_cta.dart';
import '../utils/spots_remaining.dart';
import '../utils/list_state.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/category_service.dart';
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
import '../widgets/responsive.dart';
import '../utils/event_time.dart';
import '../utils/session.dart';
import '../utils/text_utils.dart';
import '../widgets/confirm_dialog.dart';
import '../config.dart';
import 'account_settings_screen.dart';

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

        // Listen for new notifications to show in-app banner. The callback
        // fires at arbitrary later times, so it must check the State is still
        // mounted before touching its context.
        notif.onNotificationReceived = (newNotif) {
          if (!mounted) return;
          // A notification may announce an account change (NGO approval or
          // revocation). Re-read the account so the right shell appears
          // without restarting the app.
          _refreshAccount();
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
        // Notifications ride on the chat socket; a second socket used to
        // flap presence every time the inbox opened.
        chatService.onNotificationReceived = notif.pushRealtime;

        // Listen for incoming chat messages to show in-app banner
        chatService.onMessageReceived = (message) {
          if (!mounted) return;
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

        _loadRoleData();
      }
      // Load events globally
      Provider.of<EventService>(context, listen: false).fetchEvents();
      Provider.of<CategoryService>(context, listen: false).ensureLoaded();
    });
  }

  /// Re-reads `/auth/me`; if the role changed (e.g. NGO approved), resets to
  /// the first tab and loads that role's data.
  Future<void> _refreshAccount() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final before = authService.currentUser?.userType;
    await authService.fetchMe();
    if (!mounted) return;
    final after = authService.currentUser?.userType;
    if (after != null && after != before) {
      setState(() => _currentIndex = 0);
      _loadRoleData();
    }
  }

  void _loadRoleData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    if (token == null) return;
    final eventService = Provider.of<EventService>(context, listen: false);
    final isOrganizer =
        authService.currentUser?.userType == 'ORGANIZER' ||
        authService.currentUser?.userType == 'ADMIN';
    if (isOrganizer) {
      eventService.fetchOrganizerApplications(token);
      eventService.fetchOrganizerAnalytics(token);
      eventService.fetchMyEvents(token);
    } else {
      // Volunteer-only endpoints. Calling these for an organizer is not
      // merely wasteful — GET /attendance/history is @VolunteerOrAdmin, so
      // an organizer session fired a guaranteed 403 on every launch.
      Provider.of<AttendanceService>(
        context,
        listen: false,
      ).fetchHistory(token);
      // Without this the featured cards have no application data and fall
      // back to offering "Join" for drives already applied to.
      eventService.fetchUserApplications(token);
    }
  }

  ChatService? _chat;
  NotificationService? _notif;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider lookups are not allowed from dispose(); cache them here. The
    // old dispose() looked them up, threw, and the cleanup never ran.
    _chat ??= Provider.of<ChatService>(context, listen: false);
    _notif ??= Provider.of<NotificationService>(context, listen: false);
  }

  @override
  void dispose() {
    _chat?.onMessageReceived = null;
    _chat?.onNotificationReceived = null;
    _chat?.disconnectSocket();
    _notif?.onNotificationReceived = null;
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
              color: isSelected
                  ? theme.colorScheme.primary
                  : const Color(0xFF717973),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.primary
                    : const Color(0xFF717973),
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
    final isOrganizer =
        user?.userType == 'ORGANIZER' || user?.userType == 'ADMIN';

    // Tabs List
    final List<Widget> tabs = isOrganizer
        ? [
            const OrganizerDashboardTab(),
            const EventFeedScreen(),
            // Publishing needs an APPROVED verification; the API returns 403
            // otherwise, so do not offer the form.
            user?.isVerified == true
                ? const CreateEventScreen()
                : const VerificationRequiredTab(),
            const ChatListScreen(),
            const ImpactAnalyticsScreen(),
          ]
        : [
            const VolunteerDashboardTab(),
            const DiscoverEventsScreen(isEmbedded: true),
            const EventFeedScreen(),
            const ChatListScreen(),
            const VolunteerProfileTab(),
          ];

    // Same destinations drive the bottom bar (phones) and the navigation
    // rail (desktop/tablet-landscape web windows).
    final navSpecs = isOrganizer
        ? const [
            (Icons.dashboard_customize, 'Home'),
            (Icons.dynamic_feed, 'Posts'),
            (Icons.add_box, 'Create'),
            (Icons.chat, 'Chat'),
            (Icons.analytics, 'Analytics'),
          ]
        : const [
            (Icons.home, 'Home'),
            (Icons.explore, 'Events'),
            (Icons.dynamic_feed, 'Posts'),
            (Icons.chat, 'Chat'),
            (Icons.person, 'Profile'),
          ];

    final useRail = Breakpoints.isDesktop(context);
    final content = IndexedStack(index: _currentIndex, children: tabs);

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
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
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
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  backgroundColor: Colors.white,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: theme.colorScheme.secondaryContainer,
                  selectedIconTheme: IconThemeData(
                    color: theme.colorScheme.primary,
                  ),
                  selectedLabelTextStyle: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: Color(0xFF717973),
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: Color(0xFF717973),
                    fontSize: 12,
                  ),
                  destinations: [
                    for (final spec in navSpecs)
                      NavigationRailDestination(
                        icon: Icon(spec.$1),
                        label: Text(spec.$2),
                      ),
                  ],
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFE8EFF1),
                ),
                Expanded(
                  child: ResponsiveCenter(maxWidth: 1000, child: content),
                ),
              ],
            )
          : content,
      bottomNavigationBar: useRail
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < navSpecs.length; i++)
                    _buildNavItem(i, navSpecs[i].$1, navSpecs[i].$2),
                ],
              ),
            ),
    );
  }

  Widget _accountTile(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.manage_accounts_outlined,
        color: Color(0xFF012D1D),
      ),
      title: const Text(
        'Account & privacy',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text(
        'Download your data or delete your account',
        style: TextStyle(fontSize: 12),
      ),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AccountSettingsScreen(),
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, bool isOrganizer, dynamic user) {
    final profile = user?.profile;

    // Initials for avatar fallback
    final initials = initialOf(
      user?.fullName as String?,
      fallback: isOrganizer ? 'O' : 'V',
    );

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
              backgroundImage:
                  profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              // A 404'd avatar must not throw an unhandled image error.
              onBackgroundImageError:
                  profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                  ? (_, _) {}
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isOrganizer ? 'NGO ORGANIZER' : 'VOLUNTEER',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
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
                        leading: const Icon(
                          Icons.dashboard_customize,
                          color: Color(0xFF012D1D),
                        ),
                        title: const Text(
                          'Dashboard',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentIndex = 0;
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.add_box,
                          color: Color(0xFF012D1D),
                        ),
                        title: const Text(
                          'Publish New Event',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateEventScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.qr_code_scanner,
                          color: Color(0xFF012D1D),
                        ),
                        title: const Text(
                          'Scan QR Attendance',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QrScannerScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.analytics,
                          color: Color(0xFF012D1D),
                        ),
                        title: const Text(
                          'Impact Analytics',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentIndex = 4; // Switch to Analytics tab
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.dynamic_feed,
                          color: Color(0xFF012D1D),
                        ),
                        title: const Text(
                          'Community Posts Feed',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentIndex = 1; // Switch to Posts tab
                          });
                        },
                      ),
                      if (AppConfig.paymentsEnabled && user?.isVerified == true)
                        ListTile(
                          leading: const Icon(
                            Icons.payment,
                            color: Color(0xFF012D1D),
                          ),
                          title: const Text(
                            'NGO Subscriptions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PaymentsScreen(),
                              ),
                            );
                          },
                        ),
                      ListTile(
                        leading: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF012D1D),
                        ),
                        title: const Text(
                          'Edit Profile',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                        },
                      ),
                      _accountTile(context),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          user?.isVerified == true
                              ? Icons.verified_user
                              : Icons.gpp_maybe,
                          color: user?.isVerified == true
                              ? const Color(0xFF006C48)
                              : const Color(0xFFBA1A1A),
                        ),
                        title: const Text(
                          'NGO Verification Details',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _showNgoVerificationDialog(context, user);
                        },
                      ),
                    ]
                  : [
                      // VOLUNTEER OPTIONS
                      ListTile(
                        leading: const Icon(
                          Icons.home,
                          color: Color(0xFF0E6C4A),
                        ),
                        title: const Text(
                          'Home Dashboard',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentIndex = 0;
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.event_available,
                          color: Color(0xFF0E6C4A),
                        ),
                        title: const Text(
                          'My Drives & Passes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const VolunteerEventsScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.leaderboard,
                          color: Color(0xFF0E6C4A),
                        ),
                        title: const Text(
                          'Rankings & Leaderboard',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LeaderboardScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF0E6C4A),
                        ),
                        title: const Text(
                          'Completions & Certificates',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CompletionsScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.dynamic_feed,
                          color: Color(0xFF0E6C4A),
                        ),
                        title: const Text(
                          'Community Posts Feed',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentIndex = 2; // Switch to Posts tab
                          });
                        },
                      ),
                      if (AppConfig.paymentsEnabled)
                        ListTile(
                          leading: const Icon(
                            Icons.payment,
                            color: Color(0xFF0E6C4A),
                          ),
                          title: const Text(
                            'Sponsor & Donate',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PaymentsScreen(),
                              ),
                            );
                          },
                        ),
                      ListTile(
                        leading: const Icon(
                          Icons.person,
                          color: Color(0xFF0E6C4A),
                        ),
                        title: const Text(
                          'View Profile',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentIndex = 4; // Switch to profile tab
                          });
                        },
                      ),
                      _accountTile(context),
                      ListTile(
                        leading: const Icon(
                          Icons.verified_user_outlined,
                          color: Color(0xFF0E6C4A),
                        ),
                        title: const Text(
                          'Become an NGO Host',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Submit your organization for verification',
                          style: TextStyle(fontSize: 11),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _showNgoVerificationDialog(context, user);
                        },
                      ),
                      const Divider(),
                      if (profile != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reputation Level: ${profile.reputationLevel.toString().replaceAll('_', ' ')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF0E6C4A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Score: ${profile.reputationScore} Points',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
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
            title: const Text(
              'Logout',
              style: TextStyle(
                color: Color(0xFFBA1A1A),
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              final ok = await confirmAction(
                this.context,
                title: 'Log out?',
                message: 'You will need a new sign-in code to log back in.',
                confirmLabel: 'Log out',
              );
              if (!ok || !mounted) return;
              await endSession(this.context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Submit or track NGO verification. Documents are picked from the device
  /// and uploaded to the private bucket first — the API only accepts
  /// `/files/private/` URLs, which the old free-text URL fields could never
  /// produce. Reachable by volunteers too, since approval is the only route
  /// to becoming an organizer.
  void _showNgoVerificationDialog(BuildContext context, dynamic user) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    String? registrationDocsUrl;
    String? identityProofUrl;
    String? registrationFileName;
    String? identityFileName;
    bool uploading = false;
    bool submitting = false;
    bool loadedExisting = false;
    Map<String, dynamic>? existing;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!loadedExisting) {
              loadedExisting = true;
              authService.fetchMyVerification().then((record) {
                if (!context.mounted) return;
                setDialogState(() {
                  existing = record;
                  final name = record?['ngoName'];
                  if (name is String && nameController.text.isEmpty) {
                    nameController.text = name;
                  }
                });
              });
            }

            final status = existing?['status'] as String?;
            final isApproved = status == 'APPROVED' || user?.isVerified == true;
            final canSubmit =
                !uploading &&
                !submitting &&
                registrationDocsUrl != null &&
                identityProofUrl != null;

            Future<void> pickAndUpload(bool isRegistration) async {
              final file = await FilePicker.pickFile(
                type: FileType.custom,
                allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
              );
              if (file == null) return;
              // Resolves from bytes or path, including on web.
              final bytes = await file.readAsBytes();
              if (!context.mounted) return;
              setDialogState(() => uploading = true);
              final url = await authService.uploadPrivateDocument(
                bytes,
                file.name,
              );
              if (!context.mounted) return;
              setDialogState(() {
                uploading = false;
                if (url != null) {
                  if (isRegistration) {
                    registrationDocsUrl = url;
                    registrationFileName = file.name;
                  } else {
                    identityProofUrl = url;
                    identityFileName = file.name;
                  }
                }
              });
              if (url == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Upload failed. Use a PDF or image under 25 MB.',
                    ),
                  ),
                );
              }
            }

            Widget statusRow(IconData icon, Color color, String text) {
              return Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              );
            }

            Widget docPicker({
              required String label,
              required String? fileName,
              required VoidCallback onPick,
            }) {
              return OutlinedButton.icon(
                onPressed: uploading ? null : onPick,
                icon: Icon(
                  fileName == null ? Icons.upload_file : Icons.check_circle,
                  color: fileName == null
                      ? const Color(0xFF012D1D)
                      : const Color(0xFF006C48),
                ),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    fileName ?? label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                'NGO Verification',
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
                    if (isApproved)
                      statusRow(
                        Icons.verified,
                        const Color(0xFF006C48),
                        'Verified NGO account',
                      )
                    else if (status == 'PENDING')
                      statusRow(
                        Icons.pending_actions,
                        const Color(0xFFD97706),
                        'Submitted — awaiting administrator review',
                      )
                    else if (status == 'REJECTED')
                      statusRow(
                        Icons.gpp_bad,
                        const Color(0xFFBA1A1A),
                        'Not approved — submit updated documents',
                      )
                    else
                      statusRow(
                        Icons.gpp_maybe,
                        const Color(0xFFBA1A1A),
                        'Not verified yet',
                      ),
                    const SizedBox(height: 16),
                    if (isApproved) ...[
                      Text(
                        'Organization: ${existing?['ngoName'] ?? user?.fullName ?? ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'You can publish drives, review applicants and receive donations.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ] else ...[
                      Text(
                        status == 'PENDING'
                            ? 'You can update your request while it is under review.'
                            : 'Approval is what enables publishing drives, collecting donations and premium features.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4B5563),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'NGO legal name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: contactController,
                        decoration: const InputDecoration(
                          labelText: 'Registration number / contact details',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      docPicker(
                        label: 'Upload registration certificate',
                        fileName: registrationFileName,
                        onPick: () => pickAndUpload(true),
                      ),
                      const SizedBox(height: 8),
                      docPicker(
                        label: 'Upload identity proof',
                        fileName: identityFileName,
                        onPick: () => pickAndUpload(false),
                      ),
                      if (uploading) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Documents are stored privately and visible only to platform administrators.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
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
                if (!isApproved)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF012D1D),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: !canSubmit
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final contact = contactController.text.trim();
                            if (name.length < 2 || contact.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter the organization name and contact details.',
                                  ),
                                ),
                              );
                              return;
                            }
                            // Captured before the async gap: the dialog is
                            // dismissible while the request is in flight.
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            setDialogState(() => submitting = true);
                            final result = await authService
                                .submitNgoVerification(
                                  ngoName: name,
                                  contactDetails: contact,
                                  registrationDocs: registrationDocsUrl!,
                                  identityProof: identityProofUrl!,
                                );
                            if (context.mounted) {
                              setDialogState(() => submitting = false);
                            }
                            if (result['success'] == true) {
                              if (context.mounted) navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Verification request submitted. You will be notified once an administrator reviews it.',
                                  ),
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result['message'] ?? 'Submission failed',
                                  ),
                                ),
                              );
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(status == 'PENDING' ? 'Update' : 'Submit'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Shown in the organizer's "Create" tab until verification is approved.
class VerificationRequiredTab extends StatelessWidget {
  const VerificationRequiredTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gpp_maybe, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'NGO verification required',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Publishing drives is enabled once an administrator approves your organization. Open the menu and choose "NGO Verification Details" to submit or track your request.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF717973)),
            ),
          ],
        ),
      ),
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
    final double loggedHours = completedDrives.fold(
      0.0,
      (sum, drive) => sum + drive.hoursLogged,
    );

    final double goalHours = 20.0;
    final double progress = (loggedHours / goalHours).clamp(0.0, 1.0);
    final double remainingHours = (goalHours - loggedHours).clamp(
      0.0,
      goalHours,
    );
    final int progressPct = (progress * 100).round();

    // Use actual served metrics instead of reputation-based estimations
    final double hours = loggedHours;
    final int eventsCount = completedDrives.length;

    return RefreshIndicator(
      onRefresh: () async {
        final token = authService.token;
        await Future.wait([
          eventService.fetchEvents(),
          if (token != null) eventService.fetchUserApplications(token),
          if (token != null) attService.fetchHistory(token),
          authService.fetchMe(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
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
                  backgroundImage:
                      profile?.avatarUrl != null &&
                          profile!.avatarUrl!.isNotEmpty
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  onBackgroundImageError:
                      profile?.avatarUrl != null &&
                          profile!.avatarUrl!.isNotEmpty
                      ? (_, _) {}
                      : null,
                  child:
                      profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty
                      ? Text(
                          user?.fullName.isNotEmpty == true
                              ? initialOf(user!.fullName)
                              : 'V',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
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
                        ),
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Every hour counts',
                              style: TextStyle(
                                color: Color(0xFFA0F4C8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hours.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                                const Text(
                                  'Hours Served',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$eventsCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                                const Text(
                                  'Events',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
                        ),
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
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(
                              Icons.trending_up,
                              color: Color(0xFF006C48),
                              size: 16,
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$progressPct%',
                              style: const TextStyle(
                                color: Color(0xFF012D1D),
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${loggedHours.toStringAsFixed(1)} / ${goalHours.toStringAsFixed(0)} hours',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
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
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF006C48),
                                ),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              remainingHours > 0
                                  ? '${remainingHours.toStringAsFixed(1)} hrs left to goal!'
                                  : 'Goal achieved!',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 8,
                              ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardScreen(),
                    ),
                  );
                }),
                _buildQuickAction(context, Icons.qr_code_2, 'My Passes', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VolunteerEventsScreen(),
                    ),
                  );
                }),
                _buildQuickAction(
                  context,
                  Icons.check_circle_outline,
                  'Completions',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CompletionsScreen(),
                      ),
                    );
                  },
                ),
                if (AppConfig.paymentsEnabled)
                  _buildQuickAction(context, Icons.payment, 'Sponsor', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PaymentsScreen(),
                      ),
                    );
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
                    textStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: Color(0xFF006C48),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal Scrolling featured events list
            SizedBox(
              height: 220,
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        'No featured drives available.',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: events.take(5).length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        // A drive the volunteer already applied to must not keep
                        // advertising "Join" — the detail screen showed the real
                        // state, the card did not.
                        // Read from the already-listening `eventService` above,
                        // not context.watch here: itemBuilder runs during
                        // layout, and registering a dependency there makes a
                        // later notifyListeners mark this element dirty
                        // mid-layout ("setState() called during build").
                        final cta = driveCtaFor(
                          eventId: event.id,
                          userApplications: eventService.userApplications,
                        );
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
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EventDetailScreen(eventId: event.id),
                                ),
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
                                        (event.bannerUrl != null &&
                                                event.bannerUrl!.isNotEmpty)
                                            ? event.bannerUrl!
                                            : 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500',
                                        height: 100,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.green[100],
                                                height: 100,
                                              );
                                            },
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          event.category,
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Bottom details
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 12,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              event.address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            spotsLabel(
                                              volunteersNeeded:
                                                  event.volunteersNeeded,
                                              approvedCount:
                                                  event.approvedCount,
                                            ),
                                            style: TextStyle(
                                              // Red means "hurry". Reserve it for
                                              // drives that are genuinely nearly
                                              // full instead of painting every
                                              // card with an alarm colour.
                                              color:
                                                  spotsAreScarce(
                                                    volunteersNeeded:
                                                        event.volunteersNeeded,
                                                    approvedCount:
                                                        event.approvedCount,
                                                  )
                                                  ? const Color(0xFFEF4444)
                                                  : Colors.grey[600],
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cta.isApplied
                                                  ? theme.colorScheme.primary
                                                        .withValues(alpha: 0.12)
                                                  : theme.colorScheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              cta.label,
                                              style: TextStyle(
                                                color: cta.isApplied
                                                    ? theme.colorScheme.primary
                                                    : Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
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
                textStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Vertical Near You List
            events.isEmpty
                ? Center(
                    child: Text(
                      'No events nearby.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];

                      // Simple dynamic left border colors based on indexes
                      Color leftBorderColor = theme.colorScheme.secondary;
                      if (index % 3 == 1)
                        leftBorderColor = const Color(0xFFFD8704);
                      if (index % 3 == 2)
                        leftBorderColor = theme.colorScheme.secondaryContainer;

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
                              border: Border(
                                left: BorderSide(
                                  color: leftBorderColor,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EventDetailScreen(eventId: event.id),
                                  ),
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
                                        (event.bannerUrl != null &&
                                                event.bannerUrl!.isNotEmpty)
                                            ? event.bannerUrl!
                                            : 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.green[500],
                                                width: 60,
                                                height: 60,
                                              );
                                            },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            event.distance != null
                                                ? '${event.distance!.toStringAsFixed(1)} km away'
                                                : event.address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.people_outline,
                                                size: 12,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                // Same wording as the card
                                                // carousel above; this row used
                                                // to state total capacity while
                                                // the card stated places left.
                                                spotsLabel(
                                                  volunteersNeeded:
                                                      event.volunteersNeeded,
                                                  approvedCount:
                                                      event.approvedCount,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: Colors.grey[400],
                                    ),
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
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
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
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF161D1F),
              ),
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
    // /events/mine carries every status; the public list drops FULL and
    // COMPLETED drives. Fall back to the public list until it has loaded.
    final events = eventService.myEvents.isNotEmpty
        ? eventService.myEvents
        : eventService.events.where((e) => e.organizerId == user?.id).toList();

    final apps = eventService.organizerApplications;
    // Until /events/mine has answered, this screen knows nothing about the
    // account — it must not claim the organizer has no drives.
    final driveState = listStateFor(
      hasLoaded: eventService.hasLoadedMyEvents,
      count: events.length,
    );
    final loading = driveState == ListState.loading;
    final pendingCount = apps.where((app) => app['status'] == 'PENDING').length;
    final confirmedCount = apps
        .where((app) => app['status'] == 'APPROVED')
        .length;

    final impactScoreRaw = events.length * 200 + confirmedCount * 100;
    final impactScore = impactScoreRaw >= 1000
        ? '${(impactScoreRaw / 1000).toStringAsFixed(1)}k'
        : '$impactScoreRaw';

    return RefreshIndicator(
      onRefresh: () async {
        final token = authService.token;
        if (token == null) return;
        await Future.wait([
          eventService.fetchMyEvents(token),
          eventService.fetchOrganizerApplications(token),
          authService.fetchMe(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
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
                    user?.fullName.isNotEmpty == true
                        ? initialOf(user!.fullName)
                        : 'O',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Organizer Portal',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
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
                        const Text(
                          'Total Events',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loading ? '—' : '${events.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                        const Text(
                          'Pending Apps',
                          style: TextStyle(
                            color: Color(0xFF005235),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$pendingCount',
                          style: const TextStyle(
                            color: Color(0xFF005235),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                        const Text(
                          'Impact Score',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          impactScore,
                          style: const TextStyle(
                            color: Color(0xFF012D1D),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateEventScreen(),
                    ),
                  );
                }),
                _buildAction(context, Icons.qr_code_scanner, 'Scan QR', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QrScannerScreen(),
                    ),
                  );
                }),
                _buildAction(context, Icons.analytics, 'Analytics', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ImpactAnalyticsScreen(),
                    ),
                  );
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
                    textStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF006C48),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateEventScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Organizer Events List
            loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                : events.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_note,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No drives published yet.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap + to publish your first drive.',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
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
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                child: Image.network(
                                  (event.bannerUrl != null &&
                                          event.bannerUrl!.isNotEmpty)
                                      ? event.bannerUrl!
                                      : 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=500',
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.green[100],
                                        height: 120,
                                      ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            event.title,
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final newAppsCount = apps
                                                .where(
                                                  (app) =>
                                                      app['eventId'] ==
                                                          event.id &&
                                                      app['status'] ==
                                                          'PENDING',
                                                )
                                                .length;
                                            if (newAppsCount == 0)
                                              return const SizedBox.shrink();
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '$newAppsCount New Apps',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formatLocalIsoDate(event.startTime),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Builder(
                                      builder: (context) {
                                        final filledCount = apps
                                            .where(
                                              (app) =>
                                                  app['eventId'] == event.id &&
                                                  app['status'] == 'APPROVED',
                                            )
                                            .length;
                                        final double fillRatio =
                                            event.volunteersNeeded > 0
                                            ? (filledCount /
                                                  event.volunteersNeeded)
                                            : 0.0;
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: fillRatio.clamp(
                                                  0.0,
                                                  1.0,
                                                ),
                                                backgroundColor: const Color(
                                                  0xFFE8EFF1,
                                                ),
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                      Color
                                                    >(Color(0xFF006C48)),
                                                minHeight: 6,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '$filledCount/${event.volunteersNeeded} spots filled',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                Text(
                                                  'Click to review applications',
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme
                                                        .secondary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
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
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
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
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF161D1F),
              ),
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
        Provider.of<ChatService>(
          context,
          listen: false,
        ).fetchConversations(auth.token!);
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
        if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day) {
          final hour = date.hour > 12
              ? date.hour - 12
              : (date.hour == 0 ? 12 : date.hour);
          final minute = date.minute.toString().padLeft(2, '0');
          final ampm = date.hour >= 12 ? 'PM' : 'AM';
          return '$hour:$minute $ampm';
        } else {
          final months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
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

      final matchesSearch =
          name.contains(query) ||
          lastMsg.contains(query) ||
          event.contains(query);
      if (!matchesSearch) return false;

      if (_selectedFilter == 'Unread') return c['unread'] == true;
      if (_selectedFilter == 'Active Events') {
        return c['userType'] == 'ORGANIZER';
      }
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
              ? Center(
                  child: Text(
                    'No conversations matching criteria.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
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
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                              child: Text(
                                initialOf(chat['name'] as String?),
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
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
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              chat['name'] as String,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              formatTime(chat['time'] as String?),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              chat['event'] as String,
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chat['lastMsg'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
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
        ),
      ],
    );
  }

  Widget _buildFilterPill(String filter) {
    final isSelected =
        _selectedFilter == (filter == 'All Messages' ? 'All' : filter);
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
          color: isSelected
              ? theme.colorScheme.primary
              : const Color(0xFFE8EFF1),
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
    final double actualHours = completedDrives.fold(
      0.0,
      (sum, drive) => sum + drive.hoursLogged,
    );
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
                        backgroundImage:
                            profile?.avatarUrl != null &&
                                profile!.avatarUrl!.isNotEmpty
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        onBackgroundImageError:
                            profile?.avatarUrl != null &&
                                profile!.avatarUrl!.isNotEmpty
                            ? (_, _) {}
                            : null,
                        child:
                            profile?.avatarUrl == null ||
                                profile!.avatarUrl!.isEmpty
                            ? Text(
                                user?.fullName.isNotEmpty == true
                                    ? initialOf(user!.fullName)
                                    : 'V',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    if (user?.isVerified == true)
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
                          child: const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user?.fullName ?? 'Volunteer',
                  style: GoogleFonts.plusJakartaSans(
                    textStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
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
                  child: const Text(
                    'Edit Profile',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE8EFF1),
                child: IconButton(
                  icon: const Icon(
                    Icons.share,
                    color: Color(0xFF414844),
                    size: 18,
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              _buildProfileStatCard(
                actualHours.toStringAsFixed(1),
                'Hours',
                theme,
              ),
              const SizedBox(width: 12),
              _buildProfileStatCard('$actualEventsCount', 'Events', theme),
              const SizedBox(width: 12),
              _buildProfileStatCard(
                '${profile?.reputationScore ?? 0}',
                'Points',
                theme,
              ),
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

              // Same thresholds the server promotes at (attendance.service):
              // SILVER 100, GOLD 300, PLATINUM 750, IMPACT LEADER 1500.
              if (score < 100) {
                levelLabel = 'BRONZE';
                nextLevelLabel = 'SILVER';
                minScore = 0;
                maxScore = 100;
              } else if (score < 300) {
                levelLabel = 'SILVER';
                nextLevelLabel = 'GOLD';
                minScore = 100;
                maxScore = 300;
              } else if (score < 750) {
                levelLabel = 'GOLD';
                nextLevelLabel = 'PLATINUM';
                minScore = 300;
                maxScore = 750;
              } else if (score < 1500) {
                levelLabel = 'PLATINUM';
                nextLevelLabel = 'IMPACT LEADER';
                minScore = 750;
                maxScore = 1500;
              } else {
                levelLabel = 'IMPACT LEADER';
                nextLevelLabel = 'MAX LEVEL';
                minScore = 1500;
                maxScore = 1500;
              }

              final int range = maxScore - minScore;
              final int currentProgress = (score - minScore).clamp(0, range);
              final double progressPct = range > 0
                  ? (currentProgress / range)
                  : 1.0;
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
                        Text(
                          'LEVEL: $levelLabel',
                          style: const TextStyle(
                            color: Color(0xFFA0F4C8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Next: $nextLevelLabel',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${profile?.reputationLevel.toString().replaceAll('_', ' ') ?? 'BRONZE TIER'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progressPct.clamp(0.0, 1.0),
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFA0F4C8),
                        ),
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
            },
          ),
          const SizedBox(height: 24),

          // Additional Profile Details Card
          if ((profile?.location?.isNotEmpty ?? false) ||
              (profile?.educationOrJob?.isNotEmpty ?? false) ||
              (profile?.socialGithub?.isNotEmpty ?? false) ||
              (profile?.socialLinkedin?.isNotEmpty ?? false)) ...[
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
                      textStyle: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (profile?.location?.isNotEmpty ?? false) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: theme.colorScheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          profile!.location!,
                          style: const TextStyle(
                            color: Color(0xFF161D1F),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (profile?.educationOrJob?.isNotEmpty ?? false) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          color: theme.colorScheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          profile!.educationOrJob!,
                          style: const TextStyle(
                            color: Color(0xFF161D1F),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Socials
                  if ((profile?.socialGithub?.isNotEmpty ?? false) ||
                      (profile?.socialLinkedin?.isNotEmpty ?? false)) ...[
                    const Divider(height: 1, color: Color(0xFFE8EFF1)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (profile?.socialGithub?.isNotEmpty ?? false) ...[
                          GestureDetector(
                            onTap: () {
                              // Github clicked
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4FAFD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE8EFF1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.code,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'GitHub',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF161D1F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (profile?.socialLinkedin?.isNotEmpty ?? false) ...[
                          GestureDetector(
                            onTap: () {
                              // Linkedin clicked
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4FAFD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE8EFF1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.link,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'LinkedIn',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF161D1F),
                                    ),
                                  ),
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
                        textStyle: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.security,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (profile?.emergencyName != null &&
                    profile!.emergencyName!.isNotEmpty &&
                    profile.emergencyContact != null &&
                    profile.emergencyContact!.isNotEmpty) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.emergencyName!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF161D1F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.emergencyContact!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'No emergency contact setup yet. Please update in Edit Profile to be cleared for offline drives.',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
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
                  textStyle: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (completedDrives.isNotEmpty)
                Text(
                  'View All',
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
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
                  final months = [
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec',
                  ];
                  dateStr =
                      '${months[drive.checkOut!.month - 1]} ${drive.checkOut!.day.toString().padLeft(2, '0')}, ${drive.checkOut!.year}';
                }
              } catch (_) {}

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPastImpactCard(
                  title,
                  dateStr,
                  hours,
                  'Volunteer',
                  theme,
                ),
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
            Text(
              val,
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF414844),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastImpactCard(
    String title,
    String date,
    String duration,
    String role,
    ThemeData theme,
  ) {
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
              child: Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$date • $duration',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
