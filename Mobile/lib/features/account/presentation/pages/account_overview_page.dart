// Account overview page showing account summary and navigation to sections.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../shared/models/auth_models.dart';
import '../../../authentication/presentation/state/auth_state.dart';
import '../../../../l10n/generated/app_localizations.dart';

class AccountOverviewPage extends ConsumerWidget {
  const AccountOverviewPage({super.key});

  List<_AccountSection> _sections(AppLocalizations l10n) => [
    _AccountSection(
      key: 'personal_information',
      title: l10n.personalInformation,
      subtitle: l10n.emailPhone,
      icon: Icons.person_outline_rounded,
      route: '/account/personal-information',
    ),
    _AccountSection(
      key: 'login_methods',
      title: l10n.passwordAndLogin,
      subtitle: l10n.changePasswordManageLogin,
      icon: Icons.lock_outline_rounded,
      route: '/account/login-methods',
    ),
    _AccountSection(
      key: 'two_factor',
      title: l10n.twoFactorAuthentication,
      subtitle: l10n.authenticatorSmsBackup,
      icon: Icons.shield_outlined,
      route: '/mfa/manage',
    ),
    _AccountSection(
      key: 'connected_accounts',
      title: l10n.connectedAccounts,
      subtitle: l10n.googleAccountLinking,
      icon: Icons.link_outlined,
      route: '/account/connected-accounts',
    ),
    _AccountSection(
      key: 'sessions',
      title: l10n.activeSessions,
      subtitle: l10n.whereSignedIn,
      icon: Icons.devices_outlined,
      route: '/sessions',
    ),
    _AccountSection(
      key: 'devices',
      title: l10n.trustedDevices,
      subtitle: l10n.manageRegisteredDevices,
      icon: Icons.phone_android_outlined,
      route: '/devices',
    ),
    _AccountSection(
      key: 'security_activity',
      title: l10n.securityActivity,
      subtitle: l10n.recentSignInsSecurityEvents,
      icon: Icons.history_outlined,
      route: '/account/security-activity',
    ),
    _AccountSection(
      key: 'privacy',
      title: l10n.privacyAndData,
      subtitle: l10n.dataExportAccountDeletion,
      icon: Icons.privacy_tip_outlined,
      route: '/account/privacy',
    ),
    _AccountSection(
      key: 'preferences',
      title: l10n.preferencesAndNotifications,
      subtitle: l10n.regionalFormats,
      icon: Icons.tune_outlined,
      route: '/account/preferences',
    ),
    _AccountSection(
      key: 'account_status',
      title: l10n.accountStatus,
      subtitle: l10n.verificationRestrictions,
      icon: Icons.badge_outlined,
      route: '/account/status',
    ),
    _AccountSection(
      key: 'organization_access',
      title: l10n.organizationAndAccess,
      subtitle: l10n.organizationMemberships,
      icon: Icons.groups_outlined,
      route: '/account/organization-access',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.account),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Help & support',
          ),
        ],
      ),
      body: user == null
          ? _buildUnauthenticatedView(context)
          : SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAccountHeader(context, user),
                  const SizedBox(height: 24),
                  _buildAccountStatusCard(context, user),
                  const SizedBox(height: 24),
                  _buildSectionList(context),
                  const SizedBox(height: 32),
                  _buildAccountActions(context, ref),
                ],
              ),
            ),
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'Sign in to manage your account',
              style: AppTypography.headlineSmall.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Access your personal information, security settings, and preferences.',
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
          ],
        ),
      ),
    );
  }

  Widget _buildAccountHeader(BuildContext context, AuthUser user) {
    final theme = Theme.of(context);
    final hasEmail = user.email != null && user.email!.isNotEmpty;
    final hasPhone = user.phone != null && user.phone!.isNotEmpty;

    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              _getInitials(user.firstName, user.lastName),
              style: AppTypography.headlineMedium.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.firstName} ${user.lastName}',
                  style: AppTypography.titleLarge.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if (hasEmail)
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user.email!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (hasPhone) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.phone!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: user.roles.map((role) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: AppBorderRadius.roundRadius,
                      ),
                      child: Text(
                        _formatRole(role),
                        style: AppTypography.labelSmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStatusCard(BuildContext context, AuthUser user) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(theme, user.accountStatus);
    final statusIcon = _getStatusIcon(user.accountStatus);
    final statusLabel = _formatAccountStatus(user.accountStatus);

    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: AppBorderRadius.mediumRadius,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account status',
                  style: AppTypography.titleMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: AppBorderRadius.roundRadius,
                      ),
                      child: Text(
                        statusLabel,
                        style: AppTypography.labelMedium.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (user.emailVerified || user.phoneVerified) ...[
                      const SizedBox(width: 8),
                      _buildVerificationBadge(
                        context,
                        'Email',
                        user.emailVerified,
                      ),
                      const SizedBox(width: 4),
                      _buildVerificationBadge(
                        context,
                        'Phone',
                        user.phoneVerified,
                      ),
                    ],
                    if (user.mfaEnabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: AppBorderRadius.roundRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 12,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'MFA enabled',
                              style: AppTypography.labelSmall.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/account/status'),
            child: const Text('Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge(
    BuildContext context,
    String label,
    bool verified,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: verified
            ? theme.colorScheme.secondary.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 12,
            color: verified
                ? theme.colorScheme.secondary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: verified
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionList(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.accountSettings,
          style: AppTypography.titleMedium.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ..._sections(
          l10n,
        ).map((section) => _buildSectionTile(context, section)),
      ],
    );
  }

  Widget _buildSectionTile(BuildContext context, _AccountSection section) {
    final theme = Theme.of(context);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push(section.route),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: AppBorderRadius.mediumRadius,
            ),
            child: Icon(
              section.icon,
              color: theme.colorScheme.onPrimaryContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  section.subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActions(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account actions',
          style: AppTypography.titleMedium.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: AppBorderRadius.mediumRadius,
                  ),
                  child: Icon(
                    Icons.pause_circle_outline_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Pause account',
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Pause access; restore it later using a verified email or phone',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => _pauseAccount(context, ref),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: AppBorderRadius.mediumRadius,
                  ),
                  child: Icon(
                    Icons.download_outlined,
                    color: theme.colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Download your data',
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Request a copy of your account data',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => context.go('/account/privacy'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: AppBorderRadius.mediumRadius,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.onErrorContainer,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Delete account',
                  style: AppTypography.bodyLarge.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Mark your account for deletion and revoke access',
                  style: AppTypography.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => _showDeleteAccountDialog(context),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pauseAccount(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pause your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You will be signed out. Restore your account later with a code sent to a verified email or phone. Recent MFA verification is required; enter your password too if your account has one.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Pause account'),
          ),
        ],
      ),
    );
    final password = controller.text;
    controller.dispose();
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/account/pause',
            data: {
              'confirmation': 'PAUSE',
              if (password.isNotEmpty) 'currentPassword': password,
            },
          );
      await ref
          .read(authNotifierProvider.notifier)
          .handleAction(const AuthAction.logoutAll());
      if (context.mounted) context.go('/welcome');
    } on DioException catch (error) {
      if (!context.mounted) return;
      final data = error.response?.data;
      final message = data is Map<String, dynamic> && data['message'] is String
          ? data['message'] as String
          : 'Unable to pause your account. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(
              context,
              Icons.email_outlined,
              'Email support',
              'support@getkeja.com',
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              context,
              Icons.article_outlined,
              'Help center',
              'Visit help.getkeja.com for guides',
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              context,
              Icons.security_outlined,
              'Security concerns',
              'Report security issues to security@getkeja.com',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete account?',
          style: AppTypography.titleLarge.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        content: const Text(
          'This action is irreversible. All your data, including properties, tenancies, messages, and preferences will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/account/privacy');
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Proceed to deletion'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String firstName, String lastName) {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  String _formatRole(String role) {
    return role
        .split('_')
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _formatAccountStatus(String status) {
    switch (status) {
      case 'pending_verification':
        return 'Pending verification';
      case 'active':
        return 'Active';
      case 'suspended':
        return 'Suspended';
      case 'locked':
        return 'Locked';
      case 'deactivated':
        return 'Deactivated';
      case 'deleted':
        return 'Deleted';
      default:
        return status;
    }
  }

  Color _getStatusColor(ThemeData theme, String status) {
    switch (status) {
      case 'pending_verification':
        return theme.colorScheme.tertiary;
      case 'active':
        return theme.colorScheme.secondary;
      case 'suspended':
      case 'locked':
        return theme.colorScheme.error;
      case 'deactivated':
      case 'deleted':
        return theme.colorScheme.onSurfaceVariant;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending_verification':
        return Icons.hourglass_top_rounded;
      case 'active':
        return Icons.check_circle_rounded;
      case 'suspended':
        return Icons.pause_circle_rounded;
      case 'locked':
        return Icons.lock_rounded;
      case 'deactivated':
      case 'deleted':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

class _AccountSection {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _AccountSection({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}
