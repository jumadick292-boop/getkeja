// Devices management page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../app/preferences/app_preferences.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  List<Device> _devices = [];
  bool _isLoading = false;
  String? _currentDeviceId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.get<Map<String, dynamic>>('/devices'),
        api.get<Map<String, dynamic>>('/sessions/current'),
      ]);
      final deviceData = results[0].data?['data'];
      final sessionData = results[1].data?['data'];
      if (deviceData is! Map<String, dynamic> ||
          deviceData['devices'] is! List) {
        throw const FormatException('The server returned invalid device data.');
      }
      final devices = (deviceData['devices'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Device.fromJson)
          .toList();
      final session = sessionData is Map<String, dynamic>
          ? sessionData['session']
          : null;
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _currentDeviceId = session is Map<String, dynamic>
            ? session['deviceId'] as String?
            : null;
      });
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

  Future<void> _revokeDevice(String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke device?'),
        content: const Text(
          'This will sign you out on that device and remove its access. You\'ll need to sign in again on that device.',
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
          .delete<Map<String, dynamic>>('/devices/$deviceId');
      _showMessage('Device revoked.');
      await _loadDevices();
    } on DioException catch (error) {
      _showError(_errorMessageFrom(error));
    } on AppException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _renameDevice(String deviceId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Device name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == currentName) return;

    try {
      await ref
          .read(apiClientProvider)
          .patch<Map<String, dynamic>>(
            '/devices/$deviceId',
            data: {'deviceName': newName},
          );
      _showMessage('Device renamed.');
      await _loadDevices();
    } on DioException catch (error) {
      _showError(_errorMessageFrom(error));
    } on AppException catch (error) {
      _showError(error.message);
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
    return 'Unable to update devices. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.screenPadding,
              children: [
                if (_errorMessage != null)
                  AppNotice(message: _errorMessage!, type: NoticeType.error),
                if (_errorMessage != null)
                  TextButton(
                    onPressed: _loadDevices,
                    child: const Text('Try again'),
                  ),
                if (_currentDeviceId == null)
                  const AppNotice(
                    message:
                        'The current device could not be identified by the server. Device revocation is disabled until session linking is available.',
                    type: NoticeType.info,
                  ),
                // Current device indicator
                if (_devices.isNotEmpty) ...[
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: AppBorderRadius.mediumRadius,
                          ),
                          child: Icon(
                            Icons.phone_android_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current device',
                                style: AppTypography.titleMedium.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This is the device you\'re using right now',
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                  ),
                  const SizedBox(height: 24),
                ],

                // Devices list
                Text(
                  'All devices',
                  style: AppTypography.titleMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                if (_devices.isEmpty)
                  AppCard(
                    padding: AppSpacing.cardPadding,
                    child: Column(
                      children: [
                        Icon(
                          Icons.devices_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No devices found',
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ..._devices.map((device) => _buildDeviceCard(device)),

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
                          'Revoke devices you no longer use or recognize. Revoking a device will sign you out on that device.',
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

  Widget _buildDeviceCard(Device device) {
    final theme = Theme.of(context);
    final isCurrent = device.id == _currentDeviceId;
    final canManage =
        _currentDeviceId != null && !isCurrent && device.status == 'active';
    final (icon, platformLabel) = _getPlatformInfo(device.platform);

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
                  color: isCurrent
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: AppBorderRadius.mediumRadius,
                ),
                child: Icon(
                  icon,
                  color: isCurrent
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
                    Row(
                      children: [
                        Text(
                          device.deviceName ?? platformLabel,
                          style: AppTypography.bodyLarge.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: AppBorderRadius.roundRadius,
                            ),
                            child: Text(
                              'This device',
                              style: AppTypography.labelSmall.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.deviceModel ?? ''} • ${device.osVersion ?? ''}'
                          .trim()
                          .replaceAll(RegExp(r'^\s*•\s*'), ''),
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(device.status),
            ],
          ),
          if (canManage) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DeviceInfoItem(
                    label: 'Last active',
                    value: _formatDateTime(device.lastActivityAt),
                  ),
                ),
                Expanded(
                  child: _DeviceInfoItem(
                    label: 'Location',
                    value:
                        '${device.lastCity ?? ''}, ${device.lastCountryCode ?? ''}'
                            .trim()
                            .replaceAll(RegExp(r'^\s*,\s*'), ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isCurrent)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _renameDevice(
                        device.id,
                        device.deviceName ?? platformLabel,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Rename'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                if (!isCurrent) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _revokeDevice(device.id),
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
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final theme = Theme.of(context);
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = theme.colorScheme.secondary;
        label = 'Active';
        break;
      case 'revoked':
        color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
        label = 'Revoked';
        break;
      case 'expired':
        color = theme.colorScheme.tertiary;
        label = 'Expired';
        break;
      default:
        color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (IconData, String) _getPlatformInfo(String platform) {
    switch (platform) {
      case 'android':
        return (Icons.phone_android_rounded, 'Android');
      case 'ios':
        return (Icons.phone_iphone_rounded, 'iOS');
      case 'web':
        return (Icons.web_rounded, 'Web');
      default:
        return (Icons.devices_rounded, platform);
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    return AppFormatters.relativeTime(dateTime);
  }
}

class _DeviceInfoItem extends StatelessWidget {
  const _DeviceInfoItem({required this.label, required this.value});

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
