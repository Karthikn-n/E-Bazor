import 'dart:io';
import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Ebozor/data/repositories/job_repository.dart';
import 'package:Ebozor/ui/screens/jobs/introduction_recording_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/constant.dart';
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
  final JobRepository _jobRepository = JobRepository();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSaving = false;

  // Basic Info Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nationalityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _languagesController = TextEditingController();
  String? _gender;
  String? _visaStatus;

  String _phoneCountryCode = "971";
  String _phoneCountryFlag = "🇦🇪";

  // Qualifications list (supports multiple)
  final List<Map<String, dynamic>> _qualificationsList = [];
  String? _educationLevel;
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _universityController =
      TextEditingController();
  String? _qualificationCountry;
  String? _graduationStartYear;
  String? _graduationEndYear;

  // Experience list (supports multiple)
  final List<Map<String, dynamic>> _experiencesList = [];
  String _experienceType = "Fresher"; // "Fresher" | "Experienced"
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _jobDescriptionController =
      TextEditingController();
  String? _experienceCategory;
  String? _experienceIndustry;
  String? _experienceCountry;
  String? _experienceStartDate;
  String? _experienceEndDate;
  bool _currentlyWorking = false;
  String? _totalExperience;
  String? _noticePeriod;

  // Skills fields
  final List<String> _skillsList = [];
  String? _jobCategory;
  String? _industry;

  // Resume fields
  File? _resumeFile;
  String? _existingResumeUrl;

  // Digital Profile fields
  String? _audioIntroPath;
  String? _videoIntroPath;

  // Additional sections (Licences, Portfolio, References)
  final List<Map<String, String>> _licencesList = [];
  final List<Map<String, String>> _portfoliosList = [];
  final List<Map<String, String>> _referencesList = [];

  // Static options
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
    "Other",
  ];
  final List<String> _experiences = [
    "Fresher",
    "0-1 Years",
    "1-2 Years",
    "2-5 Years",
    "5-10 Years",
    "10+ Years",
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


  @override
  void initState() {
    super.initState();
    _loadJobProfile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    _locationController.dispose();
    _languagesController.dispose();
    _specializationController.dispose();
    _universityController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    _jobDescriptionController.dispose();
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

    try {
      final userDetail = await _jobRepository.fetchUserDetail();
      if (userDetail != null && mounted) {
        if (userDetail['name'] != null &&
            userDetail['name'].toString().isNotEmpty) {
          _nameController.text = userDetail['name'].toString();
        }
        if (userDetail['email'] != null &&
            userDetail['email'].toString().isNotEmpty) {
          _emailController.text = userDetail['email'].toString();
        }
        if (userDetail['mobile'] != null &&
            userDetail['mobile'].toString().isNotEmpty) {
          _phoneController.text = userDetail['mobile'].toString();
        }
        if (userDetail['nationality'] != null) {
          _nationalityController.text = userDetail['nationality'].toString();
        }
        if (userDetail['current_location'] != null) {
          _locationController.text =
              userDetail['current_location'].toString();
        }
        if (userDetail['language'] != null) {
          _languagesController.text = userDetail['language'].toString();
        }
        if (userDetail['gender'] != null &&
            _genders.contains(userDetail['gender'])) {
          _gender = userDetail['gender'].toString();
        }
        if (userDetail['visa_status'] != null &&
            _visaStatuses.contains(userDetail['visa_status'])) {
          _visaStatus = userDetail['visa_status'].toString();
        }
        // Qualifications parsing (List and scalar fallback)
        _qualificationsList.clear();
        if (userDetail['user_qualification'] is List) {
          for (var q in userDetail['user_qualification']) {
            if (q is Map) {
              final map = Map<String, dynamic>.from(q);
              final degree = (map['degree'] ?? '').toString().trim();
              final uni = (map['university_name'] ?? '').toString().trim();
              final spec = (map['specialization'] ?? '').toString().trim();
              if (degree.isNotEmpty || uni.isNotEmpty || spec.isNotEmpty) {
                _qualificationsList.add(map);
              }
            }
          }
        }
        if (_qualificationsList.isEmpty &&
            userDetail['degree'] != null &&
            userDetail['degree'].toString().trim().isNotEmpty) {
          _qualificationsList.add({
            'degree': userDetail['degree'].toString().trim(),
            'specialization':
                (userDetail['specialization'] ?? '').toString().trim(),
            'university_name':
                (userDetail['university_name'] ?? '').toString().trim(),
            'country': userDetail['country']?.toString().trim(),
            'graduation_from': userDetail['graduation_from']?.toString().trim(),
            'graduation_to': userDetail['graduation_to']?.toString().trim(),
          });
        }

        // Experiences parsing (List and scalar fallback)
        _experiencesList.clear();
        if (userDetail['user_experience'] is List) {
          for (var exp in userDetail['user_experience']) {
            if (exp is Map) {
              final map = Map<String, dynamic>.from(exp);
              final isFresher = map['fresher'] == 1 ||
                  map['fresher'] == "1" ||
                  map['fresher'] == true;
              final title =
                  (map['experience_job_titel'] ?? '').toString().trim();
              final company =
                  (map['experience_company'] ?? '').toString().trim();
              final category =
                  (map['experience_job_category'] ?? '').toString().trim();
              if (isFresher ||
                  title.isNotEmpty ||
                  company.isNotEmpty ||
                  category.isNotEmpty) {
                _experiencesList.add(map);
              }
            }
          }
        }
        if (_experiencesList.isEmpty) {
          final isFresher = userDetail['fresher'] == 1 ||
              userDetail['fresher'] == "1" ||
              userDetail['fresher'] == true;
          final title =
              (userDetail['experience_job_titel'] ?? '').toString().trim();
          final company =
              (userDetail['experience_company'] ?? '').toString().trim();
          if (isFresher || title.isNotEmpty || company.isNotEmpty) {
            _experiencesList.add({
              'fresher': isFresher ? 1 : 0,
              'experience_company': company,
              'experience_job_titel': title,
              'experience_job_description':
                  (userDetail['experience_job_description'] ?? '').toString().trim(),
              'experience_job_category': userDetail['experience_job_category'],
              'experience_industry': userDetail['experience_industry'],
              'experience_country': userDetail['experience_country'],
              'experience_start_date': userDetail['experience_start_date'],
              'experience_end_date': userDetail['experience_end_date'],
              'currently_working':
                  userDetail['currently_working']?.toString() == "1" ? 1 : 0,
            });
          }
        }

        if (userDetail['skills'] != null) {
          final sList = userDetail['skills'].toString().split(',');
          _skillsList.clear();
          for (var s in sList) {
            if (s.trim().isNotEmpty && !_skillsList.contains(s.trim())) {
              _skillsList.add(s.trim());
            }
          }
        }
        if (userDetail['resume'] != null) {
          _existingResumeUrl = userDetail['resume'].toString();
        }
      }
    } catch (e) {
      debugPrint("Error loading job profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _calculateRemainingSections() {
    int totalSections = 6;
    int filled = 0;
    if (_nameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty) {
      filled++;
    }
    if (_educationLevel != null && _educationLevel!.isNotEmpty) filled++;
    if (_experienceType == "Fresher" ||
        _companyController.text.trim().isNotEmpty ||
        _positionController.text.trim().isNotEmpty) {
      filled++;
    }
    if (_skillsList.isNotEmpty || _jobCategory != null) filled++;
    if (_resumeFile != null ||
        (_existingResumeUrl != null && _existingResumeUrl!.isNotEmpty)) {
      filled++;
    }
    if (_audioIntroPath != null || _videoIntroPath != null) filled++;
    return (totalSections - filled).clamp(0, totalSections);
  }

  double _calculateProgress() {
    int remaining = _calculateRemainingSections();
    return (6 - remaining) / 6.0;
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
      await _saveJobProfileData();
    }
  }

  Future<void> _saveJobProfileData() async {
    setState(() => _isSaving = true);
    try {
      final phoneDigits = _phoneController.text.trim();
      final fullPhone = phoneDigits.startsWith('+')
          ? phoneDigits
          : "+$_phoneCountryCode$phoneDigits";

      // Filter and sanitize qualifications
      final validQualifications = _qualificationsList.where((q) {
        final degree = (q['degree'] ?? '').toString().trim();
        final uni = (q['university_name'] ?? '').toString().trim();
        final spec = (q['specialization'] ?? '').toString().trim();
        return degree.isNotEmpty || uni.isNotEmpty || spec.isNotEmpty;
      }).map((q) {
        final map = <String, dynamic>{};
        if (q['id'] != null) map['id'] = q['id'];
        if (q['degree'] != null) map['degree'] = q['degree'].toString().trim();
        if (q['specialization'] != null) {
          map['specialization'] = q['specialization'].toString().trim();
        }
        if (q['university_name'] != null) {
          map['university_name'] = q['university_name'].toString().trim();
        }
        if (q['country'] != null) map['country'] = q['country'].toString().trim();
        if (q['graduation_from'] != null) {
          map['graduation_from'] = q['graduation_from'].toString().trim();
        }
        if (q['graduation_to'] != null) {
          map['graduation_to'] = q['graduation_to'].toString().trim();
        }
        return map;
      }).toList();

      // Filter and sanitize experiences
      final validExperiences = _experiencesList.where((exp) {
        final isFresher = exp['fresher'] == 1 ||
            exp['fresher'] == "1" ||
            exp['fresher'] == true;
        final title = (exp['experience_job_titel'] ?? '').toString().trim();
        final comp = (exp['experience_company'] ?? '').toString().trim();
        final cat = (exp['experience_job_category'] ?? '').toString().trim();
        return isFresher || title.isNotEmpty || comp.isNotEmpty || cat.isNotEmpty;
      }).map((exp) {
        final map = <String, dynamic>{};
        if (exp['id'] != null) map['id'] = exp['id'];
        map['fresher'] = (exp['fresher'] == 1 ||
                exp['fresher'] == "1" ||
                exp['fresher'] == true)
            ? 1
            : 0;
        if (exp['experience_company'] != null) {
          map['experience_company'] = exp['experience_company'].toString().trim();
        }
        if (exp['experience_job_titel'] != null) {
          map['experience_job_titel'] =
              exp['experience_job_titel'].toString().trim();
        }
        if (exp['experience_job_description'] != null) {
          map['experience_job_description'] =
              exp['experience_job_description'].toString().trim();
        }
        if (exp['experience_job_category'] != null) {
          map['experience_job_category'] =
              exp['experience_job_category'].toString().trim();
        }
        if (exp['experience_industry'] != null) {
          map['experience_industry'] =
              exp['experience_industry'].toString().trim();
        }
        if (exp['experience_country'] != null) {
          map['experience_country'] =
              exp['experience_country'].toString().trim();
        }
        if (exp['experience_start_date'] != null) {
          map['experience_start_date'] =
              exp['experience_start_date'].toString().trim();
        }
        if (exp['experience_end_date'] != null) {
          map['experience_end_date'] =
              exp['experience_end_date'].toString().trim();
        }
        map['currently_working'] = (exp['currently_working'] == 1 ||
                exp['currently_working'] == "1" ||
                exp['currently_working'] == true)
            ? 1
            : 0;
        return map;
      }).toList();

      final Map<String, dynamic> userDetailData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobile': fullPhone,
        if (_nationalityController.text.trim().isNotEmpty)
          'nationality': _nationalityController.text.trim(),
        if (_locationController.text.trim().isNotEmpty)
          'current_location': _locationController.text.trim(),
        if (_languagesController.text.trim().isNotEmpty)
          'language': _languagesController.text.trim(),
        if (_gender != null) 'gender': _gender,
        if (_visaStatus != null) 'visa_status': _visaStatus,
        if (_skillsList.isNotEmpty) 'skills': _skillsList.join(', '),
        if (_jobCategory != null) 'experience_industry': _jobCategory,
        'user_qualification': validQualifications,
        'user_experience': validExperiences,
      };

      await _jobRepository.saveUserDetail(
        userDetailData,
        resumeFile: _resumeFile,
      );

      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Profile updated successfully",
          type: MessageType.success,
        );
        _loadJobProfile();
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Error saving profile: $e",
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Date Picker for Month & Year Only Selection
  // ---------------------------------------------------------------------------
  Future<String?> _showMonthYearPicker({String? initialValue}) {
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;

    if (initialValue != null && initialValue.contains('-')) {
      final parts = initialValue.split('-');
      if (parts.length >= 2) {
        selectedYear = int.tryParse(parts[0]) ?? selectedYear;
        selectedMonth = int.tryParse(parts[1]) ?? selectedMonth;
      }
    }

    final months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setPickerState) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select Month & Year",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Year Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () {
                          setPickerState(() => selectedYear--);
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.color.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.color.borderColor,
                          ),
                        ),
                        child: Text(
                          "$selectedYear",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          if (selectedYear < DateTime.now().year + 5) {
                            setPickerState(() => selectedYear++);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Months Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = selectedMonth == monthNum;
                      return InkWell(
                        onTap: () {
                          setPickerState(() => selectedMonth = monthNum);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.color.territoryColor
                                : context.color.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? context.color.territoryColor
                                  : context.color.borderColor,
                            ),
                          ),
                          child: Text(
                            months[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : context.color.textDefaultColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Select Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.color.territoryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        final formattedMonth =
                            selectedMonth.toString().padLeft(2, '0');
                        Navigator.pop(ctx, "$selectedYear-$formattedMonth");
                      },
                      child: const Text("Select Date"),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Single Field Bottom Sheet
  // ---------------------------------------------------------------------------
  void _showSingleFieldBottomSheet({
    required String title,
    required String fieldKey,
    required String? currentValue,
    List<String>? options,
  }) {
    String? tempOption = currentValue;
    final textCtrl = TextEditingController(text: currentValue ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (options != null) ...[
                    ...options.map((opt) {
                      final isSelected = tempOption == opt;
                      return InkWell(
                        onTap: () {
                          setSheetState(() => tempOption = opt);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.color.territoryColor
                                    .withValues(alpha: 0.1)
                                : context.color.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? context.color.territoryColor
                                  : context.color.borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                opt,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: context.color.textDefaultColor,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded,
                                    size: 20,
                                    color: context.color.territoryColor),
                            ],
                          ),
                        ),
                      );
                    }),
                  ] else ...[
                    TextFormField(
                      controller: textCtrl,
                      decoration: _inputDecoration("Enter $title"),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: context.color.borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            foregroundColor: context.color.textDefaultColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.color.territoryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            setState(() {
                              if (fieldKey == "visa_status") {
                                _visaStatus = tempOption;
                              } else if (fieldKey == "gender") {
                                _gender = tempOption;
                              } else if (fieldKey == "nationality") {
                                _nationalityController.text = textCtrl.text;
                              } else if (fieldKey == "language") {
                                _languagesController.text = textCtrl.text;
                              } else if (fieldKey == "location") {
                                _locationController.text = textCtrl.text;
                              }
                            });
                            Navigator.pop(ctx);
                            _saveJobProfileData();
                          },
                          child: const Text("Save"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Basic Info Full Bottom Sheet (Opens on Edit icon)
  // ---------------------------------------------------------------------------
  void _showBasicInfoBottomSheet() {
    final formKey = GlobalKey<FormState>();
    final tempNameCtrl = TextEditingController(text: _nameController.text);
    final tempEmailCtrl = TextEditingController(text: _emailController.text);
    final tempPhoneCtrl = TextEditingController(text: _phoneController.text);
    final tempNatCtrl =
        TextEditingController(text: _nationalityController.text);
    final tempLocCtrl =
        TextEditingController(text: _locationController.text);
    final tempLangCtrl =
        TextEditingController(text: _languagesController.text);
    String? tempGender = _gender;
    String? tempVisa = _visaStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Edit Basic Info",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildFieldLabel("Full Name *"),
                      TextFormField(
                        controller: tempNameCtrl,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? "Required" : null,
                        decoration: _inputDecoration("Enter full name"),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Email Address *"),
                      TextFormField(
                        controller: tempEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            Validator.validateEmail(email: v, context: context),
                        decoration: _inputDecoration("Enter email"),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Phone Number *"),
                      TextFormField(
                        controller: tempPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? "Required" : null,
                        decoration: _inputDecoration("Enter phone number"),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Visa Status"),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: tempVisa != null &&
                                _visaStatuses.contains(tempVisa)
                            ? tempVisa
                            : null,
                        hint: Text("Select Visa Status",
                            style:
                                TextStyle(color: context.color.textLightColor)),
                        items: _visaStatuses
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setModalState(() => tempVisa = v),
                        decoration: _inputDecoration(""),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Gender"),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: tempGender != null &&
                                _genders.contains(tempGender)
                            ? tempGender
                            : null,
                        hint: Text("Select Gender",
                            style:
                                TextStyle(color: context.color.textLightColor)),
                        items: _genders
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setModalState(() => tempGender = v),
                        decoration: _inputDecoration(""),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Nationality"),
                      TextFormField(
                        controller: tempNatCtrl,
                        decoration:
                            _inputDecoration("e.g. Emirati, Indian, British"),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Current Location / City"),
                      TextFormField(
                        controller: tempLocCtrl,
                        decoration:
                            _inputDecoration("e.g. Dubai, Abu Dhabi"),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Languages"),
                      TextFormField(
                        controller: tempLangCtrl,
                        decoration:
                            _inputDecoration("e.g. English, Arabic, Hindi"),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side:
                                    BorderSide(color: context.color.borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                foregroundColor: context.color.textDefaultColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancel"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.color.territoryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  setState(() {
                                    _nameController.text = tempNameCtrl.text;
                                    _emailController.text = tempEmailCtrl.text;
                                    _phoneController.text = tempPhoneCtrl.text;
                                    _nationalityController.text =
                                        tempNatCtrl.text;
                                    _locationController.text = tempLocCtrl.text;
                                    _languagesController.text =
                                        tempLangCtrl.text;
                                    _gender = tempGender;
                                    _visaStatus = tempVisa;
                                  });
                                  Navigator.pop(ctx);
                                  _saveJobProfileData();
                                }
                              },
                              child: const Text("Save"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Qualifications Bottom Sheet (Add / Edit)
  // ---------------------------------------------------------------------------
  void _showQualificationsBottomSheet({
    Map<String, dynamic>? initialData,
    int? editIndex,
  }) {
    String? tempEducation = initialData?['degree'] ?? _educationLevel;
    final tempSpecCtrl = TextEditingController(
        text: initialData?['specialization'] ?? _specializationController.text);
    final tempUniCtrl = TextEditingController(
        text: initialData?['university_name'] ?? _universityController.text);
    String? tempCountry = initialData?['country'] ?? _qualificationCountry;
    String? tempStartYear =
        initialData?['graduation_from'] ?? _graduationStartYear;
    String? tempEndYear = initialData?['graduation_to'] ?? _graduationEndYear;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          editIndex != null
                              ? "Edit Qualification"
                              : "Add Qualification",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildFieldLabel("Highest Education Level *"),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: tempEducation != null &&
                              _educationLevels.contains(tempEducation)
                          ? tempEducation
                          : null,
                      hint: Text("Select Highest Education",
                          style:
                              TextStyle(color: context.color.textLightColor)),
                      items: _educationLevels
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setModalState(() => tempEducation = v),
                      decoration: _inputDecoration(""),
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel("Degree / Specialization"),
                    TextFormField(
                      controller: tempSpecCtrl,
                      decoration:
                          _inputDecoration("e.g. Computer Science, Finance"),
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel("University / Institute Name"),
                    TextFormField(
                      controller: tempUniCtrl,
                      decoration:
                          _inputDecoration("e.g. University of Dubai"),
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel("Country"),
                    InkWell(
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          showWorldWide: false,
                          countryListTheme: CountryListThemeData(
                            backgroundColor: context.color.secondaryColor,
                            textStyle: TextStyle(
                                color: context.color.textDefaultColor),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18)),
                          ),
                          onSelect: (country) {
                            setModalState(() {
                              tempCountry = country.name;
                            });
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: context.color.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.color.borderColor,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tempCountry ?? "Select Country",
                              style: TextStyle(
                                fontSize: 13.5,
                                color: tempCountry != null
                                    ? context.color.textDefaultColor
                                    : context.color.textLightColor,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFieldLabel("Year of Graduation (Start - End)"),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await _showMonthYearPicker(
                                  initialValue: tempStartYear);
                              if (picked != null) {
                                setModalState(() => tempStartYear = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: context.color.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: context.color.borderColor,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tempStartYear ?? "Start Year",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: tempStartYear != null
                                          ? context.color.textDefaultColor
                                          : context.color.textLightColor,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_month_outlined,
                                      size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await _showMonthYearPicker(
                                  initialValue: tempEndYear);
                              if (picked != null) {
                                setModalState(() => tempEndYear = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: context.color.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: context.color.borderColor,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tempEndYear ?? "End Year",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: tempEndYear != null
                                          ? context.color.textDefaultColor
                                          : context.color.textLightColor,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_month_outlined,
                                      size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: context.color.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              foregroundColor: context.color.textDefaultColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.color.territoryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              final newQual = {
                                'degree': tempEducation ?? '',
                                'specialization': tempSpecCtrl.text.trim(),
                                'university_name': tempUniCtrl.text.trim(),
                                'country': tempCountry ?? '',
                                'graduation_from': tempStartYear ?? '',
                                'graduation_to': tempEndYear ?? '',
                              };

                              setState(() {
                                if (editIndex != null &&
                                    editIndex < _qualificationsList.length) {
                                  _qualificationsList[editIndex] = newQual;
                                } else {
                                  _qualificationsList.add(newQual);
                                }
                                _educationLevel = newQual['degree']?.toString();
                                _specializationController.text =
                                    newQual['specialization']?.toString() ?? '';
                                _universityController.text =
                                    newQual['university_name']?.toString() ?? '';
                                _qualificationCountry =
                                    newQual['country']?.toString();
                                _graduationStartYear =
                                    newQual['graduation_from']?.toString();
                                _graduationEndYear =
                                    newQual['graduation_to']?.toString();
                              });
                              Navigator.pop(ctx);
                              _saveJobProfileData();
                            },
                            child: const Text("Save"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Experience Bottom Sheet (Add / Edit)
  // ---------------------------------------------------------------------------
  void _showExperienceBottomSheet({
    Map<String, dynamic>? initialData,
    int? editIndex,
  }) {
    String tempExpType = initialData != null
        ? ((initialData['fresher'] == 1 || initialData['fresher'] == "1")
            ? "Fresher"
            : "Experienced")
        : _experienceType;
    final tempCompanyCtrl = TextEditingController(
        text: initialData?['experience_company'] ?? _companyController.text);
    final tempPosCtrl = TextEditingController(
        text: initialData?['experience_job_titel'] ?? _positionController.text);
    final tempDescCtrl = TextEditingController(
        text: initialData?['experience_job_description'] ??
            _jobDescriptionController.text);
    String? tempCat =
        initialData?['experience_job_category'] ?? _experienceCategory;
    String? tempInd =
        initialData?['experience_industry'] ?? _experienceIndustry;
    String? tempCountry =
        initialData?['experience_country'] ?? _experienceCountry;
    String? tempStartDate =
        initialData?['experience_start_date'] ?? _experienceStartDate;
    String? tempEndDate =
        initialData?['experience_end_date'] ?? _experienceEndDate;
    bool tempCurrent = initialData != null
        ? (initialData['currently_working'] == 1 ||
            initialData['currently_working'] == "1" ||
            initialData['currently_working'] == true)
        : _currentlyWorking;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          editIndex != null
                              ? "Edit Experience"
                              : "Add Experience",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Fresher vs Experienced Selection Boxes
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setModalState(() => tempExpType = "Fresher");
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: tempExpType == "Fresher"
                                    ? context.color.territoryColor
                                        .withValues(alpha: 0.12)
                                    : context.color.backgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: tempExpType == "Fresher"
                                      ? context.color.territoryColor
                                      : context.color.borderColor,
                                  width: tempExpType == "Fresher" ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    color: tempExpType == "Fresher"
                                        ? context.color.territoryColor
                                        : context.color.textLightColor,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Fresher",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: tempExpType == "Fresher"
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: context.color.textDefaultColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setModalState(
                                  () => tempExpType = "Experienced");
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: tempExpType == "Experienced"
                                    ? context.color.territoryColor
                                        .withValues(alpha: 0.12)
                                    : context.color.backgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: tempExpType == "Experienced"
                                      ? context.color.territoryColor
                                      : context.color.borderColor,
                                  width: tempExpType == "Experienced" ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.work_outline_rounded,
                                    color: tempExpType == "Experienced"
                                        ? context.color.territoryColor
                                        : context.color.textLightColor,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Experienced",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: tempExpType == "Experienced"
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: context.color.textDefaultColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (tempExpType == "Experienced") ...[
                      const SizedBox(height: 16),
                      _buildFieldLabel("Job Title / Position *"),
                      TextFormField(
                        controller: tempPosCtrl,
                        decoration:
                            _inputDecoration("e.g. Senior Software Engineer"),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Company Name *"),
                      TextFormField(
                        controller: tempCompanyCtrl,
                        decoration: _inputDecoration("e.g. Acme Tech Solutions"),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Job Category"),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: tempCat != null && _categories.contains(tempCat)
                            ? tempCat
                            : null,
                        hint: Text("Select Category",
                            style:
                                TextStyle(color: context.color.textLightColor)),
                        items: _categories
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setModalState(() => tempCat = v),
                        decoration: _inputDecoration(""),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Industry"),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: tempInd != null && _categories.contains(tempInd)
                            ? tempInd
                            : null,
                        hint: Text("Select Industry",
                            style:
                                TextStyle(color: context.color.textLightColor)),
                        items: _categories
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setModalState(() => tempInd = v),
                        decoration: _inputDecoration(""),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Country"),
                      InkWell(
                        onTap: () {
                          showCountryPicker(
                            context: context,
                            showWorldWide: false,
                            countryListTheme: CountryListThemeData(
                              backgroundColor: context.color.secondaryColor,
                              textStyle: TextStyle(
                                  color: context.color.textDefaultColor),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(18)),
                            ),
                            onSelect: (country) {
                              setModalState(() {
                                tempCountry = country.name;
                              });
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: context.color.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.color.borderColor,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tempCountry ?? "Select Country",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: tempCountry != null
                                      ? context.color.textDefaultColor
                                      : context.color.textLightColor,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Period (Start Date - End Date)"),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await _showMonthYearPicker(
                                    initialValue: tempStartDate);
                                if (picked != null) {
                                  setModalState(() => tempStartDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: context.color.backgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: context.color.borderColor,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      tempStartDate ?? "Start Month/Yr",
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: tempStartDate != null
                                            ? context.color.textDefaultColor
                                            : context.color.textLightColor,
                                      ),
                                    ),
                                    const Icon(Icons.calendar_month_outlined,
                                        size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: tempCurrent
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: context.color.backgroundColor
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: context.color.borderColor,
                                      ),
                                    ),
                                    child: Text(
                                      "Present",
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: context.color.territoryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : InkWell(
                                    onTap: () async {
                                      final picked = await _showMonthYearPicker(
                                          initialValue: tempEndDate);
                                      if (picked != null) {
                                        setModalState(
                                            () => tempEndDate = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: context.color.backgroundColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: context.color.borderColor,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            tempEndDate ?? "End Month/Yr",
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: tempEndDate != null
                                                  ? context
                                                      .color.textDefaultColor
                                                  : context
                                                      .color.textLightColor,
                                            ),
                                          ),
                                          const Icon(
                                              Icons.calendar_month_outlined,
                                              size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: tempCurrent,
                            activeColor: context.color.territoryColor,
                            onChanged: (v) {
                              setModalState(() {
                                tempCurrent = v ?? false;
                                if (tempCurrent) tempEndDate = "Present";
                              });
                            },
                          ),
                          Text(
                            "I currently work here",
                            style: TextStyle(
                              fontSize: 13.5,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Job Description / Responsibilities"),
                      TextFormField(
                        controller: tempDescCtrl,
                        maxLines: 3,
                        decoration: _inputDecoration(
                            "Briefly describe your key responsibilities and accomplishments"),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: context.color.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              foregroundColor: context.color.textDefaultColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.color.territoryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              final newExp = {
                                'fresher': tempExpType == "Fresher" ? 1 : 0,
                                'experience_company':
                                    tempCompanyCtrl.text.trim(),
                                'experience_job_titel': tempPosCtrl.text.trim(),
                                'experience_job_description':
                                    tempDescCtrl.text.trim(),
                                'experience_job_category': tempCat ?? '',
                                'experience_industry': tempInd ?? '',
                                'experience_country': tempCountry ?? '',
                                'experience_start_date': tempStartDate ?? '',
                                'experience_end_date': tempEndDate ?? '',
                                'currently_working': tempCurrent ? 1 : 0,
                              };

                              setState(() {
                                if (editIndex != null &&
                                    editIndex < _experiencesList.length) {
                                  _experiencesList[editIndex] = newExp;
                                } else {
                                  _experiencesList.add(newExp);
                                }
                                _experienceType = tempExpType;
                                _companyController.text =
                                    newExp['experience_company']?.toString() ??
                                        '';
                                _positionController.text =
                                    newExp['experience_job_titel']
                                            ?.toString() ??
                                        '';
                                _jobDescriptionController.text =
                                    newExp['experience_job_description']
                                            ?.toString() ??
                                        '';
                                _experienceCategory =
                                    newExp['experience_job_category']
                                        ?.toString();
                                _experienceIndustry =
                                    newExp['experience_industry']?.toString();
                                _experienceCountry =
                                    newExp['experience_country']?.toString();
                                _experienceStartDate =
                                    newExp['experience_start_date']?.toString();
                                _experienceEndDate =
                                    newExp['experience_end_date']?.toString();
                                _currentlyWorking = tempCurrent;
                              });
                              Navigator.pop(ctx);
                              _saveJobProfileData();
                            },
                            child: const Text("Save"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Skills Bottom Sheet
  // ---------------------------------------------------------------------------
  void _showSkillsBottomSheet() {
    final List<String> tempSkills = List.from(_skillsList);
    final skillInputCtrl = TextEditingController();
    String? tempCat = _jobCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void addSkill() {
              final val = skillInputCtrl.text.trim();
              if (val.isNotEmpty && !tempSkills.contains(val)) {
                setModalState(() {
                  tempSkills.add(val);
                  skillInputCtrl.clear();
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Skills & Expertise",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildFieldLabel("Job Industry / Category"),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: tempCat != null && _categories.contains(tempCat)
                          ? tempCat
                          : null,
                      hint: Text("Select Industry",
                          style:
                              TextStyle(color: context.color.textLightColor)),
                      items: _categories
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setModalState(() => tempCat = v),
                      decoration: _inputDecoration(""),
                    ),
                    const SizedBox(height: 14),
                    _buildFieldLabel("Add Skills (Type and tap Add)"),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: skillInputCtrl,
                            onFieldSubmitted: (_) => addSkill(),
                            decoration:
                                _inputDecoration("e.g. Flutter, Salesforce"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.color.territoryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          onPressed: addSkill,
                          child: const Text("Add"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (tempSkills.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tempSkills.map((skill) {
                          return Chip(
                            backgroundColor: context.color.territoryColor
                                .withValues(alpha: 0.12),
                            label: Text(
                              skill,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.color.territoryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            deleteIcon:
                                const Icon(Icons.close_rounded, size: 16),
                            deleteIconColor: context.color.territoryColor,
                            onDeleted: () {
                              setModalState(() => tempSkills.remove(skill));
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side:
                                  BorderSide(color: context.color.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              foregroundColor: context.color.textDefaultColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.color.territoryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _skillsList.clear();
                                _skillsList.addAll(tempSkills);
                                _jobCategory = tempCat;
                                _industry = tempCat;
                              });
                              Navigator.pop(ctx);
                              _saveJobProfileData();
                            },
                            child: const Text("Save"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Digital Profile Bottom Sheet
  // ---------------------------------------------------------------------------
  void _showDigitalProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Digital Profile",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tile 1: Add your audio introduction
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    IntroductionRecordingScreen.route(RecordingType.audio),
                  );
                  if (result != null && result is Map) {
                    setState(() {
                      _audioIntroPath = result['filePath']?.toString();
                    });
                    HelperUtils.showSnackBarMessage(
                      context,
                      "Audio introduction saved successfully!",
                      type: MessageType.success,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.color.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Add your audio introduction",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _audioIntroPath != null
                                  ? "Recorded (Tap to replace/listen)"
                                  : "Record a 30-60 second voice introduction",
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _audioIntroPath != null
                                    ? Colors.green
                                    : context.color.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Tile 2: Add your video introduction
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    IntroductionRecordingScreen.route(RecordingType.video),
                  );
                  if (result != null && result is Map) {
                    setState(() {
                      _videoIntroPath = result['filePath']?.toString();
                    });
                    HelperUtils.showSnackBarMessage(
                      context,
                      "Video introduction saved successfully!",
                      type: MessageType.success,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.color.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          color: Color(0xFFE50914),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Add your video introduction",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _videoIntroPath != null
                                  ? "Recorded (Tap to replace/watch)"
                                  : "Record a short video introducing yourself",
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _videoIntroPath != null
                                    ? Colors.green
                                    : context.color.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 6. "Add More Sections" Bottom Sheet
  // ---------------------------------------------------------------------------
  void _showAddMoreSectionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Add More Sections",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Item 1: Licences or Certificates
              _buildAddSectionOption(
                icon: Icons.military_tech_outlined,
                title: "Licences or Certificates",
                subtitle:
                    "Add your skill based certifications eg: Safety Licence.",
                onAdd: () {
                  Navigator.pop(ctx);
                  _showLicenceFormSheet();
                },
              ),

              const SizedBox(height: 12),
              Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.4)),
              const SizedBox(height: 12),

              // Item 2: Portfolio
              _buildAddSectionOption(
                icon: Icons.link_rounded,
                title: "Portfolio",
                subtitle: "Add links to your online work projects.",
                onAdd: () {
                  Navigator.pop(ctx);
                  _showPortfolioFormSheet();
                },
              ),

              const SizedBox(height: 12),
              Divider(
                  height: 1,
                  color: context.color.borderColor.withValues(alpha: 0.4)),
              const SizedBox(height: 12),

              // Item 3: Reference
              _buildAddSectionOption(
                icon: Icons.person_outline_rounded,
                title: "Reference",
                subtitle:
                    "Add details of your previous employer for background and experience check.",
                onAdd: () {
                  Navigator.pop(ctx);
                  _showReferenceFormSheet();
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddSectionOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onAdd,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.color.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.color.borderColor),
          ),
          child: Icon(icon, color: context.color.textDefaultColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.color.textLightColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: const Text("Add"),
          style: TextButton.styleFrom(
            foregroundColor: context.color.textDefaultColor,
            textStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Licences, Portfolio & Reference Forms
  // ---------------------------------------------------------------------------
  void _showLicenceFormSheet() {
    final nameCtrl = TextEditingController();
    final orgCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add Licence or Certificate",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 14),
              _buildFieldLabel("Course / Certificate Name *"),
              TextFormField(
                controller: nameCtrl,
                decoration: _inputDecoration(
                    "e.g. AWS Certified Solutions Architect"),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel("Issuing Organization"),
              TextFormField(
                controller: orgCtrl,
                decoration: _inputDecoration("e.g. Amazon Web Services"),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.color.borderColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        foregroundColor: context.color.textDefaultColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.color.territoryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (nameCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            _licencesList.add({
                              'name': nameCtrl.text.trim(),
                              'org': orgCtrl.text.trim(),
                            });
                          });
                          Navigator.pop(ctx);
                          HelperUtils.showSnackBarMessage(
                            context,
                            "Certificate added",
                            type: MessageType.success,
                          );
                        }
                      },
                      child: const Text("Save"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPortfolioFormSheet() {
    final nameCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add Portfolio Project",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 14),
              _buildFieldLabel("Project / Portfolio Name *"),
              TextFormField(
                controller: nameCtrl,
                decoration: _inputDecoration("e.g. E-Commerce Mobile App"),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel("Portfolio Link / URL"),
              TextFormField(
                controller: linkCtrl,
                decoration: _inputDecoration(
                    "https://github.com/... or https://behance.net/..."),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.color.borderColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        foregroundColor: context.color.textDefaultColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.color.territoryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (nameCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            _portfoliosList.add({
                              'name': nameCtrl.text.trim(),
                              'link': linkCtrl.text.trim(),
                            });
                          });
                          Navigator.pop(ctx);
                          HelperUtils.showSnackBarMessage(
                            context,
                            "Portfolio added",
                            type: MessageType.success,
                          );
                        }
                      },
                      child: const Text("Save"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReferenceFormSheet() {
    final nameCtrl = TextEditingController();
    final compCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add Reference",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 14),
              _buildFieldLabel("Reference Person Name *"),
              TextFormField(
                controller: nameCtrl,
                decoration: _inputDecoration("e.g. John Doe"),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel("Company Name"),
              TextFormField(
                controller: compCtrl,
                decoration: _inputDecoration("e.g. Previous Employer LLC"),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel("Email Address"),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration("e.g. manager@example.com"),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.color.borderColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        foregroundColor: context.color.textDefaultColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.color.territoryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (nameCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            _referencesList.add({
                              'name': nameCtrl.text.trim(),
                              'company': compCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                            });
                          });
                          Navigator.pop(ctx);
                          HelperUtils.showSnackBarMessage(
                            context,
                            "Reference added",
                            type: MessageType.success,
                          );
                        }
                      },
                      child: const Text("Save"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build Methods (Tile View)
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remainingSections = _calculateRemainingSections();
    final progress = _calculateProgress();
    final user = HiveUtils.getUserDetails();
    final userName = _nameController.text.isNotEmpty
        ? _nameController.text
        : (user.name ?? "Candidate");

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
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Hero Header
                    _buildTopHeroHeader(
                        userName, remainingSections, progress, user, isDark),

                    const SizedBox(height: 10),

                    // 2. Sections in Flat Tile View
                    Container(
                      color: context.color.secondaryColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section 1: Basic Info Tile (Requirement 3: rows without arrows once filled)
                          _buildBasicInfoTile(),
                          _buildTileDivider(),

                          // Section 2: Qualifications Tile
                          _buildQualificationTile(),
                          _buildTileDivider(),

                          // Section 3: Experience Tile
                          _buildExperienceTile(),
                          _buildTileDivider(),

                          // Section 4: Skills Tile
                          _buildSkillsTile(),
                          _buildTileDivider(),

                          // Section 5: Resume Tile
                          _buildResumeTile(),
                          _buildTileDivider(),

                          // Section 6: Digital Profile Tile
                          _buildDigitalProfileTile(),

                          // Section 7+: Dynamic added sections (Licences, Portfolio, Reference)
                          if (_licencesList.isNotEmpty) ...[
                            _buildTileDivider(),
                            _buildLicencesTile(),
                          ],
                          if (_portfoliosList.isNotEmpty) ...[
                            _buildTileDivider(),
                            _buildPortfolioTile(),
                          ],
                          if (_referencesList.isNotEmpty) ...[
                            _buildTileDivider(),
                            _buildReferenceTile(),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 3. "Add More Sections" Button (opens Image 2 Sheet)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        onTap: _showAddMoreSectionsBottomSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: context.color.secondaryColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.color.borderColor,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                color: context.color.territoryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Add More Sections",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: context.color.territoryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTileDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: context.color.borderColor.withValues(alpha: 0.4),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Hero Header
  // ---------------------------------------------------------------------------
  Widget _buildTopHeroHeader(String userName, int remainingSections,
      double progress, dynamic user, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                  context.color.secondaryColor,
                ]
              : [
                  const Color(0xFFE0F2FE),
                  const Color(0xFFF0F9FF),
                  context.color.secondaryColor,
                ],
        ),
        border: Border(
          bottom: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Avatar + Name + More Dropdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: user.profile != null && user.profile!.isNotEmpty
                      ? UiUtils.getImage(user.profile!, fit: BoxFit.cover)
                      : const Icon(
                          Icons.camera_alt_outlined,
                          color: Color(0xFF2563EB),
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  userName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                color: context.color.secondaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == "share") {
                    Share.share(
                        "Check out $userName's Job Profile on ${Constant.appName}");
                  } else if (value == "refresh") {
                    _loadJobProfile();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: "share",
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, size: 18),
                        SizedBox(width: 10),
                        Text("Share Profile"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: "refresh",
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 18),
                        SizedBox(width: 10),
                        Text("Refresh Details"),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? context.color.secondaryColor
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? context.color.borderColor
                          : const Color(0xFF93C5FD).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "More",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: context.color.textDefaultColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Remaining Sections & Progress
          Text(
            remainingSections > 0
                ? "$remainingSections Sections Remaining"
                : "Profile Completed 🎉",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFDBEAFE),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            "Complete candidate profiles get more attention from potential employers.",
            style: TextStyle(
              fontSize: 12.5,
              color: context.color.textLightColor,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          // Horizontal Quick Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildQuickChip(
                  icon: Icons.school_outlined,
                  label: "Qualifications",
                  onTap: _showQualificationsBottomSheet,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _buildQuickChip(
                  icon: Icons.work_outline_rounded,
                  label: "Experience",
                  onTap: _showExperienceBottomSheet,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _buildQuickChip(
                  icon: Icons.auto_graph_rounded,
                  label: "Skills",
                  onTap: _showSkillsBottomSheet,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _buildQuickChip(
                  icon: Icons.description_outlined,
                  label: "Resume",
                  onTap: _pickResumeFile,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _buildQuickChip(
                  icon: Icons.mic_none_rounded,
                  label: "Digital Profile",
                  onTap: _showDigitalProfileBottomSheet,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? context.color.secondaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? context.color.borderColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.color.textDefaultColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Basic Info Tile (Requirement 3: rows without arrows once selected)
  // ---------------------------------------------------------------------------
  Widget _buildBasicInfoTile() {
    final user = HiveUtils.getUserDetails();
    final name = _nameController.text.isNotEmpty
        ? _nameController.text
        : (user.name ?? "N/A");
    final email =
        _emailController.text.isNotEmpty ? _emailController.text : "N/A";
    final phone =
        _phoneController.text.isNotEmpty ? _phoneController.text : "N/A";
    final nationality = _nationalityController.text.trim();
    final languages = _languagesController.text.trim();
    final location = _locationController.text.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Basic Info",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: context.color.textLightColor,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: _showBasicInfoBottomSheet,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Standard Rows (No Arrow)
          _buildInfoRow("Full Name", name),
          const SizedBox(height: 8),
          _buildInfoRow("Email", email),
          const SizedBox(height: 8),
          _buildInfoRow("Phone", phone),

          // Dynamic selected fields: once selected, shown exactly like Name & Phone (no arrows)
          if (_visaStatus != null && _visaStatus!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow("Visa Status", _visaStatus!),
          ],
          if (_gender != null && _gender!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow("Gender", _gender!),
          ],
          if (nationality.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow("Nationality", nationality),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow("Location", location),
          ],
          if (languages.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow("Languages", languages),
          ],

          // Any unselected field shows as an "+ Add" action
          if (_visaStatus == null || _visaStatus!.isEmpty) ...[
            const SizedBox(height: 8),
            _buildAddClickable(
              label: "+ Add Visa Status",
              onTap: () => _showSingleFieldBottomSheet(
                title: "Visa Status",
                fieldKey: "visa_status",
                currentValue: _visaStatus,
                options: _visaStatuses,
              ),
            ),
          ],
          if (_gender == null || _gender!.isEmpty) ...[
            const SizedBox(height: 8),
            _buildAddClickable(
              label: "+ Add Gender",
              onTap: () => _showSingleFieldBottomSheet(
                title: "Gender",
                fieldKey: "gender",
                currentValue: _gender,
                options: _genders,
              ),
            ),
          ],
          if (nationality.isEmpty) ...[
            const SizedBox(height: 8),
            _buildAddClickable(
              label: "+ Add Nationality",
              onTap: () => _showSingleFieldBottomSheet(
                title: "Nationality",
                fieldKey: "nationality",
                currentValue: nationality,
              ),
            ),
          ],
          if (location.isEmpty) ...[
            const SizedBox(height: 8),
            _buildAddClickable(
              label: "+ Add Location",
              onTap: () => _showSingleFieldBottomSheet(
                title: "Location",
                fieldKey: "location",
                currentValue: location,
              ),
            ),
          ],
          if (languages.isEmpty) ...[
            const SizedBox(height: 8),
            _buildAddClickable(
              label: "+ Add Languages",
              onTap: () => _showSingleFieldBottomSheet(
                title: "Languages",
                fieldKey: "language",
                currentValue: languages,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Qualifications Tile (Supports Multiple Qualifications)
  // ---------------------------------------------------------------------------
  Widget _buildQualificationTile() {
    final hasQuals = _qualificationsList.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Qualifications",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              InkWell(
                onTap: () => _showQualificationsBottomSheet(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: context.color.territoryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Add",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.color.territoryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasQuals) ...[
            InkWell(
              onTap: () => _showQualificationsBottomSheet(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 24,
                    color: context.color.textLightColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Add your academic qualification details such as School, Undergrad and Post graduation degree.",
                      style: TextStyle(
                        fontSize: 13.5,
                        color: context.color.textLightColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Column(
              children: List.generate(_qualificationsList.length, (index) {
                final q = _qualificationsList[index];
                final degree = q['degree']?.toString() ?? '';
                final spec = q['specialization']?.toString() ?? '';
                final uni = q['university_name']?.toString() ?? '';
                final country = q['country']?.toString() ?? '';
                final fromYear = q['graduation_from']?.toString() ?? '';
                final toYear = q['graduation_to']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 22,
                        color: context.color.territoryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (degree.isNotEmpty)
                              Text(
                                degree,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: context.color.textDefaultColor,
                                ),
                              ),
                            if (spec.isNotEmpty)
                              Text(
                                spec,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.color.textDefaultColor,
                                ),
                              ),
                            if (uni.isNotEmpty || country.isNotEmpty)
                              Text(
                                "$uni${uni.isNotEmpty && country.isNotEmpty ? ', ' : ''}$country",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: context.color.textLightColor,
                                ),
                              ),
                            if (fromYear.isNotEmpty || toYear.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  "Graduation: $fromYear - $toYear",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.color.textLightColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: context.color.textLightColor,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showQualificationsBottomSheet(
                              initialData: q,
                              editIndex: index,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _qualificationsList.removeAt(index);
                              });
                              _saveJobProfileData();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Experience Tile (Supports Multiple Experiences)
  // ---------------------------------------------------------------------------
  Widget _buildExperienceTile() {
    final hasExps = _experiencesList.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Experience",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              InkWell(
                onTap: () => _showExperienceBottomSheet(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: context.color.territoryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Add",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.color.territoryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasExps) ...[
            InkWell(
              onTap: () => _showExperienceBottomSheet(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.work_outline_rounded,
                    size: 24,
                    color: context.color.textLightColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Add your current and past work experiences.",
                      style: TextStyle(
                        fontSize: 13.5,
                        color: context.color.textLightColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Column(
              children: List.generate(_experiencesList.length, (index) {
                final exp = _experiencesList[index];
                final isFresher = exp['fresher'] == 1 ||
                    exp['fresher'] == "1" ||
                    exp['fresher'] == true;
                final title =
                    exp['experience_job_titel']?.toString() ?? '';
                final company =
                    exp['experience_company']?.toString() ?? '';
                final category =
                    exp['experience_job_category']?.toString() ?? '';
                final start =
                    exp['experience_start_date']?.toString() ?? '';
                final end =
                    exp['experience_end_date']?.toString() ?? '';
                final currentlyWorking = exp['currently_working'] == 1 ||
                    exp['currently_working'] == "1" ||
                    exp['currently_working'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isFresher
                            ? Icons.school_outlined
                            : Icons.work_outline_rounded,
                        size: 22,
                        color: context.color.territoryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isFresher) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "Fresher",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ] else ...[
                              if (title.isNotEmpty)
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                              if (company.isNotEmpty)
                                Text(
                                  company,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                              if (category.isNotEmpty)
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.color.textLightColor,
                                  ),
                                ),
                              if (start.isNotEmpty || end.isNotEmpty || currentlyWorking)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    "$start - ${currentlyWorking ? 'Present' : end}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: context.color.textLightColor,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _showExperienceBottomSheet(
                              initialData: exp,
                              editIndex: index,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _experiencesList.removeAt(index);
                              });
                              _saveJobProfileData();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Skills Tile
  // ---------------------------------------------------------------------------
  Widget _buildSkillsTile() {
    final hasSkills = _skillsList.isNotEmpty || _jobCategory != null;

    return InkWell(
      onTap: _showSkillsBottomSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Skills",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                Icon(
                  hasSkills ? Icons.edit_outlined : Icons.add_rounded,
                  size: 20,
                  color: context.color.textLightColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_graph_rounded,
                  size: 24,
                  color: hasSkills
                      ? context.color.territoryColor
                      : context.color.textLightColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: hasSkills
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_jobCategory != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _jobCategory!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                            if (_skillsList.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _skillsList.map((s) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: context.color.backgroundColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: context.color.borderColor),
                                    ),
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.color.textDefaultColor,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        )
                      : Text(
                          "Add your technical or soft skills such as Salesforce, Communication skills etc.",
                          style: TextStyle(
                            fontSize: 13.5,
                            color: context.color.textLightColor,
                            height: 1.4,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Resume Tile
  // ---------------------------------------------------------------------------
  Widget _buildResumeTile() {
    final hasResume = _resumeFile != null ||
        (_existingResumeUrl != null && _existingResumeUrl!.isNotEmpty);

    return InkWell(
      onTap: _pickResumeFile,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Resume",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                Icon(
                  hasResume ? Icons.edit_outlined : Icons.add_rounded,
                  size: 20,
                  color: context.color.textLightColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 24,
                  color:
                      hasResume ? Colors.green : context.color.textLightColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: hasResume
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _resumeFile != null
                                  ? _resumeFile!.path
                                      .split(Platform.pathSeparator)
                                      .last
                                  : "Uploaded Resume",
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            if (_existingResumeUrl != null &&
                                _existingResumeUrl!.isNotEmpty &&
                                _resumeFile == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: InkWell(
                                  onTap: () async {
                                    final uri =
                                        Uri.parse(_existingResumeUrl!);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode:
                                              LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Text(
                                    "Preview Uploaded Resume",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.color.territoryColor,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Text(
                          "Upload your most recent resume.",
                          style: TextStyle(
                            fontSize: 13.5,
                            color: context.color.textLightColor,
                            height: 1.4,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Digital Profile Tile
  // ---------------------------------------------------------------------------
  Widget _buildDigitalProfileTile() {
    final hasDigital = _audioIntroPath != null || _videoIntroPath != null;

    return InkWell(
      onTap: _showDigitalProfileBottomSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Digital Profile",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                Icon(
                  hasDigital ? Icons.edit_outlined : Icons.add_rounded,
                  size: 20,
                  color: context.color.textLightColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.mic_none_rounded,
                  size: 24,
                  color: hasDigital
                      ? const Color(0xFFE50914)
                      : context.color.textLightColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: hasDigital
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_audioIntroPath != null)
                              Row(
                                children: [
                                  const Icon(Icons.mic,
                                      size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Audio Introduction Recorded",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.color.textDefaultColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            if (_videoIntroPath != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.videocam,
                                        size: 16, color: Color(0xFFE50914)),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Video Introduction Recorded",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.color.textDefaultColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : Text(
                          "Add your audio and video introduction to grab potential employers attention.",
                          style: TextStyle(
                            fontSize: 13.5,
                            color: context.color.textLightColor,
                            height: 1.4,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Additional Dynamic Tiles (Licences, Portfolio, Reference)
  // ---------------------------------------------------------------------------
  Widget _buildLicencesTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Licences or Certificates",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                color: context.color.textLightColor,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: _showLicenceFormSheet,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._licencesList.map((lic) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.military_tech_outlined,
                      size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lic['name'] ?? '',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        if (lic['org'] != null && lic['org']!.isNotEmpty)
                          Text(
                            lic['org']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.color.textLightColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPortfolioTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Portfolio",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                color: context.color.textLightColor,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: _showPortfolioFormSheet,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._portfoliosList.map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded,
                      size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'] ?? '',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        if (p['link'] != null && p['link']!.isNotEmpty)
                          Text(
                            p['link']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.color.territoryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReferenceTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Reference",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                color: context.color.textLightColor,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: _showReferenceFormSheet,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._referencesList.map((ref) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref['name'] ?? '',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        if (ref['company'] != null &&
                            ref['company']!.isNotEmpty)
                          Text(
                            ref['company']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.color.textLightColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers & UI Primitives
  // ---------------------------------------------------------------------------
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.color.textLightColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: context.color.textDefaultColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddClickable({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2563EB),
          ),
        ),
      ),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: context.color.borderColor.withValues(alpha: 0.8),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: context.color.borderColor.withValues(alpha: 0.8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: context.color.territoryColor,
          width: 1.5,
        ),
      ),
    );
  }
}
