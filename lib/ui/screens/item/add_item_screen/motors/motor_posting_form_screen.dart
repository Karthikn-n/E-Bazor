import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:Ebozor/data/cubits/item/fetch_my_promoted_items_cubit.dart';
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
import 'package:Ebozor/ui/screens/widgets/custom_text_form_field.dart';

enum MotorCategoryType {
  numberPlates,
  autoAccessories,
  motorcycles,
  boats,
  heavyVehicles,
  general,
}

class MotorPostingFormScreen extends StatefulWidget {
  final CategoryModel? category;
  final List<CategoryModel>? breadcrumbs;
  final List<CustomFieldModel>? customFields;

  const MotorPostingFormScreen({
    super.key,
    this.category,
    this.breadcrumbs,
    this.customFields,
  });

  static Route route(RouteSettings settings) {
    Map<String, dynamic>? arguments =
        settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) => MotorPostingFormScreen(
        category: arguments?['category'] ?? arguments?['current'],
        breadcrumbs: arguments?['breadcrumbs'] ?? arguments?['breadCrumbItems'],
        customFields: arguments?['customFields'],
      ),
    );
  }

  @override
  State<MotorPostingFormScreen> createState() => _MotorPostingFormScreenState();
}

class _MotorPostingFormScreenState extends State<MotorPostingFormScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];

  late MotorCategoryType _categoryType;

  // Form Field Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Number Plates Specific Controllers
  final TextEditingController _plateNumberController = TextEditingController();
  final TextEditingController _plateCodeController = TextEditingController();
  String _plateCity = "Dubai";
  String _plateDesign = "Private";

  // Auto Accessories Specific
  String _itemCondition = "Brand New";
  String _itemUsage = "Never Used";
  final TextEditingController _brandCompatibilityController =
      TextEditingController();

  // Motorcycles / Heavy Vehicles / Boats Fields
  final TextEditingController _kilometersController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _horsepowerController = TextEditingController();
  int _selectedYear = 2025;
  String _selectedEngineCapacity = "500 - 999 cc";
  String _selectedWheels = "2 Wheels";
  String _selectedWarranty = "Yes";
  String _selectedFuelType = "Diesel";
  String _selectedTransmission = "Manual";
  String _selectedFinalDrive = "Chain";
  String _selectedSellerType = "Owner";
  String _selectedBodyType = "Flatbed";
  String _selectedExteriorColor = "White";
  String _selectedInteriorColor = "Black";
  String _selectedSteeringSide = "Left Hand Side";
  String _selectedCapacityTonnes = "3 - 7 Tonnes";
  String _selectedHorsepower = "250 - 400 HP";

  bool _showPhone = true;
  int _descriptionCharCount = 0;
  bool _termsAgreed = true;
  bool _isLoadingDynamicFields = false;
  final Map<String, int> _fieldNameToId = {};
  final Set<String> _activeCustomFieldKeys = {};

  bool _hasField(String key) {
    if (_isLoadingDynamicFields) {
      if (key == 'year' ||
          key == 'kilometers' ||
          key == 'seller_type' ||
          key == 'warranty') {
        return true;
      }
      return false;
    }
    if (_activeCustomFieldKeys.isEmpty) {
      return key == 'year' || key == 'seller_type' || key == 'warranty';
    }
    return _activeCustomFieldKeys.contains(key);
  }

  // Location Data
  String _locationLabel = "Home";
  String _selectedLocationName = "Downtown Dubai";
  String _selectedAddress = "Downtown Dubai, Dubai, United Arab Emirates";
  LatLng _currentLocationLatLng = const LatLng(25.2048, 55.2708);

  late final List<int> _years;

  // Dynamic custom fields and controllers
  List<CustomFieldModel> _dynamicFields = [];
  final Map<String, CustomFieldModel> _fieldModelsByName = {};
  final Map<int, TextEditingController> _dynamicFieldControllers = {};
  final Map<int, List<String>> _dynamicFieldMultiSelections = {};
  final Map<int, String> _dynamicFieldSingleSelections = {};

  // Category option lists - initially empty, populated dynamically from API response
  List<String> _plateCities = [];
  List<String> _plateDesigns = [];
  List<String> _plateLetters = [];
  List<String> _conditions = [];
  List<String> _usages = [];
  List<String> _motoEngineCapacities = [];
  List<String> _motoWheels = [];
  List<String> _motoTransmissions = [];
  List<String> _motoFinalDrives = [];
  List<String> _warranties = [];
  List<String> _sellerTypes = [];
  List<String> _heavyBodyTypes = [];
  List<String> _exteriorColors = [];
  List<String> _interiorColors = [];
  List<String> _steeringSides = [];
  List<String> _fuelTypes = [];
  List<String> _heavyCapacities = [];
  List<String> _heavyHorsepowers = [];
  List<String> _neighbourhoods = [];

  @override
  void initState() {
    super.initState();
    _categoryType = _detectCategoryType(widget.category, widget.breadcrumbs);

    final currentYear = DateTime.now().year;
    _selectedYear = currentYear;
    _years = List.generate(currentYear - 1979, (index) => currentYear - index);

    final userPhone = HiveUtils.getUserDetails().mobile;
    _phoneController.text = (userPhone != null && userPhone.isNotEmpty)
        ? userPhone
        : "+9715056525";

    _initDefaultTitlesAndDescriptions();

    _descriptionController.addListener(() {
      setState(() {
        _descriptionCharCount = _descriptionController.text.length;
      });
    });

    if (widget.customFields != null && widget.customFields!.isNotEmpty) {
      _populateDynamicCustomFields(widget.customFields!);
    } else {
      _fetchDynamicCustomFields();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _plateNumberController.dispose();
    _plateCodeController.dispose();
    _brandCompatibilityController.dispose();
    _kilometersController.dispose();
    _lengthController.dispose();
    _horsepowerController.dispose();
    for (var ctrl in _dynamicFieldControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  List<String> _extractValuesList(dynamic rawValues) {
    if (rawValues == null) return [];
    if (rawValues is List) {
      return rawValues
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (rawValues is String) {
      if (rawValues.startsWith('[') && rawValues.endsWith(']')) {
        try {
          final decoded = jsonDecode(rawValues);
          if (decoded is List) {
            return decoded
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }
      return rawValues
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  void _populateDynamicCustomFields(List<CustomFieldModel> fields) {
    if (fields.isEmpty) return;
    _dynamicFields = fields;
    _activeCustomFieldKeys.clear();
    _fieldModelsByName.clear();

    for (var f in fields) {
      if (f.id == null) continue;
      final fName = (f.name ?? "").toLowerCase().trim();
      final fId = f.id!;
      final fType = (f.type ?? "").toLowerCase().trim();

      _fieldModelsByName[fName] = f;
      _fieldModelsByName[fName.replaceAll(' ', '_')] = f;
      _fieldModelsByName[fName.replaceAll('_', ' ')] = f;

      if (fType == "number" || fType == "text" || fType == "textbox" || fType == "textarea") {
        _dynamicFieldControllers.putIfAbsent(fId, () => TextEditingController());
      }

      String? mappedKey;
      if (fName.contains("body type") || fName.contains("body_type")) {
        mappedKey = "body_type";
      } else if (fName.contains("exterior color") ||
          fName.contains("exterior_color") ||
          fName == "color") {
        mappedKey = "exterior_color";
      } else if (fName.contains("interior color") ||
          fName.contains("interior_color")) {
        mappedKey = "interior_color";
      } else if (fName.contains("steering") ||
          fName.contains("steering_side")) {
        mappedKey = "steering_side";
      } else if (fName.contains("transmission")) {
        mappedKey = "transmission";
      } else if (fName.contains("fuel") ||
          fName.contains("fuel_type")) {
        mappedKey = "fuel_type";
      } else if (fName.contains("capacity") ||
          fName.contains("payload") ||
          fName.contains("tonnes")) {
        mappedKey = "capacity";
      } else if (fName.contains("horsepower") || fName.contains("hp")) {
        mappedKey = "horsepower";
      } else if (fName.contains("warranty")) {
        mappedKey = "warranty";
      } else if (fName.contains("seller") ||
          fName.contains("seller_type")) {
        mappedKey = "seller_type";
      } else if (fName.contains("engine") ||
          fName.contains("engine_capacity")) {
        mappedKey = "engine_capacity";
      } else if (fName.contains("wheel")) {
        mappedKey = "wheels";
      } else if (fName.contains("drive") ||
          fName.contains("final_drive")) {
        mappedKey = "final_drive";
      } else if (fName.contains("condition")) {
        mappedKey = "condition";
      } else if (fName.contains("usage")) {
        mappedKey = "usage";
      } else if (fName.contains("city") ||
          fName.contains("plate_city") ||
          fName.contains("emirate")) {
        mappedKey = "plate_city";
      } else if (fName.contains("design") ||
          fName.contains("plate_design")) {
        mappedKey = "plate_design";
      } else if (fName.contains("letter") ||
          fName.contains("plate_code") ||
          fName.contains("code") ||
          fName.contains("plate_letter")) {
        mappedKey = "plate_code";
      } else if (fName.contains("kilometer") ||
          fName.contains("mileage") ||
          fName == "km") {
        mappedKey = "kilometers";
      } else if (fName.contains("year")) {
        mappedKey = "year";
      } else if (fName.contains("length")) {
        mappedKey = "length";
      }

      if (mappedKey != null) {
        _activeCustomFieldKeys.add(mappedKey);
        _fieldNameToId[mappedKey] = fId;
        _fieldModelsByName[mappedKey] = f;
      }
      _fieldNameToId[fName] = fId;
      _fieldNameToId[fName.replaceAll(' ', '_')] = fId;

      final options = _extractValuesList(f.values);
      if (options.isNotEmpty) {
        if (f.isFieldMultiselect == true) {
          _dynamicFieldMultiSelections.putIfAbsent(fId, () => []);
        } else {
          _dynamicFieldSingleSelections.putIfAbsent(fId, () => options.first);
        }

        if (mappedKey == "body_type") {
          _heavyBodyTypes = options;
          if (!_heavyBodyTypes.contains(_selectedBodyType)) {
            _selectedBodyType = _heavyBodyTypes.first;
          }
        } else if (mappedKey == "exterior_color") {
          _exteriorColors = options;
          if (!_exteriorColors.contains(_selectedExteriorColor)) {
            _selectedExteriorColor = _exteriorColors.first;
          }
        } else if (mappedKey == "interior_color") {
          _interiorColors = options;
          if (!_interiorColors.contains(_selectedInteriorColor)) {
            _selectedInteriorColor = _interiorColors.first;
          }
        } else if (mappedKey == "steering_side") {
          _steeringSides = options;
          if (!_steeringSides.contains(_selectedSteeringSide)) {
            _selectedSteeringSide = _steeringSides.first;
          }
        } else if (mappedKey == "transmission") {
          _motoTransmissions = options;
          if (!_motoTransmissions.contains(_selectedTransmission)) {
            _selectedTransmission = _motoTransmissions.first;
          }
        } else if (mappedKey == "fuel_type") {
          _fuelTypes = options;
          if (!_fuelTypes.contains(_selectedFuelType)) {
            _selectedFuelType = _fuelTypes.first;
          }
        } else if (mappedKey == "capacity") {
          _heavyCapacities = options;
          if (!_heavyCapacities.contains(_selectedCapacityTonnes)) {
            _selectedCapacityTonnes = _heavyCapacities.first;
          }
        } else if (mappedKey == "horsepower") {
          _heavyHorsepowers = options;
          if (!_heavyHorsepowers.contains(_selectedHorsepower)) {
            _selectedHorsepower = _heavyHorsepowers.first;
          }
        } else if (mappedKey == "warranty") {
          _warranties = options;
          if (!_warranties.contains(_selectedWarranty)) {
            _selectedWarranty = _warranties.first;
          }
        } else if (mappedKey == "seller_type") {
          _sellerTypes = options;
          if (!_sellerTypes.contains(_selectedSellerType)) {
            _selectedSellerType = _sellerTypes.first;
          }
        } else if (mappedKey == "engine_capacity") {
          _motoEngineCapacities = options;
          if (!_motoEngineCapacities.contains(_selectedEngineCapacity)) {
            _selectedEngineCapacity = _motoEngineCapacities.first;
          }
        } else if (mappedKey == "wheels") {
          _motoWheels = options;
          if (!_motoWheels.contains(_selectedWheels)) {
            _selectedWheels = _motoWheels.first;
          }
        } else if (mappedKey == "final_drive") {
          _motoFinalDrives = options;
          if (!_motoFinalDrives.contains(_selectedFinalDrive)) {
            _selectedFinalDrive = _motoFinalDrives.first;
          }
        } else if (mappedKey == "condition") {
          _conditions = options;
          if (!_conditions.contains(_itemCondition)) {
            _itemCondition = _conditions.first;
          }
        } else if (mappedKey == "usage") {
          _usages = options;
          if (!_usages.contains(_itemUsage)) {
            _itemUsage = _usages.first;
          }
        } else if (mappedKey == "plate_city") {
          _plateCities = options;
          if (!_plateCities.contains(_plateCity)) {
            _plateCity = _plateCities.first;
          }
        } else if (mappedKey == "plate_design") {
          _plateDesigns = options;
          if (!_plateDesigns.contains(_plateDesign)) {
            _plateDesign = _plateDesigns.first;
          }
        } else if (mappedKey == "plate_code") {
          _plateLetters = options;
          if (!_plateLetters.contains(_plateCodeController.text)) {
            _plateCodeController.text = _plateLetters.first;
          }
        }
      }
    }
    _isLoadingDynamicFields = false;
  }

  String _getDynamicLabel(String key, String fallback) {
    final norm = key.toLowerCase().trim();
    final model = _fieldModelsByName[norm] ??
        _fieldModelsByName[norm.replaceAll('_', ' ')] ??
        _fieldModelsByName[norm.replaceAll(' ', '_')];
    if (model != null && model.label != null && model.label!.trim().isNotEmpty) {
      final req = (model.required == 1) ? " *" : "";
      return "${model.label!.trim()}$req";
    }
    return fallback;
  }

  bool _isAlreadyRenderedInSpecificSection(CustomFieldModel field) {
    final normName = (field.name ?? "").toLowerCase().trim();
    if (_categoryType == MotorCategoryType.numberPlates) {
      if (normName.contains("city") ||
          normName.contains("emirate") ||
          normName.contains("design") ||
          normName.contains("letter") ||
          normName.contains("code") ||
          normName.contains("number")) {
        return true;
      }
    } else if (_categoryType == MotorCategoryType.motorcycles) {
      if (normName.contains("year") ||
          normName.contains("kilometer") ||
          normName.contains("engine") ||
          normName.contains("wheel") ||
          normName.contains("drive") ||
          normName.contains("warranty") ||
          normName.contains("seller")) {
        return true;
      }
    } else if (_categoryType == MotorCategoryType.heavyVehicles) {
      if (normName.contains("year") ||
          normName.contains("kilometer") ||
          normName.contains("body") ||
          normName.contains("color") ||
          normName.contains("steering") ||
          normName.contains("fuel") ||
          normName.contains("transmission") ||
          normName.contains("capacity") ||
          normName.contains("tonnes") ||
          normName.contains("horsepower") ||
          normName.contains("hp") ||
          normName.contains("warranty") ||
          normName.contains("seller")) {
        return true;
      }
    } else if (_categoryType == MotorCategoryType.boats) {
      if (normName.contains("year") ||
          normName.contains("kilometer") ||
          normName.contains("length") ||
          normName.contains("warranty") ||
          normName.contains("seller")) {
        return true;
      }
    } else if (_categoryType == MotorCategoryType.autoAccessories) {
      if (normName.contains("condition") ||
          normName.contains("usage") ||
          normName.contains("year") ||
          normName.contains("warranty") ||
          normName.contains("seller")) {
        return true;
      }
    }
    return false;
  }

  List<Widget> _buildGenericDynamicFields(BuildContext context) {
    if (_dynamicFields.isEmpty) return [];
    List<Widget> widgets = [];

    for (var field in _dynamicFields) {
      if (field.id == null) continue;
      if (_isAlreadyRenderedInSpecificSection(field)) continue;

      final fId = field.id!;
      final fType = (field.type ?? "").toLowerCase().trim();
      final label = "${field.label ?? field.name ?? ''}${field.required == 1 ? ' *' : ''}";
      final options = _extractValuesList(field.values);

      widgets.add(_buildFieldLabel(label));

      if (fType == "number") {
        final ctrl = _dynamicFieldControllers.putIfAbsent(
            fId, () => TextEditingController());
        widgets.add(
          _buildTextField(
            controller: ctrl,
            hint: field.label ?? field.name ?? '',
            keyboardType: TextInputType.number,
          ),
        );
      } else if (fType == "text" ||
          fType == "textbox" ||
          fType == "textarea" ||
          (options.isEmpty && fType != "radio" && fType != "dropdown")) {
        final ctrl = _dynamicFieldControllers.putIfAbsent(
            fId, () => TextEditingController());
        widgets.add(
          _buildTextField(
            controller: ctrl,
            hint: field.label ?? field.name ?? '',
            keyboardType: TextInputType.text,
            maxLines: fType == "textarea" ? 4 : 1,
          ),
        );
      } else if (options.isNotEmpty ||
          fType == "radio" ||
          fType == "dropdown" ||
          fType == "checkbox") {
        if (field.isFieldMultiselect == true) {
          final selectedList =
              _dynamicFieldMultiSelections.putIfAbsent(fId, () => []);
          widgets.add(
            _buildDropdownTile(
              title: selectedList.isNotEmpty
                  ? selectedList.join(', ')
                  : "Select ${field.label ?? field.name ?? ''}",
              onTap: () => _showMultiSelectPickerModal(
                title: "Select ${field.label ?? field.name ?? ''}",
                items: options,
                selected: selectedList,
                onSelect: (val) => setState(() {
                  _dynamicFieldMultiSelections[fId] = val;
                }),
              ),
            ),
          );
        } else {
          final selectedVal =
              _dynamicFieldSingleSelections[fId] ?? (options.isNotEmpty ? options.first : "");
          widgets.add(
            _buildDropdownTile(
              title: selectedVal.isNotEmpty
                  ? selectedVal
                  : "Select ${field.label ?? field.name ?? ''}",
              onTap: () => _showPickerModal(
                title: "Select ${field.label ?? field.name ?? ''}",
                items: options,
                selected: selectedVal,
                onSelect: (val) => setState(() {
                  _dynamicFieldSingleSelections[fId] = val;
                }),
              ),
            ),
          );
        }
      }

      widgets.add(const SizedBox(height: 18));
    }

    return widgets;
  }

  Future<void> _fetchDynamicCustomFields() async {
    final catId = widget.category?.id ??
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

  MotorCategoryType _detectCategoryType(
      CategoryModel? category, List<CategoryModel>? breadcrumbs) {
    final allText = [
      category?.slug?.toLowerCase() ?? '',
      category?.name?.toLowerCase() ?? '',
      if (breadcrumbs != null)
        ...breadcrumbs.map((b) =>
            '${b.slug?.toLowerCase() ?? ''} ${b.name?.toLowerCase() ?? ''}')
    ].join(' ');

    if (allText.contains('plate') || allText.contains('number-plate')) {
      return MotorCategoryType.numberPlates;
    }
    if (allText.contains('accessori') ||
        allText.contains('part') ||
        allText.contains('tool') ||
        allText.contains('apparel') ||
        allText.contains('merchandise')) {
      return MotorCategoryType.autoAccessories;
    }
    if (allText.contains('boat') ||
        allText.contains('sailboat') ||
        allText.contains('motorboat')) {
      return MotorCategoryType.boats;
    }
    if (allText.contains('motorcycle') ||
        allText.contains('bike') ||
        allText.contains('scooter') ||
        allText.contains('trike') ||
        allText.contains('karting') ||
        allText.contains('mo-ped') ||
        allText.contains('golf-cart')) {
      return MotorCategoryType.motorcycles;
    }
    if (allText.contains('heavy') ||
        allText.contains('truck') ||
        allText.contains('bus') ||
        allText.contains('forklift') ||
        allText.contains('crane') ||
        allText.contains('tanker') ||
        allText.contains('trailer') ||
        allText.contains('aircraft')) {
      return MotorCategoryType.heavyVehicles;
    }
    return MotorCategoryType.general;
  }

  void _initDefaultTitlesAndDescriptions() {
    String catName = widget.category?.name ?? 'Item';
    if (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty) {
      final validNames = widget.breadcrumbs!
          .map((e) => e.name)
          .where((n) => n != null && n.isNotEmpty && n.toLowerCase() != 'motors')
          .toList();
      if (validNames.isNotEmpty) {
        catName = validNames.last!;
      }
    }
    if (_categoryType == MotorCategoryType.numberPlates) {
      _plateCodeController.text = "A";
      _plateNumberController.text = "";
      _plateCity = _extractCityFromCategory(catName);
      _titleController.text = "$_plateCity Plate";
      _descriptionController.text =
          "Special $_plateCity number plate available for transfer.";
    } else if (_categoryType == MotorCategoryType.autoAccessories) {
      _titleController.text = catName;
      _descriptionController.text =
          "Genuine $catName for sale. Excellent quality and condition.";
    } else {
      _titleController.text = catName;
      _descriptionController.text =
          "Well-maintained $catName in excellent running condition.";
    }
    _descriptionCharCount = _descriptionController.text.length;
  }

  String _extractCityFromCategory(String name) {
    final lower = name.toLowerCase();
    for (final city in _plateCities) {
      if (lower.contains(city.toLowerCase())) {
        return city;
      }
    }
    return "Dubai";
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

    if (_categoryType == MotorCategoryType.numberPlates) {
      if (_plateNumberController.text.trim().isEmpty) {
        HelperUtils.showSnackBarMessage(
          context,
          "Please enter the Plate Number",
          type: MessageType.warning,
        );
        return;
      }
    }

    final price = double.tryParse(_priceController.text.replaceAll(',', '').trim());
    if (_priceController.text.trim().isEmpty || price == null || price <= 0) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a valid Price in AED",
        type: MessageType.warning,
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a contact Phone number",
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

    if (_selectedImages.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please add at least 1 photo for your ad",
        type: MessageType.warning,
      );
      return;
    }

    final Map<String, dynamic> genericAdData = {
      'category': widget.category,
      'breadcrumbs': widget.breadcrumbs,
      'categoryType': _categoryType.name,
      'title': _titleController.text.trim(),
      'price': price,
      'contactPhone': _phoneController.text.trim(),
      'showPhone': _showPhone,
      'description': _descriptionController.text.trim(),
      'imageFiles': _selectedImages,
      'locationNeighbourhood': _selectedLocationName,
      'locationAddress': _selectedAddress,
    };

    // Build custom fields map per category
    final Map<String, dynamic> customFieldsMap = {};

    if (_categoryType == MotorCategoryType.numberPlates) {
      genericAdData['plateCity'] = _plateCity;
      genericAdData['plateDesign'] = _plateDesign;
      genericAdData['plateCode'] = _plateCodeController.text.trim();
      genericAdData['plateNumber'] = _plateNumberController.text.trim();
      customFieldsMap['plate_city'] = [_plateCity];
      customFieldsMap['plate_design'] = [_plateDesign];
      customFieldsMap['plate_code'] = [_plateCodeController.text.trim()];
      customFieldsMap['plate_number'] = [_plateNumberController.text.trim()];
    } else if (_categoryType == MotorCategoryType.autoAccessories) {
      genericAdData['condition'] = _itemCondition;
      genericAdData['usage'] = _itemUsage;
      genericAdData['year'] = _selectedYear;
      genericAdData['warranty'] = _selectedWarranty;
      genericAdData['sellerType'] = _selectedSellerType;
      customFieldsMap['condition'] = [_itemCondition];
      customFieldsMap['usage'] = [_itemUsage];
      customFieldsMap['year'] = [_selectedYear.toString()];
      customFieldsMap['warranty'] = [_selectedWarranty];
      customFieldsMap['seller_type'] = [_selectedSellerType];
    } else if (_categoryType == MotorCategoryType.motorcycles) {
      genericAdData['kilometers'] = _kilometersController.text.trim();
      genericAdData['year'] = _selectedYear;
      genericAdData['engineCapacity'] = _selectedEngineCapacity;
      genericAdData['wheels'] = _selectedWheels;
      genericAdData['transmission'] = _selectedTransmission;
      genericAdData['finalDrive'] = _selectedFinalDrive;
      genericAdData['warranty'] = _selectedWarranty;
      genericAdData['sellerType'] = _selectedSellerType;
      if (_kilometersController.text.trim().isNotEmpty) {
        customFieldsMap['kilometers'] = [_kilometersController.text.trim()];
      }
      customFieldsMap['year'] = [_selectedYear.toString()];
      customFieldsMap['engine_capacity'] = [_selectedEngineCapacity];
      customFieldsMap['wheels'] = [_selectedWheels];
      customFieldsMap['transmission'] = [_selectedTransmission];
      customFieldsMap['final_drive'] = [_selectedFinalDrive];
      customFieldsMap['warranty'] = [_selectedWarranty];
      customFieldsMap['seller_type'] = [_selectedSellerType];
    } else if (_categoryType == MotorCategoryType.boats) {
      genericAdData['length'] = _lengthController.text.trim();
      genericAdData['kilometers'] = _kilometersController.text.trim();
      genericAdData['year'] = _selectedYear;
      genericAdData['warranty'] = _selectedWarranty;
      genericAdData['sellerType'] = _selectedSellerType;
      if (_lengthController.text.trim().isNotEmpty) {
        customFieldsMap['length'] = [_lengthController.text.trim()];
      }
      if (_kilometersController.text.trim().isNotEmpty) {
        customFieldsMap['kilometers'] = [_kilometersController.text.trim()];
      }
      customFieldsMap['year'] = [_selectedYear.toString()];
      customFieldsMap['warranty'] = [_selectedWarranty];
      customFieldsMap['seller_type'] = [_selectedSellerType];
    } else if (_categoryType == MotorCategoryType.heavyVehicles) {
      genericAdData['kilometers'] = _kilometersController.text.trim();
      genericAdData['year'] = _selectedYear;
      genericAdData['bodyType'] = _selectedBodyType;
      genericAdData['exteriorColor'] = _selectedExteriorColor;
      genericAdData['interiorColor'] = _selectedInteriorColor;
      genericAdData['steeringSide'] = _selectedSteeringSide;
      genericAdData['fuelType'] = _selectedFuelType;
      genericAdData['transmission'] = _selectedTransmission;
      genericAdData['capacity'] = _selectedCapacityTonnes;
      genericAdData['horsepower'] = _selectedHorsepower;
      genericAdData['warranty'] = _selectedWarranty;
      genericAdData['sellerType'] = _selectedSellerType;
      if (_kilometersController.text.trim().isNotEmpty) {
        customFieldsMap['kilometers'] = [_kilometersController.text.trim()];
      }
      customFieldsMap['year'] = [_selectedYear.toString()];
      customFieldsMap['body_type'] = [_selectedBodyType];
      customFieldsMap['exterior_color'] = [_selectedExteriorColor];
      customFieldsMap['interior_color'] = [_selectedInteriorColor];
      customFieldsMap['steering_side'] = [_selectedSteeringSide];
      customFieldsMap['fuel_type'] = [_selectedFuelType];
      customFieldsMap['transmission'] = [_selectedTransmission];
      customFieldsMap['capacity'] = [_selectedCapacityTonnes];
      customFieldsMap['horsepower'] = [_selectedHorsepower];
      customFieldsMap['warranty'] = [_selectedWarranty];
      customFieldsMap['seller_type'] = [_selectedSellerType];
    }

    final categoryId = widget.category?.id ??
        (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty
            ? widget.breadcrumbs!.last.id
            : 1);
    final allCategoryIds = widget.breadcrumbs != null &&
            widget.breadcrumbs!.isNotEmpty
        ? widget.breadcrumbs!
            .map((b) => b.id)
            .where((id) => id != null)
            .join(',')
        : "$categoryId";

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
      'hide_phone_number': _showPhone ? 0 : 1,
      'country': 'United Arab Emirates',
      'state': 'Dubai',
      'city': 'Dubai',
      'latitude': _currentLocationLatLng.latitude,
      'longitude': _currentLocationLatLng.longitude,
      'address': _selectedAddress,
    };

    final Map<String, dynamic> mergedCustomFields = {};
    if (customFieldsMap.isNotEmpty) {
      customFieldsMap.forEach((key, val) {
        final id = _fieldNameToId[key.toLowerCase()] ??
            _fieldNameToId[key.replaceAll('_', ' ').toLowerCase()];
        if (id != null && val != null) {
          mergedCustomFields["$id"] =
              val is List ? val : [val.toString()];
        }
      });
    }

    _dynamicFieldControllers.forEach((fieldId, ctrl) {
      if (ctrl.text.trim().isNotEmpty) {
        mergedCustomFields["$fieldId"] = [ctrl.text.trim()];
      }
    });

    _dynamicFieldMultiSelections.forEach((fieldId, list) {
      if (list.isNotEmpty) {
        mergedCustomFields["$fieldId"] = list;
      }
    });

    _dynamicFieldSingleSelections.forEach((fieldId, val) {
      if (val.trim().isNotEmpty) {
        mergedCustomFields["$fieldId"] = [val.trim()];
      }
    });

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
      log("Item create API log error: $e");
      Widgets.hideLoder(context);
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to create ad: $e",
          type: MessageType.error,
        );
      }
      return;
    } finally {
      Widgets.hideLoder(context);
    }

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
      FetchMyPromotedItemsCubit.globalInstance?.fetchMyPromotedItems();
    } catch (_) {}

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      Routes.carPackagePaymentScreen,
      arguments: {
        'genericAdData': genericAdData,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Title
                      Center(
                        child: Text(
                          "Tell us about your ${_getHeaderNoun()}",
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
                            _getCategoryIcon(),
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
                      _buildFieldLabel("Title *"),
                      _buildTextField(
                        controller: _titleController,
                        hint: "Title *",
                        maxLength: 100,
                      ),
                      const SizedBox(height: 18),

                      // 2. Price (AED)
                      _buildFieldLabel("Price *"),
                      _buildTextField(
                        controller: _priceController,
                        hint: "Price *",
                        keyboardType: TextInputType.number,
                        suffixText: "AED",
                      ),
                      const SizedBox(height: 18),

                      // 3. Photos Section
                      _buildAddPicturesSection(context),
                      const SizedBox(height: 20),

                      // 4. Contact Number
                      _buildFieldLabel("Contact number *"),
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
                          _buildFieldLabel("Describe your item *"),
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
                      _buildLocationMapSection(context),
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

  String _getHeaderNoun() {
    switch (_categoryType) {
      case MotorCategoryType.numberPlates:
        return "plate";
      case MotorCategoryType.autoAccessories:
        return "part / accessory";
      case MotorCategoryType.motorcycles:
        return "motorcycle";
      case MotorCategoryType.boats:
        return "boat";
      case MotorCategoryType.heavyVehicles:
        return "vehicle";
      case MotorCategoryType.general:
        return "item";
    }
  }

  IconData _getCategoryIcon() {
    switch (_categoryType) {
      case MotorCategoryType.numberPlates:
        return Icons.featured_play_list_outlined;
      case MotorCategoryType.autoAccessories:
        return Icons.handyman_outlined;
      case MotorCategoryType.motorcycles:
        return Icons.two_wheeler_outlined;
      case MotorCategoryType.boats:
        return Icons.directions_boat_outlined;
      case MotorCategoryType.heavyVehicles:
        return Icons.local_shipping_outlined;
      case MotorCategoryType.general:
        return Icons.directions_car_outlined;
    }
  }

  List<Widget> _buildCategorySpecificFields(BuildContext context) {
    List<Widget> specificWidgets = [];
    switch (_categoryType) {
      case MotorCategoryType.numberPlates:
        specificWidgets = _buildNumberPlateFields(context);
        break;
      case MotorCategoryType.autoAccessories:
        specificWidgets = _buildAutoAccessoriesFields(context);
        break;
      case MotorCategoryType.motorcycles:
        specificWidgets = _buildMotorcycleFields(context);
        break;
      case MotorCategoryType.boats:
        specificWidgets = _buildBoatFields(context);
        break;
      case MotorCategoryType.heavyVehicles:
        specificWidgets = _buildHeavyVehiclesFields(context);
        break;
      case MotorCategoryType.general:
        specificWidgets = [];
        break;
    }
    return [
      ...specificWidgets,
      ..._buildGenericDynamicFields(context),
    ];
  }

  /// 1. Number Plates Fields
  List<Widget> _buildNumberPlateFields(BuildContext context) {
    return [
      // Stylized Plate Preview
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.8),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              _plateCity.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: context.color.textLightColor,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD31027).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD31027)),
                  ),
                  child: Text(
                    _plateCodeController.text.isNotEmpty
                        ? _plateCodeController.text
                        : "A",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD31027),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  _plateNumberController.text.isNotEmpty
                      ? _plateNumberController.text
                      : "12345",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),

      // Emirate / Plate City
      _buildFieldLabel(_getDynamicLabel("plate_city", "Emirate / City *")),
      _buildDropdownTile(
        title: _plateCity.isNotEmpty ? _plateCity : "Select Emirate",
        onTap: () => _showPickerModal(
          title: "Select Emirate",
          items: _plateCities,
          selected: _plateCity,
          onSelect: (val) {
            setState(() {
              _plateCity = val;
              _titleController.text = "$_plateCity Plate";
            });
          },
        ),
      ),
      const SizedBox(height: 18),

      // Plate Design / Type
      _buildFieldLabel(_getDynamicLabel("plate_design", "Plate Design *")),
      _buildDropdownTile(
        title: _plateDesign.isNotEmpty ? _plateDesign : "Select Plate Design",
        onTap: () => _showPickerModal(
          title: "Select Plate Design",
          items: _plateDesigns,
          selected: _plateDesign,
          onSelect: (val) => setState(() => _plateDesign = val),
        ),
      ),
      const SizedBox(height: 18),

      // Plate Code / Letter & Plate Number Side-by-Side
      Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel(_getDynamicLabel("plate_code", "Code / Letter *")),
                _buildDropdownTile(
                  title: _plateCodeController.text.isNotEmpty
                      ? _plateCodeController.text
                      : (_plateLetters.isNotEmpty ? _plateLetters.first : "A"),
                  onTap: () => _showPickerModal(
                    title: "Select Code / Letter",
                    items: _plateLetters,
                    selected: _plateCodeController.text,
                    onSelect: (val) =>
                        setState(() => _plateCodeController.text = val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel(_getDynamicLabel("plate_number", "Plate Number *")),
                _buildTextField(
                  controller: _plateNumberController,
                  hint: "e.g. 12345",
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
    ];
  }

  /// 2. Auto Accessories & Parts Fields
  List<Widget> _buildAutoAccessoriesFields(BuildContext context) {
    return [
      if (_hasField("condition")) ...[
        _buildFieldLabel(_getDynamicLabel("condition", "Item Condition *")),
        _buildDropdownTile(
          title: _itemCondition.isNotEmpty ? _itemCondition : "Select Item Condition",
          onTap: () => _showPickerModal(
            title: "Select Item Condition",
            items: _conditions,
            selected: _itemCondition,
            onSelect: (val) => setState(() => _itemCondition = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("usage")) ...[
        _buildFieldLabel(_getDynamicLabel("usage", "Usage *")),
        _buildDropdownTile(
          title: _itemUsage.isNotEmpty ? _itemUsage : "Select Usage",
          onTap: () => _showPickerModal(
            title: "Select Usage",
            items: _usages,
            selected: _itemUsage,
            onSelect: (val) => setState(() => _itemUsage = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("year")) ...[
        _buildFieldLabel(_getDynamicLabel("year", "Manufacturing Year *")),
        _buildDropdownTile(
          title: _selectedYear.toString(),
          onTap: () => _showPickerModal(
            title: "Select Year",
            items: _years.map((e) => e.toString()).toList(),
            selected: _selectedYear.toString(),
            onSelect: (val) =>
                setState(() => _selectedYear = int.tryParse(val) ?? 2025),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("warranty")) ...[
        _buildFieldLabel(_getDynamicLabel("warranty", "Warranty Status *")),
        _buildDropdownTile(
          title: _selectedWarranty.isNotEmpty ? _selectedWarranty : "Select Warranty",
          onTap: () => _showPickerModal(
            title: "Select Warranty",
            items: _warranties,
            selected: _selectedWarranty,
            onSelect: (val) => setState(() => _selectedWarranty = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("seller_type")) ...[
        _buildFieldLabel(_getDynamicLabel("seller_type", "Seller Type *")),
        _buildDropdownTile(
          title: _selectedSellerType.isNotEmpty ? _selectedSellerType : "Select Seller Type",
          onTap: () => _showPickerModal(
            title: "Select Seller Type",
            items: _sellerTypes,
            selected: _selectedSellerType,
            onSelect: (val) => setState(() => _selectedSellerType = val),
          ),
        ),
        const SizedBox(height: 20),
      ],
    ];
  }

  /// 3. Motorcycles Fields
  List<Widget> _buildMotorcycleFields(BuildContext context) {
    return [
      if (_hasField("year")) ...[
        _buildFieldLabel(_getDynamicLabel("year", "Manufacturing Year *")),
        _buildDropdownTile(
          title: _selectedYear.toString(),
          onTap: () => _showPickerModal(
            title: "Select Year",
            items: _years.map((e) => e.toString()).toList(),
            selected: _selectedYear.toString(),
            onSelect: (val) =>
                setState(() => _selectedYear = int.tryParse(val) ?? 2025),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("kilometers")) ...[
        _buildFieldLabel(_getDynamicLabel("kilometers", "Kilometers (Mileage) *")),
        _buildTextField(
          controller: _kilometersController,
          hint: "Kilometers *",
          keyboardType: TextInputType.number,
          suffixText: "km",
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("engine_capacity")) ...[
        _buildFieldLabel(_getDynamicLabel("engine_capacity", "Engine Capacity *")),
        _buildDropdownTile(
          title: _selectedEngineCapacity.isNotEmpty ? _selectedEngineCapacity : "Select Engine Capacity",
          onTap: () => _showPickerModal(
            title: "Select Engine Capacity",
            items: _motoEngineCapacities,
            selected: _selectedEngineCapacity,
            onSelect: (val) => setState(() => _selectedEngineCapacity = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("wheels")) ...[
        _buildFieldLabel(_getDynamicLabel("wheels", "Wheels (Number of Wheels) *")),
        _buildDropdownTile(
          title: _selectedWheels.isNotEmpty ? _selectedWheels : "Select Wheels",
          onTap: () => _showPickerModal(
            title: "Select Wheels",
            items: _motoWheels,
            selected: _selectedWheels,
            onSelect: (val) => setState(() => _selectedWheels = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("final_drive")) ...[
        _buildFieldLabel(_getDynamicLabel("final_drive", "Final Drive System (Optional)")),
        _buildDropdownTile(
          title: _selectedFinalDrive.isNotEmpty ? _selectedFinalDrive : "Select Final Drive",
          onTap: () => _showPickerModal(
            title: "Select Final Drive",
            items: _motoFinalDrives,
            selected: _selectedFinalDrive,
            onSelect: (val) => setState(() => _selectedFinalDrive = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("warranty")) ...[
        _buildFieldLabel(_getDynamicLabel("warranty", "Warranty Status *")),
        _buildDropdownTile(
          title: _selectedWarranty.isNotEmpty ? _selectedWarranty : "Select Warranty",
          onTap: () => _showPickerModal(
            title: "Select Warranty",
            items: _warranties,
            selected: _selectedWarranty,
            onSelect: (val) => setState(() => _selectedWarranty = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("seller_type")) ...[
        _buildFieldLabel(_getDynamicLabel("seller_type", "Seller Type *")),
        _buildDropdownTile(
          title: _selectedSellerType.isNotEmpty ? _selectedSellerType : "Select Seller Type",
          onTap: () => _showPickerModal(
            title: "Select Seller Type",
            items: _sellerTypes,
            selected: _selectedSellerType,
            onSelect: (val) => setState(() => _selectedSellerType = val),
          ),
        ),
        const SizedBox(height: 20),
      ],
    ];
  }

  /// 4. Boats Fields
  List<Widget> _buildBoatFields(BuildContext context) {
    return [
      if (_hasField("kilometers") || _hasField("mileage") || _hasField("hours")) ...[
        _buildFieldLabel(_getDynamicLabel("kilometers", "Kilometers (Mileage / Hours) *")),
        _buildTextField(
          controller: _kilometersController,
          hint: "e.g. 500",
          keyboardType: TextInputType.number,
          suffixText: "km",
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("length")) ...[
        _buildFieldLabel(_getDynamicLabel("length", "Boat Length (in feet) *")),
        _buildTextField(
          controller: _lengthController,
          hint: "e.g. 32",
          keyboardType: TextInputType.number,
          suffixText: "ft",
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("year")) ...[
        _buildFieldLabel(_getDynamicLabel("year", "Manufacturing Year *")),
        _buildDropdownTile(
          title: _selectedYear.toString(),
          onTap: () => _showPickerModal(
            title: "Select Year",
            items: _years.map((e) => e.toString()).toList(),
            selected: _selectedYear.toString(),
            onSelect: (val) =>
                setState(() => _selectedYear = int.tryParse(val) ?? 2025),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("condition")) ...[
        _buildFieldLabel(_getDynamicLabel("condition", "Condition *")),
        _buildDropdownTile(
          title: _itemCondition.isNotEmpty ? _itemCondition : "Select Condition",
          onTap: () => _showPickerModal(
            title: "Select Condition",
            items: _conditions,
            selected: _itemCondition,
            onSelect: (val) => setState(() => _itemCondition = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("warranty")) ...[
        _buildFieldLabel(_getDynamicLabel("warranty", "Warranty Status *")),
        _buildDropdownTile(
          title: _selectedWarranty.isNotEmpty ? _selectedWarranty : "Select Warranty",
          onTap: () => _showPickerModal(
            title: "Select Warranty",
            items: _warranties,
            selected: _selectedWarranty,
            onSelect: (val) => setState(() => _selectedWarranty = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("seller_type")) ...[
        _buildFieldLabel(_getDynamicLabel("seller_type", "Seller Type *")),
        _buildDropdownTile(
          title: _selectedSellerType.isNotEmpty ? _selectedSellerType : "Select Seller Type",
          onTap: () => _showPickerModal(
            title: "Select Seller Type",
            items: _sellerTypes,
            selected: _selectedSellerType,
            onSelect: (val) => setState(() => _selectedSellerType = val),
          ),
        ),
        const SizedBox(height: 20),
      ],
    ];
  }

  /// 5. Heavy Vehicles & Commercial Trucks Fields
  List<Widget> _buildHeavyVehiclesFields(BuildContext context) {
    return [
      if (_hasField("kilometers")) ...[
        _buildFieldLabel(_getDynamicLabel("kilometers", "Kilometers (Mileage) *")),
        _buildTextField(
          controller: _kilometersController,
          hint: "Kilometers *",
          keyboardType: TextInputType.number,
          suffixText: "km",
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("year")) ...[
        _buildFieldLabel(_getDynamicLabel("year", "Manufacturing Year *")),
        _buildDropdownTile(
          title: _selectedYear.toString(),
          onTap: () => _showPickerModal(
            title: "Select Year",
            items: _years.map((e) => e.toString()).toList(),
            selected: _selectedYear.toString(),
            onSelect: (val) =>
                setState(() => _selectedYear = int.tryParse(val) ?? 2025),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("body_type")) ...[
        _buildFieldLabel(_getDynamicLabel("body_type", "Body Type *")),
        _buildDropdownTile(
          title: _heavyBodyTypes.isNotEmpty ? _selectedBodyType : "Select Body Type",
          onTap: () => _showPickerModal(
            title: "Select Body Type",
            items: _heavyBodyTypes,
            selected: _selectedBodyType,
            onSelect: (val) => setState(() => _selectedBodyType = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("exterior_color")) ...[
        _buildFieldLabel(_getDynamicLabel("exterior_color", "Exterior Color *")),
        _buildDropdownTile(
          title: _exteriorColors.isNotEmpty ? _selectedExteriorColor : "Select Exterior Color",
          onTap: () => _showPickerModal(
            title: "Select Exterior Color",
            items: _exteriorColors,
            selected: _selectedExteriorColor,
            onSelect: (val) => setState(() => _selectedExteriorColor = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("interior_color")) ...[
        _buildFieldLabel(_getDynamicLabel("interior_color", "Interior Color *")),
        _buildDropdownTile(
          title: _interiorColors.isNotEmpty ? _selectedInteriorColor : "Select Interior Color",
          onTap: () => _showPickerModal(
            title: "Select Interior Color",
            items: _interiorColors,
            selected: _selectedInteriorColor,
            onSelect: (val) => setState(() => _selectedInteriorColor = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("steering_side")) ...[
        _buildFieldLabel(_getDynamicLabel("steering_side", "Steering Side *")),
        Row(
          children: [
            _buildToggleButton(
              title: "Left Hand Side",
              isSelected: _selectedSteeringSide == "Left Hand Side",
              onTap: () => setState(() => _selectedSteeringSide = "Left Hand Side"),
            ),
            const SizedBox(width: 12),
            _buildToggleButton(
              title: "Right Hand Side",
              isSelected: _selectedSteeringSide == "Right Hand Side",
              onTap: () => setState(() => _selectedSteeringSide = "Right Hand Side"),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("fuel_type")) ...[
        _buildFieldLabel(_getDynamicLabel("fuel_type", "Fuel Type *")),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildToggleButton(
              title: "Diesel",
              isSelected: _selectedFuelType == "Diesel",
              onTap: () => setState(() => _selectedFuelType = "Diesel"),
            ),
            _buildToggleButton(
              title: "Petrol",
              isSelected: _selectedFuelType == "Petrol",
              onTap: () => setState(() => _selectedFuelType = "Petrol"),
            ),
            _buildToggleButton(
              title: "Electric",
              isSelected: _selectedFuelType == "Electric",
              onTap: () => setState(() => _selectedFuelType = "Electric"),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("transmission")) ...[
        _buildFieldLabel(_getDynamicLabel("transmission", "Transmission *")),
        Row(
          children: [
            _buildToggleButton(
              title: "Manual",
              isSelected: _selectedTransmission == "Manual",
              onTap: () => setState(() => _selectedTransmission = "Manual"),
            ),
            const SizedBox(width: 12),
            _buildToggleButton(
              title: "Automatic",
              isSelected: _selectedTransmission == "Automatic",
              onTap: () => setState(() => _selectedTransmission = "Automatic"),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("capacity")) ...[
        _buildFieldLabel(_getDynamicLabel("capacity", "Capacity / Payload (Tonnes)")),
        _buildDropdownTile(
          title: _heavyCapacities.isNotEmpty ? _selectedCapacityTonnes : "Select Capacity",
          onTap: () => _showPickerModal(
            title: "Select Capacity",
            items: _heavyCapacities,
            selected: _selectedCapacityTonnes,
            onSelect: (val) => setState(() => _selectedCapacityTonnes = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("horsepower")) ...[
        _buildFieldLabel(_getDynamicLabel("horsepower", "Horsepower")),
        _buildDropdownTile(
          title: _heavyHorsepowers.isNotEmpty ? _selectedHorsepower : "Select Horsepower",
          onTap: () => _showPickerModal(
            title: "Select Horsepower",
            items: _heavyHorsepowers,
            selected: _selectedHorsepower,
            onSelect: (val) => setState(() => _selectedHorsepower = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("warranty")) ...[
        _buildFieldLabel(_getDynamicLabel("warranty", "Warranty Status *")),
        _buildDropdownTile(
          title: _selectedWarranty.isNotEmpty ? _selectedWarranty : "Select Warranty",
          onTap: () => _showPickerModal(
            title: "Select Warranty",
            items: _warranties,
            selected: _selectedWarranty,
            onSelect: (val) => setState(() => _selectedWarranty = val),
          ),
        ),
        const SizedBox(height: 18),
      ],

      if (_hasField("seller_type")) ...[
        _buildFieldLabel(_getDynamicLabel("seller_type", "Seller Type *")),
        _buildDropdownTile(
          title: _selectedSellerType.isNotEmpty ? _selectedSellerType : "Select Seller Type",
          onTap: () => _showPickerModal(
            title: "Select Seller Type",
            items: _sellerTypes,
            selected: _selectedSellerType,
            onSelect: (val) => setState(() => _selectedSellerType = val),
          ),
        ),
        const SizedBox(height: 20),
      ],
    ];
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

  Widget _buildAddPicturesSection(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: _pickImages,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD31027),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFFD31027),
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  "Add Pictures",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD31027),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = _selectedImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        image,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
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

  Widget _buildDropdownTile({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.color.textDefaultColor,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: context.color.textLightColor,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getLabelIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('home') || lower.contains('villa') || lower.contains('apt')) {
      return Icons.home_rounded;
    }
    if (lower.contains('office') || lower.contains('work') || lower.contains('business')) {
      return Icons.business_rounded;
    }
    if (lower.contains('showroom') || lower.contains('shop') || lower.contains('store')) {
      return Icons.storefront_rounded;
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

  Widget _buildLocationMapSection(BuildContext context) {
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
                    _getLabelIcon(_locationLabel),
                    size: 18,
                    color: context.color.territoryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _locationLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _openFullMapPicker,
                child: Row(
                  children: [
                    Icon(Icons.edit_location_alt_outlined,
                        size: 16, color: context.color.territoryColor),
                    const SizedBox(width: 4),
                    Text(
                      "Change Pin",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.color.territoryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _selectedAddress,
            style: TextStyle(
              fontSize: 12.5,
              color: context.color.textLightColor,
            ),
          ),
          const SizedBox(height: 14),

          // Live Google Map Widget with full interactive search / pin capability
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
                        markerId: const MarkerId("motor_loc"),
                        position: _currentLocationLatLng,
                        infoWindow: InfoWindow(
                          title: _locationLabel,
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
          const SizedBox(height: 14),

          // Location chips / buttons with Wrap to prevent any 0.397px overflow
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showLocationPicker(context),
                icon: const Icon(Icons.add,
                    size: 16, color: Color(0xFFD31027)),
                label: const Text(
                  "Add Label",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD31027),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD31027)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              InkWell(
                onTap: () => _showLocationPicker(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.color.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getLabelIcon(_locationLabel),
                        size: 14,
                        color: context.color.territoryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _locationLabel,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit,
                        size: 12,
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

  void _showLocationPicker(BuildContext context) {
    String tempNeighbourhood = _selectedLocationName;
    final buildingCtrl = TextEditingController();
    final aptCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: _locationLabel);
    final quickLabels = ["Home", "Office", "Showroom", "Workshop", "Warehouse", "Villa", "Apartment"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Material(
                color: context.color.backgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: context.color.borderColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Location Details & Label",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(modalContext),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildFieldLabel("Neighbourhood / Area *"),
                        InkWell(
                          onTap: () {
                            _showPickerModal(
                              title: "Select Neighbourhood",
                              items: _neighbourhoods,
                              selected: tempNeighbourhood,
                              onSelect: (val) {
                                setModalState(() => tempNeighbourhood = val);
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: context.color.secondaryColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.color.borderColor
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tempNeighbourhood,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: context.color.textLightColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        _buildFieldLabel("Building or Street name (Optional)"),
                        _buildTextField(
                          controller: buildingCtrl,
                          hint: "e.g. Building / Street name",
                        ),
                        const SizedBox(height: 14),

                        _buildFieldLabel("Apartment or Villa number (Optional)"),
                        _buildTextField(
                          controller: aptCtrl,
                          hint: "e.g. Apt 104 / Villa 8",
                        ),
                        const SizedBox(height: 14),

                        _buildFieldLabel("Select Location Label"),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: quickLabels.map((lbl) {
                            final isSel = labelCtrl.text.trim().toLowerCase() == lbl.toLowerCase();
                            return ChoiceChip(
                              label: Text(lbl),
                              selected: isSel,
                              selectedColor: const Color(0xFFD31027).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? const Color(0xFFD31027) : context.color.textDefaultColor,
                              ),
                              onSelected: (_) {
                                setModalState(() {
                                  labelCtrl.text = lbl;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),

                        _buildFieldLabel("Custom Label"),
                        _buildTextField(
                          controller: labelCtrl,
                          hint: "e.g. Home, Office, Showroom",
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _locationLabel = labelCtrl.text.trim().isNotEmpty
                                    ? labelCtrl.text.trim()
                                    : "Home";
                                _selectedLocationName = tempNeighbourhood;
                                _selectedAddress =
                                    "$tempNeighbourhood, Dubai, United Arab Emirates";
                              });
                              Navigator.pop(modalContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD31027),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Save Location",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPickerModal({
    required String title,
    required List<String> items,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Material(
          color: context.color.backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.55,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                const SizedBox(height: 16),
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
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: context.color.borderColor.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = selected == item;
                      return ListTile(
                        onTap: () {
                          onSelect(item);
                          Navigator.pop(modalContext);
                        },
                        title: Text(
                          item,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? context.color.territoryColor
                                : context.color.textDefaultColor,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: context.color.territoryColor,
                              )
                            : null,
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
  }

  void _showMultiSelectPickerModal({
    required String title,
    required List<String> items,
    required List<String> selected,
    required ValueChanged<List<String>> onSelect,
  }) {
    List<String> currentSelected = List<String>.from(selected);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Material(
              color: context.color.backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                    const SizedBox(height: 16),
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
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: context.color.borderColor.withValues(alpha: 0.3),
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isSelected = currentSelected.contains(item);
                          return ListTile(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  currentSelected.remove(item);
                                } else {
                                  currentSelected.add(item);
                                }
                              });
                              onSelect(currentSelected);
                            },
                            title: Text(
                              item,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? context.color.territoryColor
                                    : context.color.textDefaultColor,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_box_rounded,
                                    color: context.color.territoryColor,
                                  )
                                : Icon(
                                    Icons.check_box_outline_blank_rounded,
                                    color: context.color.textLightColor,
                                  ),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          onSelect(currentSelected);
                          Navigator.pop(modalContext);
                        },
                        child: const Text(
                          "Done",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
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
}
