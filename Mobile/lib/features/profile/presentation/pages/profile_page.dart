// Profile page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/generated/app_localizations.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../authentication/presentation/state/auth_state.dart';
import '../widgets/profile_photo_avatar.dart';

final personalLocationProvider = FutureProvider<Map<String, Object?>?>((
  ref,
) async {
  final userId = ref.watch(
    authNotifierProvider.select((state) => state.user?.id),
  );
  if (userId == null) return null;
  final response = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/api/v1/profile/locations');
  final data = response.data?['data'];
  if (data is! List) return null;
  for (final value in data) {
    if (value is! Map) continue;
    final location = value.map<String, Object?>(
      (key, item) => MapEntry(_camelCase(key.toString()), item),
    );
    if (location['locationType'] == 'personal_residential') return location;
  }
  return null;
});

String _camelCase(String value) => value.replaceAllMapped(
  RegExp(r'_([a-z])'),
  (match) => match[1]!.toUpperCase(),
);

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final personalLocation = ref.watch(personalLocationProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile)),
      body: user == null
          ? _buildUnauthenticatedView(context, theme)
          : _buildAuthenticatedView(
              context,
              theme,
              user,
              ref,
              personalLocation,
            ),
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: AppSpacing.compactScreenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to view your profile',
              style: AppTypography.titleLarge.copyWith(
                fontSize: 20,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Manage your account, devices, and preferences.',
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Sign in',
              onPressed: () => context.go('/sign-in'),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Create account',
              onPressed: () => context.go('/register'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticatedView(
    BuildContext context,
    ThemeData theme,
    AuthUser user,
    WidgetRef ref,
    Map<String, Object?>? personalLocation,
  ) {
    final name = [
      user.firstName,
      user.lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    final email = user.email;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return ListView(
      padding: AppSpacing.compactScreenPadding,
      children: [
        // Profile header
        AppCard(
          padding: AppSpacing.compactCardPadding,
          child: Column(
            children: [
              ProfilePhotoAvatar(
                radius: 40,
                initials: initials.isNotEmpty
                    ? initials
                    : email?.isNotEmpty == true
                    ? email![0].toUpperCase()
                    : 'G',
              ),
              const SizedBox(height: 16),
              Text(
                name.isNotEmpty ? name : 'GetKeja member',
                style: AppTypography.titleLarge.copyWith(
                  fontSize: 20,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email ?? '',
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (user.phone != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        user.phone!,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildStatusChip(
                    context,
                    'Email',
                    user.emailVerified ? 'Verified' : 'Unverified',
                    user.emailVerified
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.error,
                  ),
                  _buildStatusChip(
                    context,
                    'Phone',
                    user.phoneVerified ? 'Verified' : 'Unverified',
                    user.phoneVerified
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  _buildStatusChip(
                    context,
                    'MFA',
                    user.mfaEnabled ? 'Enabled' : 'Disabled',
                    user.mfaEnabled
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.error,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Account section
        _buildSection(context, 'Account', [
          AppTile(
            title: 'My location',
            subtitle:
                personalLocation?['formattedAddress']?.toString() ??
                'Set my location',
            leading: const Icon(Icons.location_on_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final saved = await context.push<bool>(
                '/profile/location',
                extra: {
                  'locationType': 'personal_residential',
                  if (personalLocation != null) 'location': personalLocation,
                },
              );
              if (saved == true) ref.invalidate(personalLocationProvider);
            },
          ),
          AppTile(
            title: 'Specialized profiles',
            subtitle:
                'Create and manage your seeker, provider, or business profiles',
            leading: const Icon(Icons.badge_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/profile/manage'),
          ),
          AppTile(
            title: 'Edit profile',
            subtitle: 'Update your name, phone, and other details',
            leading: const Icon(Icons.person_outline_rounded),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/profile/personal/edit'),
          ),
          AppTile(
            title: 'Change password',
            subtitle: 'Update your password',
            leading: const Icon(Icons.lock_outline_rounded),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/account/login-methods'),
          ),
          AppTile(
            title: 'Connected accounts',
            subtitle: 'Manage Google and other linked accounts',
            leading: const Icon(Icons.link_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/account/connected-accounts'),
          ),
        ]),

        const SizedBox(height: 16),

        // Security section
        _buildSection(context, 'Security', [
          AppTile(
            title: 'MFA methods',
            subtitle: 'Manage authenticator apps and recovery codes',
            leading: const Icon(Icons.shield_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/mfa/manage'),
          ),
          AppTile(
            title: 'Devices',
            subtitle: 'View and manage your trusted devices',
            leading: const Icon(Icons.devices_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/devices'),
          ),
          AppTile(
            title: 'Active sessions',
            subtitle: 'Review and revoke active sign-ins',
            leading: const Icon(Icons.history_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/sessions'),
          ),
        ]),

        const SizedBox(height: 16),

        // Preferences section
        _buildSection(context, 'Preferences', [
          AppTile(
            title: 'Notifications',
            subtitle: 'Manage email, push, and in-app notifications',
            leading: const Icon(Icons.notifications_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              // TODO: Navigate to notifications settings
            },
          ),
          AppTile(
            title: 'Privacy',
            subtitle: 'Control your data and privacy settings',
            leading: const Icon(Icons.privacy_tip_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              // TODO: Navigate to privacy settings
            },
          ),
        ]),

        const SizedBox(height: 16),

        // Support section
        _buildSection(context, 'Support', [
          AppTile(
            title: 'Help center',
            subtitle: 'FAQs, guides, and troubleshooting',
            leading: const Icon(Icons.help_outline_rounded),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _launchUrl('https://help.getkeja.com'),
          ),
          AppTile(
            title: 'Contact support',
            subtitle: 'Get help from our team',
            leading: const Icon(Icons.support_agent_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _launchUrl('https://getkeja.com/contact'),
          ),
          AppTile(
            title: 'Terms of Service',
            subtitle: 'Read our terms and conditions',
            leading: const Icon(Icons.description_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _launchUrl('https://getkeja.com/terms'),
          ),
          AppTile(
            title: 'Privacy Policy',
            subtitle: 'Learn how we protect your data',
            leading: const Icon(Icons.privacy_tip_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _launchUrl('https://getkeja.com/privacy'),
          ),
        ]),

        const SizedBox(height: 16),

        // Sign out button
        DestructiveButton(
          label: 'Sign out',
          icon: const Icon(Icons.logout_rounded),
          onPressed: () async {
            final notifier = ref.read(authNotifierProvider.notifier);
            try {
              await notifier.handleAction(const AuthAction.logout());
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Signed out on this device, but the server session could not be revoked.',
                  ),
                ),
              );
            } finally {
              if (context.mounted) {
                context.go('/welcome');
              }
            }
          },
        ),

        const SizedBox(height: 12),

        // Delete account button
        TextButton(
          onPressed: () => _showDeleteAccountDialog(context),
          child: Text(
            'Delete account',
            style: AppTypography.labelMedium.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        AppCard(child: AppListSection(children: children, divider: true)),
      ],
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppBorderRadius.roundRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label: $value',
              softWrap: true,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This action cannot be undone. All your data, including saved properties, bookings, and history, will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion coming soon')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    // TODO: Implement url_launcher
  }
}
