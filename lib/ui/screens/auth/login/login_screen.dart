import 'dart:async';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:device_region/device_region.dart';
import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';

import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/data/cubits/auth/login_cubit.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:Ebozor/data/cubits/system/user_details.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/custom_text_form_field.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sms_autofill/sms_autofill.dart';

class LoginScreen extends StatefulWidget {
  final bool? isDeleteAccount;
  final bool? popToCurrent;

  const LoginScreen({super.key, this.isDeleteAccount, this.popToCurrent});

  @override
  State<LoginScreen> createState() => LoginScreenState();

  static BlurredRouter route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
        builder: (_) => LoginScreen(
              isDeleteAccount: args?['isDeleteAccount'],
              popToCurrent: args?['popToCurrent'],
            ));
  }
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailMobileTextController = TextEditingController(
      text: Constant.isDemoModeOn ? Constant.demoMobileNumber : "");
  bool isOtpSent = false;
  String? phone, otp, countryCode, countryName, flagEmoji;

  Timer? timer;
  late Size size;
  CountryService countryCodeService = CountryService();
  bool isLoginButtonDisabled = true;
  bool isMobileNumberField = false;
  String numberOrEmail = "";
  bool sendMailClicked = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailMobileFocusNode = FocusNode();

  bool isObscure = true;
  late PhoneLoginPayload phoneLoginPayload = PhoneLoginPayload(
      emailMobileTextController.text, countryCode!,
      intent: AuthenticationIntent.signIn);
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

    if (Constant.mobileAuthentication == "1") {
      if (Constant.isDemoModeOn) {
        isMobileNumberField = true;
        numberOrEmail = Constant.demoMobileNumber;
      }
    }
    getSignature();
    context.read<AuthenticationCubit>().init();
    context.read<FetchSystemSettingsCubit>().fetchSettings();
    context.read<AuthenticationCubit>().listen((MLoginState state) {
      if (!mounted || !Widgets.isCurrentOrLoaderOwner(context)) return;
      if (state is MOtpSendInProgress) {
        if (mounted) Widgets.showLoader(context);
      }

      if (state is MVerificationPending) {
        if (!_isOtpFlowActive) return;
        if (mounted) {
          Widgets.hideLoder(context);

          // Widgets.showLoader(context);

          isOtpSent = true;
          setState(() {});
          if (isMobileNumberField) {
            HelperUtils.showSnackBarMessage(
                context, "optsentsuccessflly".translate(context));
          }
        }
      }

      if (state is MFail) {
        if (!_isOtpFlowActive) return;
        if (context.read<AuthenticationCubit>().state
            is AuthenticationInProcess) {
          return;
        }
        //Widgets.hideLoder(context);

        if (!isOtpSent && isMobileNumberField) {
          Widgets.hideLoder(context);
        }

        if (isOtpSent && (otp?.trim().isEmpty ?? true)) {
          HelperUtils.showSnackBarMessage(context,
              "${"weSentCodeOnNumber".translate(context)}\t${emailMobileTextController.text}",
              type: MessageType.error);
        } else {
          final message = authenticationErrorMessage(state.error);
          if (message.isNotEmpty) {
            HelperUtils.showSnackBarMessage(context, message,
                type: MessageType.error);
          }
        }
      }
      if (state is MSuccess) {
        _isOtpFlowActive = false;
        // Widgets.hideLoder(context);
      }
    });
    getSimCountry().then((value) {
      if (!mounted) return;
      countryCode = value.phoneCode;

      flagEmoji = value.flagEmoji;
      setState(() {});
    });
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

  Future<void> getSignature() async {
    signature = await SmsAutoFill().getAppSignature;
    SmsAutoFill().listenForCode;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SmsAutoFill().unregisterListener();
    if (timer != null) {
      timer!.cancel();
    }

    _passwordController.dispose();
    _emailMobileFocusNode.dispose();
    emailMobileTextController.dispose();

    super.dispose();
  }

  void _onTapContinue() {
    AppLog.i('_onTapContinue: isMobileNumberField=$isMobileNumberField',
        name: 'LoginScreen');
    if (isMobileNumberField) {
      // isOtpSent = true;
      _resetOtp(rebuild: false);
      _isOtpFlowActive = true;
      phoneLoginPayload = PhoneLoginPayload(
          emailMobileTextController.text, countryCode!,
          intent: AuthenticationIntent.signIn);

      context
          .read<AuthenticationCubit>()
          .setData(payload: phoneLoginPayload, type: AuthenticationType.phone);
      context.read<AuthenticationCubit>().verify();

      setState(() {});
    } else {
      sendMailClicked = true;
      setState(() {});
    }
  }

  Future<void> sendVerificationCode() async {
    AppLog.i('sendVerificationCode initiated', name: 'LoginScreen');
    if (widget.isDeleteAccount ?? false) {
      _resetOtp(rebuild: false);
      _isOtpFlowActive = true;
      isOtpSent = true;

      context
          .read<AuthenticationCubit>()
          .setData(payload: phoneLoginPayload, type: AuthenticationType.phone);
      context.read<AuthenticationCubit>().verify();

      setState(() {});
    }
    final form = _formKey.currentState;

    if (form == null) return;
    form.save();
    //checkbox value should be 1 before Login/SignUp
    if (form.validate()) {
      if (widget.isDeleteAccount ?? false) {
      } else {
        _onTapContinue();
      }
    }
  }

  void setDemoOTP() {
    if (Constant.mobileAuthentication == "1") {
      if (emailMobileTextController.text == Constant.demoMobileNumber) {
        otp = Constant.demoModeOTP;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;

    setDemoOTP();

    /* if (emailMobileTextController.text == Constant.demoMobileNumber) {
      _otpController.text = Constant.demoModeOTP;
    } else {
      _otpController.text = "";
    }*/

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
              if (widget.isDeleteAccount ?? false) {
                Navigator.pop(context);
              } else {
                if (isOtpSent) {
                  _cancelOtpFlow();
                  setState(() {
                    isOtpSent = false;
                    isMobileNumberField = true;
                  });
                } else if (sendMailClicked) {
                  setState(() {
                    sendMailClicked = false;
                  });
                } else {
                  setState(() {
                    isBack = true;
                  });
                  return;
                }
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
                bottomNavigationBar: !isOtpSent && !sendMailClicked
                    ? termAndPolicyTxt()
                    : SizedBox.shrink(),
                body: BlocListener<LoginCubit, LoginState>(
                  listener: (context, state) async {
                    if (!Widgets.isCurrentOrLoaderOwner(context)) return;
                    AppLog.i('LoginCubit state: $state', name: 'LoginScreen');
                    if (state is LoginSuccess) {
                      AppLog.i(
                          'LoginSuccess. isProfileCompleted=${state.isProfileCompleted}',
                          name: 'LoginScreen');
                      await HiveUtils.setUserIsAuthenticated(true);
                      if (!context.mounted) return;
                      //GuestChecker.set(isGuest: false);
                      //context.read<AuthCubit>().updateFCM(context);

                      context
                          .read<UserDetailsCubit>()
                          .fill(HiveUtils.getUserDetails());
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.locationPermissionScreen, (route) => false);
                    }

                    if (state is LoginFailure) {
                      AppLog.e('LoginFailure: ${state.errorMessage}',
                          name: 'LoginScreen');
                      HelperUtils.showSnackBarMessage(context, "Login Failed");
                    }
                  },
                  child: BlocConsumer<AuthenticationCubit, AuthenticationState>(
                    listener: (context, state) {
                      if (!Widgets.isCurrentOrLoaderOwner(context)) return;
                      AppLog.i('AuthState: $state', name: 'LoginScreen');
                      if (state is AuthenticationSuccess) {
                        if (state.type == AuthenticationType.phone) {
                          _isOtpFlowActive = false;
                        }
                        Widgets.hideLoder(context);
                        AppLog.i('AuthSuccess type: ${state.type}',
                            name: 'LoginScreen');
                        if (state.type == AuthenticationType.email) {
                          //FirebaseAuth.instance.currentUser?.sendEmailVerification();
                          if (state.credential.user!.emailVerified) {
                            context.read<LoginCubit>().login(
                                phoneNumber: state.credential.user!.phoneNumber,
                                firebaseUserId: state.credential.user!.uid,
                                type: state.type.name,
                                credential: state.credential,
                                countryCode: null);
                          } else {
                            HelperUtils.showSnackBarMessage(
                                context, "Please Verify Your email first");
                          }
                        } else if (state.type == AuthenticationType.phone) {
                          context.read<LoginCubit>().login(
                              phoneNumber: (state.payload as PhoneLoginPayload)
                                  .phoneNumber,
                              firebaseUserId: state.credential.user!.uid,
                              type: state.type.name,
                              credential: state.credential,
                              countryCode:
                                  "+${(state.payload as PhoneLoginPayload).countryCode}");
                        } else {
                          context.read<LoginCubit>().login(
                              phoneNumber: state.credential.user!.phoneNumber,
                              firebaseUserId: state.credential.user!.uid,
                              type: state.type.name,
                              credential: state.credential,
                              countryCode: null);
                        }
                      }

                      if (state is AuthenticationFail) {
                        Widgets.hideLoder(context);

                        AppLog.e('AuthFail: ${state.error}',
                            name: 'LoginScreen');
                        final message = authenticationErrorMessage(state.error);
                        if (message.isNotEmpty) {
                          HelperUtils.showSnackBarMessage(context, message,
                              type: MessageType.error, messageDuration: 5);
                        }
                      }

                      if (state is AuthenticationInProcess) {
                        Widgets.showLoader(context);
                      }
                    },
                    builder: (context, state) {
                      return Builder(builder: (context) {
                        return Form(
                          key: _formKey,
                          child: isOtpSent
                              ? verifyOTPWidget()
                              : sendMailClicked
                                  ? enterPasswordWidget()
                                  : buildLoginWidget(),
                        );
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget mobileOrEmailLogin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("loginToeClassify".translate(context))
            .size(context.font.large)
            .color(
              context.color.textColorDark,
            ),
        const SizedBox(
          height: 24,
        ),
        CustomTextFormField(
            focusNode: _emailMobileFocusNode,
            controller: emailMobileTextController,
            fillColor: context.color.secondaryColor,
            borderColor: context.color.borderColor.darken(30),
            phoneCountryCode: isMobileNumberField ? countryCode : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            formaters: isMobileNumberField
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            onChange: (value) {
              bool isNumber = value.toString().contains(RegExp(r'^[0-9]+$'));

              final wasMobileNumberField = isMobileNumberField;
              isMobileNumberField =
                  Constant.mobileAuthentication == "1" ? isNumber : false;

              numberOrEmail = value;
              setState(() {});
              if (wasMobileNumberField != isMobileNumberField) {
                _refreshIdentifierKeyboard();
              }
            },
            keyboard: (Constant.mobileAuthentication == "1" &&
                    Constant.emailAuthentication == "1")
                ? (isMobileNumberField
                    ? TextInputType.phone
                    : TextInputType.emailAddress)
                : (Constant.mobileAuthentication == "1")
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
            validator: (Constant.mobileAuthentication == "1" &&
                    Constant.emailAuthentication == "1")
                ? (isMobileNumberField
                    ? CustomTextFieldValidator.phoneNumber
                    : CustomTextFieldValidator.email)
                : (Constant.mobileAuthentication == "1")
                    ? CustomTextFieldValidator.phoneNumber
                    : CustomTextFieldValidator.email,
            fixedPrefix: (isMobileNumberField)
                ? SizedBox(
                    width: 55,
                    child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: GestureDetector(
                          onTap: () {
                            showCountryCode();
                          },
                          child: Container(
                            // color: Colors.red,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 8),
                            child: Center(
                                child: Text("+$countryCode")
                                    .size(context.font.large)
                                    .centerAlign()),
                          ),
                        )),
                  )
                : null,
            hintText: (Constant.mobileAuthentication == "1" &&
                    Constant.emailAuthentication == "1")
                ? "emailOrPhone".translate(context)
                : (Constant.mobileAuthentication == "1")
                    ? "mobileNumberLbl".translate(context)
                    : "emailAddress".translate(context)),
        const SizedBox(
          height: 46,
        ),
        UiUtils.buildButton(context,
            onPressed: sendVerificationCode,
            buttonTitle: "continue".translate(context),
            radius: 10,
            disabled: numberOrEmail.isEmpty,
            disabledColor: const Color.fromARGB(255, 104, 102, 106)),
      ],
    );
  }

  void _refreshIdentifierKeyboard() {
    _emailMobileFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailMobileFocusNode.requestFocus();
    });
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
                      HiveUtils.setUserSkip();
                      HelperUtils.killPreviousPages(context, Routes.main,
                          {"from": "login", "isSkipped": true});
                      /*Navigator.pushReplacementNamed(
                        context,
                        Routes.main,
                        arguments: {
                          "from": "login",
                          "isSkipped": true,
                        },
                      );*/
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
              Text("welcomeback".translate(context))
                  .size(context.font.extraLarge)
                  .color(context.color.textDefaultColor),
              const SizedBox(
                height: 8,
              ),
              if (Constant.mobileAuthentication == "1" ||
                  Constant.emailAuthentication == "1")
                mobileOrEmailLogin(),
              const SizedBox(
                height: 68,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (Constant.mobileAuthentication == "1" ||
                      Constant.emailAuthentication == "1")
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("dontHaveAcc".translate(context))
                            .color(context.color.textColorDark.brighten(50)),
                        const SizedBox(
                          width: 12,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                                context, Routes.signupMainScreen);
                          },
                          child: Text("signUp".translate(context))
                              .underline()
                              .color(context.color.territoryColor),
                        )
                      ],
                    ),
                  const SizedBox(
                    height: 24,
                  ),
                  if (Constant.googleAuthentication == "1" ||
                      Constant.appleAuthentication == "1")
                    googleAndAppleLogin(),
                  if (Constant.mobileAuthentication == "0" ||
                      Constant.emailAuthentication == "0") ...[
                    if ((Constant.googleAuthentication == "1") ||
                        (Constant.appleAuthentication == "1" &&
                            Platform.isIOS)) ...[
                      const SizedBox(
                        height: 65,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("dontHaveAcc".translate(context))
                              .color(context.color.textColorDark.brighten(50)),
                          const SizedBox(
                            width: 12,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                  context, Routes.signupMainScreen);
                            },
                            child: Text("signUp".translate(context))
                                .underline()
                                .color(context.color.territoryColor),
                          )
                        ],
                      )
                    ],
                  ],
                ],
              ),
              /* const Spacer(),
              termAndPolicyTxt()*/
            ],
          ),
        ),
      ),
    );
  }

  //Apple login Widgets
  Widget googleAndAppleLogin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (Constant.mobileAuthentication == "1" ||
            Constant.emailAuthentication == "1")
          if ((Constant.googleAuthentication == "1") ||
              (Constant.appleAuthentication == "1" && Platform.isIOS))
            Text("orSignInWith".translate(context))
                .color(context.color.textDefaultColor),
        const SizedBox(
          height: 24,
        ),
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
                    GoogleLoginPayload(intent: AuthenticationIntent.signIn),
                type: AuthenticationType.google);
            context.read<AuthenticationCubit>().authenticate();
          },
              radius: 8,
              height: 46,
              buttonTitle: "continueWithGoogle".translate(context)),
        const SizedBox(
          height: 12,
        ),
        if (Constant.appleAuthentication == "1" && Platform.isIOS)
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
                      color:
                          context.color.textDefaultColor.withValues(alpha: 0.5))
                  : null,
              textColor: textDarkColor, onPressed: () {
            context.read<AuthenticationCubit>().setData(
                payload: AppleLoginPayload(intent: AuthenticationIntent.signIn),
                type: AuthenticationType.apple);
            context.read<AuthenticationCubit>().authenticate();
          },
              height: 46,
              radius: 8,
              buttonTitle: "continueWithApple".translate(context)),
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
            /*CustomTextButton(
                text:
                    Text("privacyPolicy".translate(context)).underline().color(context.color.teritoryColor).size(context.font.small),
                onPressed: () => Navigator.pushNamed(
                      context,
                      Routes.profileSettings,
                      arguments: {
                        'title': UiUtils.getTranslatedLabel(
                            context, "privacyPolicy"),
                        'param': Api.privacyPolicy
                      },
                    )),*/
          ]),
        ],
      ),
    );
  }

  Future<bool> onBackPress() {
    if (widget.isDeleteAccount ?? false) {
      Navigator.pop(context);
    } else {
      if (isOtpSent == true) {
        setState(() {
          isOtpSent = false;
        });
      } else {
        return Future.value(true);
      }
    }
    return Future.value(false);
  }

  void showCountryCode() {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      showPhoneCode: true,
      countryListTheme:
          CountryListThemeData(borderRadius: BorderRadius.circular(11)),
      onSelect: (Country value) {
        flagEmoji = value.flagEmoji;
        countryCode = value.phoneCode;
        setState(() {});
      },
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
                  HelperUtils.killPreviousPages(context, Routes.main,
                      {"from": "login", "isSkipped": true});
                  /*Navigator.pushReplacementNamed(
                    context,
                    Routes.main,
                    arguments: {
                      "from": "login",
                      "isSkipped": true,
                    },
                  );*/
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
                    setState(() {
                      isOtpSent = false;
                      isMobileNumberField = true;
                    });
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
              final enteredOtp = otp?.trim() ?? '';
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

  Widget enterPasswordWidget() {
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
                  HelperUtils.killPreviousPages(context, Routes.main,
                      {"from": "login", "isSkipped": true});
                  /* Navigator.pushReplacementNamed(
                    context,
                    Routes.main,
                    arguments: {
                      "from": "login",
                      "isSkipped": true,
                    },
                  );*/
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
          Text("signInWithEmail".translate(context))
              .size(context.font.extraLarge),
          const SizedBox(
            height: 8,
          ),
          Row(
            children: [
              Text(emailMobileTextController.text).size(context.font.large),
              const SizedBox(
                width: 5,
              ),
              InkWell(
                  child: Text("change".translate(context))
                      .underline()
                      .color(context.color.territoryColor)
                      .size(context.font.large),
                  onTap: () => Navigator.pushNamed(context, Routes.login)),
            ],
          ),
          const SizedBox(
            height: 24,
          ),
          CustomTextFormField(
            hintText: "${"password".translate(context)}*",
            controller: _passwordController,
            obscureText: isObscure,
            suffix: IconButton(
              onPressed: () {
                isObscure = !isObscure;
                setState(() {});
              },
              icon: Icon(
                !isObscure ? Icons.visibility : Icons.visibility_off,
                color: context.color.textColorDark.withValues(alpha: 0.3),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: MaterialButton(
              onPressed: () {
                Navigator.pushNamed(context, Routes.forgotPassword);
              },
              child: Text("${"forgotPassword".translate(context)}?")
                  .color(context.color.textLightColor)
                  .size(context.font.normal),
            ),
          ),
          const SizedBox(
            height: 19,
          ),
          UiUtils.buildButton(
            context,
            onPressed: () {
              context.read<AuthenticationCubit>().setData(
                  payload: EmailLoginPayload(
                      email: emailMobileTextController.text,
                      password: _passwordController.text,
                      type: EmailLoginType.login),
                  type: AuthenticationType.email);
              context.read<AuthenticationCubit>().authenticate();
            },
            buttonTitle: "signIn".translate(context),
            radius: 8,
          ),
        ],
      ),
    );
  }
}
