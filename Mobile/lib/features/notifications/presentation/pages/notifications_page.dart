// Notifications page.
// Displays the authenticated user's notifications, including saved-search
// alerts, using the existing notification backend API.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../app/preferences/app_preferences.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../house_seeker/presentation/pages/house_seeker_listing_detail_page.dart';
import '../../../house_seeker/presentation/pages/house_seeker_saved_searches_page.dart';
import '../../domain/entities/notification_model.dart';
import '../state/notification_state.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationProvider);
    final unreadAsync = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.notificationsTitle),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.notificationPreferences,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/notifications/preferences'),
          ),
          Consumer(
            builder: (context, ref, child) {
              final unread = ref.watch(unreadCountProvider);
              return unread.when(
                data: (count) => count > 0
                    ? TextButton(
                        onPressed: () async {
                          await ref.read(notificationProvider.notifier).markAllAsRead();
                          ref.refresh(unreadCountProvider);
                        },
                        child: Text(AppLocalizations.of(context)!.markAllRead),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
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
                    AppLocalizations.of(context)!.noNotifications,
                    style: AppTypography.titleMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.noNotificationsDescription,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(notificationProvider.notifier).refresh();
              ref.refresh(unreadCountProvider);
            },
            child: ListView.builder(
              padding: AppSpacing.screenPadding,
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: () => _onNotificationTap(context, ref, notification),
                  onMarkRead: () async {
                    await ref
                        .read(notificationProvider.notifier)
                        .markSingleAsRead(notification.id);
                    ref.refresh(unreadCountProvider);
                  },
                );
              },
            ),
          );
        },
        loading: () => const AppListSkeleton(rows: 4),
        error: (error, stackTrace) => AppNotice(
          message: AppLocalizations.of(context)!.couldNotLoadNotifications,
          type: NoticeType.error,
          actionLabel: AppLocalizations.of(context)!.retry,
          onAction: () {
            ref.read(notificationProvider.notifier).refresh();
            ref.refresh(unreadCountProvider);
          },
        ),
      ),
    );
  }

  void _onNotificationTap(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
  ) {
    // Mark as read when opened.
    ref.read(notificationProvider.notifier).markSingleAsRead(notification.id);
    ref.refresh(unreadCountProvider);

    final listingId = notification.listingId;
    final savedSearchId = notification.savedSearchId;

    // If the notification references a listing, open the property details page.
    // The listing data is fetched fresh from the backend — notification content
    // is never trusted as the source of truth for the current listing state.
    if (listingId != null && listingId.isNotEmpty) {
      context.pushNamed(
        'house-seeker-listing-detail',
        pathParameters: <String, String>{'listingId': listingId},
      );
      return;
    }

    // If the notification references a saved search, open the saved searches page.
    if (savedSearchId != null && savedSearchId.isNotEmpty) {
      context.pushNamed('house-seeker-saved-searches');
      return;
    }

    // Operational notifications carry a safe deep link; open the relevant
    // service detail / conversation. The target re-checks authorization.
    final path = notificationDeepLinkToPath(notification.deepLink);
    if (path != null) {
      context.push(path);
    }
  }
}

/// Map a backend `getkeja://` deep link to an in-app GoRouter location.
/// Returns null for unknown/unsafe links so callers can ignore them.
String? notificationDeepLinkToPath(String? link) {
  if (link == null || !link.startsWith('getkeja://')) return null;
  final rest = link.substring('getkeja://'.length);
  if (rest.isEmpty) return null;
  final parts = rest.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  final resource = parts.first;
  final tail = parts.length > 1 ? parts.sublist(1) : const <String>[];
  switch (resource) {
    case 'messaging':
      return tail.length >= 2 ? '/messaging/conversations/${tail[1]}' : null;
    case 'moving':
      return tail.length >= 2 ? '/moving/jobs/${tail[1]}' : null;
    case 'garbage':
      return tail.length >= 2 ? '/garbage/jobs/${tail[1]}' : null;
    case 'laundry':
      return tail.length >= 2 ? '/laundry/orders/${tail[1]}' : null;
    case 'marketplace':
      return tail.length >= 2 ? '/marketplace/requests/${tail[1]}' : null;
    case 'scheduling':
      return '/scheduling/calendar';
    default:
      return null;
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final (icon, color) = _getCategoryIconAndColor(notification.category, theme);
    final isUnread = !notification.isRead;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppSpacing.cardPadding,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread)
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
                    if (notification.isSearchAlert &&
                        (notification.listingTitle != null ||
                            notification.summary != null)) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: AppBorderRadius.roundRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.home_outlined,
                              size: 12,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                notification.listingTitle ??
                                    notification.summary ??
                                    '',
                                style: AppTypography.labelSmall.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                              theme,
                            ).withValues(alpha: 0.1),
                            borderRadius: AppBorderRadius.roundRadius,
                          ),
                          child: Text(
                            notification.priority.toUpperCase(),
                            style: AppTypography.labelSmall.copyWith(
                              color: _getPriorityColor(
                                notification.priority,
                                theme,
                              ),
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
                        const Spacer(),
                        if (isUnread)
                          TextButton(
                            onPressed: onMarkRead,
                            child: Text(localizations.markAsRead),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (IconData, Color) _getCategoryIconAndColor(
    String category,
    ThemeData theme,
  ) {
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
      case 'account':
        return (Icons.person_outlined, AppColors.brand);
      case 'operational':
        return (Icons.settings_outlined, theme.colorScheme.tertiary);
      case 'marketing':
        return (Icons.campaign_outlined, AppColors.brand);
      default:
        return (
          Icons.notifications_outlined,
          theme.colorScheme.onSurfaceVariant,
        );
    }
  }

  Color _getPriorityColor(String priority, ThemeData theme) {
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

  String _formatTimeAgo(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return AppFormatters.relativeTime(dateTime);
    } catch (_) {
      return dateTimeString;
    }
  }
}
