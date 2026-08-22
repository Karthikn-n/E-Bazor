import 'dart:io';
import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Ebozor/data/repositories/job_repository.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/utils/validator.dart';

class JobApplyFormScreen extends StatefulWidget {
  final int itemId;
  final String? itemTitle;
  final String? categoryName;

  const JobApplyFormScreen({
    super.key,
    required this.itemId,
    this.itemTitle,
    this.categoryName,
  });

  static Route route(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>? ?? {};
    return CupertinoPageRoute(
      builder: (context) => JobApplyFormScreen(
        itemId: args['itemId'] ?? 0,
        itemTitle: args['itemTitle'],
        categoryName: args['categoryName'],
      ),
    );
  }

  @override
  State<JobApplyFormScreen> createState() => _JobApplyFormScreenState();
}

class _JobApplyFormScreenState extends State<JobApplyFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final JobRepository _jobRepository = JobRepository();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSubmitted = false;

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
    _loadPreviousJobApplicationInfo();
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

  Future<void> _loadPreviousJobApplicationInfo() async {
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

    if (widget.categoryName != null && widget.categoryName!.isNotEmpty) {
      final matchedCat = _categories.firstWhere(
        (c) => c.toLowerCase().contains(widget.categoryName!.toLowerCase()) ||
            widget.categoryName!.toLowerCase().contains(c.toLowerCase()),
        orElse: () => _categories.first,
      );
      _jobCategory = matchedCat;
      _industry = matchedCat;
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
        _existingResumeUrl = info.resume;
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

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final phoneDigits = _phoneController.text.trim();
      final fullPhone = phoneDigits.startsWith('+')
          ? phoneDigits
          : "+$_phoneCountryCode$phoneDigits";

      final Map<String, dynamic> data = {
        'item_id': widget.itemId,
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

      final response = await _jobRepository.saveJobApplicationInfo(
        data,
        resumeFile: _resumeFile,
      );

      if (response['error'] == true) {
        throw ApiException(
            response['message']?.toString() ?? "Failed to submit job application");
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
        title: "Apply for Job",
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              "Application Submitted!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.color.textColorDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Your profile and CV have been successfully delivered to the recruiter. You can track this application in My Job Applications.",
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
                  Navigator.pop(context, true);
                },
                child: const Text(
                  "Done",
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
          _buildJobHeaderCard(),
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
                    v == null || v.trim().isEmpty ? "Please enter full name" : null,
                decoration: _inputDecoration("Enter your full name"),
              ),
              const SizedBox(height: 14),
              _buildFieldLabel("Email Address *"),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    Validator.validateEmail(email: v, context: context),
                decoration: _inputDecoration("Enter your email address"),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: context.color.secondaryColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.color.borderColor.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(_phoneCountryFlag,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            "+$_phoneCountryCode",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.color.textDefaultColor,
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
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? "Please enter phone" : null,
                      decoration: _inputDecoration("Phone number"),
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
                          onChanged: (v) => setState(() => _gender = v!),
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
                          decoration: _inputDecoration("e.g. UAE, India"),
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
                decoration: _inputDecoration("e.g. United Arab Emirates"),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: Professional Details
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
                          onChanged: (v) => setState(() => _visaStatus = v!),
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
                          onChanged: (v) => setState(() => _jobStatus = v!),
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
                decoration: _inputDecoration("e.g. Senior Accountant"),
              ),
              const SizedBox(height: 14),
              _buildFieldLabel("Notice Period *"),
              _buildDropdown(
                value: _noticePeriod,
                items: _noticePeriods,
                onChanged: (v) => setState(() => _noticePeriod = v!),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 4: Resume / CV
          _buildSectionCard(
            title: "Resume / CV Attachment",
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Saved Resume on Profile",
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            Text(
                              "Will be attached automatically unless replaced",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.color.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_red_eye_outlined),
                        tooltip: "Preview Resume",
                        color: context.color.territoryColor,
                        onPressed: () async {
                          final uri = Uri.parse(_existingResumeUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
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
                            : "Upload Custom CV for this Job (PDF / DOCX)",
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

          // Submit Application Button
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
              onPressed: _isSubmitting ? null : _submitApplication,
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
                      "Submit Application",
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
    );
  }

  Widget _buildJobHeaderCard() {
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
              Icons.work_outline_rounded,
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
                  widget.itemTitle ?? "Job Application",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.categoryName ?? "Jobs",
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
