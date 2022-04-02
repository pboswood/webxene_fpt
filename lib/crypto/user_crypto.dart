import 'dart:typed_data';
import 'dart:convert';
import 'package:webcrypto/webcrypto.dart';
import "constants.dart";

class UserCryptoKeys {
	RsaOaepPrivateKey? encryptPrivate;          // RSA private key, as set by DecryptSecureKey()
	RsaOaepPublicKey? encryptPublic;            // RSA public key, as set by FetchPublicKeys()
	RsassaPkcs1V15PrivateKey? signPrivate;      // RSA-SSA signing private key, as set by DecryptSecureKey()
	RsassaPkcs1V15PublicKey? signPublic;        // RSA-SSA signing public key, as set by FetchPublicKeys()
}

mixin UserCrypto {
	UserCryptoKeys cryptoKeys = UserCryptoKeys();

	// Decrypt securekey with our securecode and set appropriate private keys for crypto+signing.
	Future<void> DecryptSecurekey(String securecode, String iterationsB64, String saltB64, String securekeyCipherdataB64, String securekeyHMACB64) async {
		// Using the securecode, use PBKDF2 to generate an AES key and HMAC key.
		final pbkdf2 = await Pbkdf2SecretKey.importRawKey(Uint8List.fromList(utf8.encode(securecode)));
		final pbkdfIterations = base64Decode(iterationsB64).buffer.asByteData(0).getInt32(0, Endian.little);
		final pbkdfSalt = base64Decode(saltB64);
		final pbkdfOutput = await pbkdf2.deriveBits(CRYPTO_PBKDF2_LENGTH, Hash.sha1, pbkdfSalt, pbkdfIterations);
		// From the PBKDF2 output, import our AES key and our HMAC key.
		final aesKey = await AesCbcSecretKey.importRawKey(pbkdfOutput.sublist(0, CRYPTO_AES_LENGTH ~/ 8));
		final aesHmacKey = pbkdfOutput.sublist(CRYPTO_AES_LENGTH ~/ 8);

		// Load securekey cipherdata and HMAC signature, and separate into IV+ciphertext
		final securekeyCipherdata = base64Decode(securekeyCipherdataB64);
		final securekeyHMACSignature = base64Decode(securekeyHMACB64);
		final securekeyIV = securekeyCipherdata.sublist(0, CRYPTO_IV_LENGTH);
		final securekeyCiphertext = securekeyCipherdata.sublist(CRYPTO_IV_LENGTH);

		// Check HMAC matches our signature.
		final securekeyHMAC = await HmacSecretKey.importRawKey(aesHmacKey, Hash.sha1);
		final securekeyHMACGood = await securekeyHMAC.verifyBytes(securekeyHMACSignature, securekeyCipherdata);
		if (!securekeyHMACGood) {
			throw Exception("Securekey HMAC not valid");
		}

		// AES decrypt the securekey with the generated PBKDF2 key, then parse as UTF8 JSON.
		final securekeyPlaintext = await aesKey.decryptBytes(securekeyCiphertext, securekeyIV);
		final securekeyJSON = jsonDecode(Utf8Decoder().convert(securekeyPlaintext));

		// Import JWK for signing and encryption private keys from this JSON.
		// TODO: NB: https://github.com/google/webcrypto.dart/issues/21#issuecomment-963684465 <-- impl_ffi.utils.dart changes
		cryptoKeys.encryptPrivate = await RsaOaepPrivateKey.importJsonWebKey(securekeyJSON['encrypt'], Hash.sha1);
		cryptoKeys.signPrivate = await RsassaPkcs1V15PrivateKey.importJsonWebKey(securekeyJSON['sign'],Hash.sha256);
	}

}