import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}

class GoogleLogin extends LoginSystem {
  GoogleSignIn? _googleSignIn;

  @override
  void init() {
    _googleSignIn = GoogleSignIn(
      scopes: ["profile", "email"],
    );
  }

  @override
  Future<UserCredential?> login() async {
    try {
      emit(MProgress());
      // Clear the cached Google account so an explicit button press always
      // presents the account chooser instead of silently reusing it.
      await _googleSignIn?.signOut();
      final googleSignIn = await _googleSignIn?.signIn();
      if (googleSignIn == null) {
        throw const GoogleSignInCancelledException();
      }

      GoogleSignInAuthentication? googleAuth =
          await googleSignIn.authentication;

      AuthCredential authCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await firebaseAuth.signInWithCredential(authCredential);
      emit(MSuccess());

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  @override
  void onEvent(MLoginState state) {
    // TODO: implement onEvent
  }
}
