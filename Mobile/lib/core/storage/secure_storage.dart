// Secure storage service using flutter_secure_storage.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../errors/app_exceptions.dart';

abstract interface class SecureStorageService {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> deleteAll();
  Future<bool> containsKey(String key);
  Future<void> writeAll(Map<String, String> entries);
  Future<Map<String, String>> readAll();
}

class FlutterSecureStorageService implements SecureStorageService {
  FlutterSecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Exception catch (error) {
      throw StorageException(
        'Failed to write to secure storage',
        originalError: error,
      );
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Exception catch (error) {
      throw StorageException(
        'Failed to read from secure storage',
        originalError: error,
      );
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on Exception catch (error) {
      throw StorageException(
        'Failed to delete from secure storage',
        originalError: error,
      );
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } on Exception catch (error) {
      throw StorageException(
        'Failed to clear secure storage',
        originalError: error,
      );
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } on Exception catch (error) {
      throw StorageException(
        'Failed to check key in secure storage',
        originalError: error,
      );
    }
  }

  @override
  Future<void> writeAll(Map<String, String> entries) async {
    try {
      for (final entry in entries.entries) {
        await _storage.write(key: entry.key, value: entry.value);
      }
    } on Exception catch (error) {
      throw StorageException(
        'Failed to write multiple entries',
        originalError: error,
      );
    }
  }

  @override
  Future<Map<String, String>> readAll() async {
    try {
      return await _storage.readAll();
    } on Exception catch (error) {
      throw StorageException(
        'Failed to read all from secure storage',
        originalError: error,
      );
    }
  }
}

class AuthTokenStorage {
  AuthTokenStorage(this._storage);

  final SecureStorageService _storage;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.writeAll({
      AppConstants.accessTokenKey: accessToken,
      AppConstants.refreshTokenKey: refreshToken,
    });
  }

  Future<String?> getAccessToken() async {
    return _storage.read(AppConstants.accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(AppConstants.refreshTokenKey);
  }

  Future<void> saveEnrollmentToken(String token) async {
    await _storage.write(AppConstants.enrollmentTokenKey, token);
  }

  Future<String?> getEnrollmentToken() async {
    return _storage.read(AppConstants.enrollmentTokenKey);
  }

  Future<void> clearEnrollmentToken() async {
    await _storage.delete(AppConstants.enrollmentTokenKey);
  }

  Future<void> clearAllTokens() async {
    await _storage.delete(AppConstants.accessTokenKey);
    await _storage.delete(AppConstants.refreshTokenKey);
    await _storage.delete(AppConstants.enrollmentTokenKey);
  }

  Future<bool> hasTokens() async {
    final accessToken = await _storage.read(AppConstants.accessTokenKey);
    final refreshToken = await _storage.read(AppConstants.refreshTokenKey);
    return (accessToken?.isNotEmpty ?? false) ||
        (refreshToken?.isNotEmpty ?? false);
  }
}

class DeviceStorage {
  DeviceStorage(this._storage);

  final SecureStorageService _storage;

  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(AppConstants.deviceIdKey, deviceId);
  }

  Future<String?> getDeviceId() async {
    return _storage.read(AppConstants.deviceIdKey);
  }

  Future<void> saveUserId(String userId) async {
    await _storage.write(AppConstants.userIdKey, userId);
  }

  Future<String?> getUserId() async {
    return _storage.read(AppConstants.userIdKey);
  }

  Future<void> clearDeviceData() async {
    await _storage.delete(AppConstants.deviceIdKey);
    await _storage.delete(AppConstants.userIdKey);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      // flutter_secure_storage uses Android Keystore-backed encryption by default.
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(),
    lOptions: LinuxOptions(),
    wOptions: WindowsOptions(),
  );
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return FlutterSecureStorageService(ref.watch(secureStorageProvider));
});

final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  return AuthTokenStorage(ref.watch(secureStorageServiceProvider));
});

final deviceStorageProvider = Provider<DeviceStorage>((ref) {
  return DeviceStorage(ref.watch(secureStorageServiceProvider));
});
