import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/api/api_client.dart';

const bool _mapsEnabled = bool.fromEnvironment('GOOGLE_MAPS_ENABLED');

class LocationSharingPage extends ConsumerStatefulWidget {
  const LocationSharingPage({super.key});

  @override
  ConsumerState<LocationSharingPage> createState() =>
      _LocationSharingPageState();
}

class _LocationSharingPageState extends ConsumerState<LocationSharingPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _ownedSessions = [];
  List<Map<String, dynamic>> _sharedWithMe = [];
  Map<String, dynamic>? _active;
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastUpdate;
  bool _loading = true;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_positionSubscription?.cancel());
    final session = _active;
    if (session != null) unawaited(_stopSession(session, refresh: false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final session = _active;
      if (session != null) unawaited(_stopSession(session));
    }
  }

  List<Map<String, dynamic>> _rows(Object? payload) => payload is List
      ? payload
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final responses = await Future.wait([
        api.get<Map<String, dynamic>>(
          '/api/v1/location-sharing/eligible-visits',
        ),
        api.get<Map<String, dynamic>>('/api/v1/location-sharing/sessions'),
        api.get<Map<String, dynamic>>(
          '/api/v1/location-sharing/shared-with-me',
        ),
      ]);
      final visits = _rows(responses[0].data?['data']);
      final owned = _rows(responses[1].data?['data']);
      final received = _rows(responses[2].data?['data']);
      // A process restart never resumes tracking. Revoke any prior active session.
      final currentSessionId = _active?['id']?.toString();
      for (final session in owned.where(
        (row) =>
            row['active'] == true && row['id']?.toString() != currentSessionId,
      )) {
        await api.post<Map<String, dynamic>>(
          '/api/v1/location-sharing/sessions/${session['id']}/stop',
        );
      }
      if (!mounted) return;
      setState(() {
        _visits = visits;
        _ownedSessions = owned.where((row) => row['active'] != true).toList();
        _sharedWithMe = received;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Location sharing could not be loaded. Try again.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError(
        'Turn on device location services to share your location.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw StateError(
        'Enable location permission in device settings to continue.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw StateError(
        'Location permission is required for a sharing session.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> _startSharing(Map<String, dynamic> visit) async {
    final duration = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Share your live location with ${visit['recipientName'] ?? 'the other site visit participant'}',
              ),
              subtitle: const Text(
                'Only this person can see it. Sharing stops when time expires or you stop it.',
              ),
            ),
            for (final choice in const [
              (15, '15 minutes'),
              (30, '30 minutes'),
              (60, '1 hour'),
              (480, 'Until stopped (maximum 8 hours)'),
            ])
              ListTile(
                title: Text(choice.$2),
                onTap: () => Navigator.pop(context, choice.$1),
              ),
          ],
        ),
      ),
    );
    if (duration == null || !mounted) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      // Request permission and get a fresh fix before creating a share session.
      final position = await _getPosition();
      final response = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/api/v1/location-sharing/sessions',
            data: {
              'siteVisitId': visit['siteVisitId'],
              'recipientUserId': visit['recipientUserId'],
              'durationMinutes': duration,
            },
          );
      final data = response.data?['data'];
      if (data is! Map || data['id'] == null)
        throw StateError('Could not start the sharing session.');
      final session = Map<String, dynamic>.from(data);
      if (!mounted) return;
      setState(() => _active = session);
      await _sendPosition(session, position);
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((next) => unawaited(_sendPosition(session, next)));
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Could not start location sharing.',
        );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _sendPosition(
    Map<String, dynamic> session,
    Position position,
  ) async {
    final now = DateTime.now();
    if (_lastUpdate != null &&
        now.difference(_lastUpdate!) < const Duration(seconds: 15))
      return;
    _lastUpdate = now;
    try {
      await ref
          .read(apiClientProvider)
          .patch<Map<String, dynamic>>(
            '/api/v1/location-sharing/sessions/${session['id']}/location',
            data: {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracyMeters': position.accuracy,
            },
          );
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Location update failed. Stop and restart sharing if the connection returns.',
        );
    }
  }

  Future<void> _stopSession(
    Map<String, dynamic> session, {
    bool refresh = true,
  }) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/api/v1/location-sharing/sessions/${session['id']}/stop',
          );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not confirm the stop request. Sharing access remains available until the server receives it or the session expires. Retry stopping when you are online.',
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        _active = null;
        _lastUpdate = null;
      });
      if (refresh) await _load();
    }
  }

  Future<void> _viewSharedLocation(Map<String, dynamic> share) async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/api/v1/location-sharing/sessions/${share['id']}/location',
          );
      final data = response.data?['data'];
      if (data is! Map || !mounted) return;
      final lat = double.tryParse(data['latitude'].toString());
      final lon = double.tryParse(data['longitude'].toString());
      if (lat == null || lon == null) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Shared live location'),
          content: SizedBox(
            width: 420,
            height: 300,
            child: _mapsEnabled
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(lat, lon),
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('shared-location'),
                        position: LatLng(lat, lon),
                      ),
                    },
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                  )
                : Center(
                    child: Text(
                      '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This shared location has expired or been stopped.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location sharing'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Sharing is off unless you start a session for a scheduled or confirmed site visit. Precise coordinates are visible only to the other participant, and background tracking is not used.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (active != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.location_searching),
                      title: const Text('Location is being shared'),
                      subtitle: Text(
                        'Expires ${active['expiresAt'] ?? 'automatically'}',
                      ),
                      trailing: TextButton(
                        onPressed: () => _stopSession(active),
                        child: const Text('Stop now'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Eligible site visits',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_visits.isEmpty)
                  const ListTile(
                    title: Text(
                      'No scheduled visits with another app user are available.',
                    ),
                  ),
                for (final visit in _visits)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text(
                        visit['propertyTitle']?.toString() ?? 'Site visit',
                      ),
                      subtitle: Text(
                        [
                              visit['recipientName']?.toString(),
                              visit['city']?.toString(),
                              visit['scheduledAt']?.toString(),
                            ]
                            .whereType<String>()
                            .where((value) => value.isNotEmpty)
                            .join(' · '),
                      ),
                      trailing: active != null
                          ? null
                          : TextButton(
                              onPressed: _starting
                                  ? null
                                  : () => _startSharing(visit),
                              child: const Text('Share'),
                            ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Shared with me',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_sharedWithMe.isEmpty)
                  const ListTile(title: Text('No active location shares.')),
                for (final share in _sharedWithMe)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        share['sharerName']?.toString() ??
                            'Site visit participant',
                      ),
                      subtitle: Text(
                        'Expires ${share['expiresAt'] ?? 'automatically'}',
                      ),
                      trailing: TextButton(
                        onPressed: () => _viewSharedLocation(share),
                        child: const Text('View'),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Recent sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final session in _ownedSessions.take(10))
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text('Site visit ${session['siteVisitId']}'),
                    subtitle: Text(
                      'Expires ${session['expiresAt'] ?? 'automatically'}',
                    ),
                  ),
              ],
            ),
    );
  }
}
