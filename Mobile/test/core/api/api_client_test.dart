import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/core/api/api_client.dart';
import 'package:get_keja_mobile/core/storage/secure_storage.dart';

void main() {
  group('ApiClient request paths', () {
    late Uri? requestUri;
    late ApiClient client;

    setUp(() {
      requestUri = null;
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.authBaseUrl));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestUri = options.uri;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'success': true, 'data': <Object>[]},
              ),
            );
          },
        ),
      );
      client = ApiClient(
        dio: dio,
        tokenStorage: AuthTokenStorage(_FakeStorage()),
      );
    });

    test('sends profile endpoints at the API root', () async {
      await client.get<Map<String, dynamic>>('/api/v1/profile/profiles');

      expect(requestUri?.path, '/api/v1/profile/profiles');
    });

    test('keeps auth account endpoints under the auth API prefix', () async {
      await client.get<Map<String, dynamic>>('/account/preferences');

      expect(requestUri?.path, '/api/v1/auth/account/preferences');
    });

    test(
      'attaches the stored access token to authenticated requests',
      () async {
        final Dio authenticatedDio = Dio(
          BaseOptions(baseUrl: ApiConfig.authBaseUrl),
        );
        String? authorizationHeader;
        authenticatedDio.interceptors.add(
          AuthInterceptor(
            AuthTokenStorage(_FakeStorage(accessToken: 'test-access-token')),
          ),
        );
        authenticatedDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              authorizationHeader = options.headers['Authorization'] as String?;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{'success': true},
                ),
              );
            },
          ),
        );

        await authenticatedDio.get<Map<String, dynamic>>('/account/profile');

        expect(authorizationHeader, 'Bearer test-access-token');
      },
    );
  });
}

class _FakeStorage implements SecureStorageService {
  _FakeStorage({this.accessToken});

  final String? accessToken;

  @override
  Future<bool> containsKey(String key) async => false;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => accessToken;

  @override
  Future<Map<String, String>> readAll() async => <String, String>{};

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> writeAll(Map<String, String> entries) async {}
}
