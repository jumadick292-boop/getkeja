import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_client.dart';

const bool _mapsEnabled = bool.fromEnvironment(
  'GOOGLE_MAPS_ENABLED',
  defaultValue: false,
);

class NearbyPropertiesPage extends ConsumerStatefulWidget {
  const NearbyPropertiesPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<NearbyPropertiesPage> createState() =>
      _NearbyPropertiesPageState();
}

class _NearbyPropertiesPageState extends ConsumerState<NearbyPropertiesPage> {
  static const _nairobi = LatLng(-1.286389, 36.817223);
  final _searchController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng _center = _nairobi;
  LatLngBounds? _bounds;
  List<Map<String, dynamic>> _items = [];
  double _radiusKm = 10;
  double? _rentMin;
  double? _rentMax;
  int? _bedrooms;
  bool _loading = false;
  bool _locating = false;
  bool _showMap = _mapsEnabled;
  bool _hasSearch = false;
  bool _hasCenterLocation = false;
  String? _error;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeSearch());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  double? _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  Future<void> _initializeSearch() async {
    if (_searchController.text.trim().isNotEmpty) {
      _hasSearch = true;
      await _search();
      return;
    }
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/api/v1/profile/locations');
      final rows = response.data?['data'];
      if (rows is List) {
        for (final row in rows.whereType<Map>()) {
          final type = row['location_type'] ?? row['locationType'];
          final lat = _number(row['latitude']);
          final lon = _number(row['longitude']);
          if (type == 'personal_residential' && lat != null && lon != null) {
            _center = LatLng(lat, lon);
            _hasSearch = true;
            _hasCenterLocation = true;
            break;
          }
        }
      }
    } catch (_) {
      // Search remains available by text if saved-location lookup is unavailable.
    }
    if (_hasSearch) await _search();
    if (mounted) setState(() {});
  }

  Future<void> _search({LatLngBounds? bounds}) async {
    final requestVersion = ++_requestVersion;
    _hasSearch = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, Object>{
        'radiusKm': _radiusKm,
        'limit': 50,
        if (_rentMin != null) 'rentMin': _rentMin!,
        if (_rentMax != null) 'rentMax': _rentMax!,
        if (_bedrooms != null) 'bedrooms': _bedrooms!,
        if (_searchController.text.trim().isNotEmpty)
          'q': _searchController.text.trim(),
      };
      final visible = bounds ?? _bounds;
      if (visible != null) {
        params.addAll({
          'north': visible.northeast.latitude,
          'south': visible.southwest.latitude,
          'east': visible.northeast.longitude,
          'west': visible.southwest.longitude,
        });
      } else if (_hasCenterLocation) {
        params.addAll({
          'latitude': _center.latitude,
          'longitude': _center.longitude,
        });
      }
      if (visible == null &&
          !_hasCenterLocation &&
          _searchController.text.trim().isEmpty) {
        if (mounted) {
          setState(
            () => _error =
                'Search a town or estate, or choose Use current location to search nearby.',
          );
        }
        return;
      }
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/api/v1/listings/nearby',
            queryParameters: params,
          );
      final payload = response.data?['data'];
      final raw = payload is Map ? payload['items'] : null;
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _items = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
      });
      if (_showMap && _mapController != null && bounds == null) {
        await _mapController!.animateCamera(CameraUpdate.newLatLng(_center));
      }
    } catch (_) {
      if (mounted && requestVersion == _requestVersion) {
        setState(
          () => _error =
              'Listings could not be loaded. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Turn on device location services, or search by place name.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
        throw StateError(
          'Location permission is unavailable. You can still search by place name.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _bounds = null;
        _hasCenterLocation = true;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_center, 13),
      );
      await _search();
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Could not read your current location.',
        );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _editFilters() async {
    final minimum = TextEditingController(
      text: _rentMin?.toStringAsFixed(0) ?? '',
    );
    final maximum = TextEditingController(
      text: _rentMax?.toStringAsFixed(0) ?? '',
    );
    var bedrooms = _bedrooms;
    final filters = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Property filters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minimum,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum rent',
                        prefixText: 'KSh ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maximum,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum rent',
                        prefixText: 'KSh ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: bedrooms,
                decoration: const InputDecoration(
                  labelText: 'Bedrooms',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Any')),
                  for (var count = 0; count <= 5; count++)
                    DropdownMenuItem<int?>(
                      value: count,
                      child: Text(
                        count == 0
                            ? 'Bedsitter / studio'
                            : count == 5
                            ? '5 bedrooms'
                            : '$count bedroom${count == 1 ? '' : 's'}',
                      ),
                    ),
                ],
                onChanged: (value) => refresh(() => bedrooms = value),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final min = double.tryParse(minimum.text.trim());
                  final max = double.tryParse(maximum.text.trim());
                  final invalid =
                      (minimum.text.trim().isNotEmpty && min == null) ||
                      (maximum.text.trim().isNotEmpty && max == null) ||
                      (min != null && max != null && min > max);
                  if (invalid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid rent range.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, <String, Object?>{
                    'rentMin': min ?? -1,
                    'rentMax': max ?? -1,
                    'bedrooms': bedrooms ?? -1,
                  });
                },
                child: const Text('Apply filters'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, <String, Object?>{
                  'rentMin': -1,
                  'rentMax': -1,
                  'bedrooms': -1,
                }),
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      ),
    );
    minimum.dispose();
    maximum.dispose();
    if (filters == null || !mounted) return;
    setState(() {
      final min = (filters['rentMin'] as num).toDouble();
      final max = (filters['rentMax'] as num).toDouble();
      _rentMin = min < 0 ? null : min;
      _rentMax = max < 0 ? null : max;
      final bedroom = filters['bedrooms'] as int;
      _bedrooms = bedroom < 0 ? null : bedroom;
    });
    await _search();
  }

  Future<void> _openDirections(Map<String, dynamic> item) async {
    final lat = _number(item['latitude']);
    final lon = _number(item['longitude']);
    if (lat == null || lon == null) return;
    final destination = LatLng(lat, lon);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!enabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Current location is unavailable');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final response = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/api/v1/listings/directions',
            data: {
              'origin': {
                'latitude': position.latitude,
                'longitude': position.longitude,
              },
              'destination': {
                'latitude': destination.latitude,
                'longitude': destination.longitude,
              },
              'travelMode': 'DRIVE',
            },
          );
      final data = response.data?['data'];
      final routes = data is Map ? data['routes'] : null;
      if (routes is! List || routes.isEmpty || routes.first is! Map) {
        throw StateError('No route is available for this destination');
      }
      final route = Map<String, dynamic>.from(routes.first as Map);
      final encoded = route['polyline'] is Map
          ? (route['polyline'] as Map)['encodedPolyline']?.toString()
          : null;
      final points = encoded == null ? <LatLng>[] : _decodePolyline(encoded);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          final seconds = int.tryParse(
            '${route['duration']}'.replaceAll('s', ''),
          );
          final meters = _number(route['distanceMeters']);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    route['description']?.toString() ?? 'Route preview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${meters == null ? 'Distance unavailable' : '${(meters / 1000).toStringAsFixed(1)} km'} · ${seconds == null ? 'Duration unavailable' : '${(seconds / 60).ceil()} min'}',
                  ),
                  if (_mapsEnabled && points.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 250,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: points[points.length ~/ 2],
                          zoom: 11,
                        ),
                        polylines: {
                          Polyline(
                            polylineId: const PolylineId('route-preview'),
                            points: points,
                            color: Theme.of(context).colorScheme.primary,
                            width: 5,
                          ),
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('route-origin'),
                            position: LatLng(
                              position.latitude,
                              position.longitude,
                            ),
                          ),
                          Marker(
                            markerId: const MarkerId('route-destination'),
                            position: destination,
                          ),
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _launchExternalNavigation(destination);
                    },
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Open navigation app'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Route preview is unavailable. Opening an external navigation app.',
            ),
          ),
        );
      }
    }
    await _launchExternalNavigation(destination);
  }

  Future<void> _launchExternalNavigation(LatLng destination) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a navigation app.')),
      );
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;
    while (index < encoded.length) {
      var result = 0;
      var shift = 0;
      int value;
      do {
        value = encoded.codeUnitAt(index++) - 63;
        result |= (value & 0x1f) << shift;
        shift += 5;
      } while (value >= 0x20 && index < encoded.length);
      latitude += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      result = 0;
      shift = 0;
      do {
        value = encoded.codeUnitAt(index++) - 63;
        result |= (value & 0x1f) << shift;
        shift += 5;
      } while (value >= 0x20 && index < encoded.length);
      longitude += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }
    return points;
  }

  Set<Marker> get _markers => {
    for (final item in _items)
      if (_number(item['latitude']) case final lat?)
        if (_number(item['longitude']) case final lon?)
          Marker(
            markerId: MarkerId(item['id'].toString()),
            position: LatLng(lat, lon),
            infoWindow: InfoWindow(
              title: item['title']?.toString() ?? 'Property',
            ),
          ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a home'),
        actions: [
          IconButton(
            tooltip: 'Filter properties',
            onPressed: _editFilters,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: _showMap ? 'Show list' : 'Show map',
            onPressed: _mapsEnabled
                ? () => setState(() => _showMap = !_showMap)
                : null,
            icon: Icon(_showMap ? Icons.list_alt : Icons.map_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(bounds: null),
                        onChanged: (_) => _bounds = null,
                        decoration: InputDecoration(
                          hintText: 'Town, estate, address or property',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            onPressed: _search,
                            icon: const Icon(Icons.arrow_forward),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Use current location',
                      onPressed: _locating ? null : _useCurrentLocation,
                      icon: _locating
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Within'),
                    const SizedBox(width: 8),
                    DropdownButton<double>(
                      value: _radiusKm,
                      items: const [5, 10, 20, 50]
                          .map(
                            (km) => DropdownMenuItem(
                              value: km.toDouble(),
                              child: Text('$km km'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _radiusKm = value;
                          _bounds = null;
                        });
                        _search();
                      },
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _loading ? null : _search,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Search this area'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                if (_error!.contains('permission'))
                  TextButton(
                    onPressed: Geolocator.openAppSettings,
                    child: const Text('Settings'),
                  ),
                TextButton(onPressed: _search, child: const Text('Retry')),
              ],
            ),
          if (_showMap && _mapsEnabled)
            SizedBox(
              height: 300,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _center,
                  zoom: 11,
                ),
                onMapCreated: (controller) => _mapController = controller,
                onCameraMove: (position) => _center = position.target,
                onCameraIdle: () async {
                  final controller = _mapController;
                  if (controller != null)
                    _bounds = await controller.getVisibleRegion();
                },
                markers: _markers,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
              ),
            )
          else if (_showMap)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Map is unavailable until a restricted Maps SDK key is configured. Listing search still works.',
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _items.isEmpty && !_loading
                ? Center(
                    child: Text(
                      _error == null
                          ? (_hasSearch
                                ? 'No published properties found in this area.'
                                : 'Search a town or estate, or use your current location to find nearby homes.')
                          : '',
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final locality = [item['city'], item['county']]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(', ');
                      final distance = _number(item['distanceKm']);
                      final minimumRent = _number(item['minimumRent']);
                      final availableCount = item['availableUnitCount'];
                      final unitTypes = item['unitTypes'] is List
                          ? (item['unitTypes'] as List).join(', ')
                          : '';
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.home_outlined),
                        ),
                        title: Text(item['title']?.toString() ?? 'Property'),
                        subtitle: Text(
                          [
                            locality,
                            if (distance != null)
                              '${distance.toStringAsFixed(1)} km away',
                            if (minimumRent != null && minimumRent > 0)
                              'From KSh ${minimumRent.toStringAsFixed(0)}/mo',
                            if (availableCount != null)
                              '$availableCount available',
                            if (unitTypes.isNotEmpty) unitTypes,
                          ].where((text) => text.isNotEmpty).join(' · '),
                        ),
                        trailing: IconButton(
                          tooltip: 'Get directions',
                          onPressed: () => _openDirections(item),
                          icon: const Icon(Icons.directions_outlined),
                        ),
                        onTap: () => _openDirections(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
