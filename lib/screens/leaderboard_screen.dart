import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../widgets/responsive.dart';
import '../utils/text_utils.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LeaderboardService>(
        context,
        listen: false,
      ).fetchLeaderboard();
    });
  }

  String _formatLevelName(String level) {
    return level.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);
    final leaderboardService = Provider.of<LeaderboardService>(context);

    final currentUser = authService.currentUser;
    final topUsers = leaderboardService.topVolunteers;
    final isLoading = leaderboardService.isLoading;

    // Use actual top volunteers from database
    final displayUsers = topUsers;

    final podiumUsers = displayUsers.take(3).toList();
    final remainingUsers = displayUsers.skip(3).toList();

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
          'Top Performers',
          style: GoogleFonts.plusJakartaSans(
            textStyle: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        actions: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text(
              initialOf(currentUser?.fullName, fallback: 'V'),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 840,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () => leaderboardService.fetchLeaderboard(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        170,
                      ), // Extra bottom padding for sticky bar
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top 3 Podium Section / List View
                          if (displayUsers.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 60,
                                horizontal: 20,
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.emoji_events_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No rankings available yet.',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Serve in drives and earn reputation points to rank up!',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            if (podiumUsers.length >= 3) ...[
                              _buildPodiumSection(podiumUsers),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Rank',
                                    style: TextStyle(
                                      color: Color(0xFF717973),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const Text(
                                    'Volunteer',
                                    style: TextStyle(
                                      color: Color(0xFF717973),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const Text(
                                    'Impact',
                                    style: TextStyle(
                                      color: Color(0xFF717973),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: remainingUsers.length,
                                itemBuilder: (context, index) {
                                  final user = remainingUsers[index];
                                  final rank = index + 4;
                                  return _buildLeaderboardRow(
                                    user,
                                    rank,
                                    theme,
                                  );
                                },
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Rank',
                                    style: TextStyle(
                                      color: Color(0xFF717973),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const Text(
                                    'Volunteer',
                                    style: TextStyle(
                                      color: Color(0xFF717973),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const Text(
                                    'Impact',
                                    style: TextStyle(
                                      color: Color(0xFF717973),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: displayUsers.length,
                                itemBuilder: (context, index) {
                                  final user = displayUsers[index];
                                  final rank = index + 1;
                                  return _buildLeaderboardRow(
                                    user,
                                    rank,
                                    theme,
                                  );
                                },
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Sticky persistent "Your Rank" Bar at bottom
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              // The person's initial. This circle reads as an
                              // avatar everywhere else in the app, but showed
                              // the reputation level's first letter — so a
                              // GOLD volunteer called Alex saw "G". The level
                              // is already spelled out beside it.
                              (currentUser?.fullName.trim().isNotEmpty == true
                                      ? currentUser!.fullName.trim()
                                      : 'V')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Your score: ${currentUser?.profile?.reputationScore ?? 0} pts',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Level: ${_formatLevelName(currentUser?.profile?.reputationLevel ?? 'BRONZE')}',
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPodiumSection(List<LeaderboardUser> users) {
    if (users.isEmpty) return const SizedBox.shrink();

    final first = users.isNotEmpty ? users[0] : null;
    final second = users.length > 1 ? users[1] : null;
    final third = users.length > 2 ? users[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF012D1D).withOpacity(0.03),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null)
            _buildPodiumItem(second, 2, const Color(0xFF717973), 64)
          else
            const SizedBox(width: 64),

          if (first != null)
            _buildPodiumItem(first, 1, const Color(0xFFC9A24A), 84),

          if (third != null)
            _buildPodiumItem(third, 3, const Color(0xFFB45309), 56)
          else
            const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(
    LeaderboardUser user,
    int rank,
    Color accentColor,
    double size,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Avatar with highlight ring
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor,
                  width: rank == 1 ? 4 : 2,
                ),
                boxShadow: rank == 1
                    ? [
                        BoxShadow(
                          color: const Color(0xFFC9A24A).withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: const Color(0xFFF4FAFD),
                child: Text(
                  initialOf(user.fullName),
                  style: TextStyle(
                    color: const Color(0xFF012D1D),
                    fontWeight: FontWeight.bold,
                    fontSize: rank == 1 ? 22 : 16,
                  ),
                ),
              ),
            ),
            // Floating award crown/ribbon for Rank 1
            if (rank == 1)
              const Positioned(
                top: -12,
                child: Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFC9A24A),
                  size: 24,
                ),
              ),
            // Rank Badge Number
            Positioned(
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.fullName.trim().isEmpty
                  ? 'Volunteer'
                  : user.fullName.trim().split(' ')[0],
              style: const TextStyle(
                color: Color(0xFF012D1D),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${user.reputationScore} pts',
          style: const TextStyle(
            color: Color(0xFF0E6C4A),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(LeaderboardUser user, int rank, ThemeData theme) {
    final rankStr = rank.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EFF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank ID
          Text(
            rankStr,
            style: const TextStyle(
              color: Color(0x66012D1D),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text(
              initialOf(user.fullName),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and Label Level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        color: Color(0xFF161D1F),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (user.reputationLevel == 'IMPACT_LEADER' ||
                        user.reputationLevel == 'PLATINUM') ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.eco, color: Color(0xFF0E6C4A), size: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatLevelName(user.reputationLevel),
                  style: const TextStyle(
                    color: Color(0xFF717973),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Score points
          Text(
            '${user.reputationScore}',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
