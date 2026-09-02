import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../widgets/responsive.dart';

class ImpactAnalyticsScreen extends StatefulWidget {
  const ImpactAnalyticsScreen({super.key});

  @override
  State<ImpactAnalyticsScreen> createState() => _ImpactAnalyticsScreenState();
}

class _ImpactAnalyticsScreenState extends State<ImpactAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAnalytics();
    });
  }

  void _fetchAnalytics() {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token != null) {
      Provider.of<EventService>(
        context,
        listen: false,
      ).fetchOrganizerAnalytics(auth.token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventService = Provider.of<EventService>(context);
    final analytics = eventService.organizerAnalytics;
    final isLoading = eventService.isLoading;

    if (isLoading && analytics == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0e6c4a)),
          ),
        ),
      );
    }

    // Fallbacks
    final double totalHours =
        (analytics?['totalHours'] as num?)?.toDouble() ?? 0.0;
    final int activeVolunteers = analytics?['activeVolunteers'] ?? 0;
    final double completionRate =
        (analytics?['completionRate'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> categoryBreakdown =
        analytics?['categoryBreakdown'] ?? [];
    final List<dynamic> monthlyTrend = analytics?['monthlyTrend'] ?? [];

    // Calculate total events for category percentage
    final int totalEvents = categoryBreakdown.fold(
      0,
      (sum, item) => sum + (item['count'] as int),
    );

    // Calculate max value for trend normalization
    final int maxTrendCount = monthlyTrend.fold(1, (max, item) {
      final val = item['count'] as int;
      return val > max ? val : max;
    });

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
          'Impact Analytics',
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
            onPressed: _fetchAnalytics,
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 1000,
        child: RefreshIndicator(
          onRefresh: () async => _fetchAnalytics(),
          color: const Color(0xFF0e6c4a),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Screen Title & Subtitle
                Text(
                  'Chapter Impact',
                  style: GoogleFonts.plusJakartaSans(
                    textStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Real-time measurement of your NGO's growth and contributions.",
                  style: TextStyle(color: Color(0xFF717973), fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Bento Metric Cards Grid
                _buildStatMetricCard(
                  title: 'TOTAL CONTRIBUTION HOURS',
                  value: totalHours.toStringAsFixed(1),
                  trend: 'Real-time verified logs',
                  icon: Icons.schedule,
                  accentColor: const Color(0xFF0E6C4A),
                  theme: theme,
                ),
                const SizedBox(height: 16),
                _buildStatMetricCard(
                  title: 'ACTIVE VOLUNTEERS',
                  value: '$activeVolunteers',
                  trend: 'Unique attendees checked in',
                  icon: Icons.people_alt,
                  accentColor: const Color(0xFFFD8704),
                  theme: theme,
                ),
                const SizedBox(height: 16),
                _buildStatMetricCard(
                  title: 'DRIVE COMPLETION RATE',
                  value: '${completionRate.toStringAsFixed(1)}%',
                  trend: 'Events successfully closed',
                  icon: Icons.task_alt,
                  accentColor: theme.colorScheme.primary,
                  theme: theme,
                ),
                const SizedBox(height: 28),

                // Category Breakdown Chart Bento Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                      Text(
                        'Category Distributions',
                        style: GoogleFonts.plusJakartaSans(
                          textStyle: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Drives breakdown by volunteer categories',
                        style: TextStyle(
                          color: Color(0xFF717973),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (categoryBreakdown.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No categories data available',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      else
                        ...categoryBreakdown.map((item) {
                          final catName = item['category'] as String;
                          final count = item['count'] as int;
                          final double pct = totalEvents > 0
                              ? (count / totalEvents)
                              : 0.0;
                          final pctStr = '${(pct * 100).round()}%';

                          Color barColor = const Color(0xFF0e6c4a);
                          if (catName.contains('Support'))
                            barColor = const Color(0xFFFD8704);
                          if (catName.contains('Health'))
                            barColor = const Color(0xFF012D1D);
                          if (catName.contains('Education'))
                            barColor = const Color(0xFF2196F3);
                          if (catName.contains('Animal'))
                            barColor = const Color(0xFFE91E63);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildCategoryProgressRow(
                              catName,
                              pct,
                              pctStr,
                              barColor,
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Monthly Trend Chart Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                      Text(
                        'Volunteer Turnout',
                        style: GoogleFonts.plusJakartaSans(
                          textStyle: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Monthly active attendees trend',
                        style: TextStyle(
                          color: Color(0xFF717973),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (monthlyTrend.isEmpty)
                        const SizedBox(
                          height: 140,
                          child: Center(
                            child: Text(
                              'No trend data available',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 140,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: monthlyTrend.map((item) {
                              final month = item['month'] as String;
                              final count = item['count'] as int;
                              final double pct = count / maxTrendCount;
                              return _buildChartBar(month, pct, count, theme);
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // "Export PDF" only showed a snackbar; removed until a real
                // export exists.
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatMetricCard({
    required String title,
    required String value,
    required String trend,
    required IconData icon,
    required Color accentColor,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EFF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: accentColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        textStyle: const TextStyle(
                          color: Color(0xFF717973),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    textStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.info_outline, color: accentColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      trend,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryProgressRow(
    String category,
    double value,
    String percentStr,
    Color barColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: const TextStyle(
                color: Color(0xFF161D1F),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              percentStr,
              style: TextStyle(
                color: barColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: const Color(0xFFE8EFF1),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildChartBar(
    String month,
    double heightPct,
    int count,
    ThemeData theme,
  ) {
    return Tooltip(
      message: '$count volunteers',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 24,
            height: (100 * heightPct).clamp(8.0, 100.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            month,
            style: const TextStyle(
              color: Color(0xFF717973),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
