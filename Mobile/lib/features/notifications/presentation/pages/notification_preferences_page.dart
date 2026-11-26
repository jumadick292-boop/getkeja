// Notification preferences page.
// Lets users control delivery channels and per-category opt-outs. Essential
// security notifications are always delivered regardless of these settings
// (enforced by the backend); marketing is a separate opt-in.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/datasources/notification_remote_datasource.dart';

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationRemoteDataSource(apiClient.dio);
});

final notificationPreferencesProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(notificationRemoteDataSourceProvider).getPreferences();
});

class NotificationPreferencesPage extends ConsumerStatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  ConsumerState<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends ConsumerState<NotificationPreferencesPage> {
  bool _saving = false;

  Future<void> _setFlag(String key, bool value) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(notificationRemoteDataSourceProvider)
          .updatePreferences(<String, dynamic>{key: value});
      ref.invalidate(notificationPreferencesProvider);
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotLoadNotifications)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationPreferences)),
      body: prefsAsync.when(
        data: (prefs) => _buildContent(context, prefs),
        loading: () => const AppListSkeleton(rows: 6),
        error: (_, __) => AppNotice(
          message: l10n.couldNotLoadNotifications,
          type: NoticeType.error,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(notificationPreferencesProvider),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> prefs) {
    final l10n = AppLocalizations.of(context)!;
    bool flag(String key, {bool fallback = true}) =>
        prefs[key] as bool? ?? fallback;

    final channels = <(String, String)>[
      ('emailEnabled', l10n.emailNotifications),
      ('smsEnabled', l10n.smsNotifications),
      ('pushEnabled', l10n.pushNotifications),
      ('inAppEnabled', l10n.inAppNotifications),
    ];

    final categories = <(String, String, String)>[
      ('security', l10n.categorySecurity, 'security'),
      ('service', l10n.categoryService, 'service'),
      ('operational', l10n.categoryOperational, 'operational'),
      ('marketing', l10n.categoryMarketing, 'marketing'),
    ];

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        AppSectionHeader(title: l10n.notificationChannels),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (key, label) in channels)
                _switchTile(
                  label,
                  flag(key),
                  _saving ? null : (v) => _setFlag(key, v),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSectionHeader(title: l10n.notificationCategories),
        for (final (category, label, _) in categories) ...[
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final channel in const [
                  ('Email', 'Email'),
                  ('Sms', 'Sms'),
                  ('Push', 'Push'),
                  ('InApp', 'InApp'),
                ])
                  _switchTile(
                    '$label · ${channel.$1}',
                    flag('$category${channel.$2}'),
                    _saving ? null : (v) => _setFlag('$category${channel.$2}', v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (categories.any((c) => c.$1 == 'security'))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.securityNotificationsAlwaysOn,
              style: AppTypography.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool>? onChanged) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        title: Text(label, style: AppTypography.bodyMedium),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}