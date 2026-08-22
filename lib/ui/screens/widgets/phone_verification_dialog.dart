import 'dart:async';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum VerificationStep { phoneInput, otpInput, success }

class PhoneVerificationDialog extends StatefulWidget {
  final VoidCallback? onVerified;

  const PhoneVerificationDialog({super.key, this.onVerified});

  static Future<bool?> show(BuildContext context, {VoidCallback? onVerified}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => PhoneVerificationDialog(onVerified: onVerified),
    );
  }

  @override
  State<PhoneVerificationDialog> createState() => _PhoneVerificationDialogState();
}

class _PhoneVerificationDialogState extends State<PhoneVerificationDialog> {
  VerificationStep _currentStep = VerificationStep.phoneInput;

  // Phone input state
  late TextEditingController _phoneController;
  String _countryCode = Constant.defaultCountryCode; // e.g. "971" or "91"
  bool _isLoading = false;

  // OTP state
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  String _sid = "";
  int _resendCountdown = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    final user = HiveUtils.getUserDetails();
    String initialMobile = user.mobile ?? "";
    String initialCode = Constant.defaultCountryCode;
    _countryCode = initialCode;
    _phoneController = TextEditingController(text: initialMobile);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _resendCountdown = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _resendCountdown--;
          });
        }
      }
    });
  }

  void _selectCountry() {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        borderRadius: BorderRadius.circular(16),
        backgroundColor: context.color.secondaryColor,
        textStyle: TextStyle(color: context.color.textDefaultColor),
      ),
      onSelect: (Country country) {
        setState(() {
          _countryCode = country.phoneCode;
        });
      },
    );
  }

  String _cleanNumber() {
    String raw = _phoneController.text.trim();
    // Strip leading '+' if user typed it
    if (raw.startsWith('+')) raw = raw.substring(1);
    // Strip leading zeros
    raw = raw.replaceFirst(RegExp(r'^0+'), '');
    return raw;
  }

  String _getFullPhoneNumber() {
    String raw = _cleanNumber();
    String code = _countryCode.replaceAll("+", "").trim();
    if (raw.startsWith(code)) {
      return "+$raw";
    }
    return "+$code$raw";
  }

  Future<void> _sendOtp() async {
    final rawNumber = _cleanNumber();
    if (rawNumber.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a valid phone number",
        type: MessageType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullNumber = _getFullPhoneNumber();
      final response = await Api.post(
        url: Api.sendOtpApi,
        parameter: {
          "number": fullNumber,
        },
      );

      // Provider response handling (e.g. sid returned inside data or root)
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
        final msg = response['message']?.toString() ?? "Failed to send OTP";
        HelperUtils.showSnackBarMessage(context, msg, type: MessageType.error);
        return;
      }

      _sid = sid;
      _otpController.clear();
      _startResendTimer();

      if (mounted) {
        setState(() {
          _currentStep = VerificationStep.otpInput;
        });
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _otpFocusNode.requestFocus();
        });
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Failed to send OTP: $e",
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length < 4) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter the verification code",
        type: MessageType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullNumber = _getFullPhoneNumber();
      final response = await Api.post(
        url: Api.verifyOtpApi,
        parameter: {
          if (_sid.isNotEmpty) "sid": _sid,
          "code": code,
          "number": fullNumber,
        },
      );

      if (response['error'] == true) {
        final msg = response['message']?.toString() ?? "Invalid OTP code";
        HelperUtils.showSnackBarMessage(context, msg, type: MessageType.error);
        return;
      }

      // Success! Update local user state
      var user = HiveUtils.getUserDetails();
      user.isVerified = 1;
      user.mobile = _phoneController.text.trim();
      HiveUtils.setUserData(user.toJson());

      try {
        context.read<FetchVerificationRequestsCubit>().fetchVerificationRequests();
      } catch (_) {}

      widget.onVerified?.call();

      if (mounted) {
        setState(() {
          _currentStep = VerificationStep.success;
        });
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Verification failed: $e",
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Close 'X' Button at top right
            Positioned(
              top: 14,
              right: 14,
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: context.color.textLightColor,
                  size: 22,
                ),
                splashRadius: 18,
                onPressed: () => Navigator.pop(context, _currentStep == VerificationStep.success),
              ),
            ),

            // Main Modal Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildCurrentStepWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case VerificationStep.phoneInput:
        return _buildPhoneInputStep();
      case VerificationStep.otpInput:
        return _buildOtpInputStep();
      case VerificationStep.success:
        return _buildSuccessStep();
    }
  }

  // ================= STEP 1: PHONE INPUT =================
  Widget _buildPhoneInputStep() {
    return Column(
      key: const ValueKey('phone_step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top Shield Illustration
        _buildShieldIllustration(),
        const SizedBox(height: 22),

        // Title
        Text(
          "Safety first!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.color.textDefaultColor,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),

        // Subtitle
        Text(
          "Verify your phone number and enjoy connecting with more sellers.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: context.color.textLightColor,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 24),

        // Phone Input with Country Code Selector
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: context.color.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              // Country Picker Button
              InkWell(
                onTap: _selectCountry,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "+$_countryCode",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: context.color.textLightColor,
                      ),
                    ],
                  ),
                ),
              ),

              // Vertical Divider
              Container(
                width: 1,
                height: 26,
                color: context.color.borderColor.withValues(alpha: 0.8),
              ),

              // Number Input
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.color.textDefaultColor,
                  ),
                  decoration: InputDecoration(
                    hintText: "Phone number",
                    hintStyle: TextStyle(
                      fontSize: 14.5,
                      color: context.color.textLightColor.withValues(alpha: 0.7),
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Red "Send Verification Code" Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD31027),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.zero,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    "Send Verification Code",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Contact Customer Support Link
        InkWell(
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, Routes.contactUs);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Text(
              "Contact Customer Support.",
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= STEP 2: OTP INPUT =================
  Widget _buildOtpInputStep() {
    return Column(
      key: const ValueKey('otp_step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Shield with lock/key icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD31027).withValues(alpha: 0.1),
          ),
          child: const Center(
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 36,
              color: Color(0xFFD31027),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Title
        Text(
          "Enter Verification Code",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.color.textDefaultColor,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle with formatted phone
        Text(
          "We sent a verification code to\n${_getFullPhoneNumber()}",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            color: context.color.textLightColor,
          ),
        ),
        const SizedBox(height: 6),

        // Edit Phone Number link
        InkWell(
          onTap: () {
            setState(() {
              _currentStep = VerificationStep.phoneInput;
            });
          },
          child: Text(
            "Change phone number",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Clean OTP Input Field
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: context.color.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          child: TextField(
            controller: _otpController,
            focusNode: _otpFocusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: context.color.textDefaultColor,
            ),
            decoration: InputDecoration(
              hintText: "• • • • • •",
              hintStyle: TextStyle(
                fontSize: 18,
                letterSpacing: 6,
                color: context.color.textLightColor.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onSubmitted: (_) => _verifyOtp(),
          ),
        ),
        const SizedBox(height: 16),

        // Resend Timer / Button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive code? ",
              style: TextStyle(
                fontSize: 13,
                color: context.color.textLightColor,
              ),
            ),
            if (_resendCountdown > 0)
              Text(
                "Resend in ${_resendCountdown}s",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.color.territoryColor,
                ),
              )
            else
              InkWell(
                onTap: _isLoading ? null : _sendOtp,
                child: Text(
                  "Resend Code",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD31027),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // Verify Code Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD31027),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    "Verify Code",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ================= STEP 3: SUCCESS =================
  Widget _buildSuccessStep() {
    return Column(
      key: const ValueKey('success_step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        // Success Shield / Check Badge
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withValues(alpha: 0.12),
          ),
          child: const Center(
            child: Icon(
              Icons.verified_rounded,
              size: 48,
              color: Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Text(
          "You're Verified!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.color.textDefaultColor,
          ),
        ),
        const SizedBox(height: 10),

        // Subtitle
        Text(
          "Your phone number has been verified successfully. Your verified badge is now active across Ebazzor.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: context.color.textLightColor,
          ),
        ),
        const SizedBox(height: 26),

        // Done Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD31027),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "Done",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Shield Icon Illustration matching the mockup
  Widget _buildShieldIllustration() {
    return SizedBox(
      width: 120,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft clouds
          Positioned(
            top: 10,
            left: 4,
            child: Icon(
              Icons.cloud_rounded,
              size: 38,
              color: Colors.lightBlue.shade100.withValues(alpha: 0.7),
            ),
          ),
          Positioned(
            top: 24,
            right: 8,
            child: Icon(
              Icons.cloud_rounded,
              size: 32,
              color: Colors.lightBlue.shade100.withValues(alpha: 0.6),
            ),
          ),

          // Green Leaves Sprigs around shield
          Positioned(
            bottom: 4,
            left: 10,
            child: Transform.rotate(
              angle: -0.4,
              child: Icon(
                Icons.eco_rounded,
                size: 26,
                color: Colors.green.shade300,
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 10,
            child: Transform.rotate(
              angle: 0.4,
              child: Icon(
                Icons.eco_rounded,
                size: 26,
                color: Colors.green.shade300,
              ),
            ),
          ),

          // Main Shield
          Container(
            width: 76,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(38),
                topRight: Radius.circular(38),
                bottomLeft: Radius.circular(42),
                bottomRight: Radius.circular(42),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.blue.shade50,
                width: 2.0,
              ),
            ),
            child: Center(
              // Blue Circle with White Checkmark
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF3B82F6), // Vibrant Shield Blue
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
