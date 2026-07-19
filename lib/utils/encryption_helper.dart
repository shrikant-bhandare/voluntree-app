import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' hide Key;

String rsaPublicKeyToJson(RSAPublicKey key) {
  return jsonEncode({
    'modulus': key.modulus!.toString(),
    'exponent': key.exponent!.toString(),
  });
}

RSAPublicKey rsaPublicKeyFromJson(String jsonStr) {
  final Map<String, dynamic> data = jsonDecode(jsonStr);
  return RSAPublicKey(
    BigInt.parse(data['modulus']!),
    BigInt.parse(data['exponent']!),
  );
}

String rsaPrivateKeyToJson(RSAPrivateKey key) {
  return jsonEncode({
    'modulus': key.modulus!.toString(),
    'privateExponent': key.privateExponent!.toString(),
    'publicExponent': key.publicExponent!.toString(),
    'p': key.p!.toString(),
    'q': key.q!.toString(),
  });
}

RSAPrivateKey rsaPrivateKeyFromJson(String jsonStr) {
  final Map<String, dynamic> data = jsonDecode(jsonStr);
  return RSAPrivateKey(
    BigInt.parse(data['modulus']!),
    BigInt.parse(data['privateExponent']!),
    BigInt.parse(data['p']!),
    BigInt.parse(data['q']!),
  );
}

// Top-level function for background key generation to avoid blocking UI thread
Map<String, String> _generateRSAKeysInBackground(int strength) {
  final keyGen = RSAKeyGenerator();
  final secureRandom = FortunaRandom();
  final random = Random.secure();
  final seeds = List<int>.generate(32, (_) => random.nextInt(256));
  secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));
  
  // Using certainty 20 for faster prime generation while remaining cryptographically secure
  keyGen.init(pc.ParametersWithRandom(
    RSAKeyGeneratorParameters(BigInt.parse('65537'), strength, 20),
    secureRandom,
  ));

  final pair = keyGen.generateKeyPair();
  final pubKey = pair.publicKey as RSAPublicKey;
  final privKey = pair.privateKey as RSAPrivateKey;

  return {
    'publicKey': rsaPublicKeyToJson(pubKey),
    'privateKey': rsaPrivateKeyToJson(privKey),
  };
}

class EncryptionHelper {
  // Cached private key loaded on startup for synchronous message decryption
  static String? localPrivateKey;
  static RSAPrivateKey? _cachedPrivateKey;

  // Load private key from storage
  static Future<void> loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    localPrivateKey = prefs.getString('e2ee_private_key');
    if (localPrivateKey != null) {
      try {
        _cachedPrivateKey = rsaPrivateKeyFromJson(localPrivateKey!);
      } catch (e) {
        debugPrint('[CRYPTO HELPER] Error caching private key: $e');
      }
    }
  }

  // Generate RSA Key pair and save JSON strings to SharedPreferences
  static Future<Map<String, String>> generateAndSaveKeys() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if keys already exist
    final storedPub = prefs.getString('e2ee_public_key');
    final storedPriv = prefs.getString('e2ee_private_key');
    if (storedPub != null && storedPriv != null) {
      localPrivateKey = storedPriv;
      try {
        _cachedPrivateKey ??= rsaPrivateKeyFromJson(storedPriv);
      } catch (e) {
        debugPrint('[CRYPTO HELPER] Error caching stored private key: $e');
      }
      return {'publicKey': storedPub, 'privateKey': storedPriv};
    }
    
    // Generate new RSA-2048 keypair in a background isolate
    final keys = await compute(_generateRSAKeysInBackground, 2048);
    final pubJson = keys['publicKey']!;
    final privJson = keys['privateKey']!;

    await prefs.setString('e2ee_public_key', pubJson);
    await prefs.setString('e2ee_private_key', privJson);

    localPrivateKey = privJson;
    try {
      _cachedPrivateKey = rsaPrivateKeyFromJson(privJson);
    } catch (e) {
      debugPrint('[CRYPTO HELPER] Error caching newly generated private key: $e');
    }

    return {'publicKey': pubJson, 'privateKey': privJson};
  }

  // Get local private key JSON
  static Future<String?> getPrivateKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('e2ee_private_key');
  }

  // Get local public key JSON
  static Future<String?> getPublicKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('e2ee_public_key');
  }

  // Encrypt message hybridly:
  // 1. Generate a random 32-byte AES key and 16-byte IV.
  // 2. Encrypt plaintext using AES-256-CBC.
  // 3. Encrypt the AES key + IV using recipient's RSA public key.
  // 4. Return map containing ciphertext and encrypted key payload.
  static Map<String, String>? encryptMessage({
    required String plaintext,
    required String recipientPublicKeyJson,
    String? fileUrl,
  }) {
    try {
      // Generate random AES key (32 bytes = 256 bits) and IV (16 bytes)
      final random = Random.secure();
      final aesKeyBytes = List<int>.generate(32, (_) => random.nextInt(256));
      final ivBytes = List<int>.generate(16, (_) => random.nextInt(256));
      
      final aesKey = Key(Uint8List.fromList(aesKeyBytes));
      final iv = IV(Uint8List.fromList(ivBytes));

      // 1. Symmetrically encrypt message content
      final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
      final encryptedContent = encrypter.encrypt(plaintext, iv: iv);

      // 2. Symmetrically encrypt fileUrl if present
      String? fileCt;
      if (fileUrl != null) {
        fileCt = encrypter.encrypt(fileUrl, iv: iv).base64;
      }

      // 3. Encrypt symmetric key info (AES key + IV) using RSA Public Key
      final recipientPublicKey = rsaPublicKeyFromJson(recipientPublicKeyJson);
      final rsaEncrypter = Encrypter(RSA(publicKey: recipientPublicKey));
      
      final keyBundle = jsonEncode({
        'key': base64.encode(aesKey.bytes),
        'iv': base64.encode(iv.bytes),
      });
      
      final encryptedKeyBundle = rsaEncrypter.encrypt(keyBundle);

      final result = {
        'ciphertext': encryptedContent.base64,
        'encryptedKey': encryptedKeyBundle.base64,
      };
      
      if (fileCt != null) {
        result['fileCt'] = fileCt;
      }
      
      return result;
    } catch (e) {
      debugPrint('[CRYPTO HELPER] Encryption Error: $e');
      return null;
    }
  }

  // Decrypt hybrid message:
  // 1. Decrypt the keyBundle using recipient's RSA private key.
  // 2. Parse the AES key and IV.
  // 3. Decrypt ciphertext using AES-256-CBC.
  static String decryptMessage({
    required String ciphertext,
    required String encryptedKey,
    required String privateKeyJson,
  }) {
    try {
      final RSAPrivateKey privateKey;
      if (_cachedPrivateKey != null && localPrivateKey == privateKeyJson) {
        privateKey = _cachedPrivateKey!;
      } else {
        privateKey = rsaPrivateKeyFromJson(privateKeyJson);
      }
      
      // 1. Decrypt AES key bundle using RSA private key
      final rsaEncrypter = Encrypter(RSA(privateKey: privateKey));
      final decryptedKeyBundleJson = rsaEncrypter.decrypt(Encrypted.fromBase64(encryptedKey));
      
      final Map<String, dynamic> bundle = jsonDecode(decryptedKeyBundleJson);
      final aesKeyBytes = base64.decode(bundle['key']!);
      final ivBytes = base64.decode(bundle['iv']!);
      
      final aesKey = Key(aesKeyBytes);
      final iv = IV(ivBytes);

      // 2. Decrypt content using AES-CBC
      final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
      return encrypter.decrypt(Encrypted.fromBase64(ciphertext), iv: iv);
    } catch (e) {
      debugPrint('[CRYPTO HELPER] Decryption Error: $e');
      return '[Decryption failed: Secure key mismatch]';
    }
  }
}
