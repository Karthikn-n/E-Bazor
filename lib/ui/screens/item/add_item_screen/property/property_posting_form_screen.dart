import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/custom_fields_repository.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/ui/screens/advertisement/my_advertisment_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/cloudState/cloud_state.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/dynamic_custom_fields_form.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/posting_form_shared.dart';

class PropertyPostingFormScreen extends StatefulWidget {
  final CategoryModel? category;
  final List<CategoryModel>? breadcrumbs;
  final List<CustomFieldModel>? customFields;
  final bool isEdit;
  final ItemModel? item;

  const PropertyPostingFormScreen({
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
      builder: (context) => PropertyPostingFormScreen(
        category: arguments?['category'] ?? arguments?['current'],
        breadcrumbs: arguments?['breadcrumbs'] ?? arguments?['breadCrumbItems'],
        customFields: arguments?['customFields'],
        isEdit: arguments?['isEdit'] ?? false,
        item: arguments?['item'],
      ),
    );
  }

  @override
  CloudState<PropertyPostingFormScreen> createState() =>
      _PropertyPostingFormScreenState();
}

class _PropertyPostingFormScreenState
    extends CloudState<PropertyPostingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Fields that are part of every listing, independent of dashboard custom fields.
  late final TextEditingController _titleController;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _youtubeUrlController = TextEditingController();
  final TextEditingController _tour360UrlController = TextEditingController();
  bool _showPhoneNumber = true;

  final List<File> _selectedImages = [];
  final List<String> _existingNetworkImages = [];
  final ImagePicker _picker = ImagePicker();

  bool _isLoadingDynamicFields = true;
  final DynamicCustomFieldsController _adminFieldsController =
      DynamicCustomFieldsController();
  // Location / Google Maps
  PostingLocationData _location = const PostingLocationData.dubai();
  GoogleMapController? _mapController;
  bool _isLocating = false;

  bool get _isPropertySaleOrRent {
    final categories = <CategoryModel>[
      ...?widget.breadcrumbs,
      if (widget.category != null) widget.category!,
    ];
    return categories.any((category) {
      final slug = category.slug?.trim().toLowerCase() ?? '';
      final name = category.name?.trim().toLowerCase() ?? '';
      return category.id == 65 ||
          category.id == 139 ||
          slug.contains('property-for-rent') ||
          slug.contains('property-for-sale') ||
          name == 'property for rent' ||
          name == 'property for sale';
    });
  }

  @override
  void initState() {
    super.initState();
    // New ads must always be titled explicitly on this form. Existing titles
    // are retained only while editing an item.
    final prefilled = widget.item?.name ?? "";
    _titleController = TextEditingController(text: prefilled);

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
      _youtubeUrlController.text = item.videoLink ?? "";
      _showPhoneNumber =
          item.hidePhoneNumber != 1 && item.hidePhoneNumber != true;
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

    final existingFields = widget.item?.customFields ?? widget.customFields;
    if (existingFields != null && existingFields.isNotEmpty) {
      _populateDynamicCustomFields(existingFields);
    }
    _fetchDynamicCustomFields();
  }

  void _populateDynamicCustomFields(List<CustomFieldModel> fields) {
    _adminFieldsController.replaceFields(fields);
    _isLoadingDynamicFields = false;
  }

  Future<void> _fetchDynamicCustomFields() async {
    final catId = widget.category?.id ??
        widget.item?.categoryId ??
        (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty
            ? widget.breadcrumbs!.last.id
            : null);
    if (catId == null) {
      setState(() => _isLoadingDynamicFields = false);
      return;
    }

    setState(() => _isLoadingDynamicFields = true);
    try {
      final fields =
          await CustomFieldRepository().getCustomFieldsByCategoryId(catId);
      log("📦 [PROPERTY DYNAMIC FIELDS] Fetched ${fields.length} fields for category $catId");

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
      log("⚠️ [PROPERTY DYNAMIC FIELDS ERROR]: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDynamicFields = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _youtubeUrlController.dispose();
    _tour360UrlController.dispose();
    _adminFieldsController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        imageQuality: 85,
      );
      if (picked.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(picked.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      log("Error picking images: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        final target = LatLng(position.latitude, position.longitude);
        if (mounted) {
          setState(() => _location = _location.copyWith(coordinates: target));
        }
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          final locTitle = place.subLocality?.isNotEmpty == true
              ? place.subLocality!
              : (place.locality?.isNotEmpty == true
                  ? place.locality!
                  : "My Location");
          final addr = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country
          ].where((e) => e != null && e.isNotEmpty).join(", ");

          setState(() {
            _location = PostingLocationData(
              coordinates: target,
              area: locTitle,
              city: place.locality?.trim().isNotEmpty == true
                  ? place.locality!.trim()
                  : _location.city,
              state: place.administrativeArea?.trim().isNotEmpty == true
                  ? place.administrativeArea!.trim()
                  : _location.state,
              country: place.country?.trim().isNotEmpty == true
                  ? place.country!.trim()
                  : _location.country,
              address: addr.isNotEmpty ? addr : _location.address,
            );
          });
        }
      }
    } catch (e) {
      log("Location error: $e");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _validateAndProceed() async {
    if (!_formKey.currentState!.validate()) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please fill all required fields",
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
        "Please upload at least 1 image",
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

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a valid price",
        type: MessageType.warning,
      );
      return;
    }

    final categoryId = widget.category?.id ??
        widget.item?.categoryId ??
        (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty
            ? widget.breadcrumbs!.last.id
            : 2);

    final allCategoryIds =
        isEditMode && (widget.item?.allCategoryIds?.trim().isNotEmpty ?? false)
            ? widget.item!.allCategoryIds!
            : widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty
                ? widget.breadcrumbs!
                    .map((b) => b.id)
                    .where((id) => id != null)
                    .join(',')
                : (widget.item?.allCategoryIds ?? "$categoryId");

    final mergedCustomFields = _adminFieldsController.toSubmissionMap();

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
      'contact': _phoneController.text.trim(),
      'hide_phone_number': _showPhoneNumber ? 0 : 1,
      if (_isPropertySaleOrRent)
        'video_link': _youtubeUrlController.text.trim(),
      if (_isPropertySaleOrRent)
        'threeD_image': _tour360UrlController.text.trim(),
      ..._location.toItemDetails(),
    };

    if (mergedCustomFields.isNotEmpty) {
      itemDetails['custom_fields'] = jsonEncode(mergedCustomFields);
    }

    Widgets.showLoader(context);

    if (isEditMode) {
      try {
        itemDetails.addAll(
          await _adminFieldsController.toFileSubmissionMap(),
        );
        final mainImg =
            _selectedImages.isNotEmpty ? _selectedImages.first : null;
        final otherImgs =
            _selectedImages.length > 1 ? _selectedImages.sublist(1) : null;
        await ItemRepository().editItem(itemDetails, mainImg, otherImgs);
      } catch (e) {
        log("Property edit API error: $e");
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
      Navigator.of(context).pop(true);
      return;
    }

    ItemModel? createdItemModel;
    try {
      itemDetails.addAll(
        await _adminFieldsController.toFileSubmissionMap(),
      );
      final mainImg = _selectedImages.first;
      final otherImgs =
          _selectedImages.length > 1 ? _selectedImages.sublist(1) : <File>[];
      createdItemModel =
          await ItemRepository().createItem(itemDetails, mainImg, otherImgs);
    } catch (e) {
      log("Property create API log error: $e");
      Widgets.hideLoder(context);
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to post ad: ${e.toString().replaceAll("ApiException: ", "").replaceAll("Exception: ", "")}",
          type: MessageType.error,
        );
      }
      return;
    }

    Widgets.hideLoder(context);

    // ignore: unnecessary_null_comparison
    if (createdItemModel == null) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to create property ad. Please check your fields and try again.",
          type: MessageType.error,
        );
      }
      return;
    }

    try {
      MyAdvertisementScreen.refreshCallback?.call();
    } catch (_) {}

    if (mounted) {
      Navigator.pushNamed(
        context,
        Routes.carPackagePaymentScreen,
        arguments: {
          'model': createdItemModel,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final breadcrumbText =
        widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty
            ? widget.breadcrumbs!.map((b) => b.name ?? "").join(" > ")
            : (widget.category?.name ?? "Property");

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
            title: "Property Details",
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    "You're almost there!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Include as much details and pictures as possible, and set the right price!",
                    style: TextStyle(
                      fontSize: 13.5,
                      color: context.color.textLightColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Breadcrumbs
                  Text(
                    breadcrumbText,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.color.territoryColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. Title
                  const PostingFieldLabel("Title *"),
                  _buildTextField(
                    controller: _titleController,
                    hint: "Property title",
                    validator: (val) => val == null || val.trim().isEmpty
                        ? "Title is required"
                        : null,
                  ),
                  const SizedBox(height: 18),

                  // 2. Description
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const PostingFieldLabel("Description *"),
                      Text(
                        "${_descriptionController.text.length}/16000",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.color.textLightColor,
                        ),
                      ),
                    ],
                  ),
                  _buildTextField(
                    controller: _descriptionController,
                    hint:
                        "Describe the property features, views, nearby landmarks...",
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? "Description is required"
                        : null,
                  ),
                  const SizedBox(height: 18),

                  // 3. Pictures
                  PostingPicturesSection(
                    images: _selectedImages,
                    existingImages: _existingNetworkImages,
                    onAdd: _pickImages,
                    onRemove: (index) =>
                        setState(() => _selectedImages.removeAt(index)),
                    onRemoveExisting: (index) =>
                        setState(() => _existingNetworkImages.removeAt(index)),
                  ),
                  const SizedBox(height: 18),
                  if (_isPropertySaleOrRent) ...[
                    PostingMediaLinksSection(
                      youtubeController: _youtubeUrlController,
                      tour360Controller: _tour360UrlController,
                    ),
                    const SizedBox(height: 18),
                  ],
                  // 4. Price
                  const PostingFieldLabel("Price *"),
                  _buildTextField(
                    controller: _priceController,
                    hint: "e.g. 850000",
                    keyboardType: TextInputType.number,
                    suffixText: "AED",
                    validator: (val) => val == null || val.trim().isEmpty
                        ? "Price is required"
                        : null,
                  ),
                  const SizedBox(height: 18),

                  // 5. Phone Number
                  const PostingFieldLabel("Phone number *"),
                  _buildTextField(
                    controller: _phoneController,
                    hint: "+971",
                    keyboardType: TextInputType.phone,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? "Phone number is required"
                        : null,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Show phone number on the ad"),
                    value: _showPhoneNumber,
                    onChanged: (value) =>
                        setState(() => _showPhoneNumber = value),
                  ),
                  const SizedBox(height: 18),

                  DynamicCustomFieldsForm(
                    controller: _adminFieldsController,
                    isLoading: _isLoadingDynamicFields,
                  ),

                  // 21. Location Section
                  PostingLocationSection(
                    location: _location,
                    onChanged: (value) => setState(() => _location = value),
                    onUseCurrentLocation: _getCurrentLocation,
                    isLocating: _isLocating,
                    onMapCreated: (controller) => _mapController = controller,
                  ),
                  const SizedBox(height: 28),

                  // 22. Next / Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD31027),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _validateAndProceed,
                      child: const Text(
                        "Next",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
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
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
        ),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14.5,
          color: context.color.textDefaultColor,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 14,
            color: context.color.textLightColor.withValues(alpha: 0.7),
          ),
          suffixText: suffixText,
          suffixStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: context.color.territoryColor,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
