import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/utils/validator.dart';
import 'package:Ebozor/utils/login/google_login/google_login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('country-aware phone validation', () {
    test('accepts a valid UAE mobile number for UAE', () {
      expect(Validator.isValidPhoneNumber('501234567', '971'), isTrue);
    });

    test('accepts a valid Indian mobile number for India', () {
      expect(Validator.isValidPhoneNumber('9080803737', '+91'), isTrue);
    });

    test('rejects a UAE number with the wrong country code', () {
      expect(Validator.isValidPhoneNumber('501234567', '91'), isFalse);
    });

    test('rejects letters, punctuation, and impossible lengths', () {
      expect(Validator.isValidPhoneNumber('50-123-4567', '971'), isFalse);
      expect(Validator.isValidPhoneNumber('123', '971'), isFalse);
      expect(Validator.isValidPhoneNumber('5012345678901234', '971'), isFalse);
    });
  });

  group('authentication flow messages', () {
    test('Google cancellation is silent', () {
      expect(
        authenticationErrorMessage(const GoogleSignInCancelledException()),
        isEmpty,
      );
    });

    test('new login is reported as missing account', () {
      expect(
        authenticationErrorMessage(
          const AuthenticationFlowException('account-not-found'),
        ),
        'No account found. Please sign up first.',
      );
    });

    test('existing signup is reported as an existing account', () {
      expect(
        authenticationErrorMessage(
          const AuthenticationFlowException('account-already-exists'),
        ),
        'An account already exists. Please sign in instead.',
      );
    });

    test('masked Firebase login failure explains password and Google options',
        () {
      expect(
        authenticationErrorMessage(
          FirebaseAuthException(code: 'invalid-credential'),
        ),
        'No account matches these credentials. Check your email and password, or sign up first.',
      );
    });

    test('password reset result does not falsely guarantee email delivery', () {
      expect(passwordResetRequestMessage, contains('If this email has'));
      expect(passwordResetRequestMessage, contains('Continue with Google'));
      expect(passwordResetRequestMessage, isNot(contains('sent you')));
    });

    test('provider conflict directs an existing user to Google or recovery',
        () {
      expect(
        authenticationErrorMessage(
          FirebaseAuthException(
            code: 'account-exists-with-different-credential',
          ),
        ),
        'An account already exists for this email. Continue with Google if you registered with Google, or use Login/Forgot Password.',
      );
    });

    test('phone app-verification configuration error is actionable', () {
      expect(
        authenticationErrorMessage(
          FirebaseAuthException(code: 'missing-client-identifier'),
        ),
        contains('not configured'),
      );
    });
  });
}
