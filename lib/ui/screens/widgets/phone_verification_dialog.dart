import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/user_profile/choose_otp_method_screen.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:flutter/material.dart';

/// Compatibility entry point for the old dialog call sites. Verification is
/// now a full-screen flow so it remains stable across OTP navigation.
class PhoneVerificationDialog extends StatelessWidget {
  final VoidCallback? onVerified;

  const PhoneVerificationDialog({super.key, this.onVerified});

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onVerified,
  }) async {
    final result = await Navigator.pushNamed(
      context,
      Routes.chooseOtpMethodScreen,
      arguments: {
        'phoneNumber': HiveUtils.getUserDetails().mobile ?? '',
        'verificationPurpose': 'verifyProfile',
        'onVerified': onVerified,
      },
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return ChooseOtpMethodScreen(
      phoneNumber: HiveUtils.getUserDetails().mobile ?? '',
      verificationPurpose: 'verifyProfile',
      onVerified: onVerified,
    );
  }
}
