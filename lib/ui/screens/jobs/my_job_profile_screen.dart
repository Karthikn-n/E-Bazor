import 'dart:io';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Ebozor/data/model/job_models.dart';
import 'package:Ebozor/data/repositories/job_repository.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/utils/validator.dart';

class MyJobProfileScreen extends StatefulWidget {
  const MyJobProfileScreen({super.key});

  static Route route(RouteSettings settings) {
    return CupertinoPageRoute(
      builder: (context) => const MyJobProfileScreen(),
    );
  }

  @override
  State<MyJobProfileScreen> createState() => _MyJobProfileScreenState();
}

class _MyJobProfileScreenState extends State<MyJobProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final JobRepository _jobRepository = JobRepository();

  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nationalityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();

  String _phoneCountryCode = "971";
  String _phoneCountryFlag = "🇦🇪";

  String _gender = "Male";
  String _visaStatus = "Employment";
  String _educationLevel = "Bachelors Degree";
  String _totalExperience = "1-2 Years";
  String _jobStatus = "Experienced";
  String _jobCategory = "Information Technology";
  String _industry = "Information Technology";
  String _noticePeriod = "Available Immediately";

  File? _resumeFile;
  String? _existingResumeUrl;

  final List<String> _genders = ["Male", "Female", "Other"];
  final List<String> _visaStatuses = [
    "Employment",
    "Tourist",
    "Residence",
    "Visit",
    "Student",
    "Citizen",
    "Golden Visa",
  ];
  final List<String> _educationLevels = [
    "High School",
    "Diploma",
    "Bachelors Degree",
    "Masters Degree",
    "Doctorate",
    "N/A",
  ];
  final List<String> _experiences = [
    "Fresher",
    "0-1 Years",
    "1-2 Years",
    "2-5 Years",
    "5-10 Years",
    "10+ Years",
  ];
  final List<String> _jobStatuses = [
    "Experienced",
    "Fresher",
    "Student",
  ];
  final List<String> _categories = [
    "Information Technology",
    "Accounting / Finance",
    "Engineering",
    "Healthcare",
    "Education",
    "Marketing / Sales",
    "Customer Service",
    "Hospitality / Tourism",
    "Construction",
    "Retail",
    "Logistics / Supply Chain",
    "Human Resources",
  ];
  final List<String> _noticePeriods = [
    "Available Immediately",
    "1 Month",
    "2 Months",
    "3 Months",
  ];

  @override
  void initState() {
    super.initState();
    _loadJobProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    _locationController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _loadJobProfile() async {
    setState(() => _isLoading = true);

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

    final userDetail = await _jobRepository.fetchUserDetail();
    if (userDetail != null && mounted) {
      if (userDetail['name'] != null && userDetail['name'].toString().isNotEmpty) {
        _nameController.text = userDetail['name'].toString();
      }
      if (userDetail['email'] != null && userDetail['email'].toString().isNotEmpty) {
        _emailController.text = userDetail['email'].toString();
      }
      if (userDetail['mobile'] != null && userDetail['mobile'].toString().isNotEmpty) {
        _phoneController.text = userDetail['mobile'].toString();
      }
      if (userDetail['nationality'] != null) {
        _nationalityController.text = userDetail['nationality'].toString();
      }
      if (userDetail['current_location'] != null) {
        _locationController.text = userDetail['current_location'].toString();
      }
      if (userDetail['experience_company'] != null) {
        _companyController.text = userDetail['experience_company'].toString();
      }
      if (userDetail['experience_job_titel'] != null) {
        _positionController.text = userDetail['experience_job_titel'].toString();
      }
      if (userDetail['gender'] != null && _genders.contains(userDetail['gender'])) {
        _gender = userDetail['gender'].toString();
      }
      if (userDetail['visa_status'] != null &&
          _visaStatuses.contains(userDetail['visa_status'])) {
        _visaStatus = userDetail['visa_status'].toString();
      }
      if (userDetail['degree'] != null &&
          _educationLevels.contains(userDetail['degree'])) {
        _educationLevel = userDetail['degree'].toString();
      }
      if (userDetail['experience_industry'] != null &&
          _categories.contains(userDetail['experience_industry'])) {
        _industry = userDetail['experience_industry'].toString();
        _jobCategory = userDetail['experience_industry'].toString();
      }
      if (userDetail['resume'] != null) {
        _existingResumeUrl = userDetail['resume'].toString();
      }
    }

    final info = await _jobRepository.fetchJobApplicationInfo();
    if (info != null && mounted) {
      setState(() {
        if (info.fullName != null && info.fullName!.isNotEmpty) {
          _nameController.text = info.fullName!;
        }
        if (info.emailId != null && info.emailId!.isNotEmpty) {
          _emailController.text = info.emailId!;
        }
        if (info.phoneNo != null && info.phoneNo!.isNotEmpty) {
          _phoneController.text = info.phoneNo!;
        }
        if (info.nationality != null && info.nationality!.isNotEmpty) {
          _nationalityController.text = info.nationality!;
        }
        if (info.currentlyLocated != null &&
            info.currentlyLocated!.isNotEmpty) {
          _locationController.text = info.currentlyLocated!;
        }
        if (info.currentCompany != null && info.currentCompany!.isNotEmpty) {
          _companyController.text = info.currentCompany!;
        }
        if (info.currentPosition != null && info.currentPosition!.isNotEmpty) {
          _positionController.text = info.currentPosition!;
        }

        if (info.gender != null && _genders.contains(info.gender)) {
          _gender = info.gender!;
        }
        if (info.visaStatus != null &&
            _visaStatuses.contains(info.visaStatus)) {
          _visaStatus = info.visaStatus!;
        }
        if (info.educationLevel != null &&
            _educationLevels.contains(info.educationLevel)) {
          _educationLevel = info.educationLevel!;
        }
        if (info.totalExperience != null &&
            _experiences.contains(info.totalExperience)) {
          _totalExperience = info.totalExperience!;
        }
        if (info.jobStatus != null && _jobStatuses.contains(info.jobStatus)) {
          _jobStatus = info.jobStatus!;
        }
        if (info.jobCategory != null &&
            _categories.contains(info.jobCategory)) {
          _jobCategory = info.jobCategory!;
        }
        if (info.industry != null && _categories.contains(info.industry)) {
          _industry = info.industry!;
        }
        if (info.noticePeriod != null &&
            _noticePeriods.contains(info.noticePeriod)) {
          _noticePeriod = info.noticePeriod!;
        }
        if (info.resume != null && info.resume!.isNotEmpty) {
          _existingResumeUrl = info.resume;
        }
      });
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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

  Future<void> _pickResumeFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _resumeFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final phoneDigits = _phoneController.text.trim();
      final fullPhone = phoneDigits.startsWith('+')
          ? phoneDigits
          : "+$_phoneCountryCode$phoneDigits";

      final Map<String, dynamic> userDetailData = {
        'type': 'personal',
        'email_id': _emailController.text.trim(),
        'mobile': fullPhone,
        'gender': _gender,
        'nationality': _nationalityController.text.trim().isNotEmpty
            ? _nationalityController.text.trim()
            : "United Arab Emirates",
        'current_location': _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : "United Arab Emirates",
        'visa_status': _visaStatus,
        'job_status': _jobStatus,
        'degree': _educationLevel,
        'experience_industry': _industry,
        'experience_job_category': _jobCategory,
        'experience_company': _companyController.text.trim(),
        'experience_job_titel': _positionController.text.trim(),
      };

      // Call add-user-detail API
      await _jobRepository.saveUserDetail(
        userDetailData,
        resumeFile: _resumeFile,
      );

      final Map<String, dynamic> jobAppInfoData = {
        'full_name': _nameController.text.trim(),
        'email_id': _emailController.text.trim(),
        'phone_no': fullPhone,
        'nationality': _nationalityController.text.trim().isNotEmpty
            ? _nationalityController.text.trim()
            : "United Arab Emirates",
        'currentlt_locate': _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : "United Arab Emirates",
        'gender': _gender,
        'visa_status': _visaStatus,
        'education_level': _educationLevel,
        'total_experience': _totalExperience,
        'job_status': _jobStatus,
        'job_category': _jobCategory,
        'industry': _industry,
        'current_company': _companyController.text.trim().isNotEmpty
            ? _companyController.text.trim()
            : _jobCategory,
        'current_position': _positionController.text.trim().isNotEmpty
            ? _positionController.text.trim()
            : _jobCategory,
        'notice_period': _noticePeriod,
      };

      await _jobRepository.saveJobApplicationInfo(
        jobAppInfoData,
        resumeFile: _resumeFile,
      );

      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Candidate Profile Saved Successfully",
          type: MessageType.success,
        );
        _loadJobProfile();
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "My Job Profile",
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 18),

                      // Section 1: Personal Information
                      _buildSectionCard(
                        title: "Personal Information",
                        icon: Icons.person_outline_rounded,
                        children: [
                          _buildFieldLabel("Full Name *"),
                          TextFormField(
                            controller: _nameController,
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? "Required" : null,
                            decoration: _inputDecoration("Enter full name"),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldLabel("Email Address *"),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                Validator.validateEmail(email: v, context: context),
                            decoration: _inputDecoration("Enter email address"),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldLabel("Phone Number *"),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: _showCountryCodePicker,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 48,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: context.color.secondaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: context.color.borderColor
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(_phoneCountryFlag,
                                          style:
                                              const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 4),
                                      Text(
                                        "+$_phoneCountryCode",
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              context.color.textDefaultColor,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? "Required"
                                      : null,
                                  decoration:
                                      _inputDecoration("Phone number"),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel("Gender *"),
                                    _buildDropdown(
                                      value: _gender,
                                      items: _genders,
                                      onChanged: (v) =>
                                          setState(() => _gender = v!),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel("Nationality"),
                                    TextFormField(
                                      controller: _nationalityController,
                                      decoration:
                                          _inputDecoration("e.g. UAE, India"),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildFieldLabel("Current Location (Country)"),
                          TextFormField(
                            controller: _locationController,
                            decoration:
                                _inputDecoration("e.g. United Arab Emirates"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section 2: Professional & Visa Details
                      _buildSectionCard(
                        title: "Professional Details",
                        icon: Icons.work_outline_rounded,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel("Visa Status *"),
                                    _buildDropdown(
                                      value: _visaStatus,
                                      items: _visaStatuses,
                                      onChanged: (v) =>
                                          setState(() => _visaStatus = v!),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel("Job Status *"),
                                    _buildDropdown(
                                      value: _jobStatus,
                                      items: _jobStatuses,
                                      onChanged: (v) =>
                                          setState(() => _jobStatus = v!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel("Education Level *"),
                                    _buildDropdown(
                                      value: _educationLevel,
                                      items: _educationLevels,
                                      onChanged: (v) =>
                                          setState(() => _educationLevel = v!),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel("Total Experience *"),
                                    _buildDropdown(
                                      value: _totalExperience,
                                      items: _experiences,
                                      onChanged: (v) =>
                                          setState(() => _totalExperience = v!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildFieldLabel("Job Category / Field *"),
                          _buildDropdown(
                            value: _jobCategory,
                            items: _categories,
                            onChanged: (v) => setState(() {
                              _jobCategory = v!;
                              _industry = v;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section 3: Current Employment
                      _buildSectionCard(
                        title: "Current Employment",
                        icon: Icons.business_outlined,
                        children: [
                          _buildFieldLabel("Current / Latest Company"),
                          TextFormField(
                            controller: _companyController,
                            decoration: _inputDecoration("Company name"),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldLabel("Current / Latest Job Title"),
                          TextFormField(
                            controller: _positionController,
                            decoration:
                                _inputDecoration("e.g. Senior Accountant"),
                          ),
                          const SizedBox(height: 14),
                          _buildFieldLabel("Notice Period *"),
                          _buildDropdown(
                            value: _noticePeriod,
                            items: _noticePeriods,
                            onChanged: (v) =>
                                setState(() => _noticePeriod = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section 4: Resume / CV
                      _buildSectionCard(
                        title: "Resume / CV",
                        icon: Icons.attach_file_rounded,
                        children: [
                          if (_existingResumeUrl != null &&
                              _existingResumeUrl!.isNotEmpty &&
                              _resumeFile == null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: context.color.backgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: context.color.borderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: context.color.territoryColor,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Uploaded Resume",
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                context.color.textDefaultColor,
                                          ),
                                        ),
                                        Text(
                                          "Saved on your candidate profile",
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: context.color.textLightColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_red_eye_outlined),
                                    tooltip: "Preview Resume",
                                    color: context.color.territoryColor,
                                    onPressed: () async {
                                      final uri =
                                          Uri.parse(_existingResumeUrl!);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri,
                                            mode:
                                                LaunchMode.externalApplication);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          InkWell(
                            onTap: _pickResumeFile,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 16),
                              decoration: BoxDecoration(
                                color: context.color.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _resumeFile != null
                                      ? context.color.territoryColor
                                      : context.color.borderColor,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _resumeFile != null
                                        ? Icons.check_circle_rounded
                                        : Icons.cloud_upload_outlined,
                                    size: 36,
                                    color: _resumeFile != null
                                        ? Colors.green
                                        : context.color.territoryColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _resumeFile != null
                                        ? _resumeFile!.path.split(Platform.pathSeparator).last
                                        : "Upload New Resume (PDF / DOCX)",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.color.textDefaultColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Max file size 10MB • PDF, DOC, DOCX",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                          onPressed: _isSaving ? null : _saveProfile,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Save Job Profile",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
        ),
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
              Icons.badge_outlined,
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
                  "Candidate Profile",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Auto-fills your job applications and helps recruiters discover you.",
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
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: context.color.territoryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveValue = items.contains(value) ? value : items.first;
    return DropdownButtonFormField<String>(
      value: effectiveValue,
      dropdownColor: context.color.secondaryColor,
      decoration: _inputDecoration(""),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: TextStyle(
              fontSize: 13.5,
              color: context.color.textDefaultColor,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.color.textDefaultColor,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint.isNotEmpty ? hint : null,
      hintStyle: TextStyle(
        fontSize: 13,
        color: context.color.textLightColor.withValues(alpha: 0.8),
      ),
      filled: true,
      fillColor: context.color.backgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
