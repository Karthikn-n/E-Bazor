import 'dart:async';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:device_region/device_region.dart';
import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';

import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/auth/sign_up/signup_auth_listener.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sms_autofill/sms_autofill.dart';

class MobileSignUpScreen extends StatefulWidget {
  final String? mobile;
  final String? countryCode;

  const MobileSignUpScreen({super.key, this.mobile, this.countryCode});

  @override
  State<MobileSignUpScreen> createState() => MobileSignUpScreenState();

  static BlurredRouter route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
        builder: (_) => MobileSignUpScreen(
              mobile: args?['mobile'],
              countryCode: args?['countryCode'],
            ));
  }
}

class MobileSignUpScreenState extends State<MobileSignUpScreen> {
  final TextEditingController mobileTextController = TextEditingController();
  bool isOtpSent = false;
  String? phone, otp, countryName, flagEmoji;

  Timer? timer;
  late Size size;
  CountryService countryCodeService = CountryService();
  bool isLoginButtonDisabled = true;
  final _formKey = GlobalKey<FormState>();

  // _otpController removed: PinFieldAutoFill writes to the `otp` String variable directly

  bool isObscure = true;
  late PhoneLoginPayload phoneLoginPayload = PhoneLoginPayload(
      widget.mobile!, widget.countryCode!,
      intent: AuthenticationIntent.signUp);
  bool isBack = false;
  String signature = "";
  bool _isOtpFlowActive = false;
  Key _otpFieldKey = UniqueKey();

  void _resetOtp({bool rebuild = true}) {
    otp = null;
    _otpFieldKey = UniqueKey();
    if (rebuild && mounted) setState(() {});
  }

  void _cancelOtpFlow() {
    context.read<AuthenticationCubit>().cancelPhoneVerification();
    _isOtpFlowActive = false;
    otp = null;
    _otpFieldKey = UniqueKey();
  }

  @override
  void initState() {
    super.initState();
    getSignature();
    //mobileTextController.text = widget.mobile!;

    context.read<AuthenticationCubit>().init();
    context.read<FetchSystemSettingsCubit>().fetchSettings();
    context.read<AuthenticationCubit>().listen((MLoginState state) {
      if (state is MFail) {
        if (!_isOtpFlowActive) return;
        if (context.read<AuthenticationCubit>().state
            is AuthenticationInProcess) {
          return;
        }
        Widgets.hideLoder(context);

        // Show the Firebase error message so the user knows why it failed
        // (e.g. invalid-phone-number, TOO_LONG, etc.)
        if (mounted) {
          final message = authenticationErrorMessage(state.error);
          if (message.isNotEmpty) {
            HelperUtils.showSnackBarMessage(context, message,
                type: MessageType.error);
          }

          // If OTP was never actually sent, go back to the phone input view
          if (isOtpSent) {
            setState(() {
              isOtpSent = false;
            });
          }
        }
      }
      if (state is MSuccess) _isOtpFlowActive = false;
    });
  }

  Widget emailSignUp() {
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
          '${"signupWithLbl".translate(context)} ${"emailLbl".translate(context)}',
    );
  }

  Future<void> getSignature() async {
    signature = await SmsAutoFill().getAppSignature;
    await SmsAutoFill().listenForCode;
    if (mounted) setState(() {});
  }

  /// it will return user's sim cards country code
  Future<Country> getSimCountry() async {
    List<Country> countryList = countryCodeService.getAll();
    String? simCountryCode;

    try {
      simCountryCode = await DeviceRegion.getSIMCountryCode();
    } catch (e) {}

    Country simCountry = countryList.firstWhere(
      (element) {
        if (Constant.isDemoModeOn) {
          return countryList.any(
            (element) => element.phoneCode == Constant.defaultCountryCode,
          );
        } else {
          return element.phoneCode == simCountryCode;
        }
      },
      orElse: () {
        return countryList
            .where(
              (element) => element.phoneCode == Constant.defaultCountryCode,
            )
            .first;
      },
    );

    if (Constant.isDemoModeOn) {
      simCountry = countryList
          .where((element) => element.phoneCode == Constant.demoCountryCode)
          .first;
    }

    return simCountry;
  }

  @override
  void dispose() {
    if (timer != null) {
      timer!.cancel();
    }

    //mobileTextController.dispose();
    SmsAutoFill().unregisterListener();

    super.dispose();
  }

  Future<void> sendVerificationCode() async {
    // Set the payload and request OTP — only call verify() once
    phoneLoginPayload = PhoneLoginPayload(widget.mobile!, widget.countryCode!,
        intent: AuthenticationIntent.signUp);
    _resetOtp(rebuild: false);
    _isOtpFlowActive = true;
    context
        .read<AuthenticationCubit>()
        .setData(payload: phoneLoginPayload, type: AuthenticationType.phone);
    context.read<AuthenticationCubit>().verify();

    setState(() {
      isOtpSent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.backgroundColor,
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: PopScope(
            canPop: isBack,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (isOtpSent) {
                _cancelOtpFlow();
                setState(() {
                  isOtpSent = false;
                });
              } else {
                setState(() {
                  isBack = true;
                });
                return;
              }

              setState(() {
                isBack = false;
              });
              return;
            },
            child: AnnotatedRegion(
              value: SystemUiOverlayStyle(
                statusBarColor: context.color.backgroundColor,
              ),
              child: Scaffold(
                backgroundColor: context.color.backgroundColor,
                bottomNavigationBar:
                    !isOtpSent ? termAndPolicyTxt() : SizedBox.shrink(),
                body: SignupAuthListener(
                  child: Builder(builder: (context) {
                    return Form(
                      key: _formKey,
                      child: isOtpSent ? verifyOTPWidget() : buildLoginWidget(),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLoginWidget() {
    return SingleChildScrollView(
      child: SizedBox(
        height: context.screenHeight - 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: FittedBox(
                  fit: BoxFit.none,
                  child: MaterialButton(
                    onPressed: () {
                      //HiveUtils.setUserIsNotNew();

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
                    color: context.color.forthColor.withValues(alpha: 0.102),
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
                  .size(context.font.extraLarge)
                  .color(context.color.textDefaultColor),
              const SizedBox(
                height: 8,
              ),
              Text("signUpToeClassify".translate(context))
                  .size(context.font.large)
                  .color(
                    context.color.textColorDark,
                  ),
              const SizedBox(
                height: 24,
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 18),
                decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: context.color.borderColor.darken(30))),
                child: Row(
                  children: [
                    // Display the country code as text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("+${widget.countryCode}")
                          .size(context.font.large)
                          .centerAlign(),
                    ),
                    Expanded(
                      child: Text(
                        widget.mobile!,
                      ).size(context.font.large),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 46,
              ),
              UiUtils.buildButton(context,
                  onPressed: sendVerificationCode,
                  buttonTitle: "verifyMobileNumberLbl".translate(context),
                  radius: 10,
                  disabledColor: const Color.fromARGB(255, 104, 102, 106)),
              const SizedBox(
                height: 36,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (Constant.emailAuthentication == '1') emailSignUp(),
                  if (Constant.googleAuthentication == "1" ||
                      Constant.appleAuthentication == "1")
                    googleAndAppleAuth(),
                  const SizedBox(
                    height: 24,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("alreadyHaveAcc".translate(context))
                          .color(context.color.textColorDark.brighten(50)),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget googleAndAppleAuth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (Constant.googleAuthentication == "1")
          UiUtils.buildButton(context,
              outerPadding: EdgeInsets.symmetric(vertical: 6.0),
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
          UiUtils.buildButton(context,
              prefixWidget: Padding(
                padding: EdgeInsetsDirectional.only(end: 10.0),
                child: const FaIcon(
                  FontAwesomeIcons.apple,
                  size: 22,
                  color: textDarkColor,
                ),
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
                payload: AppleLoginPayload(intent: AuthenticationIntent.signUp),
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

  Widget otpInput() {
    return Center(
        child: PinFieldAutoFill(
            key: _otpFieldKey,
            decoration: UnderlineDecoration(
              textStyle:
                  TextStyle(fontSize: 20, color: context.color.textColorDark),
              colorBuilder: FixedColorBuilder(context.color.territoryColor),
            ),
            currentCode: otp,
            codeLength: 6,
            onCodeChanged: (String? code) {
              otp = code;
              print(
                  "OTP changed: $otp"); // Log the OTP value to confirm it updates
            },
            onCodeSubmitted: (String code) {
              otp = code;
            }));
  }

  Widget verifyOTPWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: sidePadding),
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
                color: context.color.forthColor.withValues(alpha: 0.102),
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
          Text("signInWithMob".translate(context))
              .size(context.font.extraLarge),
          const SizedBox(
            height: 8,
          ),
          Row(
            children: [
              Text("+${phoneLoginPayload.countryCode}\t${phoneLoginPayload.phoneNumber}")
                  .size(context.font.large),
              const SizedBox(
                width: 5,
              ),
              InkWell(
                  child: Text("change".translate(context))
                      .underline()
                      .color(context.color.territoryColor)
                      .size(context.font.large),
                  onTap: () {
                    _cancelOtpFlow();
                    Navigator.pop(context);
                  }),
            ],
          ),
          const SizedBox(
            height: 24,
          ),
          otpInput(),
          /* CustomTextFormField(
              controller: _otpController,
              keyboard: TextInputType.number,
              hintText: "enterOTPHere".translate(context),
              //maxLength: 6,
              validator: CustomTextFieldValidator.otpSix),*/
          const SizedBox(
            height: 8,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: MaterialButton(
              onPressed: () {
                _resetOtp(rebuild: false);
                _isOtpFlowActive = true;
                context.read<AuthenticationCubit>().setData(
                      payload: phoneLoginPayload,
                      type: AuthenticationType.phone,
                    );
                context.read<AuthenticationCubit>().verify();
                setState(() {});
              },
              child: Text("resendOTP".translate(context))
                  .color(context.color.textColorDark.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(
            height: 19,
          ),
          UiUtils.buildButton(
            context,
            onPressed: () {
              if (!_isOtpFlowActive) return;
              if (context.read<AuthenticationCubit>().state
                  is AuthenticationInProcess) return;
              // otp is populated by PinFieldAutoFill, not _otpController
              final enteredOtp = otp?.trim() ?? "";
              if (enteredOtp.length < 6) {
                HelperUtils.showSnackBarMessage(
                    context, "pleaseEnterSixDigits".translate(context));
              } else {
                phoneLoginPayload.setOTP(enteredOtp);
                context.read<AuthenticationCubit>().authenticate();
              }
            },
            buttonTitle: "signIn".translate(context),
            radius: 8,
            disabled: !_isOtpFlowActive ||
                context.watch<AuthenticationCubit>().state
                    is AuthenticationInProcess,
          ),
        ],
      ),
    );
  }
}
