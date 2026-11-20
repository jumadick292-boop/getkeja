import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';

final profilePhotoUrlProvider = FutureProvider<String?>((ref) async {
  final response = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/api/v1/profile/profile/personal');
  final data = response.data?['data'];
  if (data is! Map) return null;
  final url = data['profilePhotoUrl']?.toString().trim();
  return url != null && url.startsWith('https://') ? url : null;
});

class ProfilePhotoAvatar extends ConsumerStatefulWidget {
  const ProfilePhotoAvatar({
    required this.initials,
    required this.radius,
    super.key,
  });

  final String initials;
  final double radius;

  @override
  ConsumerState<ProfilePhotoAvatar> createState() => _ProfilePhotoAvatarState();
}

class _ProfilePhotoAvatarState extends ConsumerState<ProfilePhotoAvatar> {
  bool _hovered = false;

  Future<void> _editPhoto() async {
    await context.push<bool>('/profile/personal/edit');
    if (mounted) ref.invalidate(profilePhotoUrlProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = ref
        .watch(profilePhotoUrlProvider)
        .when(data: (url) => url, loading: () => null, error: (_, _) => null);
    final diameter = widget.radius * 2;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _editPhoto,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: AnimatedScale(
            scale: _hovered ? 1.06 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _hovered
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: _hovered ? 3 : 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: theme.colorScheme.primaryContainer,
                        child: photoUrl == null
                            ? Center(child: _initials(theme))
                            : Image.network(
                                photoUrl,
                                key: ValueKey(photoUrl),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) =>
                                    Center(child: _initials(theme)),
                                loadingBuilder: (context, child, progress) =>
                                    progress == null
                                    ? child
                                    : Center(child: _initials(theme)),
                              ),
                      ),
                      if (_hovered)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.34),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white,
                            size: widget.radius * 0.7,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _initials(ThemeData theme) => Text(
    widget.initials.isNotEmpty ? widget.initials : 'G',
    style: TextStyle(
      color: theme.colorScheme.onPrimaryContainer,
      fontSize: widget.radius * 0.8,
      fontWeight: FontWeight.w700,
    ),
  );
}
