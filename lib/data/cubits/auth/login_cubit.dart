// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:io';

import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/logger.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/data/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';

abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginInProgress extends LoginState {}

class LoginSuccess extends LoginState {
  final bool isProfileCompleted;
  final User user;
  final UserCredential? credential;
  final Map<String, dynamic> apiResponse;

  LoginSuccess({
    required this.isProfileCompleted,
    required this.user,
    this.credential,
    required this.apiResponse,
  });
}

class LoginFailure extends LoginState {
  final dynamic errorMessage;

  LoginFailure(this.errorMessage);
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(LoginInitial());

  final AuthRepository _authRepository = AuthRepository();

  Future<String?> getDeviceToken() async {
    String? token;
    if (Platform.isIOS) {
      token = await FirebaseMessaging.instance.getAPNSToken();
    } else {
      token = await FirebaseMessaging.instance.getToken();
    }
    return token;
  }

  Future<void> login({
    String? phoneNumber,
    required String firebaseUserId,
    required String type,
    required UserCredential credential,
    String? countryCode,
  }) {
    return _login(
      phoneNumber: phoneNumber,
      firebaseUserId: firebaseUserId,
      type: type,
      user: credential.user!,
      credential: credential,
      countryCode: countryCode,
    );
  }

  Future<void> loginWithUser({
    String? phoneNumber,
    required User user,
    required String type,
    String? countryCode,
  }) {
    return _login(
      phoneNumber: phoneNumber,
      firebaseUserId: user.uid,
      type: type,
      user: user,
      countryCode: countryCode,
    );
  }

  Future<void> _login({
    String? phoneNumber,
    required String firebaseUserId,
    required String type,
    required User user,
    UserCredential? credential,
    String? countryCode,
  }) async {
    try {
      emit(LoginInProgress());

      /*String? token = await getDeviceToken();*/
      String? token = await () async {
        try {
          return await FirebaseMessaging.instance.getToken();
        } catch (_) {
          return '';
        }
      }();

      FirebaseAuth firebaseAuth = FirebaseAuth.instance;

      User? updatedUser;
      if (type == AuthenticationType.apple.name) {
        updatedUser = firebaseAuth.currentUser;
        if (updatedUser != null) {
          AppLog.i(
              'Apple login: display name present: ${updatedUser.displayName != null}',
              name: 'LoginCubit');
        }
        await user.reload();
      }

      final provider =
          user.providerData.isEmpty ? null : user.providerData.first;

      Map<String, dynamic> result = await _authRepository.numberLoginWithApi(
        phone: phoneNumber ?? user.phoneNumber ?? provider?.phoneNumber,
        type: type,
        uid: firebaseUserId,
        fcmId: token,
        email: user.email ?? provider?.email,
        name: type == AuthenticationType.apple.name
            ? updatedUser?.displayName ??
                user.displayName ??
                provider?.displayName
            : user.displayName ?? provider?.displayName,
        profile: user.photoURL ?? provider?.photoURL,
        countryCode: countryCode,
      );

      // Storing data to local database {HIVE}
      await HiveUtils.setJWT(result['token']);

      if ((result['data']['name'] == "" || result['data']['name'] == null) ||
          (result['data']['email'] == "" || result['data']['email'] == null)) {
        HiveUtils.setProfileNotCompleted();

        var data = result['data'];
        // data['countryCode'] = countryCode;
        await HiveUtils.setUserData(data);
        emit(LoginSuccess(
          apiResponse: Map<String, dynamic>.from(result['data']),
          isProfileCompleted: false,
          user: user,
          credential: credential,
        ));
      } else {
        var data = result['data'];
        // data['countryCode'] = countryCode;
        await HiveUtils.setUserData(data);
        emit(LoginSuccess(
          apiResponse: Map<String, dynamic>.from(result['data']),
          isProfileCompleted: true,
          user: user,
          credential: credential,
        ));
      }
    } catch (e) {
      if (e is ApiException) {}

      emit(LoginFailure(e));
    }
  }
}
