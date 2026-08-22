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

class PropertyPostingFormScreen extends StatefulWidget {
  final CategoryModel? category;
  final List<CategoryModel>? breadcrumbs;
  final String? initialTitle;
  final List<CustomFieldModel>? customFields;

  const PropertyPostingFormScreen({
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
      builder: (context) => PropertyPostingFormScreen(
        category: arguments?['category'] ?? arguments?['current'],
        breadcrumbs: arguments?['breadcrumbs'] ?? arguments?['breadCrumbItems'],
        initialTitle: arguments?['initialTitle'],
        customFields: arguments?['customFields'],
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

  // Standard Form Controllers
  late final TextEditingController _titleController;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _youtubeUrlController = TextEditingController();
  final TextEditingController _tour360UrlController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _permitNumberController = TextEditingController();
  final TextEditingController _zoneNameController = TextEditingController();
  final TextEditingController _registeredAgencyController = TextEditingController();
  final TextEditingController _reraController = TextEditingController();
  final TextEditingController _referenceIdController = TextEditingController();
  final TextEditingController _brnOldController = TextEditingController();

  // New Projects Specific Controllers
  final TextEditingController _downPaymentController = TextEditingController();
  final TextEditingController _preHandoverController = TextEditingController();
  final TextEditingController _onHandoverController = TextEditingController();
  final TextEditingController _handoverController = TextEditingController();
  final TextEditingController _developerController = TextEditingController();
  String _selectedProjectStatus = "Under Construction";
  String? _selectedUnitType;
  File? _companyIconFile;

  // Images
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  // Property Custom Fields State
  String _selectedBedrooms = "1";
  String _selectedBathrooms = "1";
  String _selectedFurnished = "Furnished";
  String _selectedRentFrequency = "Yearly";
  String _selectedListedBy = "Agent";
  final Set<String> _selectedAmenities = {};

  // Options Lists (Dynamic from API or sensible defaults)
  List<String> _bedroomOptions = [
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12+"
  ];
  List<String> _bathroomOptions = [
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12+"
  ];
  List<String> _furnishedOptions = ["Furnished", "Unfurnished"];
  List<String> _rentFrequencyOptions = [
    "Yearly", "Bi-Yearly", "Quarterly", "Monthly"
  ];
  List<String> _listedByOptions = ["Agent", "Landlord", "Developer"];
  List<String> _projectStatusOptions = ["Under Construction", "Completed"];
  List<String> _unitTypeOptions = [
    "Studio",
    "1 Bedroom",
    "2 Bedrooms",
    "3 Bedrooms",
    "4 Bedrooms",
    "5 Bedrooms",
    "6 Bedrooms",
    "7+ Bedrooms",
    "Penthouse",
    "Duplex",
    "Villa",
    "Townhouse",
    "Hotel Apartment",
    "Residential Building",
    "Residential Floor",
    "Office",
    "Retail / Shop",
    "Warehouse",
    "Land"
  ];
  List<String> _amenitiesOptions = [
    "Balcony", "Built in Wardrobes", "Central A/C", "Covered Parking",
    "Shared Pool", "Security", "Gym", "Pets Allowed", "Maid Service",
    "Concierge", "Study", "View of Landmark", "View of Water", "Walk-in Closet"
  ];

  // Dynamic Custom Fields API mappings
  final Map<String, int> _fieldNameToId = {};
  final Set<String> _activeCustomFieldKeys = {};
  bool _isLoadingDynamicFields = true;

  // Location / Google Maps
  LatLng _currentLocationLatLng = const LatLng(25.2048, 55.2708); // Dubai Default
  String _selectedAddress = "Downtown Dubai, Dubai, United Arab Emirates";
  String _selectedLocationName = "Dubai";
  GoogleMapController? _mapController;
  bool _isLocating = false;

  bool get _isNewProject {
    final catName = widget.category?.name?.toLowerCase() ?? "";
    final catSlug = widget.category?.slug?.toLowerCase() ?? "";
    final breadcrumbMatch = widget.breadcrumbs?.any((b) {
          final n = (b.name ?? "").toLowerCase();
          final s = (b.slug ?? "").toLowerCase();
          return n.contains("new project") ||
              s.contains("new-project") ||
              n.contains("off plan") ||
              s.contains("off-plan");
        }) ??
        false;
    return catName.contains("new project") ||
        catSlug.contains("new-project") ||
        catName.contains("off plan") ||
        catSlug.contains("off-plan") ||
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

    if (widget.customFields != null && widget.customFields!.isNotEmpty) {
      _populateDynamicCustomFields(widget.customFields!);
    } else {
      _fetchDynamicCustomFields();
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
    _sizeController.dispose();
    _permitNumberController.dispose();
    _zoneNameController.dispose();
    _registeredAgencyController.dispose();
    _reraController.dispose();
    _referenceIdController.dispose();
    _brnOldController.dispose();
    _downPaymentController.dispose();
    _preHandoverController.dispose();
    _onHandoverController.dispose();
    _handoverController.dispose();
    _developerController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _populateDynamicCustomFields(List<CustomFieldModel> fieldsList) {
    for (var field in fieldsList) {
      if (field.id != null && field.name != null) {
        final normName = field.name!.toLowerCase().trim();
        _fieldNameToId[normName] = field.id!;
        _activeCustomFieldKeys.add(normName);

        // Dynamically populate options from API custom field values if configured by admin
        List<String> dynamicOptions = [];
        if (field.values != null) {
          if (field.values is List) {
            dynamicOptions = (field.values as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          } else if (field.values is String) {
            final str = (field.values as String).trim();
            if (str.startsWith('[') && str.endsWith(']')) {
              try {
                final decoded = jsonDecode(str);
                if (decoded is List) {
                  dynamicOptions = decoded
                      .map((e) => e.toString().trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                }
              } catch (_) {}
            }
            if (dynamicOptions.isEmpty) {
              dynamicOptions = str
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
            }
          }
        }

        if (dynamicOptions.isNotEmpty) {
          if (normName.contains("bedroom") || normName == "rooms") {
            _bedroomOptions = dynamicOptions;
            if (!_bedroomOptions.contains(_selectedBedrooms)) {
              _selectedBedrooms = _bedroomOptions.first;
            }
          } else if (normName.contains("bathroom") || normName == "baths") {
            _bathroomOptions = dynamicOptions;
            if (!_bathroomOptions.contains(_selectedBathrooms)) {
              _selectedBathrooms = _bathroomOptions.first;
            }
          } else if (normName.contains("furnish")) {
            _furnishedOptions = dynamicOptions;
            if (!_furnishedOptions.contains(_selectedFurnished)) {
              _selectedFurnished = _furnishedOptions.first;
            }
          } else if (normName.contains("rent") ||
              normName.contains("frequency") ||
              normName.contains("period")) {
            _rentFrequencyOptions = dynamicOptions;
            if (!_rentFrequencyOptions.contains(_selectedRentFrequency)) {
              _selectedRentFrequency = _rentFrequencyOptions.first;
            }
          } else if (normName.contains("listed_by") ||
              normName.contains("listed by") ||
              normName.contains("seller_type")) {
            _listedByOptions = dynamicOptions;
            if (!_listedByOptions.contains(_selectedListedBy)) {
              _selectedListedBy = _listedByOptions.first;
            }
          } else if (normName.contains("project_status") ||
              normName.contains("status")) {
            _projectStatusOptions = dynamicOptions;
            if (!_projectStatusOptions.contains(_selectedProjectStatus)) {
              _selectedProjectStatus = _projectStatusOptions.first;
            }
          } else if (normName.contains("unit_type") || normName.contains("type")) {
            _unitTypeOptions = dynamicOptions;
          } else if (normName.contains("amenit")) {
            _amenitiesOptions = dynamicOptions;
          }
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
      log("⚠️ [PROPERTY CUSTOM FIELDS ERROR] $e");
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

  Future<void> _pickCompanyIcon() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _companyIconFile = File(picked.path);
        });
      }
    } catch (e) {
      log("Error picking company icon: $e");
    }
  }

  IconData _getLabelIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('home') || lower.contains('villa') || lower.contains('apt')) {
      return Icons.home_rounded;
    }
    if (lower.contains('office') || lower.contains('work') || lower.contains('business')) {
      return Icons.business_rounded;
    }
    return Icons.location_on_rounded;
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

  void _openAmenitiesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: context.color.textLightColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Select Amenities",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _amenitiesOptions.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, idx) {
                          final amenity = _amenitiesOptions[idx];
                          final isChecked = _selectedAmenities.contains(amenity);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              amenity,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            value: isChecked,
                            activeColor: context.color.territoryColor,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  _selectedAmenities.add(amenity);
                                } else {
                                  _selectedAmenities.remove(amenity);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD31027),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(modalCtx),
                        child: Text(
                          "Done (${_selectedAmenities.length} selected)",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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

    final Map<String, dynamic> customFieldsValues = _isNewProject
        ? {
            'project_status': [_selectedProjectStatus],
            if (_selectedUnitType != null) 'unit_type': [_selectedUnitType!],
            if (_downPaymentController.text.trim().isNotEmpty)
              'down_payment': [_downPaymentController.text.trim()],
            if (_preHandoverController.text.trim().isNotEmpty)
              'pre_handover': [_preHandoverController.text.trim()],
            if (_onHandoverController.text.trim().isNotEmpty)
              'on_handover': [_onHandoverController.text.trim()],
            if (_handoverController.text.trim().isNotEmpty)
              'handover': [_handoverController.text.trim()],
            if (_developerController.text.trim().isNotEmpty)
              'developer': [_developerController.text.trim()],
          }
        : {
            'bedrooms': [_selectedBedrooms],
            'bathrooms': [_selectedBathrooms],
            'furnished': [_selectedFurnished],
            if (_sizeController.text.trim().isNotEmpty)
              'size': [_sizeController.text.trim()],
            'rent_frequency': [_selectedRentFrequency],
            if (_selectedAmenities.isNotEmpty)
              'amenities': _selectedAmenities.toList(),
            if (_permitNumberController.text.trim().isNotEmpty)
              'permit_number': [_permitNumberController.text.trim()],
            if (_zoneNameController.text.trim().isNotEmpty)
              'zone_name': [_zoneNameController.text.trim()],
            if (_registeredAgencyController.text.trim().isNotEmpty)
              'agency': [_registeredAgencyController.text.trim()],
            if (_reraController.text.trim().isNotEmpty)
              'rera': [_reraController.text.trim()],
            if (_referenceIdController.text.trim().isNotEmpty)
              'reference_id': [_referenceIdController.text.trim()],
            if (_brnOldController.text.trim().isNotEmpty)
              'brn': [_brnOldController.text.trim()],
            'listed_by': [_selectedListedBy],
          };

    final Map<String, dynamic> mergedCustomFields = {};
    customFieldsValues.forEach((key, val) {
      final id = _fieldNameToId[key.toLowerCase()] ??
          _fieldNameToId[key.replaceAll('_', ' ').toLowerCase()];
      if (id != null && val != null) {
        mergedCustomFields["$id"] = val is List ? val : [val.toString()];
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
      if (_companyIconFile != null) {
        otherImgs.add(_companyIconFile!);
      }
      createdItemModel = await ItemRepository()
          .createItem(itemDetails, mainImg, otherImgs);
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
            title: _isNewProject ? "New Projects" : "Property Details",
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
                    hint: "Property title",
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
                    hint: "Describe the property features, views, nearby landmarks...",
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
                    hint: "e.g. 850000",
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
                  const SizedBox(height: 18),

                  // 7. 360 Tour URL
                  _buildFieldLabel("360 Tour URL (Optional)"),
                  _buildTextField(
                    controller: _tour360UrlController,
                    hint: "https://my.matterport.com/show/?m=...",
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Learn more about accepted 360 tour providers.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.color.territoryColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ================= NEW PROJECTS FIELDS =================
                  if (_isNewProject) ...[
                    // Project Status *
                    _buildFieldLabel("Project Status *"),
                    _buildChoiceChips(
                      options: _projectStatusOptions,
                      selected: _selectedProjectStatus,
                      onSelected: (val) => setState(() => _selectedProjectStatus = val),
                    ),
                    const SizedBox(height: 18),

                    // Unit Type
                    _buildFieldLabel("Unit Type"),
                    _buildUnitTypeDropdown(),
                    const SizedBox(height: 18),

                    // Down Payment
                    _buildFieldLabel("Down Payment"),
                    _buildTextField(
                      controller: _downPaymentController,
                      hint: "Down Payment (e.g. 10% or 50,000 AED)",
                    ),
                    const SizedBox(height: 18),

                    // Pre Handover
                    _buildFieldLabel("Pre Handover"),
                    _buildTextField(
                      controller: _preHandoverController,
                      hint: "Pre Handover (e.g. 40%)",
                    ),
                    const SizedBox(height: 18),

                    // On Handover
                    _buildFieldLabel("On Handover"),
                    _buildTextField(
                      controller: _onHandoverController,
                      hint: "On Handover (e.g. 50%)",
                    ),
                    const SizedBox(height: 18),

                    // Handover *
                    _buildFieldLabel("Handover *"),
                    _buildTextField(
                      controller: _handoverController,
                      hint: "Handover (e.g. Q4 2026)",
                      validator: (val) => _isNewProject &&
                              (val == null || val.trim().isEmpty)
                          ? "Handover date/quarter is required"
                          : null,
                    ),
                    const SizedBox(height: 18),

                    // Developer
                    _buildFieldLabel("Developer"),
                    _buildTextField(
                      controller: _developerController,
                      hint: "Developer (e.g. Emaar, Damac)",
                    ),
                    const SizedBox(height: 18),

                    // Company icon / Brochure Upload Box
                    _buildFieldLabel("Company icon"),
                    _buildCompanyIconUploadBox(),
                    const SizedBox(height: 24),
                  ] else ...[
                    // ================= STANDARD PROPERTY FIELDS =================
                    // 8. Bedrooms Chips
                    _buildFieldLabel("Bedrooms"),
                    _buildChoiceChips(
                      options: _bedroomOptions,
                      selected: _selectedBedrooms,
                      onSelected: (val) => setState(() => _selectedBedrooms = val),
                    ),
                    const SizedBox(height: 18),

                    // 9. Bathrooms Chips
                    _buildFieldLabel("Bathrooms"),
                    _buildChoiceChips(
                      options: _bathroomOptions,
                      selected: _selectedBathrooms,
                      onSelected: (val) => setState(() => _selectedBathrooms = val),
                    ),
                    const SizedBox(height: 18),

                    // 10. Furnished Status
                    _buildFieldLabel("Is it furnished?"),
                    _buildChoiceChips(
                      options: _furnishedOptions,
                      selected: _selectedFurnished,
                      onSelected: (val) => setState(() => _selectedFurnished = val),
                    ),
                    const SizedBox(height: 18),

                    // 11. Size (SqFt)
                    _buildFieldLabel("Size (SqFt)"),
                    _buildTextField(
                      controller: _sizeController,
                      hint: "e.g. 1250",
                      keyboardType: TextInputType.number,
                      suffixText: "SqFt",
                    ),
                    const SizedBox(height: 18),

                    // 12. Rent is paid *
                    _buildFieldLabel("Rent is paid *"),
                    _buildChoiceChips(
                      options: _rentFrequencyOptions,
                      selected: _selectedRentFrequency,
                      onSelected: (val) => setState(() => _selectedRentFrequency = val),
                    ),
                    const SizedBox(height: 18),

                    // 13. Amenities
                    _buildFieldLabel("Amenities"),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openAmenitiesBottomSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.color.borderColor.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedAmenities.isEmpty
                                    ? "Select Amenities"
                                    : _selectedAmenities.join(", "),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _selectedAmenities.isEmpty
                                      ? context.color.textLightColor
                                      : context.color.textDefaultColor,
                                ),
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                color: context.color.textLightColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 14. Property Permit Number
                    _buildFieldLabel("Property permit number"),
                    _buildTextField(
                      controller: _permitNumberController,
                      hint: "Permit Number",
                    ),
                    const SizedBox(height: 18),

                    // 15. Zone Name
                    _buildFieldLabel("Zone Name"),
                    _buildTextField(
                      controller: _zoneNameController,
                      hint: "Zone Name",
                    ),
                    const SizedBox(height: 18),

                    // 16. Registered Agency
                    _buildFieldLabel("Registered Agency"),
                    _buildTextField(
                      controller: _registeredAgencyController,
                      hint: "Agency Name",
                    ),
                    const SizedBox(height: 18),

                    // 17. RERA
                    _buildFieldLabel("RERA"),
                    _buildTextField(
                      controller: _reraController,
                      hint: "RERA Number",
                    ),
                    const SizedBox(height: 18),

                    // 18. Reference ID
                    _buildFieldLabel("Reference ID"),
                    _buildTextField(
                      controller: _referenceIdController,
                      hint: "Reference ID",
                    ),
                    const SizedBox(height: 18),

                    // 19. BRN (OLD)
                    _buildFieldLabel("BRN (OLD)"),
                    _buildTextField(
                      controller: _brnOldController,
                      hint: "BRN Number",
                    ),
                    const SizedBox(height: 18),

                    // 20. Listed By
                    _buildFieldLabel("Listed By"),
                    _buildChoiceChips(
                      options: _listedByOptions,
                      selected: _selectedListedBy,
                      onSelected: (val) => setState(() => _selectedListedBy = val),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 21. Location Section
                  _buildLocationSection(context),
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

  Widget _buildUnitTypeDropdown() {
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
          value: _selectedUnitType,
          isExpanded: true,
          hint: Text(
            "<Optional>",
            style: TextStyle(
              fontSize: 14,
              color: context.color.textLightColor.withValues(alpha: 0.7),
            ),
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: context.color.textLightColor),
          items: _unitTypeOptions.map((unit) {
            return DropdownMenuItem<String>(
              value: unit,
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: context.color.textDefaultColor,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedUnitType = val;
            });
          },
        ),
      ),
    );
  }

  Widget _buildCompanyIconUploadBox() {
    return InkWell(
      onTap: _pickCompanyIcon,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            if (_companyIconFile != null) ...[
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _companyIconFile!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _companyIconFile = null),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Company icon selected",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.color.textDefaultColor,
                ),
              ),
            ] else ...[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.file_upload_outlined,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Drag and drop or click to select",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "JPG, PNG, SVG, PDF, DOC, DOCX — below 5MB",
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.color.textLightColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChips({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelected(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.color.territoryColor
                  : context.color.secondaryColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? context.color.territoryColor
                    : context.color.borderColor.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : context.color.textDefaultColor,
              ),
            ),
          ),
        );
      }).toList(),
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
                    _getLabelIcon(_selectedLocationName),
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
                        markerId: const MarkerId("property_loc"),
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
