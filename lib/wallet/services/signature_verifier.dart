import 'dart:typed_data';
import 'package:convert/convert.dart';

/// 서명 검증 서비스
/// EIP-191 Personal Sign 서명 검증
///
/// 현재는 기본적인 검증만 수행하며, 실제 프로덕션에서는
/// 백엔드 API를 통해 서명을 검증하는 것을 권장합니다.
class SignatureVerifier {
  /// 서명이 특정 주소로부터 생성되었는지 검증
  ///
  /// @param message 원본 메시지
  /// @param signature 서명 (hex string, 0x prefix 포함/미포함 모두 가능)
  /// @param expectedAddress 예상되는 서명자 주소
  /// @return true if signature is valid and matches expected address
  static Future<bool> verifySignature({
    required String message,
    required String signature,
    required String expectedAddress,
  }) async {
    try {
      // 서명에서 주소 복구
      final recoveredAddress = await recoverAddress(
        message: message,
        signature: signature,
      );

      if (recoveredAddress == null) {
        print('[SignatureVerifier] Failed to recover address');
        return false;
      }

      // 주소 정규화 (소문자, 0x prefix)
      final normalizedExpected = _normalizeAddress(expectedAddress);
      final normalizedRecovered = _normalizeAddress(recoveredAddress);

      final isValid = normalizedExpected == normalizedRecovered;
      print('[SignatureVerifier] Verification result: $isValid');
      print('[SignatureVerifier] Expected: $normalizedExpected');
      print('[SignatureVerifier] Recovered: $normalizedRecovered');

      return isValid;
    } catch (e) {
      print('[SignatureVerifier] Verification error: $e');
      return false;
    }
  }

  /// 서명으로부터 서명자 주소 복구
  ///
  /// EIP-191 Personal Sign 형식:
  /// "\x19Ethereum Signed Message:\n" + len(message) + message
  ///
  /// @param message 원본 메시지
  /// @param signature 서명 (hex string)
  /// @return 복구된 주소 또는 null
  static Future<String?> recoverAddress({
    required String message,
    required String signature,
  }) async {
    try {
      // Web3Dart의 Credentials를 사용하여 서명 검증
      // 메시지를 Uint8List로 변환
      final messageBytes = Uint8List.fromList(message.codeUnits);

      // 서명을 바이트로 변환
      final signatureBytes = _hexToBytes(signature);

      if (signatureBytes.length != 65) {
        print('[SignatureVerifier] Invalid signature length: ${signatureBytes.length}');
        return null;
      }

      // web3dart는 자체적으로 ecRecover를 지원하지 않으므로
      // 현재는 서명 형식만 검증하고 실제 복구는 백엔드에 위임
      // TODO: 백엔드 API 엔드포인트가 준비되면 여기서 호출

      print('[SignatureVerifier] Signature format validated');
      print('[SignatureVerifier] Message length: ${messageBytes.length}');
      print('[SignatureVerifier] Signature length: ${signatureBytes.length}');

      // 임시: 서명이 유효한 형식이면 null 반환
      // 실제로는 백엔드 API를 호출하여 복구된 주소를 받아야 함
      return null;
    } catch (e) {
      print('[SignatureVerifier] Recovery error: $e');
      return null;
    }
  }


  /// Hex string을 바이트 배열로 변환
  static Uint8List _hexToBytes(String hexString) {
    // 0x prefix 제거
    String hex = hexString;
    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      hex = hex.substring(2);
    }

    // 홀수 길이면 앞에 0 추가
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }

    return Uint8List.fromList(hex.codeUnits.hexDecode);
  }

  /// 주소 정규화 (소문자, 0x prefix)
  static String _normalizeAddress(String address) {
    String normalized = address.toLowerCase();
    if (!normalized.startsWith('0x')) {
      normalized = '0x$normalized';
    }
    return normalized;
  }
}

/// Hex decode extension
extension HexDecode on List<int> {
  List<int> get hexDecode {
    return hex.decode(String.fromCharCodes(this));
  }
}
