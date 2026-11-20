import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';

const Map<String, String> _profileCategories = {
  'house_seeker': 'House seeker',
  'tenant': 'Tenant',
  'landlord': 'Landlord / property owner',
  'real_estate_agent': 'Real estate agent',
  'agency': 'Real estate agency',
  'property_manager': 'Property manager',
  'caretaker': 'Caretaker',
  'moving_service_provider': 'Moving service provider',
  'garbage_collection_provider': 'Garbage collection provider',
  'laundry_service_provider': 'Laundry service provider',
};

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(_camelCase(key.toString()), item));
  }
  return <String, Object?>{};
}

String _camelCase(String value) => value.replaceAllMapped(
  RegExp(r'_([a-z])'),
  (match) => match[1]!.toUpperCase(),
);

class ProfileManagementPage extends ConsumerStatefulWidget {
  const ProfileManagementPage({super.key});

  @override
  ConsumerState<ProfileManagementPage> createState() =>
      _ProfileManagementPageState();
}

class PersonalProfileEditorPage extends ConsumerStatefulWidget {
  const PersonalProfileEditorPage({super.key});

  @override
  ConsumerState<PersonalProfileEditorPage> createState() =>
      _PersonalProfileEditorPageState();
}

class _PersonalProfileEditorPageState
    extends ConsumerState<PersonalProfileEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    for (final field in [
      'displayName',
      'bio',
      'phoneNumber',
      'profilePhotoUrl',
      'websiteUrl',
    ])
      field: TextEditingController(),
  };
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/api/v1/profile/profile/personal');
      final profile = _objectMap(response.data?['data']);
      if (!mounted) return;
      setState(() {
        for (final entry in _controllers.entries) {
          entry.value.text = profile[entry.key]?.toString() ?? '';
        }
      });
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to load personal profile: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final body = <String, Object?>{
        for (final entry in _controllers.entries)
          if (entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
      };
      await ref
          .read(apiClientProvider)
          .patch<Map<String, dynamic>>(
            '/api/v1/profile/profile/personal',
            data: body,
          );
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to save personal profile: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadPersonalPhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (image == null || !mounted) return;
      setState(() {
        _isUploadingImage = true;
        _error = null;
      });
      final url = await ref
          .read(apiClientProvider)
          .uploadProfileImage(
            filePath: image.path,
            fileName: image.name,
            kind: 'personal_photo',
          );
      if (mounted) {
        setState(() => _controllers['profilePhotoUrl']!.text = url);
      }
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to upload profile photo: $error');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  if (_error != null)
                    AppNotice(
                      message: _error!,
                      type: NoticeType.error,
                      onDismiss: () => setState(() => _error = null),
                    ),
                  TextFormField(
                    controller: _controllers['displayName'],
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _controllers['bio'],
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'About you'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _controllers['phoneNumber'],
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Public contact phone (optional)',
                      helperText:
                          'Shown as your profile contact. Your verified sign-in phone is managed in Account settings.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_controllers['profilePhotoUrl']!.text.startsWith(
                    'https://',
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Center(
                        child: CircleAvatar(
                          radius: 36,
                          backgroundImage: NetworkImage(
                            _controllers['profilePhotoUrl']!.text,
                          ),
                          onBackgroundImageError: (_, _) {},
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _isUploadingImage ? null : _uploadPersonalPhoto,
                    icon: _isUploadingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose profile photo'),
                  ),
                  Text(
                    'JPEG, PNG, or WebP · maximum 5 MB',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _controllers['websiteUrl'],
                    decoration: const InputDecoration(
                      labelText: 'Website HTTPS URL',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Save personal profile',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _save,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileManagementPageState extends ConsumerState<ProfileManagementPage> {
  List<Map<String, Object?>> _profiles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/api/v1/profile/profiles');
      final Object? data = response.data?['data'];
      if (data is! List) {
        throw const FormatException('The profile response was invalid.');
      }
      if (!mounted) return;
      setState(() {
        _profiles = data.map(_objectMap).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load profiles: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createProfile() async {
    final category = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Choose a profile type',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final entry in _profileCategories.entries)
              ListTile(
                title: Text(entry.value),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (category == null || !mounted) return;
    final saved = await context.push<bool>(
      '/profile/manage/edit',
      extra: <String, Object?>{'category': category},
    );
    if (saved == true) await _loadProfiles();
  }

  Future<void> _editProfile(Map<String, Object?> profile) async {
    final saved = await context.push<bool>(
      '/profile/manage/edit',
      extra: <String, Object?>{'profile': profile},
    );
    if (saved == true) await _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My profiles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProfile,
        icon: const Icon(Icons.add),
        label: const Text('Add profile'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfiles,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  Text(
                    'Use one account for the profiles that apply to you. A profile does not grant property access or a platform role.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    AppNotice(
                      message: _error!,
                      type: NoticeType.error,
                      onDismiss: () => setState(() => _error = null),
                    ),
                  if (_profiles.isEmpty && _error == null)
                    AppCard(
                      child: Padding(
                        padding: AppSpacing.cardPadding,
                        child: Column(
                          children: [
                            const Icon(Icons.badge_outlined, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'No specialized profiles yet',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add a profile only when you need it. House seekers do not need to provide a home address.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final profile in _profiles) ...[
                    _ProfileCard(
                      profile: profile,
                      onTap: () => _editProfile(profile),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 88),
                ],
              ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onTap});

  final Map<String, Object?> profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = profile['profileCategory']?.toString() ?? '';
    final percentage = profile['completionPercentage'] as int? ?? 0;
    final label = _profileCategories[category] ?? category;
    final name =
        (profile['businessName'] ??
                profile['fullName'] ??
                profile['displayName'] ??
                label)
            .toString();
    final status = profile['verificationStatus']?.toString() ?? 'draft';

    return AppCard(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              category.contains('provider')
                  ? Icons.storefront_outlined
                  : Icons.person_outline,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label · ${status.replaceAll('_', ' ')}'),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: percentage / 100),
                const SizedBox(height: 4),
                Text('$percentage% complete'),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class ProfileEditorPage extends ConsumerStatefulWidget {
  const ProfileEditorPage({super.key, this.category, this.profile});

  final String? category;
  final Map<String, Object?>? profile;

  @override
  ConsumerState<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends ConsumerState<ProfileEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _laundryOptions = {
    'offersWashing': false,
    'offersDryCleaning': false,
    'offersIroning': false,
    'offersFolding': false,
    'offersBeddingCleaning': false,
    'offersHouseholdTextileCleaning': false,
    'offersOtherServices': false,
    'offersPickup': false,
    'offersDelivery': false,
    'customerVisitRequired': false,
  };
  Map<String, Object?>? _profile;
  Map<String, Object?>? _location;
  Map<String, Object?>? _completion;
  List<Map<String, Object?>> _areas = [];
  List<Map<String, Object?>> _verification = [];
  List<Map<String, Object?>> _verificationDocuments = [];
  String? _extensionId;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isUploadingDocument = false;
  String? _error;

  String get _category =>
      (_profile?['profileCategory'] ?? widget.category ?? '').toString();
  String? get _profileId => _profile?['id']?.toString();
  bool get _isProvider =>
      _category.endsWith('_service_provider') ||
      _category == 'garbage_collection_provider' ||
      _category == 'laundry_service_provider';
  bool get _isLaundry => _category == 'laundry_service_provider';
  bool get _isResidentialCategory =>
      const {'house_seeker', 'tenant', 'caretaker'}.contains(_category);

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    for (final key in [
      'fullName',
      'displayName',
      'businessName',
      'description',
      'contactEmail',
      'contactPhone',
      'websiteUrl',
      'profilePhotoUrl',
      'businessLogoUrl',
      'organisationId',
      'serviceTypes',
      'serviceDescription',
      'registrationNumber',
    ]) {
      _controllers[key] = TextEditingController(
        text: widget.profile?[key]?.toString() ?? '',
      );
    }
    if (_profileId != null) _loadDetails();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final profileId = _profileId;
    if (profileId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final profileLocationQuery = _isResidentialCategory
          ? null
          : <String, dynamic>{'profileId': profileId};
      final results = await Future.wait([
        api.get<Map<String, dynamic>>(
          '/api/v1/profile/locations',
          queryParameters: profileLocationQuery,
        ),
        api.get<Map<String, dynamic>>(
          '/api/v1/profile/profiles/$profileId/completion',
        ),
        api.get<Map<String, dynamic>>(
          '/api/v1/profile/profiles/$profileId/verification-records',
        ),
        if (_isProvider)
          api.get<Map<String, dynamic>>(
            '/api/v1/profile/profiles/$profileId/provider-extension',
          ),
        if (_isProvider)
          api.get<Map<String, dynamic>>(
            '/api/v1/profile/service-areas/$profileId',
          ),
      ]);
      final locationData = results[0].data?['data'];
      final locationRows = locationData is List
          ? locationData.map(_objectMap).toList()
          : <Map<String, Object?>>[];
      final expectedLocationType = _isResidentialCategory
          ? 'personal_residential'
          : _isProvider
          ? 'provider_operating'
          : 'business_office';
      final completion = _objectMap(results[1].data?['data']);
      final verificationData = results[2].data?['data'];
      final verification = verificationData is List
          ? verificationData.map(_objectMap).toList()
          : <Map<String, Object?>>[];
      Map<String, Object?>? extension;
      List<Map<String, Object?>> areas = [];
      var index = 3;
      if (_isProvider) {
        extension = _objectMap(results[index++].data?['data']);
        final areaData = results[index].data?['data'];
        if (areaData is List) areas = areaData.map(_objectMap).toList();
      }
      if (!mounted) return;
      Map<String, Object?>? savedLocation;
      for (final row in locationRows) {
        if (row['locationType'] == expectedLocationType) {
          savedLocation = row;
          break;
        }
      }
      setState(() {
        _location = savedLocation;
        _completion = completion;
        _verification = verification;
        _areas = areas;
        _extensionId = extension?['id']?.toString();
      });
      if (extension != null) {
        _controllers['serviceTypes']!.text =
            (extension['serviceTypes'] as List? ?? const []).join(', ');
        _controllers['serviceDescription']!.text =
            extension['serviceDescription']?.toString() ?? '';
        _controllers['registrationNumber']!.text =
            extension['registrationNumber']?.toString() ?? '';
      }
      if (_isLaundry && _extensionId != null) {
        await _loadLaundryServices(_extensionId!);
      }
      await _loadVerificationDocuments(profileId);
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to load profile details: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadVerificationDocuments(String profileId) async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/api/v1/profile/profiles/$profileId/verification-documents',
          );
      final raw = response.data?['data'];
      if (!mounted || raw is! List) return;
      setState(() => _verificationDocuments = raw.map(_objectMap).toList());
    } catch (error) {
      if (mounted)
        setState(
          () => _error = 'Unable to load verification documents: $error',
        );
    }
  }

  Future<void> _uploadVerificationDocument() async {
    final profileId = _profileId;
    if (profileId == null) {
      setState(
        () =>
            _error = 'Save this profile before adding verification documents.',
      );
      return;
    }
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (files.isEmpty || !mounted) return;
      final file = files.first;
      final path = file.path;
      if (path == null)
        throw const FormatException('Could not read the selected file.');
      final fileLength = await file.length();
      if (fileLength == null)
        throw const FormatException('Could not read the selected file size.');
      if (fileLength > 10 * 1024 * 1024) {
        throw const FormatException('Choose a document no larger than 10 MB.');
      }
      setState(() {
        _isUploadingDocument = true;
        _error = null;
      });
      await ref
          .read(apiClientProvider)
          .uploadVerificationDocument(
            filePath: path,
            fileName: file.name,
            path: '/api/v1/profile/profiles/$profileId/verification-documents',
          );
      await _loadVerificationDocuments(profileId);
    } catch (error) {
      if (mounted)
        setState(
          () => _error = 'Unable to upload verification document: $error',
        );
    } finally {
      if (mounted) setState(() => _isUploadingDocument = false);
    }
  }

  Future<void> _openVerificationDocument(String documentId) async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/api/v1/profile/verification-documents/$documentId/download-url',
          );
      final url = _objectMap(response.data?['data'])['url']?.toString();
      if (url == null ||
          !await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          )) {
        throw const FormatException('Could not open the secure document link.');
      }
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to open verification document: $error');
    }
  }

  Future<void> _loadLaundryServices(String extensionId) async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/api/v1/profile/provider-extensions/$extensionId/laundry-services',
          );
      final services = _objectMap(response.data?['data']);
      if (!mounted || services.isEmpty) return;
      setState(() {
        for (final key in _laundryOptions.keys) {
          _laundryOptions[key] = services[key] == true;
        }
      });
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to load laundry services: $error');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final body = <String, Object?>{
        'fullName': _value('fullName'),
        'displayName': _value('displayName'),
        'businessName': _value('businessName'),
        'description': _value('description'),
        'contactEmail': _value('contactEmail'),
        'contactPhone': _value('contactPhone'),
        'websiteUrl': _value('websiteUrl'),
        'profilePhotoUrl': _value('profilePhotoUrl'),
        'businessLogoUrl': _value('businessLogoUrl'),
        'organisationId': _value('organisationId'),
      }..removeWhere((key, value) => value == null);
      final api = ref.read(apiClientProvider);
      final response = _profileId == null
          ? await api.post<Map<String, dynamic>>(
              '/api/v1/profile/profiles',
              data: <String, Object?>{...body, 'profileCategory': _category},
            )
          : await api.patch<Map<String, dynamic>>(
              '/api/v1/profile/profiles/$_profileId',
              data: body,
            );
      final savedProfile = _objectMap(response.data?['data']);
      final profileId = savedProfile['id']?.toString();
      if (profileId == null)
        throw const FormatException('The saved profile has no ID.');
      if (_isProvider) {
        final extensionResponse = await api.put<Map<String, dynamic>>(
          '/api/v1/profile/profiles/$profileId/provider-extension',
          data: <String, Object?>{
            'serviceTypes': _controllers['serviceTypes']!.text
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(),
            'serviceDescription': _optional(
              _controllers['serviceDescription']!.text,
            ),
            'registrationNumber': _optional(
              _controllers['registrationNumber']!.text,
            ),
          },
        );
        final extension = _objectMap(extensionResponse.data?['data']);
        final extensionId = extension['id']?.toString();
        if (_isLaundry && extensionId != null) {
          await api.put<Map<String, dynamic>>(
            '/api/v1/profile/provider-extensions/$extensionId/laundry-services',
            data: _laundryOptions,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = savedProfile;
        _completion = _objectMap(savedProfile['completion']);
      });
      await _loadDetails();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile draft saved')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to save profile: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadSpecializedImage(String kind) async {
    final profileId = _profileId;
    if (profileId == null) {
      setState(() => _error = 'Save this profile before uploading an image.');
      return;
    }
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (image == null || !mounted) return;
      setState(() {
        _isUploadingImage = true;
        _error = null;
      });
      final url = await ref
          .read(apiClientProvider)
          .uploadProfileImage(
            filePath: image.path,
            fileName: image.name,
            kind: kind,
            profileId: profileId,
          );
      if (mounted) {
        _controllers[kind == 'profile_photo'
                    ? 'profilePhotoUrl'
                    : 'businessLogoUrl']!
                .text =
            url;
        setState(() {});
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to upload image: $error');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  String? _value(String key) => _optional(_controllers[key]!.text);

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _chooseLocation() async {
    if (_profileId == null && !_isResidentialCategory) {
      setState(
        () => _error = 'Save this profile before adding its business location.',
      );
      return;
    }
    final locationType = _isResidentialCategory
        ? 'personal_residential'
        : _isProvider
        ? 'provider_operating'
        : 'business_office';
    final saved = await context.push<bool>(
      '/profile/location',
      extra: <String, Object?>{
        'locationType': locationType,
        if (!_isResidentialCategory) 'profileId': _profileId,
        if (_location != null) 'location': _location,
      },
    );
    if (saved == true && mounted) await _loadDetails();
  }

  Future<void> _submit() async {
    final profileId = _profileId;
    if (profileId == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/api/v1/profile/profiles/$profileId/submit',
          );
      await _loadDetails();
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to submit profile: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addServiceArea() async {
    final profileId = _profileId;
    if (profileId == null) return;
    final fields = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _ServiceAreaDialog(),
    );
    if (fields == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/api/v1/profile/service-areas',
            data: <String, Object?>{
              'profileId': profileId,
              'country': fields['country'],
              'county': fields['county'],
              'city': fields['city'],
              'neighborhood': fields['neighborhood'],
              'areaDescription': fields['areaDescription'],
              if (double.tryParse(fields['latitude'] ?? '') != null)
                'latitude': double.parse(fields['latitude']!),
              if (double.tryParse(fields['longitude'] ?? '') != null)
                'longitude': double.parse(fields['longitude']!),
              if (double.tryParse(fields['radiusKm'] ?? '') != null)
                'radiusKm': double.parse(fields['radiusKm']!),
              'status': 'active',
            },
          );
      await _loadDetails();
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to add service area: $error');
    }
  }

  Future<void> _deleteServiceArea(String areaId) async {
    try {
      await ref
          .read(apiClientProvider)
          .delete<Map<String, dynamic>>(
            '/api/v1/profile/service-areas/$areaId',
          );
      await _loadDetails();
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to remove service area: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _profileCategories[_category] ?? 'New profile';
    final missing = _completion?['missingFields'] as List? ?? const [];
    final canSubmit = _completion?['canSubmit'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  if (_error != null)
                    AppNotice(
                      message: _error!,
                      type: NoticeType.error,
                      onDismiss: () => setState(() => _error = null),
                    ),
                  if (_completion != null) ...[
                    AppCard(
                      child: Padding(
                        padding: AppSpacing.cardPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile completeness',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value:
                                  ((_completion?['completionPercentage']
                                          as int?) ??
                                      0) /
                                  100,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_completion?['completionPercentage'] ?? 0}% complete'
                              '${missing.isNotEmpty ? ' · Missing: ${missing.join(', ')}' : ''}',
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Status: ${_profile?['verificationStatus'] ?? 'draft'}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _field('fullName', 'Full name'),
                  _field('displayName', 'Display name'),
                  _field('businessName', 'Business or organization name'),
                  _field('description', 'Description', maxLines: 3),
                  _field(
                    'contactEmail',
                    'Contact email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _field(
                    'contactPhone',
                    'Contact phone',
                    keyboardType: TextInputType.phone,
                  ),
                  _field('websiteUrl', 'Website URL'),
                  _field(
                    'organisationId',
                    'Organization ID (existing member only)',
                  ),
                  _imageField(
                    'profilePhotoUrl',
                    'Profile photo',
                    'profile_photo',
                  ),
                  _imageField(
                    'businessLogoUrl',
                    'Business logo',
                    'business_logo',
                  ),
                  if (_profileId != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Verification documents',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Files are private. Only you, organization administrators, and authorized reviewers can access them.',
                    ),
                    for (final document in _verificationDocuments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(
                          document['fileName']?.toString() ?? 'Document',
                        ),
                        subtitle: Text(
                          '${document['documentType'] ?? 'supporting_document'} · ${document['status'] ?? ''}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Open secure document',
                          icon: const Icon(Icons.download_outlined),
                          onPressed: () => _openVerificationDocument(
                            document['id'].toString(),
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _isUploadingDocument
                          ? null
                          : _uploadVerificationDocument,
                      icon: _isUploadingDocument
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: const Text('Add verification document'),
                    ),
                  ],
                  if (_isProvider) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Provider details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _field('serviceTypes', 'Service types (comma-separated)'),
                    _field(
                      'serviceDescription',
                      'Services offered',
                      maxLines: 3,
                    ),
                    _field(
                      'registrationNumber',
                      'Business registration number',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Operating location',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    _locationCard(),
                    const SizedBox(height: 12),
                    Text(
                      'Service areas',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final area in _areas)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          [area['neighborhood'], area['city'], area['county']]
                              .whereType<String>()
                              .where((part) => part.isNotEmpty)
                              .join(', '),
                        ),
                        subtitle: Text(
                          area['areaDescription']?.toString() ?? '',
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove area',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _deleteServiceArea(area['id'].toString()),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _profileId == null ? null : _addServiceArea,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Add service area'),
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
                    Text(
                      'Optional saved location',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isResidentialCategory
                          ? 'Your residential location is private and is not required to search for homes.'
                          : 'Save an office location without granting property access.',
                    ),
                    _locationCard(),
                  ],
                  if (_isLaundry) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Laundry services',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final entry in _laundryOptions.entries)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_laundryLabel(entry.key)),
                        value: entry.value,
                        onChanged: (value) => setState(
                          () => _laundryOptions[entry.key] = value ?? false,
                        ),
                      ),
                  ],
                  if (_verification.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Verification history',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final record in _verification)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(record['decision']?.toString() ?? ''),
                        subtitle: Text(
                          record['rejectionReason']?.toString() ?? '',
                        ),
                        trailing: Text(record['newStatus']?.toString() ?? ''),
                      ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Save draft',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _save,
                  ),
                  if (_profileId != null) ...[
                    const SizedBox(height: 10),
                    SecondaryButton(
                      label: 'Submit for review',
                      isLoading: _isSaving,
                      onPressed: !canSubmit || _isSaving ? null : _submit,
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _imageField(String key, String label, String kind) {
    if (key == 'businessLogoUrl' &&
        const {'house_seeker', 'tenant', 'caretaker'}.contains(_category)) {
      return const SizedBox.shrink();
    }
    final url = _controllers[key]!.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url.startsWith('https://'))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _isUploadingImage
                  ? null
                  : () => _uploadSpecializedImage(kind),
              icon: _isUploadingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text('Choose $label'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'JPEG, PNG, or WebP · maximum 5 MB',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _field(
    String key,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    if (!_isProvider && key == 'registrationNumber')
      return const SizedBox.shrink();
    if (key == 'serviceDescription' || key == 'serviceTypes') {
      if (!_isProvider) return const SizedBox.shrink();
    }
    final hiddenForCategory = switch (key) {
      'businessName' => const {
        'house_seeker',
        'tenant',
        'caretaker',
      }.contains(_category),
      'organisationId' => const {
        'house_seeker',
        'tenant',
        'caretaker',
      }.contains(_category),
      'businessLogoUrl' => const {
        'house_seeker',
        'tenant',
        'caretaker',
      }.contains(_category),
      _ => false,
    };
    if (hiddenForCategory) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[key],
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (key == 'contactEmail' &&
              value != null &&
              value.trim().isNotEmpty &&
              !value.contains('@')) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
    );
  }

  Widget _locationCard() {
    final location = _location;
    final address = location?['formattedAddress']?.toString();
    final latitude = location?['latitude']?.toString();
    final longitude = location?['longitude']?.toString();
    return AppCard(
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(
            address?.isNotEmpty == true ? address! : 'No location saved',
          ),
          subtitle: Text(
            latitude == null || longitude == null
                ? 'Location is optional'
                : '$latitude, $longitude',
          ),
          trailing: IconButton(
            tooltip: 'Choose location',
            icon: const Icon(Icons.edit_location_alt_outlined),
            onPressed: _chooseLocation,
          ),
          onTap: _chooseLocation,
        ),
      ),
    );
  }

  String _laundryLabel(String key) => switch (key) {
    'offersWashing' => 'Washing',
    'offersDryCleaning' => 'Dry cleaning',
    'offersIroning' => 'Ironing',
    'offersFolding' => 'Folding',
    'offersBeddingCleaning' => 'Bedding cleaning',
    'offersHouseholdTextileCleaning' => 'Household textile cleaning',
    'offersOtherServices' => 'Other services',
    'offersPickup' => 'Pickup',
    'offersDelivery' => 'Delivery',
    'customerVisitRequired' => 'Customer visit required',
    _ => key,
  };
}

class _ServiceAreaDialog extends StatefulWidget {
  const _ServiceAreaDialog();

  @override
  State<_ServiceAreaDialog> createState() => _ServiceAreaDialogState();
}

class _ServiceAreaDialogState extends State<_ServiceAreaDialog> {
  final Map<String, TextEditingController> _controllers = {
    for (final key in [
      'country',
      'county',
      'city',
      'neighborhood',
      'areaDescription',
      'latitude',
      'longitude',
      'radiusKm',
    ])
      key: TextEditingController(),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add service area'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _controllers.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: entry.value,
                  maxLines: entry.key == 'areaDescription' ? 2 : 1,
                  keyboardType:
                      const {
                        'latitude',
                        'longitude',
                        'radiusKm',
                      }.contains(entry.key)
                      ? const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        )
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: switch (entry.key) {
                      'areaDescription' => 'Coverage details',
                      'neighborhood' => 'Neighborhood',
                      _ =>
                        '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, <String, String>{
            for (final entry in _controllers.entries)
              entry.key: entry.value.text.trim(),
          }),
          child: const Text('Save area'),
        ),
      ],
    );
  }
}
