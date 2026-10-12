import 'package:Ebozor/utils/logger.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}

class GoogleLogin extends LoginSystem {
  static const String _webClientId =
      '655632443224-10i7erd7046quk6vg7k2hf3r7l4c1kh2.apps.googleusercontent.com';
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      AppLog.i('Initializing GoogleSignIn instance...', name: 'GoogleLogin');
      await GoogleSignIn.instance.initialize(
        serverClientId: _webClientId,
      );
      _initialized = true;
      AppLog.i('GoogleSignIn instance initialized successfully',
          name: 'GoogleLogin');
    } catch (e, stack) {
      AppLog.e('Failed to initialize GoogleSignIn: $e',
          error: e, stackTrace: stack, name: 'GoogleLogin');
    }
  }

  @override
  void init() {
    ensureInitialized();
  }

  @override
  Future<UserCredential?> login() async {
    try {
      emit(MProgress());
      await ensureInitialized();
      final googleSignIn = GoogleSignIn.instance;

      // Clear the cached Google account so an explicit button press always
      // presents the account chooser instead of silently reusing it.
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      AppLog.i('Calling GoogleSignIn.instance.authenticate()...',
          name: 'GoogleLogin');
      final googleUser = await googleSignIn.authenticate();

      AppLog.i('Google user authenticated: ${googleUser.email}',
          name: 'GoogleLogin');
      final googleAuth = await googleUser.authentication;

      String? accessToken;
      try {
        final clientAuth = await googleUser.authorizationClient
            .authorizeScopes(["email", "profile"]);
        accessToken = clientAuth.accessToken;
      } catch (authScopeError) {
        AppLog.w('authorizeScopes fallback: $authScopeError',
            name: 'GoogleLogin');
      }

      AuthCredential authCredential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleAuth.idToken,
      );

      AppLog.i(
          'Signing into Firebase with Google credentials (idToken present: ${googleAuth.idToken != null})...',
          name: 'GoogleLogin');
      UserCredential userCredential =
          await firebaseAuth.signInWithCredential(authCredential);

      AppLog.i('Firebase sign-in successful. UID: ${userCredential.user?.uid}',
          name: 'GoogleLogin');
      emit(MSuccess());

      return userCredential;
    } catch (e, stack) {
      AppLog.e('Google sign-in exception: $e',
          error: e, stackTrace: stack, name: 'GoogleLogin');
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
