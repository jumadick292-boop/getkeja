// Account status page showing verification status, restrictions, and account health.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../app/preferences/app_preferences.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class AccountStatusPage extends ConsumerStatefulWidget {
  const AccountStatusPage({super.key});

  @override
  ConsumerState<AccountStatusPage> createState() => _AccountStatusPageState();
}

class _AccountStatusPageState extends ConsumerState<AccountStatusPage> {
  bool _isLoading = false;
  String? _errorMessage;

  bool _emailVerified = false;
  bool _phoneVerified = false;
  bool _mfaEnabled = false;
  String _accountStatus = 'active';
  bool _isSuspended = false;
  bool _isLocked = false;
  bool _isDeactivated = false;
  String? _suspensionReason;
  String? _lockReason;
  DateTime? _lockedUntil;
  List<String> _roles = [];
  DateTime? _createdAt;
  DateTime? _lastSignInAt;
  int _activeSessions = 0;
  int _activeDevices = 0;
  int _mfaMethodsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAccountStatus();
  }

  Future<void> _loadAccountStatus() async {
    setState(() => _isLoading = true);
    try {
      final authState = ref.read(authNotifierProvider);
      final user = authState.user;
      if (user != null) {
        _emailVerified = user.emailVerified;
        _phoneVerified = user.phoneVerified;
        _mfaEnabled = user.mfaEnabled;
        _accountStatus = user.accountStatus;
        _isSuspended = user.accountStatus == 'suspended';
        _isLocked = user.accountStatus == 'locked';
        _isDeactivated = user.accountStatus == 'deactivated';
        _roles = user.roles;
        _createdAt = user.createdAt;
        _lastSignInAt = user.lastMfaVerifiedAt;

        // Load additional status info
        await Future.wait([
          _loadSuspensionInfo(),
          _loadLockInfo(),
          _loadSessionDeviceCounts(),
          _loadMfaCount(),
        ]);
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _errorMessageFrom(error));
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSuspensionInfo() async {
    if (!_isSuspended) return;
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/account/status/suspension');
      final payload = response.data?['data'];
      if (payload is Map<String, dynamic>) {
        _suspensionReason = payload['reason'] as String?;
      }
    } on DioException catch (error) {
      _errorMessage ??= _errorMessageFrom(error);
    } on AppException catch (error) {
      _errorMessage ??= error.message;
    }
  }

  Future<void> _loadLockInfo() async {
    if (!_isLocked) return;
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/account/status/lock');
      final payload = response.data?['data'];
      if (payload is Map<String, dynamic>) {
        _lockReason = payload['reason'] as String?;
        if (payload['lockedUntil'] is String) {
          _lockedUntil = DateTime.parse(payload['lockedUntil'] as String);
        }
      }
    } on DioException catch (error) {
      _errorMessage ??= _errorMessageFrom(error);
    } on AppException catch (error) {
      _errorMessage ??= error.message;
    }
  }

  Future<void> _loadSessionDeviceCounts() async {
    try {
      final sessionsResponse = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/sessions');
      final sessionsPayload = sessionsResponse.data?['data'];
      if (sessionsPayload is Map<String, dynamic> &&
          sessionsPayload['sessions'] is List) {
        final sessions = (sessionsPayload['sessions'] as List)
            .whereType<Map<String, dynamic>>();
        _activeSessions = sessions.where((s) => s['revokedAt'] == null).length;
      }

      final devicesResponse = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/devices');
      final devicesPayload = devicesResponse.data?['data'];
      if (devicesPayload is Map<String, dynamic> &&
          devicesPayload['devices'] is List) {
        final devices = (devicesPayload['devices'] as List)
            .whereType<Map<String, dynamic>>();
        _activeDevices = devices.where((d) => d['status'] == 'active').length;
      }
    } on DioException catch (error) {
      _errorMessage ??= _errorMessageFrom(error);
    } on AppException catch (error) {
      _errorMessage ??= error.message;
    } catch (error) {
      _errorMessage ??= 'Unable to load session and device details: $error';
    }
  }

  Future<void> _loadMfaCount() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/mfa/status');
      final payload = response.data?['data'];
      if (payload is Map<String, dynamic> && payload['methods'] is List) {
        _mfaMethodsCount = (payload['methods'] as List)
            .whereType<Map<String, dynamic>>()
            .where((m) => m['isActive'] == true && m['isVerified'] == true)
            .length;
      }
    } on DioException catch (error) {
      _errorMessage ??= _errorMessageFrom(error);
    } on AppException catch (error) {
      _errorMessage ??= error.message;
    } catch (error) {
      _errorMessage ??= 'Unable to load MFA details: $error';
    }
  }

  Future<void> _requestEmailVerification() async {
    final authState = ref.read(authNotifierProvider);
    final user = authState.user;
    if (user?.email == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/verify-email/request',
            data: {'email': user!.email},
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent')),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessageFrom(error))));
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _requestPhoneVerification() async {
    final authState = ref.read(authNotifierProvider);
    final user = authState.user;
    if (user?.phone == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/verify-phone/request',
            data: {'phone': user!.phone},
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent via SMS')),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessageFrom(error))));
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  String _errorMessageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to complete the action. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAccountStatus,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    AppNotice(
                      message: _errorMessage!,
                      type: NoticeType.error,
                      onDismiss: () => setState(() => _errorMessage = null),
                    ),

                  // Account status header
                  _buildStatusHeader(context),
                  const SizedBox(height: 24),

                  // Verification status
                  _buildSectionTitle(
                    context,
                    'Verification status',
                    Icons.verified_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      children: [
                        _buildVerificationRow(
                          context,
                          title: 'Email address',
                          subtitle:
                              'Required for account recovery and notifications',
                          verified: _emailVerified,
                          icon: Icons.email_outlined,
                          onAction: _emailVerified
                              ? null
                              : _requestEmailVerification,
                          actionLabel: 'Verify',
                        ),
                        const Divider(height: 24),
                        _buildVerificationRow(
                          context,
                          title: 'Phone number',
                          subtitle: 'Required for SMS notifications and 2FA',
                          verified: _phoneVerified,
                          icon: Icons.phone_outlined,
                          onAction: _phoneVerified
                              ? null
                              : _requestPhoneVerification,
                          actionLabel: 'Verify',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Security status
                  _buildSectionTitle(
                    context,
                    'Security',
                    Icons.security_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      children: [
                        _buildSecurityRow(
                          context,
                          title: 'Two-factor authentication',
                          subtitle: '$_mfaMethodsCount active method(s)',
                          status: _mfaEnabled ? 'Enabled' : 'Disabled',
                          isEnabled: _mfaEnabled,
                          icon: Icons.shield_outlined,
                          onTap: () => context.push('/mfa/manage'),
                        ),
                        const Divider(height: 24),
                        _buildSecurityRow(
                          context,
                          title: 'Active sessions',
                          subtitle:
                              '$_activeSessions session(s) across devices',
                          status: '$_activeSessions active',
                          isEnabled: _activeSessions > 0,
                          icon: Icons.devices_outlined,
                          onTap: () => context.push('/sessions'),
                        ),
                        const Divider(height: 24),
                        _buildSecurityRow(
                          context,
                          title: 'Trusted devices',
                          subtitle: '$_activeDevices registered device(s)',
                          status: '$_activeDevices device(s)',
                          isEnabled: _activeDevices > 0,
                          icon: Icons.phone_android_outlined,
                          onTap: () => context.push('/devices'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account restrictions (if any)
                  if (_isSuspended || _isLocked || _isDeactivated) ...[
                    _buildSectionTitle(
                      context,
                      'Account restrictions',
                      Icons.warning_amber_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      padding: AppSpacing.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isSuspended) ...[
                            _buildRestrictionCard(
                              context,
                              title: 'Account suspended',
                              reason:
                                  _suspensionReason ??
                                  'Your account has been suspended.',
                              icon: Icons.pause_circle_rounded,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_isLocked) ...[
                            _buildRestrictionCard(
                              context,
                              title: 'Account locked',
                              reason:
                                  _lockReason ??
                                  'Your account is temporarily locked.',
                              icon: Icons.lock_rounded,
                              color: theme.colorScheme.error,
                              expiresAt: _lockedUntil,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_isDeactivated) ...[
                            _buildRestrictionCard(
                              context,
                              title: 'Account deactivated',
                              reason: 'Your account has been deactivated.',
                              icon: Icons.cancel_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Roles & permissions
                  _buildSectionTitle(
                    context,
                    'Roles & permissions',
                    Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current roles',
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _roles.map((role) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: AppBorderRadius.mediumRadius,
                              ),
                              child: Text(
                                _formatRole(role),
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (_roles.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'No roles assigned',
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account info
                  _buildSectionTitle(
                    context,
                    'Account information',
                    Icons.info_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      children: [
                        _buildInfoRow(
                          context,
                          'Account created',
                          _formatDate(_createdAt),
                        ),
                        const Divider(height: 16),
                        _buildInfoRow(
                          context,
                          'Last sign-in',
                          _formatDate(_lastSignInAt),
                        ),
                        const Divider(height: 16),
                        _buildInfoRow(
                          context,
                          'Account status',
                          _formatAccountStatus(_accountStatus),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusHeader(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(theme, _accountStatus);
    final statusIcon = _getStatusIcon(_accountStatus);

    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: AppBorderRadius.largeRadius,
            ),
            child: Icon(statusIcon, color: statusColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account status',
                  style: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAccountStatus(_accountStatus),
                  style: AppTypography.headlineSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _mfaEnabled
                        ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                        : theme.colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: AppBorderRadius.roundRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _mfaEnabled
                            ? Icons.shield_rounded
                            : Icons.shield_outlined,
                        size: 14,
                        color: _mfaEnabled
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _mfaEnabled ? 'MFA enabled' : 'MFA not enabled',
                        style: AppTypography.labelSmall.copyWith(
                          color: _mfaEnabled
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.tertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool verified,
    required IconData icon,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: verified
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppBorderRadius.mediumRadius,
          ),
          child: Icon(
            icon,
            color: verified
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onSurfaceVariant,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: verified
                          ? theme.colorScheme.secondaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: AppBorderRadius.roundRadius,
                    ),
                    child: Text(
                      verified ? 'Verified' : 'Not verified',
                      style: AppTypography.labelSmall.copyWith(
                        color: verified
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
        if (onAction != null && actionLabel != null)
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }

  Widget _buildSecurityRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String status,
    required bool isEnabled,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppBorderRadius.mediumRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppBorderRadius.mediumRadius,
              ),
              child: Icon(
                icon,
                color: isEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      color: theme.colorScheme.onSurface,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isEnabled
                    ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppBorderRadius.roundRadius,
              ),
              child: Text(
                status,
                style: AppTypography.labelSmall.copyWith(
                  color: isEnabled
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRestrictionCard(
    BuildContext context, {
    required String title,
    required String reason,
    required IconData icon,
    required Color color,
    DateTime? expiresAt,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: AppBorderRadius.largeRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
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
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (expiresAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Lock expires: ${_formatDateTime(expiresAt)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return AppFormatters.date(date);
  }

  String _formatDateTime(DateTime date) {
    return AppFormatters.remainingTime(date);
  }
}
