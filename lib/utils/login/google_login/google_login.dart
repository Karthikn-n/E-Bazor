import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}

class GoogleLogin extends LoginSystem {
  @override
  void init() {}

  @override
  Future<UserCredential?> login() async {
    try {
      emit(MProgress());
      final googleSignIn = GoogleSignIn.instance;

      // Clear the cached Google account so an explicit button press always
      // presents the account chooser instead of silently reusing it.
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await googleSignIn.authenticate();

      final googleAuth = await googleUser.authentication;
      final clientAuth = await googleUser.authorizationClient.authorizeScopes(["email", "profile"]);

      AuthCredential authCredential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await firebaseAuth.signInWithCredential(authCredential);
      emit(MSuccess());

      return userCredential;
    } catch (e) {
      if (e.toString().contains('canceled') ||
          e.toString().contains('cancelled') ||
          e.toString().contains('aborted') ||
          e.toString().contains('ERROR_ABORTED_BY_USER')) {
        emit(MFail(const GoogleSignInCancelledException()));
        throw const GoogleSignInCancelledException();
      }
      rethrow;
    }
  }

  @override
  void onEvent(MLoginState state) {}
}
