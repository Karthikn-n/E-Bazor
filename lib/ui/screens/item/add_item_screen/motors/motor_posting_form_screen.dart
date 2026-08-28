import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/ui/screens/advertisement/my_advertisment_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/data/repositories/custom_fields_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/dynamic_custom_fields_form.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/posting_form_shared.dart';

class MotorPostingFormScreen extends StatefulWidget {
  final CategoryModel? category;
  final List<CategoryModel>? breadcrumbs;
  final List<CustomFieldModel>? customFields;
  final bool isEdit;
  final ItemModel? item;

  const MotorPostingFormScreen({
    super.key,
    this.category,
    this.breadcrumbs,
    this.customFields,
    this.isEdit = false,
    this.item,
  });

  static Route route(RouteSettings settings) {
    Map<String, dynamic>? arguments =
        settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) => MotorPostingFormScreen(
        category: arguments?['category'] ?? arguments?['current'],
        breadcrumbs: arguments?['breadcrumbs'] ?? arguments?['breadCrumbItems'],
        customFields: arguments?['customFields'],
        isEdit: arguments?['isEdit'] ?? false,
        item: arguments?['item'],
      ),
    );
  }

  @override
  State<MotorPostingFormScreen> createState() => _MotorPostingFormScreenState();
}

class _MotorPostingFormScreenState extends State<MotorPostingFormScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  final List<String> _existingNetworkImages = [];

  // Form Field Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _showPhone = true;
  int _descriptionCharCount = 0;
  bool _termsAgreed = true;
  bool _isLoadingDynamicFields = false;
  // Location Data
  PostingLocationData _location = PostingLocationData.saved();

  final DynamicCustomFieldsController _adminFieldsController =
      DynamicCustomFieldsController();

  @override
  void initState() {
    super.initState();
    final savedCode = HiveUtils.getCountryCode();
    final countryCode = savedCode != null && savedCode.isNotEmpty
        ? (savedCode.startsWith('+') ? savedCode : '+$savedCode')
        : '+971';
    final user = HiveUtils.getUserDetails();
    final userMobile = user.mobile?.trim() ?? '';

    if (userMobile.isNotEmpty) {
      if (userMobile.startsWith('+')) {
        _phoneController.text = userMobile;
      } else if (savedCode != null &&
          savedCode.isNotEmpty &&
          !userMobile.startsWith(savedCode.replaceAll('+', ''))) {
        _phoneController.text = '$countryCode $userMobile';
      } else {
        _phoneController.text = userMobile;
      }
    } else {
      _phoneController.text = countryCode;
    }

    final item = widget.item;
    if (item != null) {
      _titleController.text = item.name ?? "";
      _descriptionController.text = item.description ?? "";
      if (item.price != null && item.price! > 0) {
        _priceController.text = (item.price! % 1 == 0)
            ? item.price!.toInt().toString()
            : item.price.toString();
      }
      if (item.contact != null && item.contact.toString().isNotEmpty) {
        _phoneController.text = item.contact.toString();
      }
      _showPhone = item.hidePhoneNumber != 1 && item.hidePhoneNumber != true;
      if (item.latitude != null && item.longitude != null) {
        _location = PostingLocationData(
          coordinates: LatLng(item.latitude!, item.longitude!),
          city: item.city ?? _location.city,
          state: item.state ?? item.city ?? _location.state,
          country: item.country ?? _location.country,
          address: item.address ?? item.city ?? _location.address,
          area: item.area ?? item.address ?? item.city ?? _location.area,
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

    _descriptionController.addListener(() {
      setState(() {
        _descriptionCharCount = _descriptionController.text.length;
      });
    });

    final existingFields = widget.item?.customFields ?? widget.customFields;
    if (existingFields != null && existingFields.isNotEmpty) {
      _populateDynamicCustomFields(existingFields);
    }
    _fetchDynamicCustomFields();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _adminFieldsController.dispose();
    super.dispose();
  }

  void _populateDynamicCustomFields(List<CustomFieldModel> fields) {
    _adminFieldsController.replaceFields(fields);
  }

  Future<void> _fetchDynamicCustomFields() async {
    final catId = widget.category?.id ??
        widget.item?.categoryId ??
        (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty
            ? widget.breadcrumbs!.last.id
            : null);
    if (catId == null) return;

    setState(() => _isLoadingDynamicFields = true);
    try {
      final fields =
          await CustomFieldRepository().getCustomFieldsByCategoryId(catId);
      log("📦 [DYNAMIC CUSTOM FIELDS] Fetched ${fields.length} dynamic fields for category $catId");

      if (mounted && fields.isNotEmpty) {
        final existingFields = widget.item?.customFields ?? widget.customFields;
        if (existingFields != null && existingFields.isNotEmpty) {
          final existingMapById = <int, CustomFieldModel>{};
          final existingMapByName = <String, CustomFieldModel>{};
          for (final cf in existingFields) {
            if (cf.id != null) existingMapById[cf.id!] = cf;
            final n = (cf.name ?? cf.label ?? '').trim().toLowerCase();
            if (n.isNotEmpty) existingMapByName[n] = cf;
          }
          for (final f in fields) {
            final n = (f.name ?? f.label ?? '').trim().toLowerCase();
            if (f.id != null && existingMapById.containsKey(f.id!)) {
              f.value = existingMapById[f.id!]!.value;
            } else if (n.isNotEmpty && existingMapByName.containsKey(n)) {
              f.value = existingMapByName[n]!.value;
            }
          }
        }
        setState(() {
          _populateDynamicCustomFields(fields);
        });
      }
    } catch (e) {
      log("⚠️ [DYNAMIC CUSTOM FIELDS ERROR] Could not fetch category custom fields: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDynamicFields = false);
    }
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
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  String _getBreadcrumbText() {
    if (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty) {
      return widget.breadcrumbs!.map((e) => e.name ?? '').join('  ›  ');
    }
    return widget.category?.name ?? 'Motors';
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

    final price =
        double.tryParse(_priceController.text.replaceAll(',', '').trim());
    if (_priceController.text.trim().isEmpty || price == null || price <= 0) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a valid Price in AED",
        type: MessageType.warning,
      );
      return;
    }

    final savedCode = HiveUtils.getCountryCode();
    final countryCodeDigits =
        (savedCode ?? '971').replaceAll(RegExp(r'[^0-9]'), '');
    final contactDigits =
        _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (contactDigits.isEmpty ||
        contactDigits == countryCodeDigits ||
        contactDigits.length < 7) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a valid contact phone number",
        type: MessageType.warning,
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please provide a description of your item",
        type: MessageType.warning,
      );
      return;
    }

    if (!_termsAgreed) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please accept the posting guidelines to proceed",
        type: MessageType.warning,
      );
      return;
    }

    final isEditMode = widget.isEdit || widget.item != null;

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

    final customFieldError = _adminFieldsController.validate();
    if (customFieldError != null) {
      HelperUtils.showSnackBarMessage(
        context,
        customFieldError,
        type: MessageType.warning,
      );
      return;
    }

    final categoryId = widget.category?.id ??
        widget.item?.categoryId ??
        (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty
            ? widget.breadcrumbs!.last.id
            : 1);
    final allCategoryIds =
        isEditMode && (widget.item?.allCategoryIds?.trim().isNotEmpty ?? false)
            ? widget.item!.allCategoryIds!
            : widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty
                ? widget.breadcrumbs!
                    .map((b) => b.id)
                    .where((id) => id != null)
                    .join(',')
                : (widget.item?.allCategoryIds ?? "$categoryId");

    final itemDetails = <String, dynamic>{
      if (isEditMode && widget.item?.id != null) 'id': widget.item!.id,
      if (isEditMode && (widget.item?.status?.trim().isNotEmpty ?? false))
        'status': widget.item!.status,
      'name': _titleController.text.trim(),
      'slug': _titleController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      'category_id': categoryId,
      'all_category_ids': allCategoryIds,
      'price': (price % 1 == 0) ? price.toInt() : price,
      'description': _descriptionController.text.trim(),
      'contact': contactDigits,
      'hide_phone_number': _showPhone ? 0 : 1,
      ..._location.toItemDetails(),
    };

    final mergedCustomFields = _adminFieldsController.toSubmissionMap();

    if (mergedCustomFields.isNotEmpty) {
      itemDetails['custom_fields'] = jsonEncode(mergedCustomFields);
    }

    Widgets.showLoader(context);

    if (isEditMode) {
      late final ItemModel updatedItem;
      try {
        itemDetails.addAll(
          await _adminFieldsController.toFileSubmissionMap(),
        );
        final mainImg =
            _selectedImages.isNotEmpty ? _selectedImages.first : null;
        final otherImgs =
            _selectedImages.length > 1 ? _selectedImages.sublist(1) : null;
        updatedItem =
            await ItemRepository().editItem(itemDetails, mainImg, otherImgs);
      } catch (e) {
        log("Item edit API error: $e");
        Widgets.hideLoder(context);
        if (mounted) {
          HelperUtils.showSnackBarMessage(
            context,
            "Failed to update ad: $e",
            type: MessageType.error,
          );
        }
        return;
      } finally {
        Widgets.hideLoder(context);
      }

      if (!mounted) return;

      HelperUtils.showSnackBarMessage(
        context,
        "Ad updated successfully!",
        type: MessageType.success,
      );
      try {
        MyAdvertisementScreen.refreshCallback?.call();
      } catch (_) {}
      Navigator.of(context).pop(updatedItem);
      return;
    }

    ItemModel? createdItemModel;
    try {
      itemDetails.addAll(
        await _adminFieldsController.toFileSubmissionMap(),
      );
      final mainImg = _selectedImages.isNotEmpty ? _selectedImages.first : null;
      final otherImgs =
          _selectedImages.length > 1 ? _selectedImages.sublist(1) : <File>[];
      createdItemModel =
          await ItemRepository().createItem(itemDetails, mainImg, otherImgs);
    } catch (e) {
      log("Item create API log error: $e");
      Widgets.hideLoder(context);
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to create ad: ${e.toString().replaceAll("ApiException: ", "").replaceAll("Exception: ", "")}",
          type: MessageType.error,
        );
      }
      return;
    } finally {
      Widgets.hideLoder(context);
    }

    // ignore: unnecessary_null_comparison
    if (createdItemModel == null || createdItemModel.id == null) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Could not complete ad creation. Please try again.",
          type: MessageType.error,
        );
      }
      return;
    }

    try {
      MyAdvertisementScreen.refreshCallback?.call();
    } catch (_) {}

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      Routes.carPackagePaymentScreen,
      arguments: {
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
                          "Tell us about your listing",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Breadcrumbs Link
                      Row(
                        children: [
                          Icon(
                            Icons.sell_outlined,
                            size: 15,
                            color: const Color(0xFF3366FF),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _getBreadcrumbText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3366FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 1. Title
                      const PostingFieldLabel("Title *"),
                      _buildTextField(
                        controller: _titleController,
                        hint: "Title *",
                        maxLength: 100,
                      ),
                      const SizedBox(height: 18),

                      // 2. Price (AED)
                      const PostingFieldLabel("Price *"),
                      _buildTextField(
                        controller: _priceController,
                        hint: "Price *",
                        keyboardType: TextInputType.number,
                        suffixText: "AED",
                      ),
                      const SizedBox(height: 18),

                      // 3. Photos Section
                      PostingPicturesSection(
                        images: _selectedImages,
                        existingImages: _existingNetworkImages,
                        onAdd: _pickImages,
                        onRemove: _removeImage,
                        onRemoveExisting: (index) => setState(
                            () => _existingNetworkImages.removeAt(index)),
                      ),
                      const SizedBox(height: 20),

                      // 4. Contact Number
                      const PostingFieldLabel("Contact number *"),
                      _buildContactNumberField(context),
                      const SizedBox(height: 18),

                      // Show/Hide Phone Number Toggle (Expanded to prevent overflow)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Do you want to show or hide your phone number?",
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.info_outline,
                            size: 15,
                            color: context.color.textLightColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildToggleButton(
                            title: "Show Phone",
                            isSelected: _showPhone,
                            onTap: () => setState(() => _showPhone = true),
                          ),
                          const SizedBox(width: 12),
                          _buildToggleButton(
                            title: "Hide Phone",
                            isSelected: !_showPhone,
                            onTap: () => setState(() => _showPhone = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 5. Description
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
                      const SizedBox(height: 24),

                      // 6. Category-Specific Dynamic Form Sections (Vehicle Specs / Item Details)
                      ..._buildCategorySpecificFields(context),

                      // 7. Live Google Map Section
                      PostingLocationSection(
                        location: _location,
                        onChanged: (value) => setState(() => _location = value),
                      ),
                      const SizedBox(height: 20),

                      // 8. Guidelines & Disclaimer
                      _buildGuidelinesDisclaimerBox(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Bottom Next CTA Button
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
                      backgroundColor: const Color(0xFFD31027),
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

  List<Widget> _buildCategorySpecificFields(BuildContext context) {
    return [
      DynamicCustomFieldsForm(
        controller: _adminFieldsController,
        isLoading: _isLoadingDynamicFields,
      ),
    ];
  }

  Widget _buildContactNumberField(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: context.color.textDefaultColor,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          InkWell(
            onTap: () => _phoneController.clear(),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: context.color.textLightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? context.color.territoryColor.withValues(alpha: 0.1)
              : context.color.secondaryColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? context.color.territoryColor
                : context.color.borderColor.withValues(alpha: 0.8),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? context.color.territoryColor
                : context.color.textDefaultColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    String? suffixText,
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
        suffixText: suffixText,
        suffixStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: context.color.textDefaultColor,
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

  Widget _buildGuidelinesDisclaimerBox(BuildContext context) {
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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: context.color.textLightColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: context.color.textLightColor,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            "Your ad will be rejected if it does not comply with our ",
                      ),
                      TextSpan(
                        text: "posting guidelines",
                        style: TextStyle(
                          color: context.color.territoryColor,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: "."),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _termsAgreed,
                activeColor: const Color(0xFFD31027),
                onChanged: (val) => setState(() => _termsAgreed = val ?? true),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: context.color.textLightColor,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            "By proceeding, I confirm that I have reviewed the information provided above and confirm it is complete and accurate. ",
                      ),
                      TextSpan(
                        text: "Terms & conditions",
                        style: TextStyle(
                          color: context.color.territoryColor,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: "."),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
