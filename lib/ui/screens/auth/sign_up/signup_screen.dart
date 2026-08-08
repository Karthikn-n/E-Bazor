import 'dart:io';

import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/custom_text_form_field.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/cloudState/cloud_state.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/auth/sign_up/signup_auth_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/ui/screens/auth/sign_up/email_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  final String? emailId;

  const SignupScreen({super.key, this.emailId});

  static BlurredRouter route(RouteSettings settings) {
    Map? args = settings.arguments as Map?;
    return BlurredRouter(
      builder: (context) {
        return SignupScreen(
          emailId: args!['emailId'],
        );
      },
    );
  }

  @override
  CloudState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends CloudState<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isObscure = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.emailId?.trim() ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void onTapSignup() async {
    if (_formKey.currentState?.validate() ?? false) {
      debugPrint(
          '[SignupScreen] onTapSignup initiated. Username: ${_usernameController.text}, Email: ${_emailController.text}');
      addCloudData("signup_details", {"username": _usernameController.text});
      context.read<AuthenticationCubit>().setData(
          payload: EmailLoginPayload(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              type: EmailLoginType.signup),
          type: AuthenticationType.email);
      context.read<AuthenticationCubit>().authenticate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      bottomNavigationBar: termAndPolicyTxt(),
      body: AnnotatedRegion(
        value: SystemUiOverlayStyle(
          statusBarColor: context.color.backgroundColor,
        ),
        child: SignupAuthListener(
          child: BlocConsumer<AuthenticationCubit, AuthenticationState>(
            listener: (context, state) {
              debugPrint(
                  '[SignupScreen] BlocConsumer listener triggered: $state');
              if (state is AuthenticationSuccess) {
                debugPrint(
                    '[SignupScreen] AuthenticationSuccess. type: ${state.type}');
                if (state.type == AuthenticationType.email) {
                  Navigator.push<dynamic>(context, BlurredRouter(
                    builder: (context) {
                      return EmailVerificationScreen(
                        username: _usernameController.text,
                        email: _emailController.text,
                        password: _passwordController.text,
                      );
                    },
                  ));
                }
              }
            },
            builder: (context, state) {
              return Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(left: 18.0, right: 18, top: 23),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.bottomEnd,
                          child: FittedBox(
                            fit: BoxFit.none,
                            child: MaterialButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  Routes.main,
                                  arguments: {
                                    "from": "login",
                                    "isSkipped": true,
                                  },
                                );
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              color: context.color.forthColor
                                  .withValues(alpha: 0.102),
                              elevation: 0,
                              height: 28,
                              minWidth: 64,
                              child: Text("skip".translate(context))
                                  .color(context.color.forthColor),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 66,
                        ),
                        Text("welcome".translate(context))
                            .size(context.font.extraLarge),
                        const SizedBox(
                          height: 8,
                        ),
                        Text("signUpToeClassify".translate(context))
                            .size(context.font.large)
                            .color(
                              context.color.textColorDark.brighten(50),
                            ),
                        const SizedBox(
                          height: 24,
                        ),
                        CustomTextFormField(
                          controller: _emailController,
                          isReadOnly: true,
                          fillColor: context.color.secondaryColor,
                          validator: CustomTextFieldValidator.email,
                          hintText: "emailAddress".translate(context),
                          borderColor: context.color.borderColor.darken(10),
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        CustomTextFormField(
                          controller: _usernameController,
                          fillColor: context.color.secondaryColor,
                          validator: CustomTextFieldValidator.nullCheck,
                          hintText: "userName".translate(context),
                          borderColor: context.color.borderColor.darken(10),
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        CustomTextFormField(
                          controller: _passwordController,
                          fillColor: context.color.secondaryColor,
                          obscureText: isObscure,
                          suffix: IconButton(
                            onPressed: () {
                              isObscure = !isObscure;
                              setState(() {});
                            },
                            icon: Icon(
                              !isObscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: context.color.textColorDark
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          hintText: "password".translate(context),
                          validator: CustomTextFieldValidator.password,
                          borderColor: context.color.borderColor.darken(10),
                        ),
                        const SizedBox(
                          height: 36,
                        ),
                        UiUtils.buildButton(context,
                            onPressed: onTapSignup,
                            buttonTitle:
                                "verifyEmailAddress".translate(context),
                            radius: 10,
                            disabled: false,
                            height: 46,
                            disabledColor:
                                const Color.fromARGB(255, 104, 102, 106)),
                        const SizedBox(
                          height: 36,
                        ),
                        if (Constant.mobileAuthentication == "1") mobileAuth(),
                        if (Constant.googleAuthentication == "1" ||
                            Constant.appleAuthentication == "1")
                          googleAndAppleAuth(),
                        const SizedBox(
                          height: 24,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("alreadyHaveAcc".translate(context)).color(
                                context.color.textColorDark.brighten(50)),
                            const SizedBox(
                              width: 12,
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, Routes.login);
                              },
                              child: Text("login".translate(context))
                                  .underline()
                                  .color(context.color.territoryColor),
                            )
                          ],
                        ),
                        const SizedBox(
                          height: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget mobileAuth() {
    return UiUtils.buildButton(
      context,
      onPressed: () => Navigator.pushNamed(context, Routes.signupMainScreen),
      showElevation: false,
      buttonColor: secondaryColor_,
      border: context.watch<AppThemeCubit>().state.appTheme != AppTheme.dark
          ? BorderSide(
              color: context.color.textDefaultColor.withValues(alpha: 0.5),
            )
          : null,
      textColor: textDarkColor,
      radius: 8,
      height: 46,
      buttonTitle:
          '${"signupWithLbl".translate(context)} ${"mobileNumberLbl".translate(context)}',
    );
  }

  Widget googleAndAppleAuth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        if (Constant.googleAuthentication == "1")
          UiUtils.buildButton(context,
              prefixWidget: Padding(
                padding: EdgeInsetsDirectional.only(end: 10.0),
                child:
                    UiUtils.getSvg(AppIcons.googleIcon, width: 22, height: 22),
              ),
              showElevation: false,
              buttonColor: secondaryColor_,
              border: context.watch<AppThemeCubit>().state.appTheme !=
                      AppTheme.dark
                  ? BorderSide(
                      color:
                          context.color.textDefaultColor.withValues(alpha: 0.5))
                  : null,
              textColor: textDarkColor, onPressed: () {
            context.read<AuthenticationCubit>().setData(
                payload:
                    GoogleLoginPayload(intent: AuthenticationIntent.signUp),
                type: AuthenticationType.google);
            context.read<AuthenticationCubit>().authenticate();
          },
              radius: 8,
              height: 46,
              buttonTitle: "continueWithGoogle".translate(context)),
        if (Constant.appleAuthentication == "1" && Platform.isIOS) ...[
          const SizedBox(
            height: 12,
          ),
          if (Platform.isIOS)
            UiUtils.buildButton(context,
                prefixWidget: Padding(
                  padding: EdgeInsetsDirectional.only(end: 10.0),
                  child:
                      UiUtils.getSvg(AppIcons.appleIcon, width: 22, height: 22),
                ),
                showElevation: false,
                buttonColor: secondaryColor_,
                border: context.watch<AppThemeCubit>().state.appTheme !=
                        AppTheme.dark
                    ? BorderSide(
                        color: context.color.textDefaultColor
                            .withValues(alpha: 0.5))
                    : null,
                textColor: textDarkColor, onPressed: () {
              context.read<AuthenticationCubit>().setData(
                  payload:
                      AppleLoginPayload(intent: AuthenticationIntent.signUp),
                  type: AuthenticationType.apple);
              context.read<AuthenticationCubit>().authenticate();
            },
                height: 46,
                radius: 8,
                buttonTitle: "continueWithApple".translate(context)),
        ]
      ],
    );
  }

  Widget termAndPolicyTxt() {
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: 15.0, start: 25.0, end: 25.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("bySigningUpLoggingIn".translate(context))
              .centerAlign()
              .size(context.font.small)
              .color(context.color.textLightColor.withValues(alpha: 0.8)),
          const SizedBox(
            height: 3,
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            InkWell(
                child: Text("termsOfService".translate(context))
                    .underline()
                    .color(context.color.territoryColor)
                    .size(context.font.small),
                onTap: () => Navigator.pushNamed(
                        context, Routes.profileSettings, arguments: {
                      'title': "termsConditions".translate(context),
                      'param': Api.termsAndConditions
                    })),
            /*CustomTextButton(
                text:Text("termsOfService".translate(context)).underline().color(context.color.teritoryColor).size(context.font.small),
                onPressed: () => Navigator.pushNamed(
                        context, Routes.profileSettings,
                        arguments: {
                          'title': UiUtils.getTranslatedLabel(
                              context, "termsConditions"),
                          'param': Api.termsAndConditions
                        })),*/
            const SizedBox(
              width: 5.0,
            ),
            Text("andTxt".translate(context))
                .size(context.font.small)
                .color(context.color.textLightColor.withValues(alpha: 0.8)),
            const SizedBox(
              width: 5.0,
            ),
            InkWell(
                child: Text("privacyPolicy".translate(context))
                    .underline()
                    .color(context.color.territoryColor)
                    .size(context.font.small),
                onTap: () => Navigator.pushNamed(
                        context, Routes.profileSettings, arguments: {
                      'title': "privacyPolicy".translate(context),
                      'param': Api.privacyPolicy
                    })),
          ]),
        ],
      ),
    );
  }
}
