import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/data/cubits/auth/login_cubit.dart';
import 'package:Ebozor/data/cubits/system/user_details.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SignupAuthListener extends StatelessWidget {
  final Widget child;
  final ValueChanged<AuthenticationSuccess>? onEmailSuccess;

  const SignupAuthListener({
    super.key,
    required this.child,
    this.onEmailSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthenticationCubit, AuthenticationState>(
          listener: _onAuthenticationState,
        ),
        BlocListener<LoginCubit, LoginState>(listener: _onLoginState),
      ],
      child: child,
    );
  }

  void _onAuthenticationState(BuildContext context, AuthenticationState state) {
    if (state is AuthenticationInProcess) {
      Widgets.showLoader(context);
      return;
    }
    if (state is AuthenticationFail) {
      Widgets.hideLoder(context);
      final message = authenticationErrorMessage(state.error);
      if (message.isNotEmpty) {
        HelperUtils.showSnackBarMessage(context, message,
            type: MessageType.error);
      }
      return;
    }
    if (state is! AuthenticationSuccess) return;

    Widgets.hideLoder(context);
    if (state.type == AuthenticationType.email) {
      onEmailSuccess?.call(state);
      return;
    }

    final phonePayload = state.payload is PhoneLoginPayload
        ? state.payload as PhoneLoginPayload
        : null;
    context.read<LoginCubit>().login(
          phoneNumber:
              phonePayload?.phoneNumber ?? state.credential.user?.phoneNumber,
          firebaseUserId: state.credential.user!.uid,
          type: state.type.name,
          credential: state.credential,
          countryCode:
              phonePayload == null ? null : '+${phonePayload.countryCode}',
        );
  }

  void _onLoginState(BuildContext context, LoginState state) {
    if (state is LoginInProgress) {
      Widgets.showLoader(context);
      return;
    }
    if (state is LoginFailure) {
      Widgets.hideLoder(context);
      HelperUtils.showSnackBarMessage(
          context, 'Unable to finish sign up. Please try again.',
          type: MessageType.error);
      return;
    }
    if (state is! LoginSuccess) return;

    Widgets.hideLoder(context);
    HiveUtils.setUserIsAuthenticated(true);
    context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());

    if (state.isProfileCompleted) {
      if (HiveUtils.getCityName()?.isNotEmpty == true) {
        HelperUtils.killPreviousPages(context, Routes.main, {'from': 'signup'});
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.locationPermissionScreen, (route) => false);
      }
      return;
    }

    final authCubit = context.read<AuthenticationCubit>();
    final phonePayload = authCubit.payload is PhoneLoginPayload
        ? authCubit.payload as PhoneLoginPayload
        : null;
    Navigator.pushReplacementNamed(
      context,
      Routes.completeProfile,
      arguments: {
        'from': 'signup',
        'popToCurrent': false,
        'type': authCubit.type,
        'extraData': {
          'email': state.credential.user?.email ?? state.apiResponse['email'],
          'username': state.apiResponse['name'],
          'mobile': state.apiResponse['mobile'],
          'countryCode':
              phonePayload == null ? null : '+${phonePayload.countryCode}',
        },
      },
    );
  }
}
