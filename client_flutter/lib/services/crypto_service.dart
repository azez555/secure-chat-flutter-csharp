import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as old_crypto;
import 'package:convert/convert.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoService {
  final _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  static const _privateKeyStorageKey = 'my_private_key_cryptography';

  final _algorithm = X25519();
  SimpleKeyPair? _keyPair;

  Future<void> initialize() async {
    await _loadOrGenerateKeys();
  }

  Future<String> getPublicKeyBase64() async {
    final bytes = await getPublicKeyBytes();
    return base64Encode(bytes);
  }

  Future<void> _loadOrGenerateKeys() async {
    String? storedKeyBase64 = await _storage.read(key: _privateKeyStorageKey);

    if (storedKeyBase64 != null) {
      print("🔑 Loading existing private key (cryptography)...");
      final keyBytes = base64Decode(storedKeyBase64);

      _keyPair = await _algorithm.newKeyPairFromSeed(keyBytes);
    } else {
      print("✨ Generating new private key (cryptography)...");
      _keyPair = await _algorithm.newKeyPair();
      final keyBytes = await _keyPair!.extractPrivateKeyBytes();
      await _storage.write(
        key: _privateKeyStorageKey,
        value: base64Encode(keyBytes),
      );
    }
    print(
        "✅ CryptoService (cryptography) Initialized. Fingerprint: ${await getPublicKeyFingerprint()}");
  }

  void _ensureInitialized() {
    if (_keyPair == null) {
      throw StateError('CryptoService must be initialized before use.');
    }
  }

  Future<Uint8List> getPublicKeyBytes() async {
    _ensureInitialized();
    final simplePublicKey = await _keyPair!.extractPublicKey();
    return Uint8List.fromList(simplePublicKey.bytes);
  }

  Future<String> getPublicKeyFingerprint() async {
    _ensureInitialized();
    final publicKeyBytes = await getPublicKeyBytes();
    final hash = old_crypto.sha256.convert(publicKeyBytes);
    final fingerprint = hex.encode(hash.bytes.sublist(0, 16));
    return _formatFingerprint(fingerprint);
  }

  String _formatFingerprint(String hexString) {
    var formatted = '';
    for (var i = 0; i < hexString.length; i += 4) {
      formatted += hexString.substring(i, i + 4) + ' ';
    }
    return formatted.trim();
  }

  Future<Uint8List> createSharedSecret(Uint8List theirPublicKeyBytes) async {
    _ensureInitialized();
    final theirPublicKey = SimplePublicKey(
      theirPublicKeyBytes,
      type: KeyPairType.x25519,
    );
    final sharedSecret = await _algorithm.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: theirPublicKey,
    );
    return Uint8List.fromList(await sharedSecret.extractBytes());
  }
}
