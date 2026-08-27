import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class PhoneNumbersScreen extends StatefulWidget {
  const PhoneNumbersScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const PhoneNumbersScreen(),
    );
  }

  @override
  State<PhoneNumbersScreen> createState() => _PhoneNumbersScreenState();
}

class _PhoneNumbersScreenState extends State<PhoneNumbersScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _countryCode = "+971";
  String _flagEmoji = "🇦🇪";
  bool _isEditing = false;
  String? _currentMobile;

  @override
  void initState() {
    super.initState();
    final user = HiveUtils.getUserDetails();
    _currentMobile = user.mobile?.trim();
    if (_currentMobile == null || _currentMobile!.isEmpty) {
      _isEditing = true;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showCountryCodePicker() {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      showPhoneCode: true,
      favorite: const <String>[
        'AE',
        'SA',
        'QA',
        'KW',
        'OM',
        'BH',
        'IN',
        'PK',
        'EG',
        'GB',
        'US',
        'CA',
        'AU',
      ],
      countryListTheme: CountryListThemeData(
        backgroundColor: context.color.secondaryColor,
        textStyle: TextStyle(
          color: context.color.textDefaultColor,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
        searchTextStyle: TextStyle(
          color: context.color.textDefaultColor,
          fontSize: 14.5,
        ),
        inputDecoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          hintText: "Search country or dial code",
          hintStyle: TextStyle(
            color: context.color.textLightColor,
            fontSize: 14,
          ),
          filled: true,
          fillColor: context.color.backgroundColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.color.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.color.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.color.territoryColor),
          ),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      onSelect: (Country country) {
        setState(() {
          _countryCode = "+${country.phoneCode}";
          _flagEmoji = country.flagEmoji;
        });
      },
    );
  }

  void _onAddNumber() {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a valid mobile number",
        type: MessageType.warning,
      );
      return;
    }

    final code = _countryCode.replaceAll("+", "").trim();
    final fullNumber = raw.startsWith(code) ? "+$raw" : "+$code$raw";

    Navigator.pushNamed(
      context,
      Routes.chooseOtpMethodScreen,
      arguments: {
        'phoneNumber': fullNumber,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting = _currentMobile != null && _currentMobile!.isNotEmpty;

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          title: "primaryPhoneNumber".translate(context),
          showBackButton: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Interactive Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.color.borderColor.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Tile Header / Summary
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: hasExisting
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : context.color.territoryColor
                                      .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.phone_iphone_rounded,
                              color: hasExisting
                                  ? Colors.green
                                  : context.color.territoryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "Primary Mobile Number",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: context.color.textDefaultColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasExisting) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  hasExisting
                                      ? _currentMobile!
                                      : "No phone number added yet",
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: hasExisting
                                        ? context.color.textDefaultColor
                                            .withValues(alpha: 0.85)
                                        : context.color.textLightColor,
                                    fontWeight: hasExisting
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (hasExisting) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() {
                                  _isEditing = !_isEditing;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.color.backgroundColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.color.borderColor,
                                  ),
                                ),
                                child: Icon(
                                  _isEditing
                                      ? Icons.close_rounded
                                      : Icons.edit_outlined,
                                  color: context.color.textDefaultColor,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Expanded Edit Form Section
                    if (_isEditing) ...[
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: context.color.borderColor.withValues(alpha: 0.6),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasExisting
                                  ? "Change Primary Number"
                                  : "Add Primary Number",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "We'll send a one-time verification code to confirm your number.",
                              style: TextStyle(
                                fontSize: 13,
                                color: context.color.textLightColor,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Phone Input Box with sorted country code picker
                            Container(
                              decoration: BoxDecoration(
                                color: context.color.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: context.color.borderColor,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Country Code Selector
                                  InkWell(
                                    borderRadius: const BorderRadius.horizontal(
                                        left: Radius.circular(12)),
                                    onTap: _showCountryCodePicker,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _flagEmoji,
                                            style:
                                                const TextStyle(fontSize: 16),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _countryCode,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600,
                                              color: context
                                                  .color.textDefaultColor,
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
                                  Container(
                                    height: 26,
                                    width: 1,
                                    color: context.color.borderColor,
                                  ),
                                  const SizedBox(width: 10),
                                  // Mobile input
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: context.color.textDefaultColor,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "5X XXX XXXX",
                                        hintStyle: TextStyle(
                                          fontSize: 14.5,
                                          color: context.color.textLightColor
                                              .withValues(alpha: 0.6),
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 12),
                                      ),
                                    ),
                                  ),
                                  if (_phoneController.text.isNotEmpty)
                                    IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                        color: context.color.textLightColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _phoneController.clear();
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Action buttons
                            Row(
                              children: [
                                if (hasExisting) ...[
                                  Expanded(
                                    child: SizedBox(
                                      height: 46,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: context.color.borderColor,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          foregroundColor:
                                              context.color.textDefaultColor,
                                        ),
                                        onPressed: () {
                                          setState(() => _isEditing = false);
                                        },
                                        child: const Text(
                                          "Cancel",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  flex: hasExisting ? 1 : 2,
                                  child: SizedBox(
                                    height: 46,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            context.color.territoryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: _onAddNumber,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Text(
                                            "Continue",
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Icon(Icons.arrow_forward_rounded,
                                              size: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
