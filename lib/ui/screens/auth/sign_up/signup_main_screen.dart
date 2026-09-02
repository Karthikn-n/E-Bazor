import 'dart:async';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:device_region/device_region.dart';
import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/custom_text_form_field.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/utils/log_exporter.dart';
import 'package:Ebozor/ui/screens/auth/sign_up/signup_auth_listener.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SignUpMainScreen extends StatefulWidget {
  const SignUpMainScreen({super.key});

  @override
  State<SignUpMainScreen> createState() => LoginScreenState();

  static BlurredRouter route(RouteSettings routeSettings) {
    return BlurredRouter(builder: (_) => SignUpMainScreen());
  }
}

class LoginScreenState extends State<SignUpMainScreen> {
  final TextEditingController emailMobileTextController =
      TextEditingController();
  String? phone, countryCode, countryName, flagEmoji;

  Timer? timer;
  late Size size;
  CountryService countryCodeService = CountryService();
  bool isLoginButtonDisabled = true;
  bool isMobileNumberField = false;
  String numberOrEmail = "";
  final _formKey = GlobalKey<FormState>();
  final FocusNode _emailMobileFocusNode = FocusNode();

  late PhoneLoginPayload phoneLoginPayload = PhoneLoginPayload(
      emailMobileTextController.text, countryCode!,
      intent: AuthenticationIntent.signUp);
  bool isBack = false;

  @override
  void initState() {
    super.initState();

    context.read<AuthenticationCubit>().init();
    context.read<FetchSystemSettingsCubit>().fetchSettings();
    context.read<AuthenticationCubit>().listen((MLoginState state) {
      if (state is MOtpSendInProgress) {
        if (mounted) Widgets.showLoader(context);
      }

      if (state is MVerificationPending) {
        if (mounted) {
          Widgets.hideLoder(context);
          setState(() {});
        }
      }

      if (state is MFail) {
        if (context.read<AuthenticationCubit>().state
            is AuthenticationInProcess) {
          return;
        }
        if (mounted) {
          // Always show a user-friendly message — never the raw Firebase text
          final err = state.error;
          String friendlyMsg;
          if (err is FirebaseAuthException) {
            switch (err.code) {
              case 'invalid-phone-number':
              case 'missing-phone-number':
                friendlyMsg = "pleaseEnterValidPhoneNumber".translate(context);
                break;
              case 'too-many-requests':
                friendlyMsg = "tooManyRequests".translate(context);
                break;
              case 'network-request-failed':
                friendlyMsg = "noInternet".translate(context);
                break;
              default:
                friendlyMsg = "pleaseEnterValidPhoneNumber".translate(context);
            }
          } else {
            friendlyMsg = "pleaseEnterValidPhoneNumber".translate(context);
          }
          HelperUtils.showSnackBarMessage(context, friendlyMsg,
              type: MessageType.error);
        }
      }
      if (state is MSuccess) {
        // Widgets.hideLoder(context);
      }
    });
    getSimCountry().then((value) {
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

  @override
  void dispose() {
    if (timer != null) {
      timer!.cancel();
    }

    emailMobileTextController.dispose();
    _emailMobileFocusNode.dispose();

    super.dispose();
  }

  void _onTapContinue() {
    if (isMobileNumberField) {
      final number = emailMobileTextController.text.toString().trim();
      final code = countryCode ?? "";

      final cleanCode = code.replaceAll('+', '');
      Navigator.pushNamed(context, Routes.mobileSignUp, arguments: {
        "mobile": number,
        "countryCode": cleanCode,
      });
    } else {
      final email = emailMobileTextController.text.toString().trim();
      Navigator.pushNamed(context, Routes.signup,
          arguments: {"emailId": email});
    }
  }

  Future<void> sendVerificationCode() async {
    /*  context
        .read<AuthenticationCubit>()
        .setData(payload: phoneLoginPayload, type: AuthenticationType.phone);
    context.read<AuthenticationCubit>().verify();

    setState(() {});*/

    final form = _formKey.currentState;

    if (form == null) return;
    form.save();
    //checkbox value should be 1 before Login/SignUp
    if (form.validate()) {
      _onTapContinue();

      // firebaseLoginProcess();
    }
    // showSnackBar( UiUtils.getTranslatedLabel(context, "acceptPolicy"), context);
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
              setState(() {
                isBack = true;
              });
              return;
            },
            child: AnnotatedRegion(
              value: SystemUiOverlayStyle(
                statusBarColor: context.color.backgroundColor,
              ),
              child: Scaffold(
                backgroundColor: Colors.white,
                bottomNavigationBar: termAndPolicyTxt(),
                body: SignupAuthListener(
                  child: Builder(builder: (context) {
                    return Form(
                      key: _formKey,
                      child: buildLoginWidget(),
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

  Widget mobileAndEmailSignUp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("signUpToeClassify".translate(context))
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () => LogExporter.exportAndShareLogs(context),
                child: Text("welcome".translate(context))
                    .size(context.font.extraLarge)
                    .color(context.color.textDefaultColor),
              ),
              const SizedBox(
                height: 8,
              ),
              if (Constant.mobileAuthentication == "1" ||
                  Constant.emailAuthentication == "1")
                mobileAndEmailSignUp(),
              const SizedBox(
                height: 68,
              ),
              if (Constant.googleAuthentication == "1" ||
                  Constant.appleAuthentication == "1")
                googleAndAppleSignUp(),
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
        ),
      ),
    );
  }

  Widget googleAndAppleSignUp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (Constant.googleAuthentication == "1")
              //////////////////////////

              // continue with google
              UiUtils.buildButton(context,
                  prefixWidget: Padding(
                    padding: EdgeInsetsDirectional.only(end: 10.0),
                    child: UiUtils.getSvg(AppIcons.googleIcon,
                        width: 22, height: 22),
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
                        GoogleLoginPayload(intent: AuthenticationIntent.signUp),
                    type: AuthenticationType.google);
                context.read<AuthenticationCubit>().authenticate();
              },
                  radius: 8,
                  height: 46,
                  buttonTitle: "continueWithGoogle".translate(context)),

//apple login
            const SizedBox(
              height: 12,
            ),
            if (Constant.appleAuthentication == "1" && Platform.isIOS)

              //contiunue with apple
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
            const SizedBox(
              height: 24,
            ),
            /////
          ],
        ),
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
}
