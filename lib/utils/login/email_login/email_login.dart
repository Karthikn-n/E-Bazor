import 'package:flutter/foundation.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';

class EmailLogin extends LoginSystem {
  @override
  Future<UserCredential?> login() async {
    if (payload is! EmailLoginPayload) {
      throw StateError('Email authentication payload is missing');
    }

    final payloadData = payload as EmailLoginPayload;
    emit(MProgress());
    try {
      late UserCredential userCredential;
      if (payloadData.type == EmailLoginType.signup) {
        debugPrint(
            '[EmailLogin] Creating user with email: ${payloadData.email}');
        try {
          userCredential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: payloadData.email.trim(),
            password: payloadData.password,
          );
        } on FirebaseAuthException catch (error) {
          if (error.code != 'email-already-in-use') rethrow;

          debugPrint(
              '[EmailLogin] Existing email detected; checking for an unfinished verification.');
          try {
            userCredential =
                await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: payloadData.email.trim(),
              password: payloadData.password,
            );
          } on FirebaseAuthException catch (signInError) {
            if (signInError.code == 'invalid-credential' ||
                signInError.code == 'wrong-password' ||
                signInError.code == 'user-not-found') {
              throw FirebaseAuthException(
                code: 'account-exists-with-different-credential',
                message:
                    'This email already uses another sign-in method or password.',
              );
            }
            rethrow;
          }
          await userCredential.user?.reload();
          if (FirebaseAuth.instance.currentUser?.emailVerified == false) {
            payloadData.recoveredUnverifiedAccount = true;
            debugPrint('[EmailLogin] Recovered an existing unverified signup.');
          }
        }
        debugPrint(
            '[EmailLogin] User created successfully. UID: ${userCredential.user?.uid}');
      } else {
        debugPrint(
            '[EmailLogin] Signing in user with email: ${payloadData.email}');
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: payloadData.email.trim(),
          password: payloadData.password,
        );
        debugPrint(
            '[EmailLogin] Sign in successful. UID: ${userCredential.user?.uid}');
      }
      emit(MSuccess());
      return userCredential;
    } catch (error) {
      debugPrint(
          '[EmailLogin] ${payloadData.type.name} failed with error: $error');
      rethrow;
    }
  }

  @override
  void onEvent(MLoginState state) {}
}
