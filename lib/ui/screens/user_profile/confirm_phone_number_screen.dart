import 'dart:async';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:Ebozor/data/cubits/auth/auth_cubit.dart';
import 'package:Ebozor/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:Ebozor/data/repositories/job_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class ConfirmPhoneNumberScreen extends StatefulWidget {
  final String phoneNumber;
  final String sid;
  final String channel;
  final String verificationPurpose;
  final VoidCallback? onVerified;

  const ConfirmPhoneNumberScreen({
    super.key,
    required this.phoneNumber,
    required this.sid,
    this.channel = "WhatsApp",
    this.verificationPurpose = 'updatePhone',
    this.onVerified,
  });

  static Route route(RouteSettings routeSettings) {
    final args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ConfirmPhoneNumberScreen(
        phoneNumber: (args?['phoneNumber'] as String?) ?? "",
        sid: (args?['sid'] as String?) ?? "",
        channel: (args?['channel'] as String?) ?? "WhatsApp",
        verificationPurpose:
            (args?['verificationPurpose'] as String?) ?? 'updatePhone',
        onVerified: args?['onVerified'] as VoidCallback?,
      ),
    );
  }

  @override
  State<ConfirmPhoneNumberScreen> createState() =>
      _ConfirmPhoneNumberScreenState();
}

class _ConfirmPhoneNumberScreenState extends State<ConfirmPhoneNumberScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late String _currentSid;
  Timer? _timer;
  int _countdownSeconds = 56;
  bool _isVerifying = false;
  bool _isResending = false;
  final JobRepository _jobRepository = JobRepository();

  @override
  void initState() {
    super.initState();
    _currentSid = widget.sid;
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
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

  String get _otpCode => _otpControllers.map((c) => c.text.trim()).join();

  Future<void> _resendOtp() async {
    if (_countdownSeconds > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      final response = await Api.post(
        url: Api.sendOtpApi,
        parameter: {
          "number": widget.phoneNumber,
          "channel": "whatsapp",
          "method": "whatsapp",
        },
      );

      String sid = "";
      if (response['data'] != null && response['data'] is Map) {
        sid = response['data']['sid']?.toString() ??
            response['data']['id']?.toString() ??
            "";
      }
      if (sid.isEmpty) {
        sid = response['sid']?.toString() ?? "";
      }
      if (sid.isEmpty && response['data'] is String) {
        sid = response['data'].toString();
      }

      if (response['error'] == true) {
        final msg = response['message']?.toString() ?? "Failed to resend OTP";
        HelperUtils.showSnackBarMessage(context, msg, type: MessageType.error);
        return;
      }

      _currentSid = sid;
      for (var c in _otpControllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      _startCountdown();
      HelperUtils.showSnackBarMessage(
        context,
        "OTP resent successfully via WhatsApp",
        type: MessageType.success,
      );
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Error resending OTP: $e",
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode;
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
      final response = await Api.post(
        url: Api.verifyOtpApi,
        parameter: {
          if (_currentSid.isNotEmpty) "sid": _currentSid,
          "code": code,
          "number": widget.phoneNumber,
        },
      );

      if (response['error'] == true) {
        final msg = response['message']?.toString() ?? "Invalid OTP code";
        HelperUtils.showSnackBarMessage(context, msg, type: MessageType.error);
        return;
      }

      if (widget.verificationPurpose == 'updatePhone') {
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
      }

      final user = HiveUtils.getUserDetails();
      user.mobile = widget.phoneNumber;
      user.isVerified = 1;
      await HiveUtils.setUserData(user.toJson());

      try {
        context
            .read<FetchVerificationRequestsCubit>()
            .fetchVerificationRequests();
      } catch (_) {}
      widget.onVerified?.call();

      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Phone number verified and updated successfully!",
          type: MessageType.success,
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Verification error: $e",
        type: MessageType.error,
      );
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
              Icons.close_rounded,
              color: context.color.textDefaultColor,
              size: 24,
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // Shield Badge Graphic from Screenshot 2
              Center(
                child: UiUtils.getSvg(AppIcons.safety),
              ),

              const SizedBox(height: 24),

              // Title matching Screenshot 2
              Text(
                "You're almost verified",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14.5,
                    color: context.color.textLightColor,
                    height: 1.45,
                  ),
                  children: [
                    const TextSpan(text: "We sent a verification code to "),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626), // Red accent
                      ),
                    ),
                    TextSpan(
                      text:
                          " via ${widget.channel}. Please enter the OTP below:",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 6-box OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 46,
                    height: 54,
                    child: TextFormField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: "",
                        filled: true,
                        fillColor: context.color.secondaryColor,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.color.borderColor,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.color.borderColor,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.color.territoryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          if (index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else {
                            _focusNodes[index].unfocus();
                            _verifyOtp();
                          }
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 20),

              // Countdown Timer
              Text(
                timerText,
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.color.textLightColor,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 18),

              // Resend Code Header
              Text(
                "Resend code via",
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.color.textDefaultColor,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              // Resend Buttons (WhatsApp enabled, SMS hidden/disabled)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      side: BorderSide(
                        color: _countdownSeconds == 0
                            ? const Color(0xFF22C55E)
                            : context.color.borderColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: context.color.secondaryColor,
                    ),
                    onPressed: _countdownSeconds == 0 && !_isResending
                        ? _resendOtp
                        : null,
                    icon: _isResending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : FaIcon(
                            FontAwesomeIcons.whatsapp,
                            color: _countdownSeconds == 0
                                ? const Color(0xFF22C55E)
                                : Colors.grey,
                            size: 16,
                          ),
                    label: Text(
                      "WhatsApp",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: _countdownSeconds == 0
                            ? context.color.textDefaultColor
                            : Colors.grey,
                      ),
                    ),
                  ),

                  /*
                  const SizedBox(width: 12),
                  // SMS button hidden as requested
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      side: BorderSide(color: context.color.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.message_outlined, size: 16, color: Colors.grey),
                    label: const Text("SMS", style: TextStyle(color: Colors.grey)),
                  ),
                  */
                ],
              ),

              const SizedBox(height: 18),

              // Need help? Customer Support
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Need help? Please contact our ",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.color.textLightColor,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, Routes.faqsScreen);
                    },
                    child: const Text(
                      "Customer Support",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.color.territoryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isVerifying ? null : _verifyOtp,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Verify",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
