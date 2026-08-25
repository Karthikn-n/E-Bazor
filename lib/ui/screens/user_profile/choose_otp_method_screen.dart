import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ChooseOtpMethodScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationPurpose;
  final VoidCallback? onVerified;

  const ChooseOtpMethodScreen({
    super.key,
    required this.phoneNumber,
    this.verificationPurpose = 'updatePhone',
    this.onVerified,
  });

  static Route route(RouteSettings routeSettings) {
    final args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ChooseOtpMethodScreen(
        phoneNumber: (args?['phoneNumber'] as String?) ?? '',
        verificationPurpose:
            (args?['verificationPurpose'] as String?) ?? 'updatePhone',
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
  bool _isLoading = false;
  bool _whatsAppSelected = false;

  @override
  void initState() {
    super.initState();
    _countryCode = '+${Constant.defaultCountryCode.replaceAll('+', '')}';
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    final localNumber =
        _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(
              RegExp(r'^0+'),
              '',
            );
    return '${_countryCode.replaceAll(' ', '')}$localNumber';
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
        setState(() => _countryCode = '+${country.phoneCode}');
      },
    );
  }

  Future<void> _sendOtpViaWhatsApp() async {
    final localNumber = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (localNumber.length < 6) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please enter a valid phone number',
        type: MessageType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Api.post(
        url: Api.sendOtpApi,
        parameter: {
          'number': _fullPhoneNumber,
          'channel': 'whatsapp',
          'method': 'whatsapp',
        },
      );

      if (response['error'] == true) {
        final message = response['message']?.toString() ?? 'Failed to send OTP';
        if (mounted) {
          HelperUtils.showSnackBarMessage(
            context,
            message,
            type: MessageType.error,
          );
        }
        return;
      }

      var sid = '';
      if (response['data'] is Map) {
        sid = response['data']['sid']?.toString() ??
            response['data']['id']?.toString() ??
            '';
      } else if (response['data'] is String) {
        sid = response['data'].toString();
      }
      sid = sid.isNotEmpty ? sid : response['sid']?.toString() ?? '';

      if (!mounted) return;
      final verified = await Navigator.pushNamed(
        context,
        Routes.confirmPhoneNumberScreen,
        arguments: {
          'phoneNumber': _fullPhoneNumber,
          'sid': sid,
          'channel': 'WhatsApp',
          'verificationPurpose': widget.verificationPurpose,
          'onVerified': widget.onVerified,
        },
      );
      if (mounted && verified == true) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          'Error sending OTP: $error',
          type: MessageType.error,
        );
      }
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
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
            child: Column(
              children: [
                UiUtils.getSvg(AppIcons.safety, width: 132, height: 132),
                const SizedBox(height: 22),
                Text(
                  'Safety first',
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'To keep everyone safe on Ebozor, only phone-verified users can connect with sellers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.color.textLightColor,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.color.borderColor),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _selectCountry,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Text(
                                _countryCode,
                                style: TextStyle(
                                  color: context.color.textDefaultColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
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
                          color: context.color.borderColor),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            hintText: '5X XXX XXXX',
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Select how you would like to receive the code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.color.textDefaultColor,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.center,
                  child: ChoiceChip(
                    selected: _whatsAppSelected,
                    onSelected: (selected) {
                      setState(() => _whatsAppSelected = selected);
                    },
                    avatar: const FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: Color(0xFF16A34A),
                      size: 18,
                    ),
                    label: const Text('WhatsApp'),
                    backgroundColor: context.color.secondaryColor,
                    selectedColor: const Color(0xFFF0FDF4),
                    side: BorderSide(
                      color: _whatsAppSelected
                          ? const Color(0xFF16A34A)
                          : context.color.borderColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading || !_whatsAppSelected
                        ? null
                        : _sendOtpViaWhatsApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.color.territoryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          context.color.textLightColor.withValues(alpha: 0.15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
                            style: TextStyle(fontWeight: FontWeight.w700),
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
