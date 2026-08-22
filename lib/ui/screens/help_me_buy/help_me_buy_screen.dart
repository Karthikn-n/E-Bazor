import 'package:country_picker/country_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/utils/validator.dart';

class HelpMeBuyScreen extends StatefulWidget {
  const HelpMeBuyScreen({super.key});

  static Route route(RouteSettings settings) {
    return CupertinoPageRoute(
      builder: (context) => const HelpMeBuyScreen(),
    );
  }

  @override
  State<HelpMeBuyScreen> createState() => _HelpMeBuyScreenState();
}

class _HelpMeBuyScreenState extends State<HelpMeBuyScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String _phoneCountryCode = "971";
  String _phoneCountryFlag = "🇦🇪";
  String _selectedServiceType = "Car Buying Assistance";
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  final List<String> _serviceTypes = [
    "Car Buying Assistance",
    "Property Buying Assistance",
    "Inspection & Verification",
    "General Buying Help",
    "Finance & Consultation",
  ];

  @override
  void initState() {
    super.initState();
    final user = HiveUtils.getUserDetails();
    if (user.name != null && user.name!.isNotEmpty) {
      _nameController.text = user.name!;
    }
    if (user.email != null && user.email!.isNotEmpty) {
      _emailController.text = user.email!;
    }
    if (user.mobile != null && user.mobile!.isNotEmpty) {
      _phoneController.text = user.mobile!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _showCountryCodePicker() {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: context.color.secondaryColor,
        textStyle: TextStyle(color: context.color.textDefaultColor),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      onSelect: (country) {
        setState(() {
          _phoneCountryCode = country.phoneCode;
          _phoneCountryFlag = country.flagEmoji;
        });
      },
    );
  }

  Future<void> _submitHelpMeBuy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final phoneDigits = _phoneController.text.trim();
      final fullPhone = "+$_phoneCountryCode$phoneDigits";

      final response = await Api.post(
        url: Api.addHelpMeBuyApi,
        parameter: {
          "name": _nameController.text.trim(),
          "email": _emailController.text.trim(),
          "phone_no": fullPhone,
          "service_type": _selectedServiceType,
          "message": _messageController.text.trim(),
        },
      );

      if (response['error'] == true) {
        final msg = response['message']?.toString() ?? 'Failed to submit request';
        throw ApiException(msg);
      }

      if (mounted) {
        setState(() {
          _isSubmitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Error: $e",
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "Help Me Buy",
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _isSubmitted ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Request Submitted Successfully!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.color.textColorDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Thank you for contacting us. Our dedicated specialists will review your requirements and get in touch with you shortly.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                color: context.color.textLightColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.color.territoryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "Back to Profile",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner / Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.color.territoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color: context.color.territoryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Assisted Buying Support",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Let our experts help you inspect, negotiate, and purchase safely.",
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.color.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Name Field
          _buildFieldLabel("Full Name *"),
          TextFormField(
            controller: _nameController,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return "Please enter your name";
              }
              return null;
            },
            decoration: _inputDecoration("Enter your full name"),
          ),
          const SizedBox(height: 16),

          // Email Field
          _buildFieldLabel("Email Address *"),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (val) => Validator.validateEmail(email: val, context: context),
            decoration: _inputDecoration("Enter your email address"),
          ),
          const SizedBox(height: 16),

          // Phone Number Field with Country Code Selection
          _buildFieldLabel("Phone Number *"),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _showCountryCodePicker,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _phoneCountryFlag,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "+$_phoneCountryCode",
                        style: TextStyle(
                          fontSize: 14,
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
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Please enter phone number";
                    }
                    return null;
                  },
                  decoration: _inputDecoration("Phone number"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Service Type
          _buildFieldLabel("Service Type *"),
          DropdownButtonFormField<String>(
            initialValue: _selectedServiceType,
            dropdownColor: context.color.secondaryColor,
            decoration: _inputDecoration("Select service type"),
            items: _serviceTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.color.textDefaultColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedServiceType = val;
                });
              }
            },
          ),
          const SizedBox(height: 16),

          // Message Field
          _buildFieldLabel("Describe your requirement *"),
          TextFormField(
            controller: _messageController,
            maxLines: 4,
            maxLength: 2000,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return "Please describe what you are looking to buy";
              }
              return null;
            },
            decoration: _inputDecoration(
              "Tell us about the car, property, or item you need help buying...",
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.territoryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitHelpMeBuy,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Submit Request",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: context.color.textDefaultColor,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13.5,
        color: context.color.textLightColor.withValues(alpha: 0.8),
      ),
      filled: true,
      fillColor: context.color.secondaryColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: context.color.borderColor.withValues(alpha: 0.8),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: context.color.borderColor.withValues(alpha: 0.8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: context.color.territoryColor,
          width: 1.5,
        ),
      ),
    );
  }
}
