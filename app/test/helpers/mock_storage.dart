import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// In-memory implementation of [FlutterSecureStorage] for unit tests.
/// All operations return immediately without actual file I/O.
class MockFlutterSecureStorage implements FlutterSecureStorage {
  MockFlutterSecureStorage() : _storage = {};

  final Map<String, String> _storage;

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(_storage);
  }

  @override
  Future<void> deleteAll({
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage.containsKey(key);
  }

  @override
  AndroidOptions get aOptions => AndroidOptions();

  @override
  IOSOptions get iOptions => IOSOptions();

  @override
  LinuxOptions get lOptions => LinuxOptions();

  @override
  MacOsOptions get mOptions => MacOsOptions();

  @override
  WebOptions get webOptions => WebOptions();

  @override
  WindowsOptions get wOptions => WindowsOptions();

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => null;

  @override
  Stream<bool>? get onCupertinoProtectedDataAvailabilityChanged => null;

  @override
  void registerListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterAllListeners() {}

  @override
  void unregisterAllListenersForKey({required String key}) {}

  @override
  void unregisterListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  /// Test helper: clear all stored data.
  void clear() {
    _storage.clear();
  }

  /// Test helper: get all stored entries.
  Map<String, String> getAllStored() => Map.from(_storage);
}
