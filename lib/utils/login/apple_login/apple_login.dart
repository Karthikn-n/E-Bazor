import 'dart:convert';
import 'dart:math';

import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:Ebozor/utils/login/lib/login_system.dart';

class AppleLogin extends LoginSystem {
  OAuthCredential? credential;

  @override
  void init() async {}

  Future<UserCredential?> login() async {
    try {
      emit(MProgress());

      final String rawNonce = _generateNonce();
      final String hashedNonce =
          sha256.convert(utf8.encode(rawNonce)).toString();

      final AuthorizationCredentialAppleID appleIdCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final String? identityToken = appleIdCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-apple-identity-token',
          message: 'Apple did not return an identity token.',
        );
      }

      credential = AppleAuthProvider.credentialWithIDToken(
        identityToken,
        rawNonce,
        AppleFullPersonName(
          givenName: appleIdCredential.givenName,
          familyName: appleIdCredential.familyName,
        ),
      );

      final UserCredential userCredential =
          await firebaseAuth.signInWithCredential(credential!);

      final User? user = userCredential.user;
      final String displayName = [
        appleIdCredential.givenName,
        appleIdCredential.familyName,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');

      if ((userCredential.additionalUserInfo?.isNewUser ?? false) &&
          user != null &&
          displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
        await user.reload();
      }

      emit(MSuccess());
      return userCredential;
    } catch (e) {
      print("apple error catch***${e.toString()}");
      emit(MFail(e));
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const String characters =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final Random random = Random.secure();
    return List<String>.generate(
      length,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  @override
  void onEvent(MLoginState state) {
    print("Login state is $state");
  }
}
