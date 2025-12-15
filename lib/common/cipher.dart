import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/export.dart' as pointy;

// Default encryption key should not be hardcoded
// This should be loaded from secure storage or server
String get defaultEncKey => '';

// AES-256-CBC 암호화
String encryptAES(String plainText, {String? enckey}) {
  if (plainText == '' || enckey == null || enckey.isEmpty) return '';
  if (enckey.length < 32) return ''; // Silently fail instead of assert

  final key = Uint8List.fromList(utf8.encode(enckey.substring(0, 32)));
  final iv = Uint8List.fromList(utf8.encode(enckey.substring(0, 16)));

  final cipher = CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(key), iv));

  final input = Uint8List.fromList(utf8.encode(plainText));
  // PKCS7 패딩 적용
  final paddedInput = _addPKCS7Padding(input, 16);

  final output = Uint8List(paddedInput.length);
  var offset = 0;

  while (offset < paddedInput.length) {
    offset += cipher.processBlock(paddedInput, offset, output, offset);
  }

  return base64.encode(output);
}

// AES-256-CBC 복호화
String? decryptAES(String encrypted, {String? enckey}) {
  if (encrypted == '' || enckey == null || enckey.isEmpty) return '';
  if (enckey.length < 32) return null; // Silently fail instead of assert

  try {
    final key = Uint8List.fromList(utf8.encode(enckey.substring(0, 32)));
    final iv = Uint8List.fromList(utf8.encode(enckey.substring(0, 16)));

    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));

    final input = base64.decode(encrypted);
    final output = Uint8List(input.length);
    var offset = 0;

    while (offset < input.length) {
      offset += cipher.processBlock(input, offset, output, offset);
    }

    // PKCS7 패딩 제거
    final unpadded = _removePKCS7Padding(output);
    return utf8.decode(unpadded);
  } catch (e) {
    return null;
  }
}

// SHA-1 해시
String createSHA1Hash(String inputText) {
  final digest = Digest('SHA-1');
  final bytes = utf8.encode(inputText);
  return digest
      .process(Uint8List.fromList(bytes))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

// SHA-256 해시
String createSHA256Hash(String inputText) {
  final digest = Digest('SHA-256');
  final bytes = utf8.encode(inputText);
  return digest
      .process(Uint8List.fromList(bytes))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

// HMAC-SHA256
String createHMAC256(String inputText, String secretInput) {
  final hmac = HMac(SHA256Digest(), 64)
    ..init(KeyParameter(Uint8List.fromList(utf8.encode(inputText))));

  final bytes = Uint8List.fromList(utf8.encode(secretInput));
  return hmac
      .process(bytes)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

// PKCS7 패딩 추가
Uint8List _addPKCS7Padding(Uint8List data, int blockSize) {
  final padLength = blockSize - (data.length % blockSize);
  final padded = Uint8List(data.length + padLength)..setAll(0, data);
  for (var i = data.length; i < padded.length; i++) {
    padded[i] = padLength;
  }
  return padded;
}

// PKCS7 패딩 제거
Uint8List _removePKCS7Padding(Uint8List data) {
  final padLength = data[data.length - 1];
  return Uint8List.fromList(data.sublist(0, data.length - padLength));
}

String generateMd5(String input) {
  final bytes = utf8.encode(input);
  final digest = MD5Digest();
  final hash = digest.process(Uint8List.fromList(bytes));
  return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

// 서버가 준 salt를 이용해서 key derive
// - 사용 안함
String deriveSaltedKey(String salt, String masterKey) {
  final keyDerivator =
      pointy.PBKDF2KeyDerivator(pointy.HMac(pointy.SHA256Digest(), 64))
        ..init(pointy.Pbkdf2Parameters(utf8.encode(salt), 10000, 32));

  final derivedKeyBytes = keyDerivator.process(utf8.encode(masterKey));

  return base64.encode(derivedKeyBytes);
}
