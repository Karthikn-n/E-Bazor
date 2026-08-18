import 'dart:async';
import 'dart:io';

import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/data/cubits/auth/login_cubit.dart';
import 'package:Ebozor/ui/screens/auth/sign_up/signup_auth_listener.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String username;
  final String email;
  final String password;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.username,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  static const _emailChannel = MethodChannel('com.app.ebozor/email');
  Timer? _pollTimer;
  Timer? _resendTimer;
  bool _isSending = true;
  bool _isChecking = false;
  bool _isVerified = false;
  int _resendSeconds = 0;
  String _statusMessage = 'Sending verification email...';

  @override
  void initState() {
    super.initState();
    HiveUtils.setEmailVerificationPending(true);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendVerificationEmail();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _checkVerification(),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerification();
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_isSending && _statusMessage != 'Sending verification email...') {
      return;
    }
    if (mounted) {
      setState(() {
        _isSending = true;
        _statusMessage = 'Sending verification email...';
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const AuthenticationFlowException('authentication-failed');
      }
      await user.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Verification email sent to ${widget.email}. Check spam or junk too.';
      });
      _startResendCooldown();
    } catch (error) {
      if (!mounted) return;
      final message = authenticationErrorMessage(error);
      setState(() {
        _statusMessage = message.isEmpty
            ? 'Could not send the verification email. Please try again.'
            : message;
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _checkVerification() async {
    if (_isChecking || _isVerified) return;
    if (mounted) setState(() => _isChecking = true);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      if (FirebaseAuth.instance.currentUser?.emailVerified != true ||
          !mounted) {
        return;
      }

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: widget.email.trim(),
        password: widget.password,
      );
      await credential.user?.updateDisplayName(widget.username.trim());
      await credential.user?.reload();
      if (!mounted) return;

      _pollTimer?.cancel();
      setState(() {
        _isVerified = true;
        _statusMessage = 'Email verified. Setting up your profile...';
      });
      context.read<LoginCubit>().login(
            firebaseUserId: FirebaseAuth.instance.currentUser!.uid,
            type: AuthenticationType.email.name,
            credential: credential,
          );
    } catch (error) {
      if (mounted) {
        final message = authenticationErrorMessage(error);
        setState(() {
          _statusMessage = message.isEmpty
              ? 'Could not check verification. Please try again.'
              : message;
        });
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.backgroundColor,
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: context.color.backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        backgroundColor: context.color.backgroundColor,
        body: SafeArea(
          child: SignupAuthListener(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: SvgPicture.asset(AppIcons.verificationMail)),
                  Text('Verify your email')
                      .size(context.font.extraLarge)
                      .bold(weight: FontWeight.w600),
                  const SizedBox(height: 12),
                  Text(_statusMessage).centerAlign(),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.amber.shade900),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Can’t find the email? Check your Spam or Junk folder.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  MaterialButton(
                    onPressed: _isVerified ? null : _openEmailApp,
                    minWidth: double.infinity,
                    height: 46,
                    color: context.color.territoryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Check Email').color(context.color.buttonColor),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isSending || _resendSeconds > 0
                        ? null
                        : _sendVerificationEmail,
                    child: Text(
                      _resendSeconds > 0
                          ? 'Resend available in ${_resendSeconds}s'
                          : 'Resend verification email',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEmailApp() async {
    try {
      if (Platform.isAndroid) {
        await _emailChannel.invokeMethod<bool>('openInbox');
        return;
      }

      for (final inboxUri in <Uri>[
        Uri.parse('googlegmail://'),
        Uri.parse('message://'),
      ]) {
        if (await launchUrl(inboxUri, mode: LaunchMode.externalApplication)) {
          return;
        }
      }
    } catch (_) {
      if (!mounted) return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email app is available.')),
      );
    }
  }
}
