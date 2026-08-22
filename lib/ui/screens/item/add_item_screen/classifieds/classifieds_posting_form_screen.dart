import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/item/fetch_my_promoted_items_cubit.dart';
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

class ClassifiedsPostingFormScreen extends StatefulWidget {
  final CategoryModel? category;
  final List<CategoryModel>? breadcrumbs;
  final String? initialTitle;
  final List<CustomFieldModel>? customFields;

  const ClassifiedsPostingFormScreen({
    super.key,
    this.category,
    this.breadcrumbs,
    this.initialTitle,
    this.customFields,
  });

  static Route route(RouteSettings settings) {
    Map<String, dynamic>? arguments =
        settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) => ClassifiedsPostingFormScreen(
        category: arguments?['category'] ?? arguments?['current'],
        breadcrumbs: arguments?['breadcrumbs'] ?? arguments?['breadCrumbItems'],
        initialTitle: arguments?['initialTitle'],
        customFields: arguments?['customFields'],
      ),
    );
  }

  @override
  CloudState<ClassifiedsPostingFormScreen> createState() =>
      _ClassifiedsPostingFormScreenState();
}

class _ClassifiedsPostingFormScreenState
    extends CloudState<ClassifiedsPostingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Standard Form Controllers
  late final TextEditingController _titleController;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _youtubeUrlController = TextEditingController();

  // Dynamic Custom Fields State
  List<CustomFieldModel> _dynamicCustomFields = [];
  final Map<int, dynamic> _customFieldValues = {};
  final Map<int, TextEditingController> _customFieldControllers = {};
  final Map<String, int> _fieldNameToId = {};
  bool _isLoadingDynamicFields = true;

  // Fallback Standard Classifieds Fields
  String? _selectedUsage;
  String? _selectedWarranty;
  String? _selectedCondition;
  String? _selectedAge;

  final List<String> _usageOptions = [
    "Brand New",
    "Used (like new)",
    "Used (normal wear)",
    "Used (needs repair)"
  ];
  final List<String> _warrantyOptions = ["Yes", "No", "Under Warranty"];
  final List<String> _conditionOptions = [
    "Flawless",
    "Good Condition",
    "Fair",
    "Refurbished"
  ];
  final List<String> _ageOptions = [
    "Brand New",
    "0-1 month",
    "1-6 months",
    "6-12 months",
    "1-2 years",
    "2+ years"
  ];

  // Images
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  // Location / Google Maps
  LatLng _currentLocationLatLng = const LatLng(25.2048, 55.2708); // Dubai Default
  String _selectedAddress = "Downtown Dubai, Dubai, United Arab Emirates";
  String _selectedLocationName = "Dubai";
  GoogleMapController? _mapController;
  bool _isLocating = false;

  bool get _isPetsCategory {
    final catName = widget.category?.name?.toLowerCase() ?? "";
    final catSlug = widget.category?.slug?.toLowerCase() ?? "";
    final breadcrumbMatch = widget.breadcrumbs?.any((b) {
          final n = (b.name ?? "").toLowerCase();
          final s = (b.slug ?? "").toLowerCase();
          return n.contains("pet") || s.contains("pet");
        }) ??
        false;
    return catName.contains("pet") ||
        catSlug.contains("pet") ||
        breadcrumbMatch;
  }

  @override
  void initState() {
    super.initState();
    final prefilled = widget.initialTitle ??
        getCloudData("prefilled_listing_title")?.toString() ??
        "";
    _titleController = TextEditingController(text: prefilled);

    final user = HiveUtils.getUserDetails();
    if (user.mobile != null && user.mobile!.isNotEmpty) {
      _phoneController.text = user.mobile!;
    } else {
      _phoneController.text = "+971";
    }

    if (!_isPetsCategory) {
      if (widget.customFields != null && widget.customFields!.isNotEmpty) {
        _populateDynamicCustomFields(widget.customFields!);
      } else {
        _fetchDynamicCustomFields();
      }
    } else {
      _isLoadingDynamicFields = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _youtubeUrlController.dispose();
    for (var ctrl in _customFieldControllers.values) {
      ctrl.dispose();
    }
    _mapController?.dispose();
    super.dispose();
  }

  bool _isFieldApplicable(CustomFieldModel field) {
    final raw = (field.name ?? "").toLowerCase().trim();
    if (raw.isEmpty) return false;

    final currentCat = widget.category;
    if (currentCat == null) return true;

    final catSlug = (currentCat.slug ?? "").toLowerCase().replaceAll('-', '');
    final catName = (currentCat.name ?? "").toLowerCase().replaceAll(' ', '').replaceAll('&', '');

    // Sibling category exclusions
    if (raw.startsWith('dvd') && !catSlug.contains('dvd') && !catName.contains('dvd')) {
      return false;
    }
    if (raw.startsWith('tv') && !catSlug.contains('tv') && !catName.contains('tv') && !catName.contains('television')) {
      return false;
    }
    if (raw.startsWith('camera') && !catSlug.contains('camera') && !catName.contains('camera')) {
      return false;
    }
    if (raw.startsWith('laptop') && !catSlug.contains('laptop') && !catName.contains('laptop') && !catName.contains('computer')) {
      return false;
    }
    if (raw.startsWith('mobile') && !catSlug.contains('mobile') && !catSlug.contains('phone') && !catName.contains('mobile') && !catName.contains('phone')) {
      return false;
    }
    if (raw.startsWith('audio') || raw.startsWith('homeaudio') || raw.startsWith('speaker')) {
      if (!catSlug.contains('audio') && !catSlug.contains('speaker') && !catSlug.contains('turntable') &&
          !catName.contains('audio') && !catName.contains('speaker') && !catName.contains('turntable')) {
        return false;
      }
    }
    return true;
  }

  void _populateDynamicCustomFields(List<CustomFieldModel> fieldsList) {
    _dynamicCustomFields = fieldsList.where(_isFieldApplicable).toList();
    for (var field in _dynamicCustomFields) {
      if (field.id != null) {
        final normName = (field.name ?? "").toLowerCase().trim();
        _fieldNameToId[normName] = field.id!;

        // Initialize text controller if text/number field
        final type = (field.type ?? "").toLowerCase();
        if (type == "textbox" || type == "number" || type == "textarea") {
          _customFieldControllers[field.id!] = TextEditingController();
        }
      }
    }
    _isLoadingDynamicFields = false;
  }

  Future<void> _fetchDynamicCustomFields() async {
    try {
      final catId = widget.category?.id ??
          (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty
              ? widget.breadcrumbs!.last.id
              : 2);

      final customFieldsRepo = CustomFieldRepository();
      final List<CustomFieldModel> fieldsList =
          await customFieldsRepo.getCustomFieldsByCategoryId(catId);

      if (mounted) {
        setState(() {
          _populateDynamicCustomFields(fieldsList);
        });
      }
    } catch (e) {
      log("⚠️ [CLASSIFIEDS CUSTOM FIELDS ERROR] $e");
    } finally {
      if (mounted) setState(() => _isLoadingDynamicFields = false);
    }
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

  String _formatFieldLabel(String rawName) {
    String name = rawName.trim();
    if (name.isEmpty) return "Field";

    // Known friendly dictionary mappings
    final Map<String, String> knownMappings = {
      'connectivitytech': 'Connectivity Technology',
      'connectivityteche': 'Connectivity Technology',
      'connectivity': 'Connectivity',
      'compatible': 'Compatible Devices',
      'compatibility': 'Device Compatibility',
      'feature': 'Special Features',
      'features': 'Special Features',
      'speakersub': 'Speaker Type',
      'speakertype': 'Speaker Type',
      'usage': 'Usage',
      'condition': 'Condition',
      'warranty': 'Warranty',
      'age': 'Age',
      'brand': 'Brand',
      'color': 'Color',
      'model': 'Model',
      'storage': 'Storage Capacity',
      'ram': 'RAM Memory',
      'screensize': 'Screen Size',
      'simtype': 'SIM Type',
      'resolution': 'Resolution',
      'operatingsystem': 'Operating System',
      'battery': 'Battery Capacity',
      'camera': 'Camera Specs',
      'processor': 'Processor',
      'graphicscard': 'Graphics Card',
      'material': 'Material',
      'type': 'Type',
    };

    // Remove category prefixes
    List<String> parts = name.split('_').where((p) => p.isNotEmpty).toList();
    while (parts.length > 1) {
      final first = parts.first.toLowerCase();
      if (first.contains('homeaudio') ||
          first.contains('turntable') ||
          first.contains('speakersub') ||
          first.contains('dvdhome') ||
          first.contains('dvd') ||
          first.contains('electronics') ||
          first.contains('mobile') ||
          first.contains('classified') ||
          first.contains('property') ||
          first.contains('motor')) {
        parts.removeAt(0);
      } else {
        break;
      }
    }

    String cleanedKey = parts.join('').toLowerCase().replaceAll(' ', '');
    if (knownMappings.containsKey(cleanedKey)) {
      return knownMappings[cleanedKey]!;
    }
    if (parts.isNotEmpty && knownMappings.containsKey(parts.last.toLowerCase())) {
      return knownMappings[parts.last.toLowerCase()]!;
    }

    String formatted = parts.join(' ');
    formatted = formatted.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return formatted
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _openFullMapPicker() async {
    final result = await Navigator.pushNamed(
      context,
      Routes.locationMapScreen,
      arguments: {
        "from": "addItem",
        "latitude": _currentLocationLatLng.latitude,
        "longitude": _currentLocationLatLng.longitude,
      },
    );

    if (result is Map) {
      final lat = result['latitude'] as double?;
      final lng = result['longitude'] as double?;
      final area = result['area'] as String?;
      final city = result['city'] as String?;
      final state = result['state'] as String?;
      final country = result['country'] as String?;

      if (lat != null && lng != null) {
        setState(() {
          _currentLocationLatLng = LatLng(lat, lng);
          final locTitle = area?.isNotEmpty == true
              ? area!
              : (city?.isNotEmpty == true ? city! : "Selected Location");
          _selectedLocationName = locTitle;
          final parts = [area, city, state, country]
              .where((s) => s != null && s.isNotEmpty)
              .toList();
          _selectedAddress = parts.isNotEmpty
              ? parts.join(", ")
              : "$locTitle, United Arab Emirates";
        });
      }
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
          desiredAccuracy: LocationAccuracy.high,
        );

        final target = LatLng(position.latitude, position.longitude);
        _currentLocationLatLng = target;
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          final locTitle = place.subLocality?.isNotEmpty == true
              ? place.subLocality!
              : (place.locality?.isNotEmpty == true ? place.locality! : "My Location");
          final addr = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country
          ].where((e) => e != null && e.isNotEmpty).join(", ");

          setState(() {
            _selectedLocationName = locTitle;
            _selectedAddress = addr.isNotEmpty ? addr : "Dubai, UAE";
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

    if (_selectedImages.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please upload at least 1 image",
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
        (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty
            ? widget.breadcrumbs!.last.id
            : 2);

    final allCategoryIds = widget.breadcrumbs != null &&
            widget.breadcrumbs!.isNotEmpty
        ? widget.breadcrumbs!
            .map((b) => b.id)
            .where((id) => id != null)
            .join(',')
        : "$categoryId";

    final Map<String, dynamic> mergedCustomFields = {};

    // 1. Collect from dynamic custom fields
    for (var field in _dynamicCustomFields) {
      if (field.id == null) continue;
      final fid = field.id!;
      final type = (field.type ?? "").toLowerCase();

      if (type == "textbox" || type == "number" || type == "textarea") {
        final val = _customFieldControllers[fid]?.text.trim();
        if (val != null && val.isNotEmpty) {
          mergedCustomFields["$fid"] = [val];
        }
      } else {
        final val = _customFieldValues[fid];
        if (val != null) {
          mergedCustomFields["$fid"] = val is List ? val : [val.toString()];
        }
      }
    }

    // 2. Add fallback Classifieds fields if selected and available
    final fallbackMap = {
      'usage': _selectedUsage,
      'warranty': _selectedWarranty,
      'condition': _selectedCondition,
      'age': _selectedAge,
    };

    fallbackMap.forEach((key, val) {
      if (val != null && val.isNotEmpty) {
        final id = _fieldNameToId[key] ??
            _fieldNameToId[key.replaceAll('_', ' ')] ??
            _fieldNameToId["classified_$key"];
        if (id != null) {
          mergedCustomFields["$id"] = [val];
        }
      }
    });

    final itemDetails = <String, dynamic>{
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
      if (_youtubeUrlController.text.trim().isNotEmpty)
        'video_link': _youtubeUrlController.text.trim(),
      'country': 'United Arab Emirates',
      'state': 'Dubai',
      'city': 'Dubai',
      'latitude': _currentLocationLatLng.latitude,
      'longitude': _currentLocationLatLng.longitude,
      'address': _selectedAddress,
    };

    if (mergedCustomFields.isNotEmpty) {
      itemDetails['custom_fields'] = jsonEncode(mergedCustomFields);
    }

    Widgets.showLoader(context);
    ItemModel? createdItemModel;
    try {
      final mainImg = _selectedImages.first;
      final otherImgs = _selectedImages.length > 1
          ? _selectedImages.sublist(1)
          : <File>[];
      createdItemModel = await ItemRepository()
          .createItem(itemDetails, mainImg, otherImgs);
    } catch (e) {
      log("Classifieds create API log error: $e");
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

    if (createdItemModel == null) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to create classified ad. Please check your fields and try again.",
          type: MessageType.error,
        );
      }
      return;
    }

    try {
      context.read<FetchMyPromotedItemsCubit>().fetchMyPromotedItems();
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
    final breadcrumbText = widget.breadcrumbs != null &&
            widget.breadcrumbs!.isNotEmpty
        ? widget.breadcrumbs!.map((b) => b.name ?? "").join(" > ")
        : (widget.category?.name ?? "Classifieds");

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
            title: widget.category?.name ?? "Classifieds Details",
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
                  _buildFieldLabel("Title *"),
                  _buildTextField(
                    controller: _titleController,
                    hint: "Item title",
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? "Title is required" : null,
                  ),
                  const SizedBox(height: 18),

                  // 2. Description
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFieldLabel("Description *"),
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
                    hint: "Describe the item features, condition, brand, and usage...",
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? "Description is required" : null,
                  ),
                  const SizedBox(height: 18),

                  // 3. Add Pictures Button & Previews
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFFD31027)),
                      label: Text(
                        _selectedImages.isEmpty
                            ? "Add Pictures"
                            : "Add More Pictures (${_selectedImages.length} selected)",
                        style: const TextStyle(
                          color: Color(0xFFD31027),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD31027), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _selectedImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  _selectedImages[idx],
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedImages.removeAt(idx)),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // 4. Price
                  _buildFieldLabel("Price *"),
                  _buildTextField(
                    controller: _priceController,
                    hint: "e.g. 150",
                    keyboardType: TextInputType.number,
                    suffixText: "AED",
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? "Price is required" : null,
                  ),
                  const SizedBox(height: 18),

                  // 5. Phone Number
                  _buildFieldLabel("Phone number *"),
                  _buildTextField(
                    controller: _phoneController,
                    hint: "+971",
                    keyboardType: TextInputType.phone,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? "Phone number is required" : null,
                  ),
                  const SizedBox(height: 18),

                  // 6. YouTube URL
                  _buildFieldLabel("YouTube URL (Optional)"),
                  _buildTextField(
                    controller: _youtubeUrlController,
                    hint: "https://youtube.com/watch?v=...",
                  ),
                  const SizedBox(height: 20),

                  // 7. Dynamic Category Custom Fields (Hidden for Pets)
                  if (!_isPetsCategory) ...[
                    if (_isLoadingDynamicFields)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      ..._dynamicCustomFields.map((field) {
                        return _buildDynamicCustomFieldWidget(field);
                      }),
                    ],

                    // Fallback Standard Classifieds fields if not provided dynamically
                    if (!_dynamicCustomFields.any((f) =>
                        (f.name ?? "").toLowerCase().contains("usage"))) ...[
                      _buildFieldLabel("Usage *"),
                      _buildDropdownField(
                        hint: "Required*",
                        value: _selectedUsage,
                        options: _usageOptions,
                        onChanged: (val) => setState(() => _selectedUsage = val),
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (!_dynamicCustomFields.any((f) =>
                        (f.name ?? "").toLowerCase().contains("warranty"))) ...[
                      _buildFieldLabel("Warranty"),
                      _buildDropdownField(
                        hint: "<Optional>",
                        value: _selectedWarranty,
                        options: _warrantyOptions,
                        onChanged: (val) => setState(() => _selectedWarranty = val),
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (!_dynamicCustomFields.any((f) =>
                        (f.name ?? "").toLowerCase().contains("condition"))) ...[
                      _buildFieldLabel("Condition *"),
                      _buildDropdownField(
                        hint: "Required*",
                        value: _selectedCondition,
                        options: _conditionOptions,
                        onChanged: (val) => setState(() => _selectedCondition = val),
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (!_dynamicCustomFields.any((f) =>
                        (f.name ?? "").toLowerCase().contains("age"))) ...[
                      _buildFieldLabel("Age *"),
                      _buildDropdownField(
                        hint: "Required*",
                        value: _selectedAge,
                        options: _ageOptions,
                        onChanged: (val) => setState(() => _selectedAge = val),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],

                  const SizedBox(height: 6),

                  // 8. Location Section
                  _buildLocationSection(context),
                  const SizedBox(height: 28),

                  // 9. Next / Submit Button
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.color.textDefaultColor,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : null,
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(
              fontSize: 14,
              color: context.color.textLightColor.withValues(alpha: 0.7),
            ),
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: context.color.textLightColor),
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 14,
                  color: context.color.textDefaultColor,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDynamicCustomFieldWidget(CustomFieldModel field) {
    final rawName = field.name ?? "";
    final label = _formatFieldLabel(rawName);
    final type = (field.type ?? "").toLowerCase();
    final isRequired = field.required == 1;
    final displayLabel = isRequired ? "$label *" : label;
    final fid = field.id ?? 0;

    // Check if field has option values
    List<String> options = [];
    if (field.values is List && (field.values as List).isNotEmpty) {
      options = (field.values as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (options.isNotEmpty || type == "dropdown" || type == "radiobox") {
      final currentVal = _customFieldValues[fid]?.toString();
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(displayLabel),
            _buildDropdownField(
              hint: isRequired ? "Required*" : "<Optional>",
              value: currentVal,
              options: options,
              onChanged: (val) {
                setState(() {
                  _customFieldValues[fid] = val;
                });
              },
            ),
          ],
        ),
      );
    }

    if (type == "number") {
      final ctrl = _customFieldControllers[fid] ?? TextEditingController();
      _customFieldControllers[fid] = ctrl;
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel(displayLabel),
            _buildTextField(
              controller: ctrl,
              hint: isRequired ? "Enter $label (Required)" : "Enter $label",
              keyboardType: TextInputType.number,
              validator: isRequired
                  ? (val) => val == null || val.trim().isEmpty
                      ? "$label is required"
                      : null
                  : null,
            ),
          ],
        ),
      );
    }

    // Default text field
    final ctrl = _customFieldControllers[fid] ?? TextEditingController();
    _customFieldControllers[fid] = ctrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(displayLabel),
          _buildTextField(
            controller: ctrl,
            hint: isRequired ? "Enter $label (Required)" : "Enter $label",
            validator: isRequired
                ? (val) => val == null || val.trim().isEmpty
                    ? "$label is required"
                    : null
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.8),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: context.color.territoryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedLocationName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _getCurrentLocation,
                child: Row(
                  children: [
                    if (_isLocating)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(Icons.my_location_rounded,
                          size: 15, color: context.color.territoryColor),
                    const SizedBox(width: 4),
                    Text(
                      "Locate Me",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: context.color.territoryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _selectedAddress,
            style: TextStyle(
              fontSize: 12.5,
              color: context.color.textLightColor,
            ),
          ),
          const SizedBox(height: 14),

          // Live Google Map Widget with tap to open full map
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                children: [
                  GoogleMap(
                    key: ValueKey(
                        "${_currentLocationLatLng.latitude}_${_currentLocationLatLng.longitude}"),
                    initialCameraPosition: CameraPosition(
                      target: _currentLocationLatLng,
                      zoom: 14,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId("classifieds_loc"),
                        position: _currentLocationLatLng,
                        infoWindow: InfoWindow(
                          title: _selectedLocationName,
                          snippet: _selectedAddress,
                        ),
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    onTap: (_) => _openFullMapPicker(),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: InkWell(
                      onTap: _openFullMapPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen_rounded,
                              size: 16,
                              color: context.color.textDefaultColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Full Map",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
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
            ),
          ),
        ],
      ),
    );
  }
}
