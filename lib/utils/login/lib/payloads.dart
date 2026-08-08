abstract class LoginPayload {}

enum AuthenticationIntent { signIn, signUp }

class MultiLoginPayload {
  final Map<String, LoginPayload> payloads;

  MultiLoginPayload(this.payloads);
}

enum EmailLoginType { login, signup }

class EmailLoginPayload extends LoginPayload {
  final String email;
  final String password;
  final EmailLoginType type;
  bool recoveredUnverifiedAccount = false;

  EmailLoginPayload(
      {required this.email, required this.password, required this.type});
}

class GoogleLoginPayload extends LoginPayload {
  final AuthenticationIntent intent;

  GoogleLoginPayload({required this.intent});
}

class AppleLoginPayload extends LoginPayload {
  final AuthenticationIntent intent;

  AppleLoginPayload({required this.intent});
}

class PhoneLoginPayload extends LoginPayload {
  final String phoneNumber;
  final String countryCode;
  final AuthenticationIntent intent;
  String? otp;

  PhoneLoginPayload(this.phoneNumber, this.countryCode, {required this.intent});

  void setOTP(String value) {
    otp = value;
  }

  String? getOTP() {
    return otp;
  }
}
