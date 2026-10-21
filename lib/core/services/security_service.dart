import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Minimal key/value store so tests can run without the platform keychain.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecureStore implements SecureStore {
  const PlatformSecureStore();
  static const _s = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class MemorySecureStore implements SecureStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
}

/// Owner key pair (Ed25519). The private seed never leaves the secure store;
/// only the public key is registered on the node during commissioning.
class SecurityService {
  SecurityService(this._store);
  final SecureStore _store;
  final _algo = Ed25519();
  static const _seedKey = 'aether.owner.seed';
  static const _pubKey = 'aether.owner.pub';

  /// Returns the base64 public key, generating the pair on first use.
  Future<String> ensureOwnerKey() async {
    final existing = await _store.read(_pubKey);
    if (existing != null) return existing;
    return rotate();
  }

  Future<String> rotate() async {
    final pair = await _algo.newKeyPair();
    final seed = await pair.extractPrivateKeyBytes();
    final pub = (await pair.extractPublicKey()).bytes;
    await _store.write(_seedKey, base64Encode(seed));
    final b64 = base64Encode(pub);
    await _store.write(_pubKey, b64);
    return b64;
  }

  Future<String?> publicKey() => _store.read(_pubKey);

  /// Signs a command payload; the node verifies with the registered public key.
  Future<String> sign(String payload) async {
    final seed = await _store.read(_seedKey);
    if (seed == null)
      throw StateError('No owner key. Pair the Power Core first.');
    final pair = await _algo.newKeyPairFromSeed(base64Decode(seed));
    final sig = await _algo.sign(utf8.encode(payload), keyPair: pair);
    return base64Encode(sig.bytes);
  }

  Future<void> wipe() async {
    await _store.delete(_seedKey);
    await _store.delete(_pubKey);
  }

  static String fingerprint(String pubB64) {
    final clean = pubB64.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
    final s =
        clean.length >= 16 ? clean.substring(0, 16) : clean.padRight(16, '0');
    return [for (var i = 0; i < 16; i += 4) s.substring(i, i + 4)].join(' ');
  }
}

/// Biometric / device PIN re-auth for sensitive actions.
class ReAuth {
  const ReAuth();
  Future<bool> confirm(String reason) async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return true;
      return await auth.authenticate(localizedReason: reason);
    } catch (_) {
      // Simulator / no enrolment: allow, the node still enforces signatures.
      return true;
    }
  }
}
