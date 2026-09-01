import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppleLoginCancelledException implements Exception {
  const AppleLoginCancelledException();
}

class AppleLogin extends LoginSystem {
  @override
  void init() async {}

  @override
  Future<UserCredential?> login() async {
    try {
      emit(MProgress());

      // Ensure any existing Firebase session is cleared
      if (firebaseAuth.currentUser != null) {
        await firebaseAuth.signOut();
      }

      final AppleAuthProvider appleProvider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      final UserCredential userCredential =
          await firebaseAuth.signInWithProvider(appleProvider);

      emit(MSuccess());
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) {
        emit(MFail(const AppleLoginCancelledException()));
        throw const AppleLoginCancelledException();
      }
      try {
        if (firebaseAuth.currentUser != null) {
          await firebaseAuth.signOut();
        }
      } catch (_) {}
      emit(MFail(e));
      rethrow;
    } catch (error) {
      try {
        if (firebaseAuth.currentUser != null) {
          await firebaseAuth.signOut();
        }
      } catch (_) {}
      emit(MFail(error));
      rethrow;
    }
  }

  bool _isCancellation(String code) =>
      code == 'canceled' ||
      code == 'cancelled' ||
      code == 'web-context-canceled' ||
      code == '1001';

  @override
  void onEvent(MLoginState state) {}
}
