// Notifications page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../app/preferences/app_preferences.dart';
import '../../../../core/widgets/design_widgets.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Unread'),
            Tab(text: 'Archived'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationList('all'),
          _buildNotificationList('unread'),
          _buildNotificationList('archived'),
        ],
      ),
    );
  }

  Widget _buildNotificationList(String filter) {
    // TODO: Implement actual notification fetching
    final notifications = _getMockNotifications();

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: AppTypography.titleMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: AppTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  List<_MockNotification> _getMockNotifications() {
    return [
      _MockNotification(
        id: '1',
        title: 'New property match',
        body: 'A 2-bedroom apartment in Kilimani matches your criteria',
        category: 'property',
        priority: 'high',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      _MockNotification(
        id: '2',
        title: 'Site visit confirmed',
        body:
            'Your viewing for the Kasarani bedsitter is confirmed for tomorrow at 10:00 AM',
        category: 'tenancy',
        priority: 'normal',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      _MockNotification(
        id: '3',
        title: 'Payment reminder',
        body:
            'Your rent payment of ${AppFormatters.currency(45000, decimalDigits: 0)} is due in 3 days',
        category: 'financial',
        priority: 'high',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      _MockNotification(
        id: '4',
        title: 'Security alert',
        body: 'New sign-in from Chrome on Windows in Nairobi',
        category: 'security',
        priority: 'critical',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  Widget _buildNotificationCard(_MockNotification notification) {
    final theme = Theme.of(context);
    final (icon, color) = _getCategoryIconAndColor(notification.category);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppSpacing.cardPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppBorderRadius.mediumRadius,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppTypography.bodyLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(
                          notification.priority,
                        ).withValues(alpha: 0.1),
                        borderRadius: AppBorderRadius.roundRadius,
                      ),
                      child: Text(
                        notification.priority.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(
                          color: _getPriorityColor(notification.priority),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeAgo(notification.createdAt),
                      style: AppTypography.labelSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
  }

  (IconData, Color) _getCategoryIconAndColor(String category) {
    final theme = Theme.of(context);
    switch (category) {
      case 'security':
        return (Icons.security_rounded, theme.colorScheme.error);
      case 'property':
        return (Icons.home_outlined, theme.colorScheme.primary);
      case 'tenancy':
        return (Icons.event_outlined, AppColors.terracotta);
      case 'financial':
        return (Icons.payments_outlined, AppColors.brand);
      case 'service':
        return (Icons.build_outlined, theme.colorScheme.tertiary);
      default:
        return (
          Icons.notifications_outlined,
          theme.colorScheme.onSurfaceVariant,
        );
    }
  }

  Color _getPriorityColor(String priority) {
    final theme = Theme.of(context);
    switch (priority) {
      case 'critical':
        return theme.colorScheme.error;
      case 'high':
        return theme.colorScheme.tertiary;
      case 'normal':
        return theme.colorScheme.primary;
      case 'low':
        return theme.colorScheme.onSurfaceVariant;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    return AppFormatters.relativeTime(dateTime);
  }
}

class _MockNotification {
  const _MockNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String priority;
  final bool isRead;
  final DateTime createdAt;
}
