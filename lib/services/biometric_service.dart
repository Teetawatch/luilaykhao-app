import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'secure_storage.dart';

/// ผลของการขอยืนยันตัวตนหนึ่งครั้ง
///
/// ต้องแยก [failed] ออกจาก [unavailable] ให้ชัด: อย่างแรกคือ "ลองใหม่ได้"
/// อย่างหลังคือ "กดอีกกี่ครั้งก็ไม่มีวันผ่าน" ซึ่งถ้าปฏิบัติเหมือนกันเมื่อไหร่
/// หน้าปลดล็อกจะกลายเป็นทางตันที่ออกไม่ได้นอกจากล้างบัญชีทิ้ง
enum BiometricOutcome { success, failed, unavailable }

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// เครื่องนี้ยืนยันตัวตนได้ไหม (ไบโอเมตริกหรือ PIN/รูปแบบของเครื่องก็นับ
  /// เพราะเราเรียก [authenticate] แบบ `biometricOnly: false`)
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasEnrolledBiometrics() async {
    try {
      final list = await _auth.getAvailableBiometrics();
      return list.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<BiometricOutcome> authenticate({
    String reason = 'ยืนยันตัวตนเพื่อปลดล็อกแอป',
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricOutcome.success : BiometricOutcome.failed;
    } on LocalAuthException catch (e) {
      debugPrint('Biometric auth error: ${e.code} ${e.description}');
      return switch (e.code) {
        // ไม่มีทางสำเร็จบนเครื่องนี้ในสภาพปัจจุบัน — ไม่มีฮาร์ดแวร์ ไม่ได้ตั้ง
        // รหัสเครื่องไว้ ยังไม่ลงทะเบียนนิ้ว โดนล็อกถาวร หรือฝั่งระบบเปิด UI
        // ให้ไม่ได้ (บน Android คือกรณี Activity ไม่ใช่ FragmentActivity)
        LocalAuthExceptionCode.uiUnavailable ||
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.biometricLockout ||
        LocalAuthExceptionCode.deviceError => BiometricOutcome.unavailable,
        // ยกเลิกเอง หมดเวลา ระบบขัดจังหวะ ล็อกชั่วคราว — กดใหม่ได้
        _ => BiometricOutcome.failed,
      };
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return BiometricOutcome.failed;
    }
  }

  Future<bool> isEnabled() => SecureStorage.instance.readBiometricEnabled();

  Future<void> setEnabled(bool enabled) =>
      SecureStorage.instance.writeBiometricEnabled(enabled);
}
