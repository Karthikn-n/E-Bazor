import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class ChooseOtpMethodScreen extends StatefulWidget {
  final String phoneNumber;

  const ChooseOtpMethodScreen({
    super.key,
    required this.phoneNumber,
  });

  static Route route(RouteSettings routeSettings) {
    final args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ChooseOtpMethodScreen(
        phoneNumber: (args?['phoneNumber'] as String?) ?? "",
      ),
    );
  }

  @override
  State<ChooseOtpMethodScreen> createState() => _ChooseOtpMethodScreenState();
}

class _ChooseOtpMethodScreenState extends State<ChooseOtpMethodScreen> {
  bool _isLoading = false;

  Future<void> _sendOtpViaWhatsApp() async {
    setState(() => _isLoading = true);
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
        final msg = response['message']?.toString() ?? "Failed to send OTP";
        HelperUtils.showSnackBarMessage(context, msg, type: MessageType.error);
        return;
      }

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          Routes.confirmPhoneNumberScreen,
          arguments: {
            'phoneNumber': widget.phoneNumber,
            'sid': sid,
            'channel': 'WhatsApp',
          },
        );
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Error sending OTP: $e",
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            "Choose OTP Method",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            children: [
              const SizedBox(height: 30),

              // Illustration Graphic with Shield & Lock
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 70,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        ),
                      ),
                      Positioned(
                        top: 22,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Title matching Screenshot 3
              Text(
                "Choose OTP Method",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 14),

              // Subtitle with highlighted phone number
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14.5,
                    color: context.color.textLightColor,
                    height: 1.45,
                  ),
                  children: [
                    const TextSpan(text: "A verification code will be sent to "),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626), // Red accent
                      ),
                    ),
                    const TextSpan(
                      text: ". Please select your verification method.",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Option 1: WhatsApp Button (Active)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: context.color.secondaryColor,
                      ),
                      onPressed: _isLoading ? null : _sendOtpViaWhatsApp,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              color: Color(0xFF22C55E),
                              size: 20,
                            ),
                      label: Text(
                        "WhatsApp",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Option 2: SMS Button (Hidden as requested: "there only show the whatsapp option for now (add sms but hide that)")
                  /*
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: context.color.borderColor,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: context.color.secondaryColor,
                      ),
                      onPressed: null, // Disabled / Hidden
                      icon: const Icon(
                        Icons.message_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      label: const Text(
                        "SMS",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  */
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
