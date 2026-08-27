import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Ebozor/data/repositories/job_repository.dart';
import 'package:Ebozor/ui/screens/jobs/introduction_recording_screen.dart';
import 'package:Ebozor/ui/screens/widgets/image_cropper.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/utils/validator.dart';

enum _JobProfilePhotoAction { view, camera, gallery, remove }



String _firstNonEmptyProfileValue(
  Map<dynamic, dynamic> entry,
  List<String> keys,
) {
  for (final key in keys) {
    final value = entry[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return '';
}

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
  bool _isUpdatingProfilePhoto = false;
  File? _profilePhotoPreview;

  AudioPlayer? _audioPlayer;
  bool _isPlayingAudio = false;

  // Basic Info Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nationalityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _languagesController = TextEditingController();
  final List<String> _languagesList = [];
  String? _gender;
  String? _visaStatus;

  String _phoneCountryCode = "971";
  String _phoneCountryFlag = "🇦🇪";

  // Qualifications list (supports multiple)
  final List<Map<String, dynamic>> _qualificationsList = [];
  String? _educationLevel;
  final TextEditingController _specializationController =
      TextEditingController();
  final TextEditingController _universityController = TextEditingController();
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
  String _profileSummary = '';
  String? _jobAvailability;

  static const List<String> _availabilityOptions = [
    'Immediate',
    'Actively Looking',
  ];

  bool get _hasAddableMoreSections =>
      _licencesList.isEmpty ||
      _portfoliosList.isEmpty ||
      _referencesList.isEmpty;

  String _truncateSummaryWords(String text, int maxWords) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length <= maxWords) return text;
    return "${words.take(maxWords).join(' ')}...";
  }

  // Static options
  static const List<String> _allLanguages = [
    "Arabic",
    "Bengali",
    "Chinese (Mandarin)",
    "Dutch",
    "English",
    "French",
    "German",
    "Gujarati",
    "Hindi",
    "Indonesian",
    "Italian",
    "Japanese",
    "Kannada",
    "Korean",
    "Malay",
    "Malayalam",
    "Marathi",
    "Persian (Farsi)",
    "Polish",
    "Portuguese",
    "Punjabi",
    "Russian",
    "Spanish",
    "Swahili",
    "Tagalog (Filipino)",
    "Tamil",
    "Telugu",
    "Thai",
    "Turkish",
    "Ukrainian",
    "Urdu",
    "Vietnamese",
  ];
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
    _audioPlayer?.dispose();
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

  void _showProfilePhotoViewDialog({String? imageUrl, File? imageFile}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: imageFile != null
                      ? Image.file(
                          imageFile,
                          fit: BoxFit.contain,
                        )
                      : (imageUrl != null && imageUrl.isNotEmpty)
                          ? UiUtils.getImage(
                              imageUrl,
                              fit: BoxFit.contain,
                            )
                          : const Icon(
                              Icons.person,
                              size: 100,
                              color: Colors.white70,
                            ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showProfilePhotoPicker() async {
    final hasProfilePhoto = _profilePhotoPreview != null ||
        (HiveUtils.getUserDetails().profile ?? '').isNotEmpty;
    final action = await showModalBottomSheet<_JobProfilePhotoAction>(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: context.color.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (hasProfilePhoto)
                  ListTile(
                    leading: const Icon(Icons.visibility_outlined),
                    title: const Text('View current photo'),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      _JobProfilePhotoAction.view,
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a new photo'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _JobProfilePhotoAction.camera,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from your library'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _JobProfilePhotoAction.gallery,
                  ),
                ),
                if (hasProfilePhoto)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Remove photo',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      _JobProfilePhotoAction.remove,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _JobProfilePhotoAction.view:
        final user = HiveUtils.getUserDetails();
        _showProfilePhotoViewDialog(
          imageUrl: user.profile,
          imageFile: _profilePhotoPreview,
        );
        break;
      case _JobProfilePhotoAction.camera:
        await _pickAndUploadProfilePhoto(ImageSource.camera);
        break;
      case _JobProfilePhotoAction.gallery:
        await _pickAndUploadProfilePhoto(ImageSource.gallery);
        break;
      case _JobProfilePhotoAction.remove:
        await _removeProfilePhoto();
        break;
    }
  }

  Future<void> _pickAndUploadProfilePhoto(ImageSource source) async {
    CropImage.init(context);
    final pickedPhoto = await ImagePicker().pickImage(source: source);
    if (pickedPhoto == null || !mounted) return;

    final croppedPhoto = await CropImage.crop(filePath: pickedPhoto.path);
    if (croppedPhoto == null || !mounted) return;

    final profileFile = File(croppedPhoto.path);
    setState(() {
      _profilePhotoPreview = profileFile;
      _isUpdatingProfilePhoto = true;
    });

    try {
      final response = await _jobRepository.saveUserDetail(
        const <String, dynamic>{},
        profileFile: profileFile,
      );
      String? profileUrl = _extractProfileUrl(response);
      if (profileUrl == null) {
        profileUrl = _extractProfileUrl(await _jobRepository.fetchUserDetail());
      }
      if (profileUrl == null || profileUrl.isEmpty) {
        throw StateError(
            'The server did not return the uploaded profile photo.');
      }

      await HiveUtils.setUserData({'profile': profileUrl});
      if (!mounted) return;
      setState(() => _isUpdatingProfilePhoto = false);
      HelperUtils.showSnackBarMessage(
        context,
        response['message']?.toString() ?? 'Profile photo updated',
        type: MessageType.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profilePhotoPreview = null;
        _isUpdatingProfilePhoto = false;
      });
      HelperUtils.showSnackBarMessage(
        context,
        error.toString(),
        type: MessageType.error,
      );
    }
  }

  Future<void> _removeProfilePhoto() async {
    setState(() => _isUpdatingProfilePhoto = true);
    try {
      final response = await _jobRepository.removeProfilePhoto();
      await HiveUtils.setUserData({'profile': ''});
      if (!mounted) return;

      setState(() {
        _profilePhotoPreview = null;
        _isUpdatingProfilePhoto = false;
      });
      HelperUtils.showSnackBarMessage(
        context,
        response['message']?.toString() ?? 'Profile photo removed',
        type: MessageType.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingProfilePhoto = false);
      HelperUtils.showSnackBarMessage(
        context,
        error.toString(),
        type: MessageType.error,
      );
    }
  }

  String? _extractProfileUrl(dynamic payload) {
    if (payload is! Map) return null;
    for (final key in const ['profile', 'profile_url']) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    for (final key in const ['data', 'user', 'user_detail']) {
      final nested = _extractProfileUrl(payload[key]);
      if (nested != null) return nested;
    }
    return null;
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
        final profileUrl = userDetail['profile']?.toString().trim() ?? '';
        await HiveUtils.setUserData({'profile': profileUrl});
        _profilePhotoPreview = null;
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
          _locationController.text = userDetail['current_location'].toString();
        }
        if (userDetail['language'] != null) {
          final rawLang = userDetail['language'].toString();
          _languagesController.text = rawLang;
          _languagesList.clear();
          for (var l in rawLang.split(',')) {
            final trimmed = l.trim();
            if (trimmed.isNotEmpty && !_languagesList.contains(trimmed)) {
              _languagesList.add(trimmed);
            }
          }
        }
        if (userDetail['gender'] != null &&
            _genders.contains(userDetail['gender'])) {
          _gender = userDetail['gender'].toString();
        }
        if (userDetail['visa_status'] != null &&
            _visaStatuses.contains(userDetail['visa_status'])) {
          _visaStatus = userDetail['visa_status'].toString();
        }
        _profileSummary =
            userDetail['profile_summary']?.toString().trim() ?? '';
        final jobStatus = userDetail['job_status']?.toString().trim();
        _jobAvailability =
            jobStatus == null || jobStatus.isEmpty ? null : jobStatus;
        // Qualifications parsing (List and scalar fallback with deduplication)
        _qualificationsList.clear();
        final Set<String> seenQuals = {};
        if (userDetail['user_qualification'] is List) {
          for (var q in userDetail['user_qualification']) {
            if (q is Map) {
              final map = Map<String, dynamic>.from(q);
              final degree = (map['degree'] ?? '').toString().trim();
              final uni = (map['university_name'] ?? '').toString().trim();
              final spec = (map['specialization'] ?? '').toString().trim();
              if (degree.isNotEmpty || uni.isNotEmpty || spec.isNotEmpty) {
                final key = "$degree|$uni|$spec".toLowerCase();
                if (!seenQuals.contains(key)) {
                  seenQuals.add(key);
                  _qualificationsList.add(map);
                }
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

        // Experiences parsing (List and scalar fallback with deduplication & cleaning)
        _experiencesList.clear();
        final Set<String> seenExps = {};
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
                final key = isFresher
                    ? "fresher"
                    : "$title|$company|$category".toLowerCase();
                if (!seenExps.contains(key)) {
                  seenExps.add(key);
                  _experiencesList.add(map);
                }
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
                  (userDetail['experience_job_description'] ?? '')
                      .toString()
                      .trim(),
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
        if (userDetail['audio_introduction'] != null &&
            userDetail['audio_introduction'].toString().trim().isNotEmpty) {
          _audioIntroPath = userDetail['audio_introduction'].toString().trim();
          HiveUtils.setAudioIntroPath(_audioIntroPath);
        } else if (userDetail['audio'] != null &&
            userDetail['audio'].toString().trim().isNotEmpty) {
          _audioIntroPath = userDetail['audio'].toString().trim();
          HiveUtils.setAudioIntroPath(_audioIntroPath);
        } else {
          final localAudio = HiveUtils.getAudioIntroPath();
          if (localAudio != null &&
              (localAudio.startsWith('http') || File(localAudio).existsSync())) {
            _audioIntroPath = localAudio;
          }
        }
        if (userDetail['video_introduction'] != null &&
            userDetail['video_introduction'].toString().trim().isNotEmpty) {
          _videoIntroPath = userDetail['video_introduction'].toString().trim();
          HiveUtils.setVideoIntroPath(_videoIntroPath);
        } else if (userDetail['video'] != null &&
            userDetail['video'].toString().trim().isNotEmpty) {
          _videoIntroPath = userDetail['video'].toString().trim();
          HiveUtils.setVideoIntroPath(_videoIntroPath);
        } else {
          final localVideo = HiveUtils.getVideoIntroPath();
          if (localVideo != null &&
              (localVideo.startsWith('http') || File(localVideo).existsSync())) {
            _videoIntroPath = localVideo;
          }
        }

        _licencesList
          ..clear()
          ..addAll(
            (userDetail['licenses_certificates'] is List
                    ? userDetail['licenses_certificates'] as List
                    : const <dynamic>[])
                .whereType<Map>()
                .map(
                  (entry) => <String, String>{
                    'id': entry['id']?.toString() ?? '',
                    'name': _firstNonEmptyProfileValue(
                      entry,
                      const ['course_name', 'name'],
                    ),
                    'org': _firstNonEmptyProfileValue(
                      entry,
                      const ['issuing_organization', 'organization'],
                    ),
                  },
                )
                .where((entry) => entry['name']!.trim().isNotEmpty),
          );
        _portfoliosList
          ..clear()
          ..addAll(
            (userDetail['user_portfolio'] is List
                    ? userDetail['user_portfolio'] as List
                    : const <dynamic>[])
                .whereType<Map>()
                .map(
                  (entry) => <String, String>{
                    'id': entry['id']?.toString() ?? '',
                    'name': _firstNonEmptyProfileValue(
                      entry,
                      const ['portfolio_name', 'name'],
                    ),
                    'link': _firstNonEmptyProfileValue(
                      entry,
                      const ['portfolio_link', 'link'],
                    ),
                  },
                )
                .where((entry) => entry['name']!.trim().isNotEmpty),
          );
        _referencesList
          ..clear()
          ..addAll(
            (userDetail['user_reference'] is List
                    ? userDetail['user_reference'] as List
                    : const <dynamic>[])
                .whereType<Map>()
                .map(
                  (entry) => <String, String>{
                    'id': entry['id']?.toString() ?? '',
                    'name': _firstNonEmptyProfileValue(
                      entry,
                      const ['reference_name', 'name'],
                    ),
                    'company': _firstNonEmptyProfileValue(
                      entry,
                      const ['reference_company_name', 'company_name'],
                    ),
                    'email': _firstNonEmptyProfileValue(
                      entry,
                      const ['reference_email', 'email'],
                    ),
                  },
                )
                .where((entry) => entry['name']!.trim().isNotEmpty),
          );
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
    // 1. Basic Info
    if (_nameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty) {
      filled++;
    }
    // 2. Qualifications
    if (_qualificationsList.isNotEmpty ||
        (_educationLevel != null && _educationLevel!.isNotEmpty)) {
      filled++;
    }
    // 3. Experience
    if (_experiencesList.isNotEmpty ||
        _experienceType == "Fresher" ||
        _companyController.text.trim().isNotEmpty ||
        _positionController.text.trim().isNotEmpty) {
      filled++;
    }
    // 4. Skills
    if (_skillsList.isNotEmpty || _jobCategory != null) {
      filled++;
    }
    // 5. Resume
    if (_resumeFile != null ||
        (_existingResumeUrl != null && _existingResumeUrl!.isNotEmpty)) {
      filled++;
    }
    // 6. Digital Profile (Audio or Video introduction)
    if (_audioIntroPath != null || _videoIntroPath != null) {
      filled++;
    }
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

      final langValue = _languagesList.isNotEmpty
          ? _languagesList.join(', ')
          : _languagesController.text.trim();

      final Map<String, dynamic> userDetailData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'email_id': _emailController.text.trim(),
        'mobile': fullPhone,
        if (_nationalityController.text.trim().isNotEmpty)
          'nationality': _nationalityController.text.trim(),
        if (_locationController.text.trim().isNotEmpty)
          'current_location': _locationController.text.trim(),
        if (langValue.isNotEmpty)
          'language': langValue,
        if (_gender != null) 'gender': _gender,
        if (_visaStatus != null) 'visa_status': _visaStatus,
        if (_skillsList.isNotEmpty) 'skills': _skillsList.join(', '),
        if (_jobCategory != null) 'experience_industry': _jobCategory,
        'profile_summary': _profileSummary,
        if (_jobAvailability != null) 'job_status': _jobAvailability,
      };

      await _jobRepository.saveUserDetail(
        userDetailData,
        resumeFile: _resumeFile,
        audioFile: _audioIntroPath != null &&
                !_audioIntroPath!.startsWith('http') &&
                File(_audioIntroPath!).existsSync()
            ? File(_audioIntroPath!)
            : null,
        videoFile: _videoIntroPath != null &&
                !_videoIntroPath!.startsWith('http') &&
                File(_videoIntroPath!).existsSync()
            ? File(_videoIntroPath!)
            : null,
      );

      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Profile updated successfully",
          type: MessageType.success,
        );
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

  Future<void> _saveLicence({
    String? id,
    required String courseName,
    required String issuingOrg,
  }) async {
    setState(() => _isSaving = true);
    try {
      final response = await _jobRepository.saveUserDetail({
        'type': 'licenses_certificates',
        if (id != null && id.isNotEmpty) 'licenses_certificates_id': id,
        'course_name': courseName,
        'issuing_organization': issuingOrg,
      });
      await _loadJobProfile();
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          response['message']?.toString() ?? 'Licence saved successfully',
          type: MessageType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, e.toString(), type: MessageType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _savePortfolio({
    String? id,
    required String portfolioName,
    required String portfolioLink,
  }) async {
    setState(() => _isSaving = true);
    try {
      final response = await _jobRepository.saveUserDetail({
        'type': 'user_portfolio',
        if (id != null && id.isNotEmpty) 'user_portfolio_id': id,
        'portfolio_name': portfolioName,
        'portfolio_link': portfolioLink,
      });
      await _loadJobProfile();
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          response['message']?.toString() ?? 'Portfolio saved successfully',
          type: MessageType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, e.toString(), type: MessageType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveReference({
    String? id,
    required String refName,
    required String refCompany,
    required String refEmail,
  }) async {
    setState(() => _isSaving = true);
    try {
      final response = await _jobRepository.saveUserDetail({
        'type': 'user_reference',
        if (id != null && id.isNotEmpty) 'user_reference_id': id,
        'reference_name': refName,
        'reference_company_name': refCompany,
        'reference_email': refEmail,
      });
      await _loadJobProfile();
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          response['message']?.toString() ?? 'Reference saved successfully',
          type: MessageType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, e.toString(), type: MessageType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveQualification({
    String? id,
    required String degree,
    required String specialization,
    required String universityName,
    required String country,
    required String graduationFrom,
    required String graduationTo,
  }) async {
    setState(() => _isSaving = true);
    try {
      final response = await _jobRepository.saveUserDetail({
        'type': 'user_qualification',
        if (id != null && id.isNotEmpty) 'qualification_id': id,
        'degree': degree,
        'specialization': specialization,
        'university_name': universityName,
        'country': country,
        'graduation_from': graduationFrom,
        'graduation_to': graduationTo,
      });
      await _loadJobProfile();
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          response['message']?.toString() ?? 'Qualification saved successfully',
          type: MessageType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, e.toString(), type: MessageType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveExperience({
    String? id,
    required String company,
    required String title,
    required String description,
    required String category,
    required String industry,
    required String country,
    required String startDate,
    required String endDate,
    required bool currentlyWorking,
    required bool isFresher,
  }) async {
    setState(() => _isSaving = true);
    try {
      final response = await _jobRepository.saveUserDetail({
        'type': 'user_experience',
        if (id != null && id.isNotEmpty) 'experience_id': id,
        'experience_company': company,
        'experience_job_titel': title,
        'experience_job_description': description,
        'experience_job_category': category,
        'experience_industry': industry,
        'experience_country': country,
        'experience_start_date': startDate,
        'experience_end_date': endDate,
        'currently_working': currentlyWorking ? 1 : 0,
        'fresher': isFresher ? 1 : 0,
      });
      await _loadJobProfile();
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          response['message']?.toString() ?? 'Experience saved successfully',
          type: MessageType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, e.toString(), type: MessageType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                _languagesList.clear();
                                for (var l in textCtrl.text.split(',')) {
                                  final t = l.trim();
                                  if (t.isNotEmpty && !_languagesList.contains(t)) {
                                    _languagesList.add(t);
                                  }
                                }
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

  void _showLanguagesBottomSheet() {
    final List<String> tempLanguages = List<String>.from(_languagesList);
    if (tempLanguages.isEmpty && _languagesController.text.isNotEmpty) {
      for (var l in _languagesController.text.split(',')) {
        final t = l.trim();
        if (t.isNotEmpty && !tempLanguages.contains(t)) {
          tempLanguages.add(t);
        }
      }
    }

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
                        "Languages",
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
                  _buildFieldLabel("Select Language"),
                  DropdownButtonFormField<String>(
                    key: ValueKey("lang_dd_sheet_${tempLanguages.length}_${tempLanguages.hashCode}"),
                    isExpanded: true,
                    initialValue: null,
                    hint: Text(
                      "Choose a language to add",
                      style: TextStyle(color: context.color.textLightColor),
                    ),
                    items: _allLanguages
                        .where((lang) => !tempLanguages.contains(lang))
                        .map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(
                                lang,
                                style: TextStyle(
                                    color: context.color.textDefaultColor),
                              ),
                            ))
                        .toList(),
                    onChanged: (selectedLang) {
                      if (selectedLang != null &&
                          !tempLanguages.contains(selectedLang)) {
                        setSheetState(() {
                          tempLanguages.add(selectedLang);
                        });
                      }
                    },
                    decoration: _inputDecoration(""),
                  ),
                  if (tempLanguages.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildFieldLabel("Selected Languages"),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tempLanguages.map((lang) {
                        return Chip(
                          label: Text(
                            lang,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                          deleteIcon: const Icon(
                            Icons.cancel_rounded,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                          onDeleted: () {
                            setSheetState(() {
                              tempLanguages.remove(lang);
                            });
                          },
                          backgroundColor: context.color.backgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: context.color.borderColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 22),
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
                              // _languagesList = List.from(tempLanguages);
                              _languagesController.text =
                                  _languagesList.join(', ');
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
    final tempLocCtrl = TextEditingController(text: _locationController.text);
    final List<String> tempLanguages = List<String>.from(_languagesList);
    if (tempLanguages.isEmpty && _languagesController.text.isNotEmpty) {
      for (var l in _languagesController.text.split(',')) {
        final t = l.trim();
        if (t.isNotEmpty && !tempLanguages.contains(t)) {
          tempLanguages.add(t);
        }
      }
    }
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
                        initialValue:
                            tempVisa != null && _visaStatuses.contains(tempVisa)
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
                        initialValue:
                            tempGender != null && _genders.contains(tempGender)
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
                        decoration: _inputDecoration("e.g. Dubai, Abu Dhabi"),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Languages"),
                      DropdownButtonFormField<String>(
                        key: ValueKey("lang_dd_basic_${tempLanguages.length}_${tempLanguages.hashCode}"),
                        isExpanded: true,
                        initialValue: null,
                        hint: Text(
                          "Select languages from list",
                          style: TextStyle(color: context.color.textLightColor),
                        ),
                        items: _allLanguages
                            .where((lang) => !tempLanguages.contains(lang))
                            .map((lang) => DropdownMenuItem(
                                  value: lang,
                                  child: Text(
                                    lang,
                                    style: TextStyle(
                                        color: context.color.textDefaultColor),
                                  ),
                                ))
                            .toList(),
                        onChanged: (selectedLang) {
                          if (selectedLang != null &&
                              !tempLanguages.contains(selectedLang)) {
                            setModalState(() {
                              tempLanguages.add(selectedLang);
                            });
                          }
                        },
                        decoration: _inputDecoration(""),
                      ),
                      if (tempLanguages.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tempLanguages.map((lang) {
                            return Chip(
                              label: Text(
                                lang,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.color.textDefaultColor,
                                ),
                              ),
                              deleteIcon: const Icon(
                                Icons.cancel_rounded,
                                size: 18,
                                color: Color(0xFFEF4444),
                              ),
                              onDeleted: () {
                                setModalState(() {
                                  tempLanguages.remove(lang);
                                });
                              },
                              backgroundColor: context.color.backgroundColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: context.color.borderColor,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: context.color.borderColor),
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
                                    _languagesList.clear();
                                    _languagesList.addAll(tempLanguages);
                                    _languagesController.text =
                                        tempLanguages.join(', ');
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
                      initialValue: tempEducation != null &&
                              _educationLevels.contains(tempEducation)
                          ? tempEducation
                          : null,
                      hint: Text("Select Highest Education",
                          style:
                              TextStyle(color: context.color.textLightColor)),
                      items: _educationLevels
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
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
                      decoration: _inputDecoration("e.g. University of Dubai"),
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
                            onPressed: () async {
                              final qualId = initialData?['id'] ??
                                  (editIndex != null &&
                                          editIndex < _qualificationsList.length
                                      ? _qualificationsList[editIndex]['id']
                                      : null);
                              final newQual = {
                                if (qualId != null) 'id': qualId,
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
                                    newQual['university_name']?.toString() ??
                                        '';
                                _qualificationCountry =
                                    newQual['country']?.toString();
                                _graduationStartYear =
                                    newQual['graduation_from']?.toString();
                                _graduationEndYear =
                                    newQual['graduation_to']?.toString();
                              });
                              Navigator.pop(ctx);
                              await _saveQualification(
                                id: qualId?.toString(),
                                degree: tempEducation ?? '',
                                specialization: tempSpecCtrl.text.trim(),
                                universityName: tempUniCtrl.text.trim(),
                                country: tempCountry ?? '',
                                graduationFrom: tempStartYear ?? '',
                                graduationTo: tempEndYear ?? '',
                              );
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
                              setModalState(() => tempExpType = "Experienced");
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
                        decoration:
                            _inputDecoration("e.g. Acme Tech Solutions"),
                      ),
                      const SizedBox(height: 12),
                      _buildFieldLabel("Job Category"),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: tempCat != null && _categories.contains(tempCat)
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
                        initialValue: tempInd != null && _categories.contains(tempInd)
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
                            onPressed: () async {
                              final expId = initialData?['id'] ??
                                  (editIndex != null &&
                                          editIndex < _experiencesList.length
                                      ? _experiencesList[editIndex]['id']
                                      : null);
                              final newExp = {
                                if (expId != null) 'id': expId,
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
                              await _saveExperience(
                                id: expId?.toString(),
                                company: tempCompanyCtrl.text.trim(),
                                title: tempPosCtrl.text.trim(),
                                description: tempDescCtrl.text.trim(),
                                category: tempCat ?? '',
                                industry: tempInd ?? '',
                                country: tempCountry ?? '',
                                startDate: tempStartDate ?? '',
                                endDate: tempEndDate ?? '',
                                currentlyWorking: tempCurrent,
                                isFresher: tempExpType == "Fresher",
                              );
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
                      initialValue:
                          tempCat != null && _categories.contains(tempCat)
                              ? tempCat
                              : null,
                      hint: Text("Select Industry",
                          style:
                              TextStyle(color: context.color.textLightColor)),
                      items: _categories
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
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
                    final path = result['filePath']?.toString();
                    setState(() {
                      _audioIntroPath = path;
                    });
                    HiveUtils.setAudioIntroPath(path);
                    await _saveJobProfileData();
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
                    final path = result['filePath']?.toString();
                    setState(() {
                      _videoIntroPath = path;
                    });
                    HiveUtils.setVideoIntroPath(path);
                    await _saveJobProfileData();
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
  Future<void> _showEditJobProfileSheet() async {
    final nameController =
        TextEditingController(text: _nameController.text.trim());
    final summaryController = TextEditingController(text: _profileSummary);
    final availabilityOptions = <String>{
      ..._availabilityOptions,
      if (_jobAvailability != null && _jobAvailability!.isNotEmpty)
        _jobAvailability!,
    }.toList();
    String? selectedAvailability = _jobAvailability;
    File? selectedProfilePhoto;
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final user = HiveUtils.getUserDetails();
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Edit profile',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildFieldLabel('Profile name *'),
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration('Enter your profile name'),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Profile picture'),
                    InkWell(
                      onTap: isSaving
                          ? null
                          : () async {
                              final hasPhoto = selectedProfilePhoto != null ||
                                  (user.profile ?? '').isNotEmpty;
                              final action =
                                  await showModalBottomSheet<_JobProfilePhotoAction>(
                                context: context,
                                backgroundColor: context.color.secondaryColor,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20)),
                                ),
                                builder: (ctx) => SafeArea(
                                  top: false,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        8, 12, 8, 16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 4,
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            color: context.color.borderColor,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        if (hasPhoto)
                                          ListTile(
                                            leading: const Icon(
                                                Icons.visibility_outlined),
                                            title:
                                                const Text('View current photo'),
                                            onTap: () => Navigator.pop(
                                              ctx,
                                              _JobProfilePhotoAction.view,
                                            ),
                                          ),
                                        ListTile(
                                          leading: const Icon(
                                              Icons.photo_camera_outlined),
                                          title: const Text('Take a new photo'),
                                          onTap: () => Navigator.pop(
                                            ctx,
                                            _JobProfilePhotoAction.camera,
                                          ),
                                        ),
                                        ListTile(
                                          leading: const Icon(
                                              Icons.photo_library_outlined),
                                          title: const Text(
                                              'Choose from your library'),
                                          onTap: () => Navigator.pop(
                                            ctx,
                                            _JobProfilePhotoAction.gallery,
                                          ),
                                        ),
                                        if (hasPhoto)
                                          ListTile(
                                            leading: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.red,
                                            ),
                                            title: const Text(
                                              'Remove photo',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                            onTap: () => Navigator.pop(
                                              ctx,
                                              _JobProfilePhotoAction.remove,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              if (!mounted || action == null) return;
                              if (action == _JobProfilePhotoAction.view) {
                                _showProfilePhotoViewDialog(
                                  imageUrl: user.profile,
                                  imageFile: selectedProfilePhoto,
                                );
                              } else if (action ==
                                  _JobProfilePhotoAction.remove) {
                                await _removeProfilePhoto();
                                setSheetState(
                                    () => selectedProfilePhoto = null);
                              } else {
                                final source = action ==
                                        _JobProfilePhotoAction.camera
                                    ? ImageSource.camera
                                    : ImageSource.gallery;
                                CropImage.init(context);
                                final pickedPhoto =
                                    await ImagePicker().pickImage(
                                  source: source,
                                );
                                if (pickedPhoto == null || !mounted) return;
                                final croppedPhoto = await CropImage.crop(
                                  filePath: pickedPhoto.path,
                                );
                                if (croppedPhoto == null ||
                                    !sheetContext.mounted) {
                                  return;
                                }
                                setSheetState(
                                  () => selectedProfilePhoto =
                                      File(croppedPhoto.path),
                                );
                              }
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 76,
                                height: 76,
                                child: selectedProfilePhoto != null
                                    ? Image.file(
                                        selectedProfilePhoto!,
                                        fit: BoxFit.cover,
                                      )
                                    : (user.profile ?? '').isNotEmpty
                                        ? UiUtils.getImage(
                                            user.profile!,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color:
                                                context.color.secondaryColor,
                                            child: Icon(
                                              Icons.person_outline_rounded,
                                              size: 34,
                                              color: context
                                                  .color.territoryColor,
                                            ),
                                          ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedProfilePhoto == null
                                        ? 'Upload profile picture'
                                        : 'New picture selected',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.color.textDefaultColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to choose an image from your library',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.upload_outlined,
                              color: context.color.territoryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Profile summary'),
                    TextFormField(
                      controller: summaryController,
                      minLines: 4,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        'Tell employers about your experience and strengths',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Availability to join'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: isSaving
                                ? null
                                : () => setSheetState(() =>
                                    selectedAvailability = 'Immediate'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedAvailability == 'Immediate'
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.1)
                                    : context.color.backgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedAvailability == 'Immediate'
                                      ? const Color(0xFF10B981)
                                      : context.color.borderColor,
                                  width: selectedAvailability == 'Immediate'
                                      ? 1.8
                                      : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    color: selectedAvailability == 'Immediate'
                                        ? const Color(0xFF10B981)
                                        : context.color.textLightColor,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Immediate',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selectedAvailability ==
                                              'Immediate'
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: selectedAvailability ==
                                              'Immediate'
                                          ? const Color(0xFF10B981)
                                          : context.color.textDefaultColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Ready to join now',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: isSaving
                                ? null
                                : () => setSheetState(() =>
                                    selectedAvailability =
                                        'Actively Looking'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedAvailability ==
                                        'Actively Looking'
                                    ? const Color(0xFF2563EB)
                                        .withValues(alpha: 0.1)
                                    : context.color.backgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedAvailability ==
                                          'Actively Looking'
                                      ? const Color(0xFF2563EB)
                                      : context.color.borderColor,
                                  width: selectedAvailability ==
                                          'Actively Looking'
                                      ? 1.8
                                      : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.travel_explore_rounded,
                                    color: selectedAvailability ==
                                            'Actively Looking'
                                        ? const Color(0xFF2563EB)
                                        : context.color.textLightColor,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Actively Looking',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selectedAvailability ==
                                              'Actively Looking'
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: selectedAvailability ==
                                              'Actively Looking'
                                          ? const Color(0xFF2563EB)
                                          : context.color.textDefaultColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Open to offers',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  context.color.textDefaultColor,
                              side: BorderSide(
                                color: context.color.borderColor,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final profileName =
                                        nameController.text.trim();
                                    if (profileName.isEmpty) {
                                      HelperUtils.showSnackBarMessage(
                                        context,
                                        'Please enter your profile name',
                                        type: MessageType.warning,
                                      );
                                      return;
                                    }

                                    setSheetState(() => isSaving = true);
                                    try {
                                      final response =
                                          await _jobRepository.saveUserDetail(
                                        {
                                          'name': profileName,
                                          'profile_summary':
                                              summaryController.text.trim(),
                                          'job_status':
                                              selectedAvailability ?? '',
                                        },
                                        profileFile: selectedProfilePhoto,
                                      );
                                      final refreshedUser =
                                          await _jobRepository.fetchUserDetail();
                                      final profileUrl =
                                          _extractProfileUrl(refreshedUser) ??
                                              _extractProfileUrl(response) ??
                                              user.profile ??
                                              '';

                                      await HiveUtils.setUserData({
                                        'name': profileName,
                                        'profile': profileUrl,
                                      });
                                      if (!mounted) return;
                                      setState(() {
                                        _nameController.text = profileName;
                                        _profileSummary =
                                            summaryController.text.trim();
                                        _jobAvailability =
                                            selectedAvailability;
                                        _profilePhotoPreview = null;
                                      });
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                      }
                                      HelperUtils.showSnackBarMessage(
                                        context,
                                        response['message']?.toString() ??
                                            'Profile updated successfully',
                                        type: MessageType.success,
                                      );
                                    } catch (error) {
                                      if (mounted) {
                                        HelperUtils.showSnackBarMessage(
                                          context,
                                          error.toString(),
                                          type: MessageType.error,
                                        );
                                      }
                                      if (sheetContext.mounted) {
                                        setSheetState(
                                          () => isSaving = false,
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  context.color.territoryColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save'),
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

    nameController.dispose();
    summaryController.dispose();
  }

  // 6. "Add More Sections" Bottom Sheet
  // ---------------------------------------------------------------------------
  void _showAddMoreSectionsBottomSheet() {
    final showLicence = _licencesList.isEmpty;
    final showPortfolio = _portfoliosList.isEmpty;
    final showReference = _referencesList.isEmpty;

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

              if (showLicence) ...[
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
                if (showPortfolio || showReference) ...[
                  const SizedBox(height: 12),
                  Divider(
                      height: 1,
                      color: context.color.borderColor.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                ],
              ],

              if (showPortfolio) ...[
                _buildAddSectionOption(
                  icon: Icons.link_rounded,
                  title: "Portfolio",
                  subtitle: "Add links to your online work projects.",
                  onAdd: () {
                    Navigator.pop(ctx);
                    _showPortfolioFormSheet();
                  },
                ),
                if (showReference) ...[
                  const SizedBox(height: 12),
                  Divider(
                      height: 1,
                      color: context.color.borderColor.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                ],
              ],

              if (showReference) ...[
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
              ],

              if (!showLicence && !showPortfolio && !showReference) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "All sections have been added to your profile.",
                      style: TextStyle(
                        fontSize: 14,
                        color: context.color.textLightColor,
                      ),
                    ),
                  ),
                ),
              ],

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
  void _showLicenceFormSheet({int? editIndex, Map<String, String>? initialData}) {
    final nameCtrl = TextEditingController(text: initialData?['name'] ?? '');
    final orgCtrl = TextEditingController(text: initialData?['org'] ?? '');
    final isEditing = editIndex != null;

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
                isEditing ? "Edit Licence or Certificate" : "Add Licence or Certificate",
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
                decoration:
                    _inputDecoration("e.g. AWS Certified Solutions Architect"),
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
                      onPressed: () async {
                        final licName = nameCtrl.text.trim();
                        final licOrg = orgCtrl.text.trim();
                        if (licName.isNotEmpty) {
                          final licId = initialData?['id'] ??
                              (editIndex != null &&
                                      editIndex < _licencesList.length
                                  ? _licencesList[editIndex]['id']
                                  : null);
                          final entry = {
                            if (licId != null) 'id': licId,
                            'name': licName,
                            'org': licOrg,
                          };
                          setState(() {
                            if (isEditing) {
                              _licencesList[editIndex] = entry;
                            } else {
                              _licencesList.add(entry);
                            }
                          });
                          Navigator.pop(ctx);
                          await _saveLicence(
                            id: licId,
                            courseName: licName,
                            issuingOrg: licOrg,
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

  void _showPortfolioFormSheet({int? editIndex, Map<String, String>? initialData}) {
    final nameCtrl = TextEditingController(text: initialData?['name'] ?? '');
    final linkCtrl = TextEditingController(text: initialData?['link'] ?? '');
    final isEditing = editIndex != null;

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
                isEditing ? "Edit Portfolio Project" : "Add Portfolio Project",
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
                      onPressed: () async {
                        final portName = nameCtrl.text.trim();
                        final portLink = linkCtrl.text.trim();
                        if (portName.isNotEmpty) {
                          final portId = initialData?['id'] ??
                              (editIndex != null &&
                                      editIndex < _portfoliosList.length
                                  ? _portfoliosList[editIndex]['id']
                                  : null);
                          final entry = {
                            if (portId != null) 'id': portId,
                            'name': portName,
                            'link': portLink,
                          };
                          setState(() {
                            if (isEditing) {
                              _portfoliosList[editIndex] = entry;
                            } else {
                              _portfoliosList.add(entry);
                            }
                          });
                          Navigator.pop(ctx);
                          await _savePortfolio(
                            id: portId,
                            portfolioName: portName,
                            portfolioLink: portLink,
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

  void _showReferenceFormSheet({int? editIndex, Map<String, String>? initialData}) {
    final nameCtrl = TextEditingController(text: initialData?['name'] ?? '');
    final compCtrl = TextEditingController(text: initialData?['company'] ?? '');
    final emailCtrl = TextEditingController(text: initialData?['email'] ?? '');
    final isEditing = editIndex != null;

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
                isEditing ? "Edit Reference" : "Add Reference",
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
                      onPressed: () async {
                        final refName = nameCtrl.text.trim();
                        final refComp = compCtrl.text.trim();
                        final refEmail = emailCtrl.text.trim();
                        if (refName.isNotEmpty) {
                          final refId = initialData?['id'] ??
                              (editIndex != null &&
                                      editIndex < _referencesList.length
                                  ? _referencesList[editIndex]['id']
                                  : null);
                          final entry = {
                            if (refId != null) 'id': refId,
                            'name': refName,
                            'company': refComp,
                            'email': refEmail,
                          };
                          setState(() {
                            if (isEditing) {
                              _referencesList[editIndex] = entry;
                            } else {
                              _referencesList.add(entry);
                            }
                          });
                          Navigator.pop(ctx);
                          await _saveReference(
                            id: refId,
                            refName: refName,
                            refCompany: refComp,
                            refEmail: refEmail,
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

                          // Section 4: Licenses or Certificates Tile
                          if (_licencesList.isNotEmpty) ...[
                            _buildTileDivider(),
                            _buildLicencesTile(),
                          ],

                          _buildTileDivider(),

                          // Section 5: Skills Tile
                          _buildSkillsTile(),
                          _buildTileDivider(),

                          // Section 6: Resume Tile
                          _buildResumeTile(),
                          _buildTileDivider(),

                          // Section 7: Digital Profile Tile
                          _buildDigitalProfileTile(),

                          // Section 8+: Dynamic added sections (Portfolio, Reference)
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

                    // 3. "Add More Sections" Button – hidden when all sections are filled
                    if (_hasAddableMoreSections)
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
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _isUpdatingProfilePhoto
                            ? null
                            : _showProfilePhotoPicker,
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF334155) : Colors.white,
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
                            child: _profilePhotoPreview != null
                                ? Image.file(
                                    _profilePhotoPreview!,
                                    fit: BoxFit.cover,
                                  )
                                : user.profile != null &&
                                        user.profile!.isNotEmpty
                                    ? UiUtils.getImage(
                                        user.profile!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.person_outline_rounded,
                                        color: Color(0xFF2563EB),
                                        size: 30,
                                      ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: GestureDetector(
                        onTap: _isUpdatingProfilePhoto
                            ? null
                            : _showProfilePhotoPicker,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (_isUpdatingProfilePhoto)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    if (_jobAvailability != null &&
                        _jobAvailability!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_jobAvailability == 'Immediate' ||
                                  _jobAvailability == 'Immediate Joiner')
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_jobAvailability == 'Immediate' ||
                                        _jobAvailability == 'Immediate Joiner')
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _jobAvailability!,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: (_jobAvailability == 'Immediate' ||
                                        _jobAvailability == 'Immediate Joiner')
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_profileSummary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _truncateSummaryWords(_profileSummary, 100),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.color.textLightColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: context.color.secondaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == "addMore") {
                    _showAddMoreSectionsBottomSheet();
                  } else if (value == "edit") {
                    _showEditJobProfileSheet();
                  }
                },
                itemBuilder: (context) => [
                  if (_hasAddableMoreSections)
                    const PopupMenuItem(
                      value: "addMore",
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 18),
                          SizedBox(width: 10),
                          Text("Add More Sections"),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: "edit",
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text("Edit Profile"),
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
              backgroundColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
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
          if (_jobAvailability != null && _jobAvailability!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow("Availability", _jobAvailability!),
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
              onTap: _showLanguagesBottomSheet,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable Section Header & List Item Helpers (Premium Tile UI)
  // ---------------------------------------------------------------------------
  Widget _buildSectionHeader({
    required String title,
    VoidCallback? onAdd,
    VoidCallback? onEdit,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.color.textDefaultColor,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onAdd != null)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                color: context.color.textLightColor,
                splashRadius: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onAdd,
              ),
            if (onAdd != null && onEdit != null) const SizedBox(width: 14),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: context.color.textLightColor,
                splashRadius: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onEdit,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemTile({
    required IconData icon,
    required Widget content,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 22,
                color: const Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: content),
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: context.color.textLightColor,
                    splashRadius: 16,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: onEdit,
                  ),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.red),
                    splashRadius: 16,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Generic Manage List Bottom Sheet (Edit/Delete items from header edit icon)
  // ---------------------------------------------------------------------------
  void _showManageListSheet({
    required String title,
    required String addLabel,
    required VoidCallback onAddNew,
    required List<Widget> Function(
            BuildContext sheetCtx, StateSetter setSheetState)
        itemsBuilder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final items = itemsBuilder(sheetCtx, setSheetState);
            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            "No items found",
                            style: TextStyle(
                              fontSize: 14,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.55,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: items,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(addLabel),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: context.color.territoryColor),
                          foregroundColor: context.color.territoryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          onAddNew();
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

  void _showManageQualificationsSheet() {
    if (_qualificationsList.isEmpty) {
      _showQualificationsBottomSheet();
      return;
    }

    _showManageListSheet(
      title: "Manage Qualifications",
      addLabel: "Add New Qualification",
      onAddNew: () => _showQualificationsBottomSheet(),
      itemsBuilder: (sheetCtx, setSheetState) {
        return List.generate(_qualificationsList.length, (index) {
          final q = _qualificationsList[index];
          final degree = q['degree']?.toString() ?? '';
          final spec = q['specialization']?.toString() ?? '';
          final uni = q['university_name']?.toString() ?? '';
          final fromYear = q['graduation_from']?.toString() ?? '';
          final toYear = q['graduation_to']?.toString() ?? '';

          final titleText = degree.isNotEmpty ? degree : spec;
          final subtitleText = uni.isNotEmpty ? uni : spec;
          final yearsText = (fromYear.isNotEmpty || toYear.isNotEmpty)
              ? "$fromYear - $toYear"
              : "";

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.color.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.school_outlined,
                        size: 20, color: Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText.isNotEmpty ? titleText : "Qualification",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      if (subtitleText.isNotEmpty && subtitleText != titleText)
                        Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.color.textLightColor,
                          ),
                        ),
                      if (yearsText.isNotEmpty)
                        Text(
                          yearsText,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: context.color.textLightColor,
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _showQualificationsBottomSheet(
                      initialData: q,
                      editIndex: index,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _qualificationsList.removeAt(index);
                    });
                    setSheetState(() {});
                    _saveJobProfileData();
                    if (_qualificationsList.isEmpty) {
                      Navigator.pop(sheetCtx);
                    }
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showManageExperienceSheet() {
    if (_experiencesList.isEmpty) {
      _showExperienceBottomSheet();
      return;
    }

    _showManageListSheet(
      title: "Manage Experience",
      addLabel: "Add New Experience",
      onAddNew: () => _showExperienceBottomSheet(),
      itemsBuilder: (sheetCtx, setSheetState) {
        return List.generate(_experiencesList.length, (index) {
          final exp = _experiencesList[index];
          final isFresher = exp['fresher'] == 1 ||
              exp['fresher'] == "1" ||
              exp['fresher'] == true;
          final title = exp['experience_job_titel']?.toString() ?? '';
          final company = exp['experience_company']?.toString() ?? '';
          final start = exp['experience_start_date']?.toString() ?? '';
          final end = exp['experience_end_date']?.toString() ?? '';
          final currentlyWorking = exp['currently_working'] == 1 ||
              exp['currently_working'] == "1" ||
              exp['currently_working'] == true;

          final dateText =
              (start.isNotEmpty || end.isNotEmpty || currentlyWorking)
                  ? "$start - ${currentlyWorking ? 'Present' : end}"
                  : "";

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.color.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      isFresher
                          ? Icons.school_outlined
                          : Icons.work_outline_rounded,
                      size: 20,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFresher
                            ? "Fresher"
                            : (title.isNotEmpty ? title : "Experience"),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      if (company.isNotEmpty)
                        Text(
                          company,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.color.textLightColor,
                          ),
                        ),
                      if (dateText.isNotEmpty)
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: context.color.textLightColor,
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _showExperienceBottomSheet(
                      initialData: exp,
                      editIndex: index,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _experiencesList.removeAt(index);
                    });
                    setSheetState(() {});
                    _saveJobProfileData();
                    if (_experiencesList.isEmpty) {
                      Navigator.pop(sheetCtx);
                    }
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showManageLicencesSheet() {
    if (_licencesList.isEmpty) {
      _showLicenceFormSheet();
      return;
    }

    _showManageListSheet(
      title: "Manage Licenses & Certificates",
      addLabel: "Add New License / Certificate",
      onAddNew: _showLicenceFormSheet,
      itemsBuilder: (sheetCtx, setSheetState) {
        return List.generate(_licencesList.length, (index) {
          final lic = _licencesList[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.color.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.lightbulb_outline_rounded,
                        size: 20, color: Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lic['name'] ?? 'Certificate',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: context.color.textLightColor,
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _showLicenceFormSheet(
                      editIndex: index,
                      initialData: lic,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  onPressed: () {
                    setState(() => _licencesList.removeAt(index));
                    setSheetState(() {});
                    _saveJobProfileData();
                    if (_licencesList.isEmpty) {
                      Navigator.pop(sheetCtx);
                    }
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showManagePortfolioSheet() {
    if (_portfoliosList.isEmpty) {
      _showPortfolioFormSheet();
      return;
    }

    _showManageListSheet(
      title: "Manage Portfolio Links",
      addLabel: "Add New Portfolio Link",
      onAddNew: _showPortfolioFormSheet,
      itemsBuilder: (sheetCtx, setSheetState) {
        return List.generate(_portfoliosList.length, (index) {
          final p = _portfoliosList[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.color.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.link_rounded,
                        size: 20, color: Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] ?? 'Portfolio',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      if (p['link'] != null && p['link']!.isNotEmpty)
                        Text(
                          p['link']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: context.color.textLightColor,
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _showPortfolioFormSheet(
                      editIndex: index,
                      initialData: p,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  onPressed: () {
                    setState(() => _portfoliosList.removeAt(index));
                    setSheetState(() {});
                    _saveJobProfileData();
                    if (_portfoliosList.isEmpty) {
                      Navigator.pop(sheetCtx);
                    }
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showManageReferenceSheet() {
    if (_referencesList.isEmpty) {
      _showReferenceFormSheet();
      return;
    }

    _showManageListSheet(
      title: "Manage References",
      addLabel: "Add New Reference",
      onAddNew: _showReferenceFormSheet,
      itemsBuilder: (sheetCtx, setSheetState) {
        return List.generate(_referencesList.length, (index) {
          final ref = _referencesList[index];
          final company = ref['company'] ?? ref['org'] ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.color.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.person_outline_rounded,
                        size: 20, color: Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref['name'] ?? 'Reference',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      if (company.isNotEmpty)
                        Text(
                          company,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.color.textLightColor,
                          ),
                        ),
                      if (ref['contact'] != null && ref['contact']!.isNotEmpty)
                        Text(
                          ref['contact']!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: context.color.textLightColor,
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _showReferenceFormSheet(
                      editIndex: index,
                      initialData: ref,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  onPressed: () {
                    setState(() => _referencesList.removeAt(index));
                    setSheetState(() {});
                    _saveJobProfileData();
                    if (_referencesList.isEmpty) {
                      Navigator.pop(sheetCtx);
                    }
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildWaveformGraphic() {
    final heights = [
      12.0,
      20.0,
      32.0,
      16.0,
      28.0,
      40.0,
      22.0,
      36.0,
      48.0,
      26.0,
      38.0,
      18.0,
      30.0,
      42.0,
      20.0,
      34.0,
      16.0,
      24.0,
      14.0
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: heights.map((h) {
        return Container(
          width: 3,
          height: h,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResumeDocumentGraphic() {
    return Container(
      width: 48,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          Container(width: 28, height: 2.5, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 4),
          Container(width: 22, height: 2.5, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 4),
          Container(width: 26, height: 2.5, color: const Color(0xFFE2E8F0)),
        ],
      ),
    );
  }

  Future<void> _toggleAudioPlayback() async {
    if (_audioIntroPath == null || _audioIntroPath!.isEmpty) return;

    if (_isPlayingAudio) {
      await _audioPlayer?.pause();
      if (mounted) setState(() => _isPlayingAudio = false);
      return;
    }

    _audioPlayer ??= AudioPlayer();
    _audioPlayer!.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });

    try {
      if (_audioIntroPath!.startsWith('http')) {
        await _audioPlayer!.play(UrlSource(_audioIntroPath!));
      } else {
        await _audioPlayer!.play(DeviceFileSource(_audioIntroPath!));
      }
      if (mounted) setState(() => _isPlayingAudio = true);
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Could not play audio: $e",
        type: MessageType.error,
      );
    }
  }

  Future<void> _viewResume() async {
    if (_resumeFile != null && _resumeFile!.existsSync()) {
      try {
        await OpenFilex.open(_resumeFile!.path);
      } catch (_) {
        HelperUtils.showSnackBarMessage(
          context,
          "Resume: ${_resumeFile!.path.split(Platform.pathSeparator).last}",
          type: MessageType.success,
        );
      }
    } else if (_existingResumeUrl != null && _existingResumeUrl!.isNotEmpty) {
      final uri = Uri.parse(_existingResumeUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      _pickResumeFile();
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Qualifications Tile (Supports Multiple Qualifications)
  // ---------------------------------------------------------------------------
  Widget _buildQualificationTile() {
    final hasQuals = _qualificationsList.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: "Qualifications",
            onAdd: () => _showQualificationsBottomSheet(),
            onEdit: hasQuals ? _showManageQualificationsSheet : null,
          ),
          const SizedBox(height: 12),
          if (!hasQuals) ...[
            InkWell(
              onTap: () => _showQualificationsBottomSheet(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.school_outlined,
                            size: 22, color: Color(0xFF3B82F6)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "+ Add Qualifications (Degree, College, Years)",
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Column(
              children: List.generate(_qualificationsList.length, (index) {
                final q = _qualificationsList[index];
                final degree = q['degree']?.toString() ?? '';
                final spec = q['specialization']?.toString() ?? '';
                final uni = q['university_name']?.toString() ?? '';
                final fromYear = q['graduation_from']?.toString() ?? '';
                final toYear = q['graduation_to']?.toString() ?? '';

                final titleText = degree.isNotEmpty ? degree : spec;
                final subtitleText = uni.isNotEmpty ? uni : spec;
                final yearsText = (fromYear.isNotEmpty || toYear.isNotEmpty)
                    ? "$fromYear - $toYear"
                    : "";

                return _buildItemTile(
                  icon: Icons.school_outlined,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText.isNotEmpty ? titleText : "Qualification",
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      if (subtitleText.isNotEmpty && subtitleText != titleText)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            subtitleText,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ),
                      if (yearsText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            yearsText,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.color.textLightColor,
                            ),
                          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: "Experience",
            onAdd: () => _showExperienceBottomSheet(),
            onEdit: hasExps ? _showManageExperienceSheet : null,
          ),
          const SizedBox(height: 12),
          if (!hasExps) ...[
            InkWell(
              onTap: () => _showExperienceBottomSheet(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.work_outline_rounded,
                            size: 22, color: Color(0xFF3B82F6)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "+ Add Work Experience",
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Column(
              children: List.generate(_experiencesList.length, (index) {
                final exp = _experiencesList[index];
                final isFresher = exp['fresher'] == 1 ||
                    exp['fresher'] == "1" ||
                    exp['fresher'] == true;
                final title = exp['experience_job_titel']?.toString() ?? '';
                final company = exp['experience_company']?.toString() ?? '';
                final start = exp['experience_start_date']?.toString() ?? '';
                final end = exp['experience_end_date']?.toString() ?? '';
                final currentlyWorking = exp['currently_working'] == 1 ||
                    exp['currently_working'] == "1" ||
                    exp['currently_working'] == true;

                final dateText =
                    (start.isNotEmpty || end.isNotEmpty || currentlyWorking)
                        ? "$start - ${currentlyWorking ? 'Present' : end}"
                        : "";

                return _buildItemTile(
                  icon: isFresher
                      ? Icons.school_outlined
                      : Icons.work_outline_rounded,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isFresher) ...[
                        Text(
                          "Fresher",
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        Text(
                          "Looking for first job opportunity",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ] else ...[
                        Text(
                          title.isNotEmpty ? title : "Experience",
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        if (company.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              company,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.color.textLightColor,
                              ),
                            ),
                          ),
                        if (dateText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              dateText,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.color.textLightColor,
                              ),
                            ),
                          ),
                      ],
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
  // 4. Licenses or Certificates Tile
  // ---------------------------------------------------------------------------
  Widget _buildLicencesTile() {
    final hasLics = _licencesList.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: "Licenses or Certificates",
            onAdd: _showLicenceFormSheet,
            onEdit: hasLics ? _showManageLicencesSheet : null,
          ),
          const SizedBox(height: 12),
          if (!hasLics) ...[
            InkWell(
              onTap: _showLicenceFormSheet,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.lightbulb_outline_rounded,
                            size: 22, color: Color(0xFF3B82F6)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "+ Add Licenses or Certificates",
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ...List.generate(_licencesList.length, (index) {
              final lic = _licencesList[index];
              return _buildItemTile(
                icon: Icons.lightbulb_outline_rounded,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lic['name'] ?? 'Certificate',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    if (lic['org'] != null && lic['org']!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          lic['org']!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Skills Tile
  // ---------------------------------------------------------------------------
  Widget _buildSkillsTile() {
    final hasSkills = _skillsList.isNotEmpty || _jobCategory != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: "Skills",
            onEdit: _showSkillsBottomSheet,
          ),
          const SizedBox(height: 12),
          if (!hasSkills) ...[
            InkWell(
              onTap: _showSkillsBottomSheet,
              child: Text(
                "+ Add skills (e.g. Flutter, React, Communication)",
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_jobCategory != null && _jobCategory!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _jobCategory!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ..._skillsList.map((s) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.color.borderColor.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Resume Tile
  // ---------------------------------------------------------------------------
  Widget _buildResumeTile() {
    final hasResume = _resumeFile != null ||
        (_existingResumeUrl != null && _existingResumeUrl!.isNotEmpty);

    final fileName = _resumeFile != null
        ? _resumeFile!.path.split(Platform.pathSeparator).last
        : (_existingResumeUrl != null
            ? _existingResumeUrl!.split('/').last
            : "Resume.pdf");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: "Resume",
            onEdit: _pickResumeFile,
          ),
          const SizedBox(height: 12),
          if (hasResume) ...[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.color.borderColor.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                children: [
                  // Top Banner Graphic
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Center(
                      child: _buildResumeDocumentGraphic(),
                    ),
                  ),
                  // Bottom info row + View button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Resume",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.color.textLightColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            minimumSize: const Size(0, 32),
                            side: BorderSide(color: context.color.borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _viewResume,
                          child: Text(
                            "View",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            InkWell(
              onTap: _pickResumeFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: context.color.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.color.borderColor.withValues(alpha: 0.8),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined,
                        size: 28, color: Color(0xFF3B82F6)),
                    const SizedBox(height: 6),
                    Text(
                      "+ Upload Resume (PDF, DOCX)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Digital Profile Tile
  // ---------------------------------------------------------------------------
  Widget _buildDigitalProfileTile() {
    final hasAudio = _audioIntroPath != null && _audioIntroPath!.isNotEmpty;
    final hasVideo = _videoIntroPath != null && _videoIntroPath!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: "Digital Profile",
            onEdit: _showDigitalProfileBottomSheet,
          ),
          const SizedBox(height: 12),

          // Audio Profile Card
          if (hasAudio) ...[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.color.borderColor.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Center(
                      child: _buildWaveformGraphic(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mic_none_rounded,
                          color: Color(0xFF2563EB),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Audio Profile",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Voice Introduction",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.color.textLightColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _toggleAudioPlayback,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlayingAudio
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Video Profile Tile / Add Video
          if (hasVideo) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.color.borderColor.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.videocam_rounded,
                          size: 22, color: Color(0xFF3B82F6)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Video Profile",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Video Introduction Recorded",
                          style: TextStyle(
                            fontSize: 12,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    color: context.color.textLightColor,
                    onPressed: _showDigitalProfileBottomSheet,
                  ),
                ],
              ),
            ),
          ] else ...[
            InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  IntroductionRecordingScreen.route(RecordingType.video),
                );
                if (result != null && result is Map) {
                  final path = result['filePath']?.toString();
                  setState(() {
                    _videoIntroPath = path;
                  });
                  HiveUtils.setVideoIntroPath(path);
                  await _saveJobProfileData();
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.color.borderColor.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add,
                            size: 18, color: context.color.textDefaultColor),
                        const SizedBox(width: 6),
                        Text(
                          "Add Video",
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Add video to grab potential employer attention",
                      style: TextStyle(
                        fontSize: 12,
                        color: context.color.textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8. Portfolio Tile
  // ---------------------------------------------------------------------------
  Widget _buildPortfolioTile() {
    final hasPorts = _portfoliosList.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: "Portfolio",
            onAdd: _showPortfolioFormSheet,
            onEdit: hasPorts ? _showManagePortfolioSheet : null,
          ),
          const SizedBox(height: 12),
          if (!hasPorts) ...[
            InkWell(
              onTap: _showPortfolioFormSheet,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.link_rounded,
                            size: 22, color: Color(0xFF3B82F6)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "+ Add Portfolio Link (GitHub, Behance, Website)",
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ...List.generate(_portfoliosList.length, (index) {
              final p = _portfoliosList[index];
              return _buildItemTile(
                icon: Icons.link_rounded,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'] ?? 'Portfolio',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    if (p['link'] != null && p['link']!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: InkWell(
                          onTap: () async {
                            final raw = p['link']!;
                            final url = raw.startsWith('http')
                                ? raw
                                : 'https://$raw';
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Text(
                            p['link']!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF2563EB),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 9. Reference Tile
  // ---------------------------------------------------------------------------
  Widget _buildReferenceTile() {
    final hasRefs = _referencesList.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: "Reference",
            onAdd: _showReferenceFormSheet,
            onEdit: hasRefs ? _showManageReferenceSheet : null,
          ),
          const SizedBox(height: 12),
          if (!hasRefs) ...[
            InkWell(
              onTap: _showReferenceFormSheet,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_outline_rounded,
                            size: 22, color: Color(0xFF3B82F6)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "+ Add Reference",
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ...List.generate(_referencesList.length, (index) {
              final ref = _referencesList[index];
              return _buildItemTile(
                icon: Icons.person_outline_rounded,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref['name'] ?? 'Reference',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    if (ref['company'] != null && ref['company']!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          ref['company']!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                      )
                    else if (ref['org'] != null && ref['org']!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          ref['org']!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ),
                    if (ref['contact'] != null && ref['contact']!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          ref['contact']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
