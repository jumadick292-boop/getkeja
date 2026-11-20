import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:get_keja_mobile/core/api/api_client.dart';

const bool _googleMapsEnabled = bool.fromEnvironment(
  'GOOGLE_MAPS_ENABLED',
  defaultValue: false,
);

class LocationPickerPage extends ConsumerStatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.locationType,
    this.profileId,
    this.organizationId,
    this.location,
  });

  final String locationType;
  final String? profileId;
  final String? organizationId;
  final Map<String, Object?>? location;

  @override
  ConsumerState<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends ConsumerState<LocationPickerPage> {
  static const LatLng _defaultCenter = LatLng(-1.286389, 36.817223);

  final _formKey = GlobalKey<FormState>();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _addressController = TextEditingController();
  LatLng? _selected;
  double? _accuracy;
  String _source = 'manual_map_pin';
  String? _placeId;
  String? _country;
  String? _countryCode;
  String? _county;
  String? _city;
  String? _neighborhood;
  bool _isSaving = false;
  bool _isFindingLocation = false;
  bool _isSearchingPlaces = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final latitude = _coordinate(widget.location?['latitude']);
    final longitude = _coordinate(widget.location?['longitude']);
    if (latitude != null && longitude != null) {
      _selected = LatLng(latitude, longitude);
      _latitudeController.text = latitude.toStringAsFixed(6);
      _longitudeController.text = longitude.toStringAsFixed(6);
    }
    _addressController.text =
        widget.location?['formattedAddress']?.toString() ?? '';
    _placeId = widget.location?['placeId']?.toString();
    _country = widget.location?['country']?.toString();
    _county = widget.location?['county']?.toString();
    _city = widget.location?['city']?.toString();
    _neighborhood = widget.location?['neighborhood']?.toString();
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  double? _coordinate(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _select(LatLng position, String source, {double? accuracy}) {
    setState(() {
      _selected = position;
      _source = source;
      _accuracy = accuracy;
      _latitudeController.text = position.latitude.toStringAsFixed(6);
      _longitudeController.text = position.longitude.toStringAsFixed(6);
      _error = null;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isFindingLocation = true;
      _error = null;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled)
        throw StateError('Turn on device location services and try again.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw StateError('Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw StateError(
          'Enable location permission for GetKeja in device settings.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      _select(
        LatLng(position.latitude, position.longitude),
        'device_gps',
        accuracy: position.accuracy,
      );
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to get your location: $error');
    } finally {
      if (mounted) setState(() => _isFindingLocation = false);
    }
  }

  Future<void> _searchPlaces() async {
    final input = _addressController.text.trim();
    if (input.length < 2) {
      setState(
        () => _error = 'Enter at least two characters to search places.',
      );
      return;
    }
    setState(() {
      _isSearchingPlaces = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/api/v1/profile/places/autocomplete',
            queryParameters: {'input': input},
          );
      final raw = response.data?['data'];
      final suggestions = raw is List
          ? raw
                .whereType<Map>()
                .map((item) => Map<String, Object?>.from(item))
                .toList()
          : <Map<String, Object?>>[];
      if (!mounted) return;
      if (suggestions.isEmpty) {
        setState(
          () => _error =
              'No matching places. You can still place a pin manually.',
        );
        return;
      }
      final selected = await showModalBottomSheet<Map<String, Object?>>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final place in suggestions)
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(place['description']?.toString() ?? ''),
                  onTap: () => Navigator.pop(context, place),
                ),
            ],
          ),
        ),
      );
      final placeId = selected?['placeId']?.toString();
      if (placeId == null || !mounted) return;
      final details = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/api/v1/profile/places/${Uri.encodeComponent(placeId)}',
          );
      final place = details.data?['data'];
      if (place is! Map || !mounted) return;
      final latitude = _coordinate(place['latitude']);
      final longitude = _coordinate(place['longitude']);
      if (latitude == null || longitude == null) {
        throw const FormatException(
          'Place search returned invalid coordinates.',
        );
      }
      _select(LatLng(latitude, longitude), 'address_search');
      setState(() {
        _placeId = place['placeId']?.toString();
        _country = place['country']?.toString();
        _countryCode = place['countryCode']?.toString();
        _county = place['county']?.toString();
        _city = place['city']?.toString();
        _neighborhood = place['neighborhood']?.toString();
        _addressController.text =
            place['formattedAddress']?.toString() ?? input;
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _error =
              'Place search is unavailable. Choose a map pin or enter coordinates manually.',
        );
    } finally {
      if (mounted) setState(() => _isSearchingPlaces = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      setState(() => _error = 'Enter a valid latitude and longitude.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final location = <String, Object?>{
        'latitude': latitude,
        'longitude': longitude,
        'formattedAddress': _optional(_addressController.text),
        'locationSource': _source,
        if (_placeId != null) 'placeId': _placeId,
        if (_country != null) 'country': _country,
        if (_county != null) 'county': _county,
        if (_city != null) 'city': _city,
        if (_neighborhood != null) 'neighborhood': _neighborhood,
        if (_accuracy != null) 'accuracy': _accuracy,
        if (widget.profileId != null) 'specializedProfileId': widget.profileId,
      };
      final api = ref.read(apiClientProvider);
      if (widget.organizationId != null) {
        await api.patch<Map<String, dynamic>>(
          '/api/v1/profile/organizations/${widget.organizationId}/profile',
          data: <String, Object?>{
            'latitude': latitude,
            'longitude': longitude,
            'address': _optional(_addressController.text),
            'locationSource': _source,
            if (_placeId != null) 'placeId': _placeId,
            if (_countryCode != null) 'country': _countryCode,
            if (_county != null) 'county': _county,
            if (_city != null) 'city': _city,
            if (_neighborhood != null) 'neighborhood': _neighborhood,
          },
        );
      } else {
        await api.post<Map<String, dynamic>>(
          '/api/v1/profile/locations',
          data: <String, Object?>{
            ...location,
            'locationType': widget.locationType,
          },
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to save location: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final mapCenter = selected ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose location')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            if (_googleMapsEnabled)
              SizedBox(
                height: 300,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: mapCenter,
                      zoom: selected == null ? 6.5 : 15,
                    ),
                    onTap: (position) => _select(position, 'manual_map_pin'),
                    markers: selected == null
                        ? const {}
                        : {
                            Marker(
                              markerId: const MarkerId('confirmed-location'),
                              position: selected,
                            ),
                          },
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Map preview is disabled until a restricted Google Maps client key is configured. You can still enter coordinates or use your current location.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isFindingLocation ? null : _useCurrentLocation,
              icon: _isFindingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Use my current location'),
            ),
            if (_googleMapsEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Tap the map to place or move the pin. Location is only read when you press the button.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Search for a place or enter an address',
                hintText: 'Street, building, neighborhood, or town',
              ),
              onChanged: (_) {
                _source = 'text_entry';
                _placeId = null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isSearchingPlaces ? null : _searchPlaces,
                icon: _isSearchingPlaces
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Search places'),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) => _isValidCoordinate(value, -90, 90)
                        ? null
                        : 'Enter a value from -90 to 90',
                    onChanged: (_) => _source = 'text_entry',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) => _isValidCoordinate(value, -180, 180)
                        ? null
                        : 'Enter a value from -180 to 180',
                    onChanged: (_) => _source = 'text_entry',
                  ),
                ),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              Text(
                'Selected: ${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm and save location'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidCoordinate(String? value, double minimum, double maximum) {
    final coordinate = double.tryParse(value?.trim() ?? '');
    return coordinate != null &&
        coordinate.isFinite &&
        coordinate >= minimum &&
        coordinate <= maximum;
  }
}
