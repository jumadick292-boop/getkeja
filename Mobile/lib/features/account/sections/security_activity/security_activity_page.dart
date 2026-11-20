// Security activity page showing recent sign-ins and security events.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../app/preferences/app_preferences.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/presentation/state/auth_state.dart';
import '../../../../shared/models/auth_models.dart';

class SecurityActivityPage extends ConsumerStatefulWidget {
  const SecurityActivityPage({super.key});

  @override
  ConsumerState<SecurityActivityPage> createState() =>
      _SecurityActivityPageState();
}

class _SecurityActivityPageState extends ConsumerState<SecurityActivityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;

  List<SecurityEvent> _securityEvents = [];
  List<SecurityEvent> _signInEvents = [];

  int _securityEventsOffset = 0;
  int _signInEventsOffset = 0;
  static const int _pageSize = 20;
  bool _hasMoreSecurityEvents = true;
  bool _hasMoreSignInEvents = true;
  bool _loadingMoreSecurity = false;
  bool _loadingMoreSignIn = false;

  final _securityScrollController = ScrollController();
  final _signInScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _securityScrollController.addListener(_onSecurityScroll);
    _signInScrollController.addListener(_onSignInScroll);
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _securityScrollController.dispose();
    _signInScrollController.dispose();
    super.dispose();
  }

  void _onSecurityScroll() {
    if (_securityScrollController.position.pixels >=
        _securityScrollController.position.maxScrollExtent - 200) {
      _loadMoreSecurityEvents();
    }
  }

  void _onSignInScroll() {
    if (_signInScrollController.position.pixels >=
        _signInScrollController.position.maxScrollExtent - 200) {
      _loadMoreSignInEvents();
    }
  }

  Future<void> _loadEvents({bool refresh = false}) async {
    if (refresh) {
      _securityEventsOffset = 0;
      _signInEventsOffset = 0;
      _hasMoreSecurityEvents = true;
      _hasMoreSignInEvents = true;
    }
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadSecurityEvents(refresh: refresh),
        _loadSignInEvents(refresh: refresh),
      ]);
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

  Future<void> _loadSecurityEvents({bool refresh = false}) async {
    if (refresh) _securityEventsOffset = 0;
    if (!_hasMoreSecurityEvents) return;

    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/security-events',
            queryParameters: {
              'limit': _pageSize,
              'offset': _securityEventsOffset,
              'category': 'security',
            },
          );
      final payload = response.data?['data'];
      if (payload is Map<String, dynamic> && payload['events'] is List) {
        final events = (payload['events'] as List)
            .whereType<Map<String, dynamic>>()
            .map(SecurityEvent.fromJson)
            .toList();
        if (mounted) {
          setState(() {
            if (refresh) {
              _securityEvents = events;
            } else {
              _securityEvents.addAll(events);
            }
            _securityEventsOffset += events.length;
            _hasMoreSecurityEvents = events.length >= _pageSize;
          });
        }
      }
    } on DioException catch (error) {
      if (mounted) setState(() => _errorMessage = _errorMessageFrom(error));
    } on AppException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    }
  }

  Future<void> _loadSignInEvents({bool refresh = false}) async {
    if (refresh) _signInEventsOffset = 0;
    if (!_hasMoreSignInEvents) return;

    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/security-events',
            queryParameters: {
              'limit': _pageSize,
              'offset': _signInEventsOffset,
              'category': 'authentication',
            },
          );
      final payload = response.data?['data'];
      if (payload is Map<String, dynamic> && payload['events'] is List) {
        final events = (payload['events'] as List)
            .whereType<Map<String, dynamic>>()
            .map(SecurityEvent.fromJson)
            .toList();
        if (mounted) {
          setState(() {
            if (refresh) {
              _signInEvents = events;
            } else {
              _signInEvents.addAll(events);
            }
            _signInEventsOffset += events.length;
            _hasMoreSignInEvents = events.length >= _pageSize;
          });
        }
      }
    } on DioException catch (error) {
      if (mounted) setState(() => _errorMessage = _errorMessageFrom(error));
    } on AppException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    }
  }

  Future<void> _loadMoreSecurityEvents() async {
    if (_loadingMoreSecurity || !_hasMoreSecurityEvents) return;
    setState(() => _loadingMoreSecurity = true);
    await _loadSecurityEvents();
    if (mounted) setState(() => _loadingMoreSecurity = false);
  }

  Future<void> _loadMoreSignInEvents() async {
    if (_loadingMoreSignIn || !_hasMoreSignInEvents) return;
    setState(() => _loadingMoreSignIn = true);
    await _loadSignInEvents();
    if (mounted) setState(() => _loadingMoreSignIn = false);
  }

  String _errorMessageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to load security activity. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security activity'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Security events'),
            Tab(text: 'Sign-in activity'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadEvents(refresh: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading && _securityEvents.isEmpty && _signInEvents.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: AppSpacing.screenPadding,
                    child: AppNotice(
                      message: _errorMessage!,
                      type: NoticeType.error,
                      onDismiss: () => setState(() => _errorMessage = null),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEventList(
                        context,
                        events: _securityEvents,
                        hasMore: _hasMoreSecurityEvents,
                        loadingMore: _loadingMoreSecurity,
                        scrollController: _securityScrollController,
                        emptyMessage: 'No security events recorded',
                        emptyIcon: Icons.security_outlined,
                      ),
                      _buildEventList(
                        context,
                        events: _signInEvents,
                        hasMore: _hasMoreSignInEvents,
                        loadingMore: _loadingMoreSignIn,
                        scrollController: _signInScrollController,
                        emptyMessage: 'No sign-in activity recorded',
                        emptyIcon: Icons.login_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventList(
    BuildContext context, {
    required List<SecurityEvent> events,
    required bool hasMore,
    required bool loadingMore,
    required ScrollController scrollController,
    required String emptyMessage,
    required IconData emptyIcon,
  }) {
    final theme = Theme.of(context);

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                emptyIcon,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: AppTypography.titleMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadEvents(refresh: true),
      child: ListView.builder(
        controller: scrollController,
        padding: AppSpacing.screenPadding,
        itemCount: events.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= events.length) {
            return loadingMore
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }
          final event = events[index];
          return _buildEventCard(context, event);
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, SecurityEvent event) {
    final theme = Theme.of(context);
    final (icon, color) = _getEventIconAndColor(
      event.eventType,
      event.severity,
    );

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
                        _formatEventTitle(event.eventType),
                        style: AppTypography.bodyLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(
                          theme,
                          event.severity,
                        ).withValues(alpha: 0.1),
                        borderRadius: AppBorderRadius.roundRadius,
                      ),
                      child: Text(
                        event.severity.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(
                          color: _getSeverityColor(theme, event.severity),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (event.ipAddress != null || event.userAgent != null) ...[
                  Row(
                    children: [
                      if (event.ipAddress != null) ...[
                        Icon(
                          Icons.wifi_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.ipAddress!,
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (event.userAgent != null)
                  Text(
                    _parseUserAgent(event.userAgent!),
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _formatDateTime(event.createdAt),
                  style: AppTypography.labelSmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (event.severity == 'critical') ...[
            const SizedBox(width: 8),
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }

  (IconData, Color) _getEventIconAndColor(String eventType, String severity) {
    final theme = Theme.of(context);
    switch (eventType.toLowerCase()) {
      case 'sign_in':
      case 'login':
        return (Icons.login_rounded, theme.colorScheme.primary);
      case 'sign_out':
      case 'logout':
        return (Icons.logout_rounded, theme.colorScheme.primary);
      case 'password_change':
        return (Icons.lock_outlined, theme.colorScheme.tertiary);
      case 'email_change':
        return (Icons.email_outlined, theme.colorScheme.tertiary);
      case 'phone_change':
        return (Icons.phone_outlined, theme.colorScheme.tertiary);
      case 'mfa_enabled':
      case 'mfa_method_added':
        return (Icons.shield_outlined, theme.colorScheme.secondary);
      case 'mfa_disabled':
      case 'mfa_method_removed':
        return (Icons.shield_outlined, theme.colorScheme.error);
      case 'google_linked':
        return (Icons.g_mobiledata, theme.colorScheme.primary);
      case 'google_unlinked':
        return (Icons.link_off_outlined, theme.colorScheme.error);
      case 'device_registered':
        return (Icons.devices_outlined, theme.colorScheme.primary);
      case 'device_revoked':
        return (Icons.devices_outlined, theme.colorScheme.error);
      case 'session_revoked':
        return (Icons.logout_rounded, theme.colorScheme.error);
      case 'account_recovery':
        return (Icons.restore_outlined, AppColors.warning);
      default:
        return (Icons.event_outlined, theme.colorScheme.onSurfaceVariant);
    }
  }

  Color _getSeverityColor(ThemeData theme, String severity) {
    switch (severity) {
      case 'critical':
        return theme.colorScheme.error;
      case 'warning':
        return theme.colorScheme.tertiary;
      case 'info':
      default:
        return theme.colorScheme.primary;
    }
  }

  String _formatEventTitle(String eventType) {
    return eventType
        .split('_')
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _parseUserAgent(String userAgent) {
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
