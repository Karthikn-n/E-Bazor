import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/auth/auth_cubit.dart';
import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/data/cubits/system/user_details.dart';
import 'package:Ebozor/data/model/user_model.dart';
import 'package:Ebozor/data/repositories/job_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/image_cropper.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class UserProfileScreen extends StatefulWidget {
  final String from;
  final bool? navigateToHome;
  final bool? popToCurrent;
  final AuthenticationType? type;
  final Map<String, dynamic>? extraData;

  const UserProfileScreen({
    super.key,
    required this.from,
    this.navigateToHome,
    this.popToCurrent,
    required this.type,
    this.extraData,
  });

  @override
  State<UserProfileScreen> createState() => UserProfileScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => UserProfileScreen(
        from: (arguments?['from'] as String?) ?? "profile",
        popToCurrent: arguments?['popToCurrent'] as bool?,
        type: (arguments?['type'] as AuthenticationType?) ??
            AuthenticationType.email,
        navigateToHome: arguments?['navigateToHome'] as bool?,
        extraData: arguments?['extraData'],
      ),
    );
  }
}

class UserProfileScreenState extends State<UserProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final JobRepository _jobRepository = JobRepository();

  // Profile Name Controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  // Account Details Fields
  final TextEditingController dobController = TextEditingController();
  final TextEditingController nationalityController = TextEditingController();
  String? selectedGender; // "Male", "Female", "Prefer not to say"

  // Other existing fields
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  File? fileUserimg;
  bool isNotificationsEnabled = true;
  bool isPersonalDetailShow = true;
  bool isLoading = false;
  String? countryCode = "+${Constant.defaultCountryCode}";
  DateTime? selectedDateOfBirth;

  final List<String> genderOptions = [
    "Male",
    "Female",
    "Prefer not to say",
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final userDetails = HiveUtils.getUserDetails();
    final rawName = userDetails.name ?? "";

    if (rawName.isNotEmpty) {
      final parts = rawName.trim().split(" ");
      firstNameController.text = parts.first;
      if (parts.length > 1) {
        lastNameController.text = parts.sublist(1).join(" ");
      }
    }

    emailController.text = userDetails.email ?? "";
    addressController.text = userDetails.address ?? "";

    if (widget.from == "login") {
      isNotificationsEnabled = true;
      isPersonalDetailShow = true;
    } else {
      isNotificationsEnabled = userDetails.notification == 1;
      isPersonalDetailShow = userDetails.isPersonalDetailShow == 1;
    }

    if (HiveUtils.getCountryCode() != null) {
      countryCode = formatCountryCode(HiveUtils.getCountryCode()!);
      final storedMobile = userDetails.mobile ?? '';
      phoneController.text = storedMobile.startsWith(countryCode!)
          ? storedMobile.substring(countryCode!.length)
          : storedMobile;
    } else {
      phoneController.text = userDetails.mobile ?? "";
    }

    _loadUserDetailApi();
  }

  Future<void> _loadUserDetailApi() async {
    try {
      final userDetail = await _jobRepository.fetchUserDetail();
      if (userDetail != null && mounted) {
        setState(() {
          if (userDetail['name'] != null &&
              userDetail['name'].toString().isNotEmpty) {
            firstNameController.text = userDetail['name'].toString();
          }
          if (userDetail['last_name'] != null &&
              userDetail['last_name'].toString().isNotEmpty) {
            lastNameController.text = userDetail['last_name'].toString();
          }
          if (userDetail['nationality'] != null &&
              userDetail['nationality'].toString().isNotEmpty) {
            nationalityController.text =
                userDetail['nationality'].toString();
          }
          if (userDetail['date_of_birth'] != null &&
              userDetail['date_of_birth'].toString().isNotEmpty) {
            final rawDob = userDetail['date_of_birth'].toString();
            try {
              final parsed = DateTime.parse(rawDob);
              selectedDateOfBirth = parsed;
              dobController.text = DateFormat('MM/dd/yyyy').format(parsed);
            } catch (_) {
              dobController.text = rawDob;
            }
          }
          if (userDetail['gender'] != null &&
              userDetail['gender'].toString().isNotEmpty) {
            final g = userDetail['gender'].toString().toLowerCase();
            if (g == 'male') {
              selectedGender = 'Male';
            } else if (g == 'female') {
              selectedGender = 'Female';
            } else if (g.contains('prefer') || g.contains('other')) {
              selectedGender = 'Prefer not to say';
            } else {
              selectedGender = userDetail['gender'].toString();
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching user detail in profile screen: $e");
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    dobController.dispose();
    nationalityController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  String formatCountryCode(String code) {
    if (!code.startsWith('+')) {
      return '+$code';
    }
    return code;
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime initialDate = selectedDateOfBirth ?? DateTime(2000, 1, 1);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: context.color.territoryColor,
              onPrimary: Colors.white,
              surface: context.color.secondaryColor,
              onSurface: context.color.textDefaultColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDateOfBirth = picked;
        dobController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  void _selectNationality() {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: context.color.secondaryColor,
        textStyle: TextStyle(color: context.color.textDefaultColor),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      onSelect: (Country country) {
        setState(() {
          nationalityController.text = country.name;
        });
      },
    );
  }

  Widget _buildProfilePicture() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 110,
          width: 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.color.territoryColor.withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.color.territoryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            width: 98,
            height: 98,
            child: _getProfileImage(),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: InkWell(
            onTap: _showPicker,
            child: Container(
              height: 34,
              width: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                shape: BoxShape.circle,
                color: context.color.territoryColor,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getProfileImage() {
    if (fileUserimg != null) {
      return Image.file(
        fileUserimg!,
        fit: BoxFit.cover,
      );
    } else {
      final user = HiveUtils.getUserDetails();
      if (user.profile != null && user.profile!.isNotEmpty) {
        return UiUtils.getImage(
          user.profile!,
          fit: BoxFit.cover,
        );
      }
      return UiUtils.getSvg(
        AppIcons.defaultPersonLogo,
        color: context.color.territoryColor,
        fit: BoxFit.none,
      );
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: context.color.secondaryColor,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text("gallery".translate(context)),
                onTap: () {
                  _imgFromGallery(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text("camera".translate(context)),
                onTap: () {
                  _imgFromGallery(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
              if (fileUserimg != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  title: Text(
                    "lblremove".translate(context),
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    setState(() {
                      fileUserimg = null;
                    });
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _imgFromGallery(ImageSource imageSource) async {
    CropImage.init(context);
    final pickedFile = await ImagePicker().pickImage(source: imageSource);

    if (pickedFile != null) {
      CroppedFile? croppedFile = await CropImage.crop(
        filePath: pickedFile.path,
      );
      if (croppedFile != null) {
        setState(() {
          fileUserimg = File(croppedFile.path);
        });
      }
    }
  }

  InputDecoration _inputDecoration({String? label, String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 14,
        color: context.color.textLightColor,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14,
        color: context.color.textLightColor.withValues(alpha: 0.7),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: context.color.secondaryColor,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final fullName =
        lastName.isNotEmpty ? "$firstName $lastName" : firstName;
    final formattedDobForApi = selectedDateOfBirth != null
        ? DateFormat('yyyy-MM-dd').format(selectedDateOfBirth!)
        : (dobController.text.trim().isNotEmpty
            ? dobController.text.trim()
            : null);

    try {
      // 1. Update Profile via AuthCubit (update-profile endpoint)
      final response = await context.read<AuthCubit>().updateuserdata(
            context,
            name: fullName,
            email: emailController.text.trim(),
            fileUserimg: fileUserimg,
            address: addressController.text,
            mobile: phoneController.text,
            notification: isNotificationsEnabled ? "1" : "0",
            countryCode: countryCode,
            personalDetail: isPersonalDetailShow ? 1 : 0,
          );

      if (response['data'] != null) {
        context
            .read<UserDetailsCubit>()
            .copy(UserModel.fromJson(response['data']));
      }

      // 2. Also persist full detailed profile (add-user-detail endpoint)
      final Map<String, dynamic> userDetailPayload = {
        'name': firstName,
        'last_name': lastName,
        if (emailController.text.trim().isNotEmpty)
          'email': emailController.text.trim(),
        if (phoneController.text.trim().isNotEmpty)
          'mobile': phoneController.text.trim(),
        if (formattedDobForApi != null) 'date_of_birth': formattedDobForApi,
        if (nationalityController.text.trim().isNotEmpty)
          'nationality': nationalityController.text.trim(),
        if (selectedGender != null) 'gender': selectedGender,
      };

      await _jobRepository.saveUserDetail(
        userDetailPayload,
        profileFile: fileUserimg,
      );

      if (mounted) {
        setState(() => isLoading = false);
        HelperUtils.showSnackBarMessage(
          context,
          response['message'] ?? "Profile updated successfully",
          type: MessageType.success,
        );

        if (widget.from != "login") {
          Navigator.pop(context);
        } else {
          if (widget.popToCurrent == true) {
            Navigator.of(context)
              ..pop()
              ..pop();
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.locationPermissionScreen, (route) => false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        HelperUtils.showSnackBarMessage(
          context,
          e.toString(),
          type: MessageType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: widget.from == "login"
            ? null
            : UiUtils.buildAppBar(
                context,
                title: "myProfile".translate(context),
                showBackButton: true,
              ),
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // =========================================================
                    // Section 1: Profile Name
                    // =========================================================
                    Text(
                      "profileName".translate(context),
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "This is displayed on your profile",
                      style: TextStyle(
                        fontSize: 13,
                        color: context.color.textLightColor,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // First Name
                    TextFormField(
                      controller: firstNameController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? "First name is required"
                          : null,
                      decoration: _inputDecoration(
                        label: "firstName".translate(context),
                        hint: "Enter first name",
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Last Name
                    TextFormField(
                      controller: lastNameController,
                      decoration: _inputDecoration(
                        label: "lastName".translate(context),
                        hint: "Enter last name",
                      ),
                    ),
                    const SizedBox(height: 28),

                    // =========================================================
                    // Section 2: Account details
                    // =========================================================
                    Text(
                      "accountDetails".translate(context),
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "This is not visible to other users",
                      style: TextStyle(
                        fontSize: 13,
                        color: context.color.textLightColor,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Date of birth
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: context.color.textDefaultColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "dateOfBirth".translate(context),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _selectDateOfBirth,
                      borderRadius: BorderRadius.circular(10),
                      child: IgnorePointer(
                        child: TextFormField(
                          controller: dobController,
                          decoration: _inputDecoration(
                            hint: "MM/DD/YYYY",
                            suffix: const Icon(
                              Icons.calendar_month_outlined,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nationality
                    Row(
                      children: [
                        Icon(
                          Icons.public_outlined,
                          size: 18,
                          color: context.color.textDefaultColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "nationality".translate(context),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _selectNationality,
                      borderRadius: BorderRadius.circular(10),
                      child: IgnorePointer(
                        child: TextFormField(
                          controller: nationalityController,
                          decoration: _inputDecoration(
                            hint: "Search",
                            suffix: const Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 24,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Gender
                    Row(
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          size: 18,
                          color: context.color.textDefaultColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "gender".translate(context),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: genderOptions.map((opt) {
                        final isSelected = selectedGender == opt;
                        return InkWell(
                          onTap: () {
                            setState(() => selectedGender = opt);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? context.color.territoryColor
                                          : context.color.textLightColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: context
                                                  .color.territoryColor,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  opt,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    /*
                    // ---------------------------------------------------------
                    // Notification & Contact Info toggles commented out as requested
                    // ---------------------------------------------------------
                    const SizedBox(height: 20),
                    Text("notification".translate(context)),
                    const SizedBox(height: 10),
                    _buildNotificationSwitch(context),
                    const SizedBox(height: 14),
                    Text("showContactInfo".translate(context)),
                    const SizedBox(height: 10),
                    _buildPersonalDetailSwitch(context),
                    */

                    const SizedBox(height: 36),

                    // Save Changes Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.color.territoryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isLoading ? null : _saveChanges,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Save Changes",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
