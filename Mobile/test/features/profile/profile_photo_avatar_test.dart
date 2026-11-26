import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/features/profile/presentation/widgets/profile_photo_avatar.dart';

void main() {
  test('reads the profile photo URL from the API database field name', () {
    expect(
      profilePhotoUrlFromResponse({
        'data': {'profile_photo_url': 'https://cdn.example.com/profile.jpg'},
      }),
      'https://cdn.example.com/profile.jpg',
    );
  });

  test('accepts camel-case profile photo responses too', () {
    expect(
      profilePhotoUrlFromResponse({
        'data': {'profilePhotoUrl': 'https://cdn.example.com/profile.jpg'},
      }),
      'https://cdn.example.com/profile.jpg',
    );
  });

  test('rejects insecure or absent profile photo URLs', () {
    expect(
      profilePhotoUrlFromResponse({
        'data': {'profile_photo_url': 'http://cdn.example.com/profile.jpg'},
      }),
      isNull,
    );
    expect(profilePhotoUrlFromResponse({'data': <String, Object?>{}}), isNull);
  });
}
