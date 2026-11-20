// Sessions management page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../app/preferences/app_preferences.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({super.key});

  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
  List<Session> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/sessions');
      final payload = response.data?['data'];
      if (payload is! Map<String, dynamic> || payload['sessions'] is! List) {
        throw const FormatException(
          'The server returned invalid session data.',
        );
      }
      final sessions = (payload['sessions'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Session.fromJson)
          .toList();
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _errorMessageFrom(error));
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke session?'),
        content: const Text(
          'This will sign you out on that device/browser. You\'ll need to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(apiClientProvider)
          .delete<Map<String, dynamic>>('/sessions/$sessionId');
      _showMessage('Session revoked.');
      await _loadSessions();
    } on DioException catch (error) {
      _showError(_errorMessageFrom(error));
    } on AppException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _revokeAllOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of all other sessions?'),
        content: const Text(
          'This will revoke all sessions except the current one. You\'ll stay signed in on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign out all others'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final otherSessions = _sessions.where(
      (session) => !session.isCurrent && _isActive(session),
    );
    try {
      for (final session in otherSessions) {
        await ref
            .read(apiClientProvider)
            .delete<Map<String, dynamic>>('/sessions/${session.id}');
      }
      _showMessage('All other sessions revoked.');
      await _loadSessions();
    } on DioException catch (error) {
      _showError(
        '${_errorMessageFrom(error)} Some sessions may already have been revoked; refresh the list.',
      );
      await _loadSessions();
    } on AppException catch (error) {
      _showError(error.message);
      await _loadSessions();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to update sessions. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active sessions'),
        actions: [
          if (_sessions.any((s) => !s.isCurrent && _isActive(s)))
            TextButton.icon(
              onPressed: _revokeAllOtherSessions,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign out all others'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.screenPadding,
              children: [
                if (_errorMessage != null)
                  AppNotice(message: _errorMessage!, type: NoticeType.error),
                if (_errorMessage != null)
                  TextButton(
                    onPressed: _loadSessions,
                    child: const Text('Try again'),
                  ),
                // Current session
                if (_sessions.any((s) => s.isCurrent)) ...[
                  _buildCurrentSessionCard(
                    _sessions.firstWhere((s) => s.isCurrent),
                  ),
                  const SizedBox(height: 24),
                ],

                // Other sessions
                Text(
                  'Other sessions',
                  style: AppTypography.titleMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                if (_sessions
                    .where((s) => !s.isCurrent && _isActive(s))
                    .isEmpty)
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No other active sessions',
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ..._sessions
                      .where((s) => !s.isCurrent)
                      .map((session) => _buildSessionCard(session)),

                const SizedBox(height: 24),

                // Help text
                AppCard(
                  padding: AppSpacing.cardPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Revoke sessions you don\'t recognize. This will sign you out on those devices immediately.',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildCurrentSessionCard(Session session) {
    final theme = Theme.of(context);

    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: AppBorderRadius.mediumRadius,
                ),
                child: Icon(
                  Icons.devices_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
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
                          'Current session',
                          style: AppTypography.titleMedium.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: AppBorderRadius.roundRadius,
                          ),
                          child: Text(
                            'Active now',
                            style: AppTypography.labelSmall.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _parseUserAgent(session.userAgent),
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SessionInfoItem(
                  label: 'Location',
                  value: '${session.city ?? ''}, ${session.countryCode ?? ''}'
                      .trim()
                      .replaceAll(RegExp(r'^\s*,\s*'), ''),
                ),
              ),
              Expanded(
                child: _SessionInfoItem(
                  label: 'IP address',
                  value: session.ipAddress ?? 'Unknown',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SessionInfoItem(
                  label: 'Session started',
                  value: _formatDateTime(session.createdAt),
                ),
              ),
              Expanded(
                child: _SessionInfoItem(
                  label: 'Expires',
                  value: _formatDateTime(session.absoluteExpiresAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Session session) {
    final theme = Theme.of(context);
    final isActive = _isActive(session);
    final status = session.revokedAt != null
        ? 'Revoked'
        : isActive
        ? 'Active'
        : 'Expired';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: session.isCurrent
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: AppBorderRadius.mediumRadius,
                ),
                child: Icon(
                  Icons.devices_rounded,
                  color: session.isCurrent
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
                      _parseUserAgent(session.userAgent),
                      style: AppTypography.bodyLarge.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: !isActive
                                ? theme.colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  )
                                : theme.colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status,
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SessionInfoItem(
                  label: 'Location',
                  value: '${session.city ?? ''}, ${session.countryCode ?? ''}'
                      .trim()
                      .replaceAll(RegExp(r'^\s*,\s*'), ''),
                ),
              ),
              Expanded(
                child: _SessionInfoItem(
                  label: 'IP address',
                  value: session.ipAddress ?? 'Unknown',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SessionInfoItem(
                  label: 'Started',
                  value: _formatDateTime(session.createdAt),
                ),
              ),
              Expanded(
                child: _SessionInfoItem(
                  label: 'Expires',
                  value: _formatDateTime(session.absoluteExpiresAt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: isActive ? () => _revokeSession(session.id) : null,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Revoke'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(vertical: 8),
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isActive(Session session) {
    final now = DateTime.now();
    return session.revokedAt == null &&
        session.idleExpiresAt.isAfter(now) &&
        session.absoluteExpiresAt.isAfter(now);
  }

  Widget _buildStatusChip(String status) {
    final theme = Theme.of(context);
    final isActive = status == 'Active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: !isActive
            ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1)
            : theme.colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Text(
        status,
        style: AppTypography.labelSmall.copyWith(
          color: !isActive
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _parseUserAgent(String? userAgent) {
    if (userAgent == null) return 'Unknown device';
    if (userAgent.contains('GetKeja')) {
      if (userAgent.contains('Android')) return 'Android app';
      if (userAgent.contains('iOS')) return 'iOS app';
      return 'Mobile app';
    }
    if (userAgent.contains('Mozilla')) return 'Web browser';
    return 'Unknown device';
  }

  String _formatDateTime(DateTime dateTime) {
    return AppFormatters.relativeTime(dateTime);
  }
}

class _SessionInfoItem extends StatelessWidget {
  const _SessionInfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? 'Unknown' : value,
          style: AppTypography.bodyMedium.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
