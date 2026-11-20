import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';

Map<String, Object?> _organizationMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, Object?>{};
}

class OrganizationProfilePage extends ConsumerStatefulWidget {
  const OrganizationProfilePage({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<OrganizationProfilePage> createState() =>
      _OrganizationProfilePageState();
}

class _OrganizationProfilePageState
    extends ConsumerState<OrganizationProfilePage> {
  static const List<String> _fields = [
    'name',
    'description',
    'contactEmail',
    'contactPhone',
    'address',
    'city',
    'county',
    'country',
    'registrationNumber',
    'taxId',
    'logoUrl',
    'websiteUrl',
  ];

  final Map<String, TextEditingController> _controllers = {};
  Map<String, Object?> _profile = {};
  List<Map<String, Object?>> _verification = [];
  List<Map<String, Object?>> _verificationDocuments = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isUploadingDocument = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      _controllers[field] = TextEditingController();
    }
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
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.get<Map<String, dynamic>>(
          '/api/v1/profile/organizations/${widget.organizationId}/profile',
        ),
        api.get<Map<String, dynamic>>(
          '/api/v1/profile/organizations/${widget.organizationId}/profile/verification-records',
        ),
        api.get<Map<String, dynamic>>(
          '/api/v1/profile/organizations/${widget.organizationId}/profile/verification-documents',
        ),
      ]);
      final profile = _organizationMap(results[0].data?['data']);
      final historyData = results[1].data?['data'];
      final documentData = results[2].data?['data'];
      final verification = historyData is List
          ? historyData.map(_organizationMap).toList()
          : <Map<String, Object?>>[];
      final documents = documentData is List
          ? documentData.map(_organizationMap).toList()
          : <Map<String, Object?>>[];
      if (profile.isEmpty)
        throw const FormatException('Organization profile was empty.');
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _verification = verification;
        _verificationDocuments = documents;
        for (final field in _fields) {
          _controllers[field]!.text = profile[field]?.toString() ?? '';
        }
      });
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to load organization profile: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadVerificationDocument() async {
    if (_profile['canEdit'] != true) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (files.isEmpty || !mounted) return;
      final file = files.first;
      if (file.path == null)
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
            filePath: file.path!,
            fileName: file.name,
            path:
                '/api/v1/profile/organizations/${widget.organizationId}/profile/verification-documents',
          );
      await _load();
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
      final url = _organizationMap(response.data?['data'])['url']?.toString();
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

  Future<void> _save() async {
    if (_profile['canEdit'] != true) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final body = <String, Object?>{
        for (final field in _fields)
          if (_controllers[field]!.text.trim().isNotEmpty)
            field: _controllers[field]!.text.trim(),
      };
      await ref
          .read(apiClientProvider)
          .patch<Map<String, dynamic>>(
            '/api/v1/profile/organizations/${widget.organizationId}/profile',
            data: body,
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization profile updated')),
        );
      }
    } catch (error) {
      if (mounted)
        setState(
          () => _error = 'Unable to update organization profile: $error',
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadLogo() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (image == null || !mounted) return;
      setState(() {
        _isUploadingLogo = true;
        _error = null;
      });
      final url = await ref
          .read(apiClientProvider)
          .uploadProfileImage(
            filePath: image.path,
            fileName: image.name,
            kind: 'organization_logo',
            organizationId: widget.organizationId,
          );
      if (mounted) {
        _controllers['logoUrl']!.text = url;
        setState(() {});
      }
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to upload organization logo: $error');
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _editLocation() async {
    if (_profile['canEdit'] != true) return;
    final saved = await context.push<bool>(
      '/profile/location',
      extra: <String, Object?>{
        'organizationId': widget.organizationId,
        'locationType': 'business_office',
        if (_profile['latitude'] != null && _profile['longitude'] != null)
          'location': <String, Object?>{
            'latitude': _profile['latitude'],
            'longitude': _profile['longitude'],
            'formattedAddress': _profile['address'],
          },
      },
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _submitForReview() async {
    if (_profile['canEdit'] != true) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/api/v1/profile/organizations/${widget.organizationId}/profile/submit',
          );
      await _load();
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to submit organization: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organization profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  AppNotice(
                    message: _error!,
                    type: NoticeType.error,
                    onDismiss: () => setState(() => _error = null),
                  ),
                Text(
                  'Organization profile fields do not grant members property or service permissions. Membership permissions are managed separately.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_profile['canEdit'] != true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Your organization membership allows viewing, but not editing this profile.',
                    ),
                  ),
                const SizedBox(height: 16),
                if (_profile['completion'] is Map)
                  Builder(
                    builder: (context) {
                      final completion = _organizationMap(
                        _profile['completion'],
                      );
                      final missing =
                          completion['missingFields'] as List? ?? const [];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Organization profile · ${completion['completionPercentage'] ?? 0}% complete',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value:
                                    ((completion['completionPercentage']
                                            as int?) ??
                                        0) /
                                    100,
                              ),
                              if (missing.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Missing: ${missing.join(', ')}'),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Verification: ${_profile['verificationStatus'] ?? 'pending'}',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                for (final field in _fields) ...[
                  if (field != 'logoUrl')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _controllers[field],
                        maxLines: field == 'description' ? 3 : 1,
                        keyboardType: field == 'contactEmail'
                            ? TextInputType.emailAddress
                            : field == 'contactPhone'
                            ? TextInputType.phone
                            : TextInputType.text,
                        decoration: InputDecoration(labelText: _label(field)),
                        enabled: _profile['canEdit'] == true,
                      ),
                    ),
                  if (field == 'logoUrl') ...[
                    if (_controllers[field]!.text.startsWith('https://'))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Image.network(
                          _controllers[field]!.text,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stackTrace) =>
                              const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed:
                            _profile['canEdit'] != true || _isUploadingLogo
                            ? null
                            : _uploadLogo,
                        icon: _isUploadingLogo
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose organization logo'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'JPEG, PNG, or WebP · maximum 5 MB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(
                      _profile['address']?.toString().isNotEmpty == true
                          ? _profile['address'].toString()
                          : 'Office location not set',
                    ),
                    subtitle: Text(
                      _profile['latitude'] == null ||
                              _profile['longitude'] == null
                          ? 'Choose an office pin'
                          : '${_profile['latitude']}, ${_profile['longitude']}',
                    ),
                    trailing: const Icon(Icons.edit_location_alt_outlined),
                    onTap: _profile['canEdit'] == true ? _editLocation : null,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Verification documents',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Private files are available only to organization owners, administrators, and authorized reviewers.',
                ),
                for (final document in _verificationDocuments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(document['fileName']?.toString() ?? 'Document'),
                    subtitle: Text(
                      '${document['documentType'] ?? 'supporting_document'} · ${document['status'] ?? ''}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Open secure document',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () =>
                          _openVerificationDocument(document['id'].toString()),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _profile['canEdit'] != true || _isUploadingDocument
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
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isSaving || _profile['canEdit'] != true
                      ? null
                      : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save organization profile'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isSaving || _profile['canEdit'] != true
                      ? null
                      : _submitForReview,
                  child: const Text('Submit organization for review'),
                ),
                if (_verification.isNotEmpty) ...[
                  const SizedBox(height: 18),
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
              ],
            ),
    );
  }

  String _label(String field) => switch (field) {
    'name' => 'Organization name',
    'contactEmail' => 'Business email',
    'contactPhone' => 'Business phone',
    'registrationNumber' => 'Registration number',
    'taxId' => 'Tax ID',
    'logoUrl' => 'Organization logo',
    'websiteUrl' => 'Website HTTPS URL',
    _ => '${field[0].toUpperCase()}${field.substring(1)}',
  };
}
