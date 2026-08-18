import 'package:Ebozor/utils/logger.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';

class PhoneLogin extends LoginSystem {
  String? verificationId;
  String? _lastPhoneNumber;
  DateTime? _codeSentAt;
  int _verificationAttempt = 0;

  void cancelVerification() {
    _verificationAttempt++;
  }

  @override
  Future<UserCredential?> login() async {
    try {
      emit(MProgress());
      final otpVal = (payload as PhoneLoginPayload).getOTP();
      AppLog.i(
          'Attempting sign in. verificationId set: ${verificationId != null}',
          name: 'PhoneLogin');

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId ?? "", smsCode: otpVal!);

      final userCredential =
          await firebaseAuth.signInWithCredential(credential);

      verificationId = null;
      _codeSentAt = null;
      forceResendingToken = null;

      AppLog.i('Phone login successful.', name: 'PhoneLogin');
      emit(MSuccess());

      return userCredential;
    } catch (e) {
      AppLog.e('Phone login failed', error: e, name: 'PhoneLogin');
      rethrow;
    }
  }

  @override
  Future<void> requestVerification() async {
    emit(MOtpSendInProgress());
    final phoneNum =
        "+${(payload as PhoneLoginPayload).countryCode}${(payload as PhoneLoginPayload).phoneNumber}";
    final codeSentAt = _codeSentAt;
    final canReuseVerification = _lastPhoneNumber == phoneNum &&
        verificationId != null &&
        codeSentAt != null &&
        DateTime.now().difference(codeSentAt) <
            Duration(seconds: Constant.otpTimeOutSecond);

    if (canReuseVerification) {
      AppLog.i('Reusing active OTP session for the same phone number.',
          name: 'PhoneLogin');
      await super.requestVerification();
      return;
    }

    final attempt = ++_verificationAttempt;
    if (_lastPhoneNumber != phoneNum) {
      forceResendingToken = null;
    }
    _lastPhoneNumber = phoneNum;
    verificationId = null;
    _codeSentAt = null;
    // NOTE: phone number intentionally omitted from log to avoid leaking PII
    AppLog.i('requestVerification: calling verifyPhoneNumber',
        name: 'PhoneLogin');

    await FirebaseAuth.instance
        .verifyPhoneNumber(
          timeout: Duration(seconds: Constant.otpTimeOutSecond),
          phoneNumber: phoneNum,
          verificationCompleted: (PhoneAuthCredential credential) {
            if (attempt != _verificationAttempt) return;
            AppLog.i('verificationCompleted: auto-resolution triggered.',
                name: 'PhoneLogin');
          },
          verificationFailed: (FirebaseAuthException e) {
            if (attempt != _verificationAttempt) return;
            verificationId = null;
            _codeSentAt = null;
            AppLog.e('verificationFailed: ${e.code}',
                error: e, name: 'PhoneLogin');
            emit(MFail(e));
          },
          codeSent: (String verificationId, int? resendToken) {
            if (attempt != _verificationAttempt) return;
            AppLog.i('codeSent: SMS dispatched.', name: 'PhoneLogin');
            super.requestVerification();
            forceResendingToken = resendToken;
            this.verificationId = verificationId;
            _codeSentAt = DateTime.now();
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            if (attempt != _verificationAttempt) return;
            AppLog.w('codeAutoRetrievalTimeout reached.', name: 'PhoneLogin');
          },
          forceResendingToken: forceResendingToken,
        )
        .then((value) {});
  }

  /// Verify OTP manually (called from the OTP input screen).
  Future<void> verifyOtp(String otp) async {
    try {
      AppLog.i('verifyOtp called.', name: 'PhoneLogin');

      if (verificationId == null) {
        throw Exception("Verification ID not found");
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otp,
      );

      await firebaseAuth.signInWithCredential(credential);

      emit(MSuccess());
      AppLog.i('Manual OTP verification successful.', name: 'PhoneLogin');
    } catch (e) {
      emit(MFail(e));
      AppLog.e('Manual OTP verification failed', error: e, name: 'PhoneLogin');
    }
  }

  @override
  void onEvent(MLoginState state) {}
}
