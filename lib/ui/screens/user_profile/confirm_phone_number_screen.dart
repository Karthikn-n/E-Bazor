import 'dart:async';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/auth/auth_cubit.dart';
import 'package:Ebozor/data/repositories/job_repository.dart';
import 'package:Ebozor/data/repositories/seller/seller_verification_field_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sms_autofill/sms_autofill.dart';

class ConfirmPhoneNumberScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
  final String channel;
  final String verificationPurpose;
  final bool isFromSellerVerification;
  final VoidCallback? onVerified;

  const ConfirmPhoneNumberScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
    this.channel = "SMS",
    this.verificationPurpose = 'updatePhone',
    this.isFromSellerVerification = false,
    this.onVerified,
  });

  static Route route(RouteSettings routeSettings) {
    final args = routeSettings.arguments as Map?;
    final purpose =
        (args?['verificationPurpose'] as String?) ?? 'updatePhone';
    final isSeller = (args?['isFromSellerVerification'] as bool?) ??
        (purpose == 'sellerVerification');

    return BlurredRouter(
      builder: (_) => ConfirmPhoneNumberScreen(
        phoneNumber: (args?['phoneNumber'] as String?) ?? "",
        verificationId:
            (args?['verificationId'] ?? args?['sid'] ?? "") as String,
        resendToken: args?['resendToken'] as int?,
        channel: (args?['channel'] as String?) ?? "SMS",
        verificationPurpose: purpose,
        isFromSellerVerification: isSeller,
        onVerified: args?['onVerified'] as VoidCallback?,
      ),
    );
  }

  @override
  State<ConfirmPhoneNumberScreen> createState() =>
      _ConfirmPhoneNumberScreenState();
}

class _ConfirmPhoneNumberScreenState extends State<ConfirmPhoneNumberScreen>
    with CodeAutoFill {
  String _otpCode = "";
  late String _currentVerificationId;
  int? _resendToken;
  Timer? _timer;
  int _countdownSeconds = 56;
  bool _isVerifying = false;
  bool _isResending = false;
  final JobRepository _jobRepository = JobRepository();
  final SellerVerificationFieldRepository _verificationRepo =
      SellerVerificationFieldRepository();

  @override
  void codeUpdated() {
    if (code != null && code!.isNotEmpty) {
      setState(() {
        _otpCode = code!;
      });
      if (_otpCode.length == 6 && !_isVerifying) {
        _verifyOtp();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    listenForCode();
    _startCountdown();
  }

  @override
  void dispose() {
    cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdownSeconds = 56);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_countdownSeconds > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isResending = false);
            HelperUtils.showSnackBarMessage(
              context,
              e.message ?? "Could not resend SMS OTP",
              type: MessageType.error,
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _currentVerificationId = verificationId;
              _resendToken = resendToken;
              _isResending = false;
              _otpCode = "";
            });
            listenForCode();
            _startCountdown();
            HelperUtils.showSnackBarMessage(
              context,
              "SMS code resent successfully",
              type: MessageType.success,
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            _currentVerificationId = verificationId;
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isResending = false);
        HelperUtils.showSnackBarMessage(
          context,
          "Error resending OTP: $e",
          type: MessageType.error,
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;
    final code = _otpCode.trim();
    if (code.length < 6) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter the complete 6-digit verification code",
        type: MessageType.warning,
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // 1. Firebase Phone Auth Verification
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      // 2. Sync phone number with backend API
      try {
        await _verificationRepo.setUserPhoneNumber(
            phoneNumber: widget.phoneNumber);
      } catch (err) {
        debugPrint("Notice: setUserPhoneNumber API: $err");
      }

      // 3. Update local storage & AuthCubit profile
      await HiveUtils.setUserData({'mobile': widget.phoneNumber});

      try {
        final existingUser = HiveUtils.getUserDetails();
        await context.read<AuthCubit>().updateuserdata(
              context,
              name: existingUser.name,
              email: existingUser.email,
              address: existingUser.address?.toString(),
              fcmToken: existingUser.fcmId,
              notification: existingUser.notification?.toString(),
              mobile: widget.phoneNumber,
              countryCode: HiveUtils.getCountryCode(),
              personalDetail: existingUser.isPersonalDetailShow,
            );
        await _jobRepository.saveUserDetail({
          'mobile': widget.phoneNumber,
        });
      } catch (err) {
        debugPrint("Notice: profile sync after phone verification: $err");
      }

      widget.onVerified?.call();

      if (!mounted) return;

      HelperUtils.showSnackBarMessage(
        context,
        "Phone number verified successfully!",
        type: MessageType.success,
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Invalid or expired verification code",
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String timerText =
        "00:${_countdownSeconds.toString().padLeft(2, '0')} seconds";

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: AppBar(
          backgroundColor: context.color.secondaryColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.color.textDefaultColor,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            "Confirm Phone Number",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Center(
                child: UiUtils.getSvg(AppIcons.safety, width: 110, height: 110),
              ),
              const SizedBox(height: 20),
              Text(
                "You're almost verified",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.color.textLightColor,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: "Enter the 6-digit code sent to\n"),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const TextSpan(text: " via SMS"),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // PinFieldAutoFill: Supports multi-digit typing, pasting full OTP, and SMS auto-retrieval
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: PinFieldAutoFill(
                  currentCode: _otpCode,
                  codeLength: 6,
                  decoration: BoxLooseDecoration(
                    radius: const Radius.circular(10),
                    strokeWidth: 1.5,
                    strokeColorBuilder: PinListenColorBuilder(
                      context.color.territoryColor,
                      context.color.borderColor.withValues(alpha: 0.8),
                    ),
                    bgColorBuilder:
                        FixedColorBuilder(context.color.secondaryColor),
                    textStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                    gapSpace: 8,
                  ),
                  onCodeChanged: (val) {
                    _otpCode = val ?? "";
                    if (_otpCode.length == 6 && !_isVerifying) {
                      _verifyOtp();
                    }
                  },
                  onCodeSubmitted: (val) {
                    _otpCode = val;
                    if (_otpCode.length == 6 && !_isVerifying) {
                      _verifyOtp();
                    }
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.color.territoryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        context.color.textLightColor.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Verify & Continue",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Resend Timer / Button
              if (_countdownSeconds > 0)
                Text(
                  "Resend code in $timerText",
                  style: TextStyle(
                    fontSize: 13,
                    color: context.color.textLightColor,
                  ),
                )
              else
                TextButton(
                  onPressed: _isResending ? null : _resendOtp,
                  child: _isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Resend SMS Code",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: context.color.territoryColor,
                          ),
                        ),
                ),

              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? Contact ",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.color.textLightColor,
                    ),
                  ),
                  InkWell(
                    onTap: () =>
                        Navigator.pushNamed(context, Routes.contactUs),
                    child: const Text(
                      "Support",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
