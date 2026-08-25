import 'dart:convert';
import 'dart:io';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/ui/screens/advertisement/my_advertisment_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/cars/car_models.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/posting_form_shared.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/dynamic_custom_fields_form.dart';

class CarPostingDetailsScreen extends StatefulWidget {
  final CarSpecsData specsData;

  const CarPostingDetailsScreen({super.key, required this.specsData});

  static Route route(RouteSettings settings) {
    Map<String, dynamic>? arguments =
        settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) => CarPostingDetailsScreen(
        specsData: arguments!['specsData'],
      ),
    );
  }

  @override
  State<CarPostingDetailsScreen> createState() =>
      _CarPostingDetailsScreenState();
}

class _CarPostingDetailsScreenState extends State<CarPostingDetailsScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  final List<String> _existingNetworkImages = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final DynamicCustomFieldsController _detailsFieldsController =
      DynamicCustomFieldsController();

  PostingLocationData _location = const PostingLocationData.dubai();
  int _descriptionCharCount = 0;
  @override
  void initState() {
    super.initState();
    final item = widget.specsData.item;
    if (item != null) {
      _titleController.text = item.name ?? widget.specsData.displayName;
      _descriptionController.text = item.description ?? "";
      if (item.latitude != null && item.longitude != null) {
        _location = PostingLocationData(
          coordinates: LatLng(item.latitude!, item.longitude!),
          city: item.city ?? 'Dubai',
          state: item.state ?? item.city ?? 'Dubai',
          country: item.country ?? 'United Arab Emirates',
          address: item.address ?? item.city ?? 'Dubai',
          area: item.area ?? item.address ?? item.city ?? 'Dubai',
        );
      }
      if (item.image != null && item.image!.trim().isNotEmpty) {
        _existingNetworkImages.add(item.image!.trim());
      }
      if (item.galleryImages != null) {
        for (final g in item.galleryImages!) {
          final gUrl = g.image?.trim();
          if (gUrl != null &&
              gUrl.isNotEmpty &&
              !_existingNetworkImages.contains(gUrl)) {
            _existingNetworkImages.add(gUrl);
          }
        }
      }
    }

    _detailsFieldsController
        .replaceFields(widget.specsData.remainingCustomFields);
    _descriptionController.addListener(() {
      if (mounted) {
        setState(() {
          _descriptionCharCount = _descriptionController.text.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _detailsFieldsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(picked.map((p) => File(p.path)));
        });
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Failed to pick images: $e",
        type: MessageType.error,
      );
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  String _getBreadcrumbText() {
    if (widget.specsData.breadcrumbs != null &&
        widget.specsData.breadcrumbs!.isNotEmpty) {
      return widget.specsData.breadcrumbs!
          .map((e) => e.name ?? '')
          .join('  ›  ');
    }
    return widget.specsData.category?.name ?? 'Listing';
  }

  Future<void> _validateAndProceed() async {
    if (_titleController.text.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter an ad Title",
        type: MessageType.warning,
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please provide a description",
        type: MessageType.warning,
      );
      return;
    }

    final isEditMode = widget.specsData.isEdit || widget.specsData.item != null;

    if (!isEditMode &&
        _selectedImages.isEmpty &&
        _existingNetworkImages.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please add at least 1 photo for your ad",
        type: MessageType.warning,
      );
      return;
    }

    final customFieldError = _detailsFieldsController.validate();
    if (customFieldError != null) {
      HelperUtils.showSnackBarMessage(
        context,
        customFieldError,
        type: MessageType.warning,
      );
      return;
    }

    final postingData = CarPostingData(
      specs: widget.specsData,
      imageFiles: _selectedImages,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
    );
    final categoryId =
        widget.specsData.category?.id ?? widget.specsData.item?.categoryId ?? 1;
    final allCategoryIds = isEditMode &&
            (widget.specsData.item?.allCategoryIds?.trim().isNotEmpty ?? false)
        ? widget.specsData.item!.allCategoryIds!
        : widget.specsData.breadcrumbs != null &&
                widget.specsData.breadcrumbs!.isNotEmpty
            ? widget.specsData.breadcrumbs!
                .map((b) => b.id)
                .where((id) => id != null)
                .join(',')
            : (widget.specsData.item?.allCategoryIds ?? "$categoryId");
    final customFields = {
      ...widget.specsData.customFields,
      ..._detailsFieldsController.toSubmissionMap(),
    };

    final price = widget.specsData.price;
    final itemDetails = <String, dynamic>{
      if (isEditMode && widget.specsData.item?.id != null)
        'id': widget.specsData.item!.id,
      if (isEditMode &&
          (widget.specsData.item?.status?.trim().isNotEmpty ?? false))
        'status': widget.specsData.item!.status,
      'name': _titleController.text.trim(),
      'slug': _titleController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      'category_id': categoryId,
      'all_category_ids': allCategoryIds,
      'price': (price % 1 == 0) ? price.toInt() : price,
      'description': _descriptionController.text.trim(),
      'contact': widget.specsData.phoneNumber,
      'hide_phone_number': widget.specsData.showPhoneNumber ? 0 : 1,
      'car_make': widget.specsData.make.id,
      'car_model': widget.specsData.model.id,
      if (widget.specsData.trim != null) 'car_trim': widget.specsData.trim!.id,
      'car_make_id': widget.specsData.make.id,
      'car_model_id': widget.specsData.model.id,
      if (widget.specsData.trim != null)
        'car_trim_id': widget.specsData.trim!.id,
      ..._location.toItemDetails(),
      if (customFields.isNotEmpty) 'custom_fields': jsonEncode(customFields),
    };

    Widgets.showLoader(context);

    if (isEditMode) {
      try {
        itemDetails.addAll(
          await _detailsFieldsController.toFileSubmissionMap(),
        );
        final mainImg =
            _selectedImages.isNotEmpty ? _selectedImages.first : null;
        final otherImgs =
            _selectedImages.length > 1 ? _selectedImages.sublist(1) : null;
        await ItemRepository().editItem(itemDetails, mainImg, otherImgs);
      } catch (e) {
        Widgets.hideLoder(context);
        if (mounted) {
          HelperUtils.showSnackBarMessage(
            context,
            "Failed to update ad: $e",
            type: MessageType.error,
          );
        }
        return;
      }
      Widgets.hideLoder(context);
      if (!mounted) return;

      HelperUtils.showSnackBarMessage(
        context,
        "Ad updated successfully!",
        type: MessageType.success,
      );
      try {
        MyAdvertisementScreen.refreshCallback?.call();
      } catch (_) {}
      Navigator.of(context).pop(true);
      return;
    }

    late final ItemModel createdItemModel;
    try {
      itemDetails.addAll(
        await _detailsFieldsController.toFileSubmissionMap(),
      );
      final mainImg = _selectedImages.first;
      final otherImgs =
          _selectedImages.length > 1 ? _selectedImages.sublist(1) : <File>[];
      createdItemModel =
          await ItemRepository().createItem(itemDetails, mainImg, otherImgs);
    } catch (e) {
      Widgets.hideLoder(context);
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to create ad: $e",
          type: MessageType.error,
        );
      }
      return;
    }
    Widgets.hideLoder(context);
    if (!mounted) return;

    Navigator.pushNamed(
      context,
      Routes.carPackagePaymentScreen,
      arguments: {
        'postingData': postingData,
        'model': createdItemModel,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: UiUtils.buildAppBar(
            context,
            showBackButton: true,
            title: "Post Your Ad",
            onBackPress: () => Navigator.pop(context),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Title
                      Center(
                        child: Text(
                          "You're almost there!",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          "Include as much details and pictures as possible, and set the right price!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Breadcrumbs
                      Row(
                        children: [
                          Icon(
                            Icons.sell_outlined,
                            size: 15,
                            color: const Color(0xFF3366FF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getBreadcrumbText(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3366FF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Theme-based Listing Summary Card (with Edit button)
                      _buildListingSummaryCard(context),
                      const SizedBox(height: 20),

                      // 1. Add Pictures
                      PostingPicturesSection(
                        images: _selectedImages,
                        existingImages: _existingNetworkImages,
                        onAdd: _pickImages,
                        onRemove: _removeImage,
                        onRemoveExisting: (index) => setState(
                            () => _existingNetworkImages.removeAt(index)),
                      ),
                      const SizedBox(height: 20),

                      // 2. Title
                      const PostingFieldLabel("Title *"),
                      _buildTextField(
                        controller: _titleController,
                        hint: "Title *",
                        maxLength: 100,
                      ),
                      const SizedBox(height: 16),

                      // 3. Describe your item
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const PostingFieldLabel("Describe your item *"),
                          Text(
                            "$_descriptionCharCount/76000",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ],
                      ),
                      _buildTextField(
                        controller: _descriptionController,
                        hint: "Describe your item *",
                        maxLines: 5,
                      ),
                      const SizedBox(height: 20),

                      DynamicCustomFieldsForm(
                        controller: _detailsFieldsController,
                      ),

                      // 19. Integrated Live Google Map Section (UX REQUIREMENT 2)
                      PostingLocationSection(
                        location: _location,
                        onChanged: (value) => setState(() => _location = value),
                      ),
                      const SizedBox(height: 20),

                      // 20. Disclaimer Box
                      _buildDisclaimerBox(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // 21. Bottom Next Button
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _validateAndProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                          0xFFD31027), // Red CTA matching web screenshot
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Post & Continue to Payment",
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

  /// Theme-based Listing Summary Card (UX REQUIREMENT 3)
  Widget _buildListingSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Listing Summary",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "Edit",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD31027),
                  ),
                ),
              ),
            ],
          ),
          Divider(
            height: 20,
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),
          _buildSummaryRow("Emirate", widget.specsData.emirate),
          _buildSummaryRow("Make", widget.specsData.make.name),
          _buildSummaryRow("Model", widget.specsData.model.name),
          if (widget.specsData.trim != null)
            _buildSummaryRow("Trim", widget.specsData.trim!.name),
          _buildSummaryRow(
              "Price", "${widget.specsData.price.toStringAsFixed(0)} AED"),
          _buildSummaryRow("Phone number", widget.specsData.phoneNumber),
          ...widget.specsData.customFields.entries.map(
            (entry) => _buildSummaryRow(
              widget.specsData.customFieldLabels[entry.key] ?? 'Field',
              entry.value.join(', '),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: context.color.textLightColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: context.color.textDefaultColor,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: context.color.textLightColor.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: context.color.secondaryColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.8),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.color.territoryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimerBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: context.color.textLightColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Make sure the listing information is correct before publishing.",
              style: TextStyle(
                fontSize: 12,
                color: context.color.textLightColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
