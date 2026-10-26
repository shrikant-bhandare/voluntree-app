import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/responsive.dart';
import '../theme/brand.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.token != null) {
        final notifService = Provider.of<NotificationService>(
          context,
          listen: false,
        );
        notifService.fetchNotifications(auth.token!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final notifService = Provider.of<NotificationService>(context);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Inbox')),
      body: ResponsiveCenter(
        maxWidth: 840,
        child: notifService.isLoading
            ? const Center(child: CircularProgressIndicator())
            : notifService.notifications.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: Brand.mintWash,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 40,
                          color: Brand.growth,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No notifications found',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Matches and updates will appear here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Brand.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: notifService.notifications.length,
                itemBuilder: (context, index) {
                  final item = notifService.notifications[index];
                  final unread = !item.isRead;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: unread ? Brand.surface : Brand.mistContainerLow,
                      borderRadius: BorderRadius.circular(Brand.radiusLg),
                      border: Border.all(
                        color: unread
                            ? Brand.growth.withValues(alpha: 0.35)
                            : Brand.mistContainer,
                      ),
                      boxShadow: unread ? Brand.cardShadow : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Brand.radiusLg),
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: unread ? Brand.mintWash : Brand.mistContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: unread ? Brand.growth : Brand.sage,
                          size: 22,
                        ),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Brand.forest,
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: const BoxDecoration(
                                color: Brand.growth,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            item.body,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Brand.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (() {
                              final localTime = item.createdAt.toLocal();
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
                              final day = localTime.day.toString().padLeft(
                                2,
                                '0',
                              );
                              final month = months[localTime.month - 1];
                              final year = localTime.year;
                              final hour = localTime.hour.toString().padLeft(
                                2,
                                '0',
                              );
                              final minute = localTime.minute
                                  .toString()
                                  .padLeft(2, '0');
                              return "$day $month $year, $hour:$minute";
                            })(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Brand.sage,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!item.isRead && auth.token != null) {
                          notifService.markAsRead(auth.token!, item.id);
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
