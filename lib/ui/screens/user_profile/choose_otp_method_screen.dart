import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChooseOtpMethodScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationPurpose;
  final bool isFromSellerVerification;
  final VoidCallback? onVerified;

  const ChooseOtpMethodScreen({
    super.key,
    required this.phoneNumber,
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
      builder: (_) => ChooseOtpMethodScreen(
        phoneNumber: (args?['phoneNumber'] as String?) ?? '',
        verificationPurpose: purpose,
        isFromSellerVerification: isSeller,
        onVerified: args?['onVerified'] as VoidCallback?,
      ),
    );
  }

  @override
  State<ChooseOtpMethodScreen> createState() => _ChooseOtpMethodScreenState();
}

class _ChooseOtpMethodScreenState extends State<ChooseOtpMethodScreen> {
  late final TextEditingController _phoneController;
  late String _countryCode;
  String _flagEmoji = "🇦🇪";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initPhone();
  }

  void _initPhone() {
    String initial = widget.phoneNumber.trim();
    if (initial.isEmpty) {
      initial = HiveUtils.getUserDetails().mobile?.trim() ?? "";
    }

    if (initial.startsWith("+91")) {
      _countryCode = "+91";
      _flagEmoji = "🇮🇳";
      _phoneController = TextEditingController(text: initial.substring(3));
    } else if (initial.startsWith("+971")) {
      _countryCode = "+971";
      _flagEmoji = "🇦🇪";
      _phoneController = TextEditingController(text: initial.substring(4));
    } else if (initial.startsWith("+")) {
      _countryCode =
          initial.substring(0, initial.length > 4 ? 4 : initial.length);
      _phoneController = TextEditingController(
          text: initial.substring(initial.length > 4 ? 4 : 0));
    } else {
      _countryCode = '+${Constant.defaultCountryCode.replaceAll('+', '')}';
      _phoneController = TextEditingController(text: initial);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    String cleanPhone =
        _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    String cleanCode = _countryCode.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (!cleanCode.startsWith('+')) {
      cleanCode = '+$cleanCode';
    }
    final codeDigits = cleanCode.replaceAll('+', '');
    if (cleanPhone.startsWith(codeDigits)) {
      cleanPhone = cleanPhone.substring(codeDigits.length);
    }
    return '$cleanCode$cleanPhone';
  }

  void _selectCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        backgroundColor: context.color.secondaryColor,
        textStyle: TextStyle(color: context.color.textDefaultColor),
      ),
      onSelect: (country) {
        setState(() {
          _countryCode = '+${country.phoneCode}';
          _flagEmoji = country.flagEmoji;
        });
      },
    );
  }

  Future<void> _sendFirebaseOtp() async {
    
    final localNumber =
        _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (localNumber.length < 6) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please enter a valid phone number',
        type: MessageType.warning,
      );
      return;
    }

    final targetPhone = _fullPhoneNumber;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: targetPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // If auto-verified on Android, handled seamlessly
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            HelperUtils.showSnackBarMessage(
              context,
              e.message ?? "SMS Verification failed (${e.code})",
              type: MessageType.error,
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) async {
          if (!mounted) return;
          setState(() => _isLoading = false);

          final verified = await Navigator.pushNamed(
            context,
            Routes.confirmPhoneNumberScreen,
            arguments: {
              'phoneNumber': targetPhone,
              'verificationId': verificationId,
              'resendToken': resendToken,
              'channel': 'SMS',
              'verificationPurpose': widget.verificationPurpose,
              'isFromSellerVerification': widget.isFromSellerVerification,
              'onVerified': widget.onVerified,
            },
          );

          if (mounted && verified == true) {
            if (widget.isFromSellerVerification) {
              Navigator.pushReplacementNamed(
                context,
                Routes.sellerVerificationScreen,
                arguments: {'isResubmitted': false},
              );
            } else {
              Navigator.pop(context, true);
            }
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        HelperUtils.showSnackBarMessage(
          context,
          'Error sending SMS OTP: $error',
          type: MessageType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.secondaryColor,
        appBar: AppBar(
          backgroundColor: context.color.secondaryColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: context.color.textDefaultColor),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Text(
            'Confirm Phone Number',
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              children: [
                UiUtils.getSvg(AppIcons.safety, width: 120, height: 120),
                const SizedBox(height: 20),
                Text(
                  'Safety first',
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'To keep everyone safe on Ebozor, only phone-verified users can connect with sellers and get verified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.color.textLightColor,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),

                // Phone Input Tile
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _selectCountry,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Text(_flagEmoji,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                              Text(
                                _countryCode,
                                style: TextStyle(
                                  color: context.color.textDefaultColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: context.color.textLightColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 28,
                        width: 1,
                        color: context.color.borderColor,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            fontSize: 15,
                            color: context.color.textDefaultColor,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            hintText: 'Enter mobile number',
                            hintStyle: TextStyle(
                              color: context.color.textLightColor
                                  .withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // Send Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendFirebaseOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.color.territoryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: context.color.textLightColor
                          .withValues(alpha: 0.15),
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
                            'Send verification code',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'Need help? Please contact our ',
                      style: TextStyle(
                        color: context.color.textLightColor,
                        fontSize: 12.5,
                      ),
                    ),
                    InkWell(
                      onTap: () =>
                          Navigator.pushNamed(context, Routes.contactUs),
                      child: const Text(
                        'Customer Support',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 12.5,
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
      ),
    );
  }
}
