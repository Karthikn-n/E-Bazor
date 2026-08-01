
import 'package:flutter/foundation.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';

class EmailLogin extends LoginSystem {
  @override
  Future<UserCredential?> login() async {
    UserCredential? userCredential;
    if (payload is EmailLoginPayload) {
      var payloadData = (payload as EmailLoginPayload);

      if (payloadData.type == EmailLoginType.signup) {
        debugPrint('[EmailLogin] Creating user with email: ${payloadData.email}');
        userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: payloadData.email,
          password: payloadData.password,
        );
        debugPrint('[EmailLogin] User created successfully. UID: ${userCredential.user?.uid}');
        emit(MSuccess());
      } else {
        debugPrint('[EmailLogin] Signing in user with email: ${payloadData.email}');
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: payloadData.email,
          password: payloadData.password,
        ).catchError((e){
          debugPrint('[EmailLogin] Sign in failed with error: $e');
          emit(MFail(e));
        });
        if (userCredential != null) {
          debugPrint('[EmailLogin] Sign in successful. UID: ${userCredential.user?.uid}');
        }
      }
    }
    return userCredential;
  }

  @override
  void onEvent(MLoginState state) {

  }
}
