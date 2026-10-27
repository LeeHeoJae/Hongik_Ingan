import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_lock.dart';

class MealVoteStorageException implements Exception {
  const MealVoteStorageException();
}

class MealVoteKey {
  MealVoteKey({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'meal_vote_device_key_v1';
  final FlutterSecureStorage _storage;
  Future<String>? _pendingKey;

  Future<String?> tokenFor(String pollId, {bool create = true}) async {
    final key = create
        ? await (_pendingKey ??= _loadOrCreateSafe().whenComplete(() {
            _pendingKey = null;
          }))
        : await (_pendingKey ?? _readKey());
    if (key == null) return null;
    final bytes = List<int>.generate(
      key.length ~/ 2,
      (i) => int.parse(key.substring(i * 2, i * 2 + 2), radix: 16),
    );
    return Hmac(
      sha256,
      bytes,
    ).convert(utf8.encode('meal-choice-v1:$pollId')).toString();
  }

  Future<String> _loadOrCreateSafe() async {
    final existing = await _readKey();
    return existing ?? await withVoteKeyLock(_loadOrCreate);
  }

  Future<String> _loadOrCreate() async {
    final existing = await _readKey();
    if (existing != null) return existing;
    final random = Random.secure();
    final key = List.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    try {
      await _storage.write(key: _storageKey, value: key);
    } catch (_) {
      throw const MealVoteStorageException();
    }
    if (await _readKey() != key) throw const MealVoteStorageException();
    return key;
  }

  Future<String?> _readKey() async {
    String? existing;
    try {
      existing = await _storage.read(key: _storageKey);
      if (existing == null && await _storage.containsKey(key: _storageKey)) {
        throw const MealVoteStorageException();
      }
    } catch (_) {
      throw const MealVoteStorageException();
    }
    if (existing != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(existing)) {
      throw const MealVoteStorageException();
    }
    return existing;
  }
}
