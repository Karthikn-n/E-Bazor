import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/seller/fetch_seller_verification_field.dart';
import 'package:Ebozor/data/cubits/seller/fetch_verification_request_cubit.dart';
import 'package:Ebozor/data/cubits/seller/send_verification_field_cubit.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';

class SellerVerificationScreen extends StatefulWidget {
  final bool isResubmitted;

  const SellerVerificationScreen({super.key, required this.isResubmitted});

  @override
  State<SellerVerificationScreen> createState() =>
      _SellerVerificationScreenState();

  static Route route(RouteSettings settings) {
    final arguments = settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) {
        return SellerVerificationScreen(
          isResubmitted: arguments?["isResubmitted"] ?? false,
        );
      },
    );
  }
}

class _SellerVerificationScreenState extends State<SellerVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Dynamic Fields and Files
  final Map<int, File> _uploadedFiles = {}; // verificationFieldId -> File
  final Map<int, String> _fieldValues = {}; // verificationFieldId -> String
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      context
          .read<FetchSellerVerificationFieldsCubit>()
          .fetchSellerVerificationFields();
      if (widget.isResubmitted) {
        context
            .read<FetchVerificationRequestsCubit>()
            .fetchVerificationRequests();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _verifiedPhone {
    final user = HiveUtils.getUserDetails();
    return user.mobile?.trim() ?? "";
  }

  Future<void> _pickImageForField(int fieldId, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null && mounted) {
        setState(() {
          _uploadedFiles[fieldId] = File(picked.path);
        });
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Could not access camera/gallery: $e",
        type: MessageType.error,
      );
    }
  }

  Future<void> _pickVideoForField(int fieldId, ImageSource source) async {
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
      if (picked != null && mounted) {
        setState(() {
          _uploadedFiles[fieldId] = File(picked.path);
        });
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Could not capture video: $e",
        type: MessageType.error,
      );
    }
  }

  void _showImageSourcePicker(int fieldId, {bool isVideo = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.color.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isVideo ? "Upload Video Selfie" : "Upload Document",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.color.territoryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVideo
                        ? Icons.videocam_rounded
                        : Icons.camera_alt_outlined,
                    color: context.color.territoryColor,
                  ),
                ),
                title: Text(
                  isVideo
                      ? "Record Video Selfie"
                      : "takeNewPhoto".translate(context),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.color.textDefaultColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isVideo) {
                    _pickVideoForField(fieldId, ImageSource.camera);
                  } else {
                    _pickImageForField(fieldId, ImageSource.camera);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.color.territoryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: context.color.territoryColor,
                  ),
                ),
                title: Text(
                  "chooseFromLibrary".translate(context),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.color.textDefaultColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isVideo) {
                    _pickVideoForField(fieldId, ImageSource.gallery);
                  } else {
                    _pickImageForField(fieldId, ImageSource.gallery);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitVerification(List<VerificationFieldModel> fields) {
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields
    for (final field in fields) {
      if (field.required == 1) {
        if (field.type == 'fileinput') {
          if (!_uploadedFiles.containsKey(field.id)) {
            HelperUtils.showSnackBarMessage(
              context,
              "Please upload ${field.name ?? 'required document'}",
              type: MessageType.warning,
            );
            return;
          }
        }
      }
    }

    final Map<String, dynamic> data = {};

    // 1. Scalar fields
    for (final field in fields) {
      if (field.id == null) continue;
      if (field.type == 'fileinput') continue;

      if (field.name?.toLowerCase().contains('phone') == true) {
        data['verification_field[${field.id}]'] = _verifiedPhone;
      } else if (_textControllers.containsKey(field.id)) {
        data['verification_field[${field.id}]'] =
            _textControllers[field.id]!.text.trim();
      } else if (_fieldValues.containsKey(field.id)) {
        data['verification_field[${field.id}]'] = _fieldValues[field.id];
      }
    }

    // Always include phone field (ID 4) if present
    if (!data.keys.any((k) => k.contains('verification_field[4]')) &&
        _verifiedPhone.isNotEmpty) {
      data['verification_field[4]'] = _verifiedPhone;
    }

    // 2. Add files: verification_field_files[id]
    _uploadedFiles.forEach((fieldId, file) {
      data['verification_field_files[$fieldId]'] = file;
    });

    context.read<SendVerificationFieldCubit>().send(data: data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SendVerificationFieldCubit, SendVerificationFieldState>(
      listener: (context, state) {
        if (state is SendVerificationFieldInProgress) {
          Widgets.showLoader(context);
        } else if (state is SendVerificationFieldSuccess) {
          Widgets.hideLoder(context);
          try {
            context
                .read<FetchVerificationRequestsCubit>()
                .fetchVerificationRequests();
          } catch (_) {}
          HelperUtils.showSnackBarMessage(
            context,
            state.message.isNotEmpty
                ? state.message
                : "Verification request submitted successfully.",
            type: MessageType.success,
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                Routes.sellerVerificationComplteScreen,
              );
            }
          });
        } else if (state is SendVerificationFieldFail) {
          Widgets.hideLoder(context);
          HelperUtils.showSnackBarMessage(
            context,
            state.error.toString(),
            type: MessageType.error,
          );
        }
      },
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: AppBar(
          backgroundColor: context.color.secondaryColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.color.textDefaultColor,
              size: 20,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            "userVerification".translate(context),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.color.textDefaultColor,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: BlocBuilder<FetchSellerVerificationFieldsCubit,
              FetchSellerVerificationFieldState>(
            builder: (context, state) {
              if (state is FetchSellerVerificationFieldInProgress) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is FetchSellerVerificationFieldFail) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 44,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.color.textDefaultColor,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.color.territoryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            context
                                .read<FetchSellerVerificationFieldsCubit>()
                                .fetchSellerVerificationFields();
                          },
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final fields = state is FetchSellerVerificationFieldSuccess
                  ? state.fields
                  : <VerificationFieldModel>[];

              return Form(
                key: _formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVerifiedBadgeHeader(),
                      const SizedBox(height: 14),
                      _buildVerifiedPhoneTile(),
                      const SizedBox(height: 20),
                      _buildDocumentsSection(fields),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVerifiedBadgeHeader() {
    final user = HiveUtils.getUserDetails();
    final displayName = user.name?.isNotEmpty == true
        ? user.name!
        : (user.email?.isNotEmpty == true
            ? user.email!.split('@').first
            : "Seller");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.verified_rounded,
                    color: context.color.territoryColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Verified Seller Badge",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Upload your identity documents to earn the verified badge across all your listings.",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.color.textLightColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Badge Preview Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.color.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.verified,
                  size: 15,
                  color: context.color.territoryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  "Verified Seller",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.color.territoryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedPhoneTile() {
    final phone = _verifiedPhone;
    if (phone.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              color: Colors.green,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Verified Mobile Number",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.color.textLightColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 12, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  "Verified",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(List<VerificationFieldModel> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Upload Identity Documents",
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            color: context.color.textDefaultColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Please upload clear photos of your official ID and a short face clip selfie.",
          style: TextStyle(
            fontSize: 12.5,
            color: context.color.textLightColor,
          ),
        ),
        const SizedBox(height: 14),

        // Render dynamic document fields
        ...fields.map((field) {
          if (field.id == null) return const SizedBox.shrink();
          final isPhone =
              field.name?.toLowerCase().contains('phone') == true;
          if (isPhone) return const SizedBox.shrink();

          if (field.type == 'fileinput') {
            final isFaceClip =
                field.name?.toLowerCase().contains('face') == true ||
                    field.name?.toLowerCase().contains('video') == true;
            return _buildFileTile(
              fieldId: field.id!,
              title: field.name ?? "Document",
              isRequired: field.required == 1,
              isVideo: isFaceClip,
            );
          }

          // Fallback dynamic input
          _textControllers.putIfAbsent(
              field.id!, () => TextEditingController());
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${field.name ?? 'Field'} ${field.required == 1 ? '*' : ''}",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _textControllers[field.id!],
                  decoration: InputDecoration(
                    hintText: "Enter ${field.name ?? ''}",
                    filled: true,
                    fillColor: context.color.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: context.color.borderColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 18),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.color.territoryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _submitVerification(fields),
            child: const Text(
              "Submit Verification Request",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileTile({
    required int fieldId,
    required String title,
    required bool isRequired,
    required bool isVideo,
  }) {
    final file = _uploadedFiles[fieldId];
    final hasFile = file != null && file.existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFile
              ? Colors.green.withValues(alpha: 0.6)
              : context.color.borderColor.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isVideo
                        ? Icons.videocam_rounded
                        : Icons.badge_outlined,
                    size: 18,
                    color: hasFile
                        ? Colors.green
                        : context.color.territoryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$title ${isRequired ? '*' : ''}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ],
              ),
              if (hasFile)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    "Ready",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasFile) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                height: 130,
                color: context.color.backgroundColor,
                child: isVideo
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.video_file_rounded,
                              size: 36,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              file.path.split('/').last.split('\\').last,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Image.file(
                        file,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text("Retake"),
                  onPressed: () =>
                      _showImageSourcePicker(fieldId, isVideo: isVideo),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline,
                      size: 15, color: Colors.red),
                  label: const Text("Remove",
                      style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    setState(() {
                      _uploadedFiles.remove(fieldId);
                    });
                  },
                ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: () => _showImageSourcePicker(fieldId, isVideo: isVideo),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                height: 84,
                decoration: BoxDecoration(
                  color: context.color.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.color.borderColor.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isVideo
                          ? Icons.video_camera_front_outlined
                          : Icons.cloud_upload_outlined,
                      size: 26,
                      color: context.color.territoryColor,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isVideo
                          ? "Tap to record or upload face video"
                          : "Tap to capture or upload $title",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
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
}
