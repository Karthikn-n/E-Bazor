import 'dart:async';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailSentScreen extends StatefulWidget {
  final String email;

  const EmailSentScreen({super.key, required this.email});

  static void show(BuildContext context, {required String email}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EmailSentScreen(email: email),
    );
  }

  @override
  State<EmailSentScreen> createState() => _EmailSentScreenState();
}

class _EmailSentScreenState extends State<EmailSentScreen> {
  Timer? _timer;
  int _remainingSeconds = 895; // ~14:55
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} seconds";
  }

  Future<void> _resendEmail() async {
    if (_isResending) return;
    setState(() {
      _isResending = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Password reset email resent successfully!",
          type: MessageType.success,
        );
        setState(() {
          _remainingSeconds = 900;
          _isResending = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          e.toString(),
          type: MessageType.error,
        );
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Close Button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 24,
                  color: context.color.textDefaultColor.withValues(alpha: 0.7),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 10),

            // Email Icon Container
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FD),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(
                  Icons.mail_outline_rounded,
                  color: Color(0xFF2563EB),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header Title
            Text(
              "An email is on the way",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              "To change your password, please confirm your identity by clicking the verification link we've sent to your email.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: context.color.textDefaultColor.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 18),

            // 1 Hour Expiry Notice
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: context.color.textLightColor,
                ),
                const SizedBox(width: 6),
                Text(
                  "Please note that the link expires after 1 hour",
                  style: TextStyle(
                    fontSize: 13,
                    color: context.color.textLightColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Prompt
            Text(
              "Didn't receive? Check your spam/junk.\nOtherwise click below.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: context.color.textDefaultColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),

            // Timer
            Text(
              _formatTimer(_remainingSeconds),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.color.textLightColor,
              ),
            ),
            const SizedBox(height: 16),

            // Resend Email Button
            SizedBox(
              width: 160,
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: context.color.borderColor.withValues(alpha: 0.8),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isResending ? null : _resendEmail,
                child: _isResending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        "Resend Email",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Contact Customer Support Link
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, Routes.contactUs);
              },
              child: const Text(
                "Contact Customer Support",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
