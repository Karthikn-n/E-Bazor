import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/custom_text_form_field.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static BlurredRouter route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const ForgotPasswordScreen(),
    );
  }

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _requestStatus;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestPasswordReset() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting || _formKey.currentState?.validate() != true) return;

    setState(() {
      _isSubmitting = true;
      _requestStatus = null;
    });

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (!mounted) return;
      setState(() => _requestStatus = passwordResetRequestMessage);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(
        context,
        authenticationErrorMessage(error),
        type: MessageType.error,
        messageDuration: 5,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: sidePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: FittedBox(
                  fit: BoxFit.none,
                  child: MaterialButton(
                    onPressed: () {
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
              Text("forgotPassword".translate(context))
                  .size(context.font.extraLarge),
              const SizedBox(
                height: 20,
              ),
              Text("forgotHeadingTxt".translate(context))
                  .size(context.font.large),
              const SizedBox(
                height: 8,
              ),
              Text("forgotSubHeadingTxt".translate(context))
                  .size(context.font.small)
                  .color(context.color.textLightColor),
              const SizedBox(
                height: 24,
              ),
              CustomTextFormField(
                  controller: _emailController,
                  keyboard: TextInputType.emailAddress,
                  hintText: "emailAddress".translate(context),
                  validator: CustomTextFieldValidator.email),
              const SizedBox(
                height: 25,
              ),
              UiUtils.buildButton(
                context,
                onPressed: _requestPasswordReset,
                isInProgress: _isSubmitting,
                buttonTitle: "submitBtnLbl".translate(context),
                radius: 8,
              ),
              if (_requestStatus != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_requestStatus!)
                      .size(context.font.small)
                      .color(context.color.textLightColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
