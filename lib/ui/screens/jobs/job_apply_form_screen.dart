import 'dart:io';
import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
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
  final List<CustomFieldModel>? customFields;

  const JobApplyFormScreen({
    super.key,
    required this.itemId,
    this.itemTitle,
    this.categoryName,
    this.customFields,
  });

  static Route route(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>? ?? {};
    return CupertinoPageRoute(
      builder: (context) => JobApplyFormScreen(
        itemId: args['itemId'] ?? 0,
        itemTitle: args['itemTitle'],
        categoryName: args['categoryName'],
        customFields: args['customFields'] as List<CustomFieldModel>?,
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
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();

  String _phoneCountryCode = "971";
  String _phoneCountryFlag = "🇦🇪";

  String _nationality = "Emirati";
  String _gender = "Male";
  String _visaStatus = "Employment";
  String _educationLevel = "Bachelors Degree";
  String _totalExperience = "1-2 Years";
  String _jobStatus = "Experienced";
  String _jobCategory = "Information Technology";
  String _industry = "Information Technology";
  String _noticePeriod = "Available Immediately";
  String _employmentType = "Full Time";
  String _remotePreference = "No";

  File? _resumeFile;
  String? _existingResumeUrl;

  List<String> _genders = ["Male", "Female", "Any", "Other"];
  final List<String> _visaStatuses = [
    "Employment",
    "Tourist",
    "Residence",
    "Visit",
    "Student",
    "Citizen",
    "Golden Visa",
  ];
  List<String> _educationLevels = [
    "High School / Secondary",
    "Diploma",
    "Graduate",
    "Bachelors Degree",
    "Masters Degree",
    "BE",
    "Bsc",
    "Doctorate",
  ];
  List<String> _experiences = [
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
  List<String> _categories = [
    "Information Technology",
    "Accounting & Finance",
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
  List<String> _employmentTypes = ["Full Time", "Part Time", "Contract"];
  List<String> _remoteOptions = ["Yes", "No"];
  final List<String> _noticePeriods = [
    "Available Immediately",
    "1 Month",
    "2 Months",
    "3 Months",
  ];

  List<String> _nationalities = [
    "Emirati",
    "Afghan",
    "Albanian",
    "Algerian",
    "American",
    "Andorran",
    "Angolan",
    "Antiguan and Barbudan",
    "Argentine",
    "Armenian",
    "Australian",
    "Austrian",
    "Azerbaijani",
    "Bahamian",
    "Bahraini",
    "Bangladeshi",
    "Barbadian",
    "Belarusian",
    "Belgian",
    "Belizean",
    "Beninese",
    "Bhutanese",
    "Bolivian",
    "Bosnian and Herzegovinian",
    "Botswanan",
    "Brazilian",
    "British",
    "Bruneian",
    "Bulgarian",
    "Burkinabe",
    "Burmese",
    "Burundian",
    "Cabo Verdean",
    "Cambodian",
    "Cameroonian",
    "Canadian",
    "Central African",
    "Chadian",
    "Chilean",
    "Chinese",
    "Colombian",
    "Comorian",
    "Congolese",
    "Costa Rican",
    "Croatian",
    "Cuban",
    "Cypriot",
    "Czech",
    "Danish",
    "Djiboutian",
    "Dominican",
    "East Timorese",
    "Ecuadorean",
    "Egyptian",
    "Salvadoran",
    "Equatorial Guinean",
    "Eritrean",
    "Estonian",
    "Eswatini",
    "Ethiopian",
    "Fijian",
    "Finnish",
    "French",
    "Gabonese",
    "Gambian",
    "Georgian",
    "German",
    "Ghanaian",
    "Greek",
    "Grenadian",
    "Guatemalan",
    "Guinean",
    "Guyanese",
    "Haitian",
    "Honduran",
    "Hungarian",
    "Icelander",
    "Indian",
    "Indonesian",
    "Iranian",
    "Iraqi",
    "Irish",
    "Israeli",
    "Italian",
    "Ivorian",
    "Jamaican",
    "Japanese",
    "Jordanian",
    "Kazakh",
    "Kenyan",
    "Kiribati",
    "North Korean",
    "South Korean",
    "Kuwaiti",
    "Kyrgyz",
    "Laotian",
    "Latvian",
    "Lebanese",
    "Liberian",
    "Libyan",
    "Liechtenstein",
    "Lithuanian",
    "Luxembourgish",
    "Malagasy",
    "Malawian",
    "Malaysian",
    "Maldivian",
    "Malian",
    "Maltese",
    "Marshallese",
    "Mauritanian",
    "Mauritian",
    "Mexican",
    "Micronesian",
    "Moldovan",
    "Monegasque",
    "Mongolian",
    "Montenegrin",
    "Moroccan",
    "Mozambican",
    "Namibian",
    "Nauruan",
    "Nepalese",
    "Dutch",
    "New Zealander",
    "Nicaraguan",
    "Nigerien",
    "Nigerian",
    "North Macedonian",
    "Norwegian",
    "Omani",
    "Pakistani",
    "Palauan",
    "Palestinian",
    "Panamanian",
    "Papua New Guinean",
    "Paraguayan",
    "Peruvian",
    "Filipino",
    "Polish",
    "Portuguese",
    "Qatari",
    "Romanian",
    "Russian",
    "Rwandan",
    "Saint Kitts and Nevis",
    "Saint Lucian",
    "Saint Vincent and the Grenadines",
    "Samoan",
    "San Marinese",
    "Sao Tomean",
    "Saudi",
    "Senegalese",
    "Serbian",
    "Seychellois",
    "Sierra Leonean",
    "Singaporean",
    "Slovak",
    "Slovenian",
    "Solomon Islander",
    "Somali",
    "South African",
    "South Sudanese",
    "Spanish",
    "Sri Lankan",
    "Sudanese",
    "Surinamese",
    "Swedish",
    "Swiss",
    "Syrian",
    "Taiwanese",
    "Tajik",
    "Tanzanian",
    "Thai",
    "Togolese",
    "Tongan",
    "Trinidadian and Tobagonian",
    "Tunisian",
    "Turkish",
    "Turkmen",
    "Tuvaluan",
    "Ugandan",
    "Ukrainian",
    "Uruguayan",
    "Uzbek",
    "Vanuatu",
    "Vatican",
    "Venezuelan",
    "Vietnamese",
    "Yemeni",
    "Zambian",
    "Zimbabwean"
  ];

  // Dynamic values captured for any extra custom fields
  final Map<int, dynamic> _customFieldAnswers = {};
  final Map<int, TextEditingController> _customFieldTextControllers = {};
  late final List<CustomFieldModel> _applicationFields;
  CustomFieldModel? _cvRequirementField;

  @override
  void initState() {
    super.initState();
    _extractDynamicOptionsFromJobAd();
    _loadPreviousJobApplicationInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    for (final c in _customFieldTextControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _extractDynamicOptionsFromJobAd() {
    final selected = <String, CustomFieldModel>{};
    for (final field in widget.customFields ?? const <CustomFieldModel>[]) {
      if (field.id == null) continue;
      final name = _normalizeFieldName(field.name ?? field.label ?? '');
      if (_isCvField(name)) {
        _cvRequirementField = field;
        continue;
      }
      final key = _applicationParameterFor(name);
      if (key != null &&
          (!selected.containsKey(key) || !name.startsWith('minimum '))) {
        selected[key] = field;
      }
    }
    _applicationFields = selected.values.toList(growable: false);
    for (final field in _applicationFields) {
      if (_parseFieldValues(field.values).isEmpty) {
        _customFieldTextControllers[field.id!] = TextEditingController();
      }
    }
    /* Legacy static option mapping intentionally disabled. The live form uses
       only the fields and values present in the get-item response.
    final fields = widget.customFields;
    if (fields == null || fields.isEmpty) return;

    for (final field in fields) {
      final name = (field.name ?? "").toLowerCase();
      final values = _parseFieldValues(field.values);

      if (values.isNotEmpty) {
        if (name.contains("nationality")) {
          _nationalities = values;
          if (!_nationalities.contains(_nationality)) {
            _nationality = _nationalities.first;
          }
        } else if (name.contains("gender")) {
          _genders = values;
          if (!_genders.contains(_gender)) {
            _gender = _genders.first;
          }
        } else if (name.contains("employment type")) {
          _employmentTypes = values;
          if (!_employmentTypes.contains(_employmentType)) {
            _employmentType = _employmentTypes.first;
          }
        } else if (name.contains("experience")) {
          _experiences = values;
          if (!_experiences.contains(_totalExperience)) {
            _totalExperience = _experiences.first;
          }
        } else if (name.contains("education") || name.contains("qualification")) {
          _educationLevels = values;
          if (!_educationLevels.contains(_educationLevel)) {
            _educationLevel = _educationLevels.first;
          }
        } else if (name.contains("industry")) {
          _categories = values;
          if (!_categories.contains(_jobCategory)) {
            _jobCategory = _categories.first;
            _industry = _categories.first;
          }
        } else if (name.contains("remote")) {
          _remoteOptions = values;
          if (!_remoteOptions.contains(_remotePreference)) {
            _remotePreference = _remoteOptions.first;
          }
        }
      }
    }
    */
  }

  String _normalizeFieldName(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _isCvField(String name) =>
      name == 'cv required' ||
      name == 'resume required' ||
      name == 'cv' ||
      name == 'resume';

  String? _applicationParameterFor(String name) {
    if (name == 'full name' || name == 'name') return 'full_name';
    if (name == 'email' || name == 'email address') return 'email_id';
    if (name == 'phone' || name == 'phone number' || name == 'mobile') {
      return 'phone_no';
    }
    if (name == 'gender') return 'gender';
    if (name == 'nationality') return 'nationality';
    if (name == 'visa status') return 'visa_status';
    if (name == 'education qualifications' ||
        name == 'education qualification' ||
        name == 'education level' ||
        name == 'minimum education level') {
      return 'education_level';
    }
    if (name == 'total experience' ||
        name == 'work experience' ||
        name == 'minimum work experience') {
      return 'total_experience';
    }
    if (name == 'current location' || name == 'currently located') {
      return 'currentlt_locate';
    }
    if (name == 'job status') return 'job_status';
    if (name == 'current company' || name == 'current latest company') {
      return 'current_company';
    }
    if (name == 'current position' || name == 'current job title') {
      return 'current_position';
    }
    if (name == 'notice period') return 'notice_period';
    if (name == 'skills' || name == 'skill') return 'skills';
    return null;
  }

  List<String> _parseFieldValues(dynamic values) {
    if (values == null) return [];
    if (values is List) {
      return values
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (values is String) {
      return values
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  bool get _isCvRequired {
    final values = _cvRequirementField?.value ?? const [];
    return values.any(
      (value) => _normalizeFieldName(value.toString()) == 'yes',
    );
  }

  bool _isEmptyAnswer(dynamic answer) {
    if (answer == null) return true;
    if (answer is String) return answer.trim().isEmpty;
    if (answer is Iterable) return answer.isEmpty;
    return false;
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
        (c) =>
            c.toLowerCase().contains(widget.categoryName!.toLowerCase()) ||
            widget.categoryName!.toLowerCase().contains(c.toLowerCase()),
        orElse: () => _categories.first,
      );
      _jobCategory = matchedCat;
      _industry = matchedCat;
    }

    // 1. Fetch Candidate Saved Profile Details
    try {
      final userDetail = await _jobRepository.fetchUserDetail();
      if (userDetail != null && mounted) {
        setState(() {
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
          if (userDetail['nationality'] != null &&
              userDetail['nationality'].toString().isNotEmpty) {
            final nat = userDetail['nationality'].toString();
            if (!_nationalities.contains(nat)) {
              _nationalities.insert(0, nat);
            }
            _nationality = nat;
          }
          if (userDetail['current_location'] != null &&
              userDetail['current_location'].toString().isNotEmpty) {
            _locationController.text =
                userDetail['current_location'].toString();
          }
          if (userDetail['gender'] != null) {
            final g = userDetail['gender'].toString();
            if (_genders.contains(g)) _gender = g;
          }
          if (userDetail['visa_status'] != null) {
            final v = userDetail['visa_status'].toString();
            if (_visaStatuses.contains(v)) _visaStatus = v;
          }
          if (userDetail['experience_company'] != null) {
            _companyController.text =
                userDetail['experience_company'].toString();
          }
          if (userDetail['experience_job_titel'] != null) {
            _positionController.text =
                userDetail['experience_job_titel'].toString();
          }
          if (userDetail['resume'] != null &&
              userDetail['resume'].toString().isNotEmpty) {
            _existingResumeUrl = userDetail['resume'].toString();
          }
        });
      }
    } catch (_) {}

    // 2. Fetch prior Job Application Info
    try {
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
            final nat = info.nationality!;
            if (!_nationalities.contains(nat)) {
              _nationalities.insert(0, nat);
            }
            _nationality = nat;
          }
          if (info.currentlyLocated != null &&
              info.currentlyLocated!.isNotEmpty) {
            _locationController.text = info.currentlyLocated!;
          }
          if (info.currentCompany != null && info.currentCompany!.isNotEmpty) {
            _companyController.text = info.currentCompany!;
          }
          if (info.currentPosition != null &&
              info.currentPosition!.isNotEmpty) {
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
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showCountryCodePicker() {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      showPhoneCode: true,
      favorite: const [
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
        'AU'
      ],
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

  void _showNationalityPickerModal() {
    final searchCtrl = TextEditingController();
    List<String> filteredList = List.from(_nationalities);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.color.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Select Nationality",
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchCtrl,
                      style: TextStyle(color: context.color.textDefaultColor),
                      decoration: InputDecoration(
                        hintText: "Search nationality...",
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: context.color.backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: context.color.borderColor),
                        ),
                      ),
                      onChanged: (query) {
                        setModalState(() {
                          filteredList = _nationalities
                              .where((n) => n
                                  .toLowerCase()
                                  .contains(query.trim().toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredList.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color:
                              context.color.borderColor.withValues(alpha: 0.5),
                        ),
                        itemBuilder: (context, index) {
                          final nat = filteredList[index];
                          final isSelected = _nationality == nat;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            title: Text(
                              nat,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? context.color.territoryColor
                                    : context.color.textDefaultColor,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded,
                                    color: context.color.territoryColor,
                                    size: 20)
                                : null,
                            onTap: () {
                              setState(() {
                                _nationality = nat;
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
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

  Future<void> _pickResumeFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result.isNotEmpty && result.first.path != null) {
      setState(() {
        _resumeFile = File(result.first.path!);
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isCvRequired && _resumeFile == null && _existingResumeUrl == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please attach your CV',
        type: MessageType.error,
      );
      return;
    }

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
        'nationality': _nationality,
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
        'employment_type': _employmentType,
        'remote_preference': _remotePreference,
      };

      // Do not send fallback/static answers. Only the item id and answers to
      // questions actually supplied by get-item belong to this application.
      data
        ..clear()
        ..['item_id'] = widget.itemId;
      for (final field in _applicationFields) {
        final answer = _customFieldAnswers[field.id!];
        if (_isEmptyAnswer(answer)) continue;
        final parameter = _applicationParameterFor(
          _normalizeFieldName(field.name ?? field.label ?? ''),
        );
        if (parameter != null && parameter != 'skills') {
          data[parameter] = answer is List ? answer.join(', ') : answer;
        }
      }

      // Add dynamic custom field answers
      _customFieldAnswers.forEach((key, value) {
        data['custom_fields[$key]'] = value;
      });

      final response = await _jobRepository.saveJobApplicationInfo(
        data,
        resumeFile: _resumeFile,
      );

      if (response['error'] == true) {
        throw ApiException(response['message']?.toString() ??
            "Failed to submit job application");
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
                padding: const EdgeInsets.only(bottom: 40),
                child: _isSubmitted ? _buildSuccessView() : _buildApiFormView(),
              ),
            ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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

  Widget _buildApiFormView() {
    final hasFields = _applicationFields.isNotEmpty;
    final hasCv = _cvRequirementField != null;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildJobHeaderTile(),
          const SizedBox(height: 12),
          if (hasFields)
            Container(
              color: context.color.secondaryColor,
              child: _buildSectionTile(
                title: 'Application Details',
                subtitle: 'Complete the details requested for this job',
                icon: Icons.assignment_ind_outlined,
                children: _applicationFields
                    .map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildApiField(field),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          if (hasFields && hasCv) _buildTileDivider(),
          if (hasCv)
            Container(
              color: context.color.secondaryColor,
              child: _buildSectionTile(
                title: 'Resume / CV Attachment',
                subtitle: _isCvRequired
                    ? 'A CV is required for this job'
                    : 'Attach a CV if you want to include one',
                icon: Icons.description_outlined,
                children: [_buildApiResumeField()],
              ),
            ),
          if (!hasFields && !hasCv)
            Container(
              width: double.infinity,
              color: context.color.secondaryColor,
              padding: const EdgeInsets.all(24),
              child: const Text(
                'No additional details are required for this job.',
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
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
                    : const Text('Submit Application'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiField(CustomFieldModel field) {
    final fieldId = field.id!;
    final label = (field.name ?? field.label ?? 'Field').trim();
    final isRequired = field.required == 1;
    final options = _parseFieldValues(field.values);
    final displayLabel = isRequired ? '$label *' : label;

    if (options.isNotEmpty && field.isFieldMultiselect == true) {
      return FormField<List<String>>(
        validator: (_) =>
            isRequired && _isEmptyAnswer(_customFieldAnswers[fieldId])
                ? 'Please select $label'
                : null,
        builder: (state) {
          final selected = (_customFieldAnswers[fieldId] as List?)
                  ?.map((value) => value.toString())
                  .toList() ??
              const <String>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel(displayLabel),
              InkWell(
                onTap: () => _showApiMultiSelect(field),
                child: InputDecorator(
                  decoration: _inputDecoration('').copyWith(
                    errorText: state.errorText,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selected.isEmpty
                              ? 'Select $label'
                              : selected.join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected.isEmpty
                                ? context.color.textLightColor
                                : context.color.textDefaultColor,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    if (options.isNotEmpty) {
      final selected = _customFieldAnswers[fieldId] as String?;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(displayLabel),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: options.contains(selected) ? selected : null,
            hint: Text('Select $label'),
            dropdownColor: context.color.secondaryColor,
            decoration: _inputDecoration(''),
            items: options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      option,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            validator: (value) => isRequired && _isEmptyAnswer(value)
                ? 'Please select $label'
                : null,
            onChanged: (value) => setState(
              () => _customFieldAnswers[fieldId] = value,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(displayLabel),
        TextFormField(
          controller: _customFieldTextControllers[fieldId],
          maxLength: field.maxLength,
          minLines: field.type == 'textarea' ? 3 : 1,
          maxLines: field.type == 'textarea' ? 5 : 1,
          decoration: _inputDecoration('Enter $label'),
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'Please enter $label';
            }
            if (value != null &&
                field.minLength != null &&
                value.trim().length < field.minLength!) {
              return '$label must be at least ${field.minLength} characters';
            }
            return null;
          },
          onChanged: (value) => _customFieldAnswers[fieldId] = value.trim(),
        ),
      ],
    );
  }

  Future<void> _showApiMultiSelect(CustomFieldModel field) async {
    final options = _parseFieldValues(field.values);
    final selected = <String>{
      ...((_customFieldAnswers[field.id!] as List?)
              ?.map((value) => value.toString()) ??
          const <String>[]),
    };
    final searchController = TextEditingController();
    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = options
              .where((option) => option.toLowerCase().contains(query))
              .toList(growable: false);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: searchController,
                      decoration: _inputDecoration(
                        'Search ${field.name ?? field.label ?? ''}',
                      ),
                      onChanged: (value) => setModalState(
                        () => query = value.trim().toLowerCase(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        return CheckboxListTile(
                          value: selected.contains(option),
                          title: Text(option),
                          onChanged: (checked) => setModalState(() {
                            checked == true
                                ? selected.add(option)
                                : selected.remove(option);
                          }),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _customFieldAnswers[field.id!] =
                              selected.toList());
                          Navigator.pop(modalContext);
                        },
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
  }

  Widget _buildApiResumeField() {
    return Column(
      children: [
        if (_existingResumeUrl?.isNotEmpty == true && _resumeFile == null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: context.color.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.color.borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined),
                const SizedBox(width: 10),
                const Expanded(child: Text('Use profile saved resume')),
                TextButton(
                  onPressed: () async {
                    final uri = Uri.tryParse(_existingResumeUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: const Text('Preview'),
                ),
              ],
            ),
          ),
        InkWell(
          onTap: _pickResumeFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.color.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.color.borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  _resumeFile == null
                      ? Icons.cloud_upload_outlined
                      : Icons.check_circle_rounded,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _resumeFile == null
                        ? 'Upload CV (PDF, DOC, DOCX)'
                        : _resumeFile!.path.split(Platform.pathSeparator).last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Kept temporarily for source compatibility while the API-only renderer is
  // exercised in production; it is never used by this screen.
  // ignore: unused_element
  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Job Info Header Tile
          _buildJobHeaderTile(),

          const SizedBox(height: 12),

          // 2. Main Sections in Unified Flat Tile Group
          Container(
            color: context.color.secondaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Personal Information Tile
                _buildSectionTile(
                  title: "Personal Information",
                  subtitle: "Your basic contact and identity details",
                  icon: Icons.person_outline_rounded,
                  children: [
                    _buildFieldLabel("Full Name *"),
                    TextFormField(
                      controller: _nameController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? "Please enter full name"
                          : null,
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
                              color: context.color.backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: context.color.borderColor
                                    .withValues(alpha: 0.8),
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
                            validator: (v) => v == null || v.trim().isEmpty
                                ? "Please enter phone"
                                : null,
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
                              _buildFieldLabel("Nationality *"),
                              InkWell(
                                onTap: _showNationalityPickerModal,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: context.color.backgroundColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: context.color.borderColor
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _nationality,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color:
                                                context.color.textDefaultColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: context.color.textLightColor,
                                      ),
                                    ],
                                  ),
                                ),
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

                _buildTileDivider(),

                // Section 2: Professional Details Tile
                _buildSectionTile(
                  title: "Professional Details",
                  subtitle:
                      "Career status, experience, and educational background",
                  icon: Icons.school_outlined,
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("Employment Type"),
                              _buildDropdown(
                                value: _employmentType,
                                items: _employmentTypes,
                                onChanged: (v) =>
                                    setState(() => _employmentType = v!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("Remote Preference"),
                              _buildDropdown(
                                value: _remotePreference,
                                items: _remoteOptions,
                                onChanged: (v) =>
                                    setState(() => _remotePreference = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildFieldLabel("Job Category / Industry *"),
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

                _buildTileDivider(),

                // Section 3: Current Employment Tile
                _buildSectionTile(
                  title: "Current Employment",
                  subtitle: "Present company and joining availability",
                  icon: Icons.work_outline_rounded,
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

                _buildTileDivider(),

                // Section 4: Resume / CV Tile
                _buildSectionTile(
                  title: "Resume / CV Attachment",
                  subtitle: "Upload or use your saved resume file",
                  icon: Icons.description_outlined,
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
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: context.color.territoryColor
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.description_outlined,
                                color: context.color.territoryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Profile Saved Resume",
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.color.textDefaultColor,
                                    ),
                                  ),
                                  Text(
                                    "Will be attached automatically",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final uri = Uri.parse(_existingResumeUrl!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text(
                                  "Preview",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: context.color.territoryColor,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
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
                            vertical: 16, horizontal: 16),
                        decoration: BoxDecoration(
                          color: context.color.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _resumeFile != null
                                ? const Color(0xFF10B981)
                                : context.color.borderColor,
                            width: _resumeFile != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _resumeFile != null
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.12)
                                    : context.color.territoryColor
                                        .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _resumeFile != null
                                    ? Icons.check_circle_rounded
                                    : Icons.cloud_upload_outlined,
                                size: 22,
                                color: _resumeFile != null
                                    ? const Color(0xFF10B981)
                                    : context.color.territoryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _resumeFile != null
                                        ? _resumeFile!.path
                                            .split(Platform.pathSeparator)
                                            .last
                                        : "Upload Custom CV for this Job",
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.color.textDefaultColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _resumeFile != null
                                        ? "Tap to replace document"
                                        : "PDF, DOC, DOCX (Max 10MB)",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: context.color.textLightColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Security Note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: context.color.textLightColor,
                ),
                const SizedBox(width: 6),
                Text(
                  "Your application is securely sent to the employer",
                  style: TextStyle(
                    fontSize: 12,
                    color: context.color.textLightColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Submit Application Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.color.territoryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildJobHeaderTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border(
          bottom: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? context.color.territoryColor.withValues(alpha: 0.15)
                  : const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.work_outline_rounded,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.categoryName ?? "Jobs",
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "• Quick Apply",
                      style: TextStyle(
                        fontSize: 12,
                        color: context.color.textLightColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: context.color.territoryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    Text(
                      subtitle,
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
          const SizedBox(height: 16),
          ...children,
        ],
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

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveValue =
        items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: effectiveValue,
      dropdownColor: context.color.secondaryColor,
      decoration: _inputDecoration(""),
      items: items.toSet().toList().map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
