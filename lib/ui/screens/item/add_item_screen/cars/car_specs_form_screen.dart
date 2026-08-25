import 'package:flutter/material.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/cars/car_models.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/repositories/cars_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/data/repositories/custom_fields_repository.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/dynamic_custom_fields_form.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/posting_form_shared.dart';

import 'package:Ebozor/data/model/item/item_model.dart';

class CarSpecsFormScreen extends StatefulWidget {
  final CategoryModel? category;
  final List<CategoryModel>? breadcrumbs;
  final CarSpecsData? initialData;
  final List<CustomFieldModel>? customFields;
  final bool isEdit;
  final ItemModel? item;

  const CarSpecsFormScreen({
    super.key,
    this.category,
    this.breadcrumbs,
    this.initialData,
    this.customFields,
    this.isEdit = false,
    this.item,
  });

  static Route route(RouteSettings settings) {
    Map<String, dynamic>? arguments =
        settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) => CarSpecsFormScreen(
        category: arguments?['category'] ?? arguments?['current'],
        breadcrumbs: arguments?['breadcrumbs'] ?? arguments?['breadCrumbItems'],
        initialData: arguments?['initialData'],
        customFields: arguments?['customFields'],
        isEdit: arguments?['isEdit'] ?? false,
        item: arguments?['item'],
      ),
    );
  }

  @override
  State<CarSpecsFormScreen> createState() => _CarSpecsFormScreenState();
}

class _CarSpecsFormScreenState extends State<CarSpecsFormScreen> {
  final CarsRepository _carsRepository = CarsRepository();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedEmirate = 'Dubai';
  CarMake? _selectedMake;
  CarModelItem? _selectedModel;
  CarTrim? _selectedTrim;
  List<CarMake> _makes = [];
  List<CarModelItem> _models = [];
  List<CarTrim> _trims = [];
  bool _isLoadingMakes = true;
  bool _isLoadingModels = false;
  bool _isLoadingTrims = false;
  bool _showPhoneNumber = true;
  bool _isLoadingCustomFields = false;
  List<CustomFieldModel> _remainingCustomFields = const [];
  final DynamicCustomFieldsController _adminFieldsController =
      DynamicCustomFieldsController();

  static const _emirates = [
    'Dubai',
    'Abu Dhabi',
    'Sharjah',
    'Ajman',
    'Ras Al Khaimah',
    'Fujairah',
    'Umm Al Quwain',
    'Al Ain',
  ];

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

    final initialData = widget.initialData;
    if (initialData != null) {
      _selectedEmirate = initialData.emirate;
      _selectedMake = initialData.make;
      _selectedModel = initialData.model;
      _selectedTrim = initialData.trim;
      _priceController.text =
          initialData.price > 0 ? initialData.price.toStringAsFixed(0) : "";
      if (initialData.phoneNumber.isNotEmpty) {
        _phoneController.text = initialData.phoneNumber;
      }
      _showPhoneNumber = initialData.showPhoneNumber;
    }

    final item = widget.item;
    if (item != null) {
      if (item.price != null && item.price! > 0) {
        _priceController.text = (item.price! % 1 == 0)
            ? item.price!.toInt().toString()
            : item.price.toString();
      }
      if (item.contact != null && item.contact.toString().isNotEmpty) {
        _phoneController.text = item.contact.toString();
      }
      _showPhoneNumber =
          item.hidePhoneNumber != 1 && item.hidePhoneNumber != true;
      if (item.city != null && item.city.toString().isNotEmpty) {
        _selectedEmirate = item.city.toString();
      }
    }

    final existingFields = widget.item?.customFields ?? widget.customFields;
    if (existingFields != null && existingFields.isNotEmpty) {
      _setCustomFields(existingFields);
    }
    _fetchCustomFields();
    _loadMakes();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _phoneController.dispose();
    _adminFieldsController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomFields() async {
    final categoryId = widget.category?.id ??
        widget.item?.categoryId ??
        (widget.breadcrumbs?.isNotEmpty == true
            ? widget.breadcrumbs!.last.id
            : null);
    if (categoryId == null) return;
    setState(() => _isLoadingCustomFields = true);
    try {
      final fields =
          await CustomFieldRepository().getCustomFieldsByCategoryId(categoryId);
      if (mounted) {
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
        setState(() => _setCustomFields(fields));
      }
    } finally {
      if (mounted) setState(() => _isLoadingCustomFields = false);
    }
  }

  void _setCustomFields(List<CustomFieldModel> fields) {
    final firstScreen = fields.where(_isFirstScreenCarField).toList();
    _remainingCustomFields =
        fields.where((field) => !_isFirstScreenCarField(field)).toList();
    _adminFieldsController.replaceFields(firstScreen);
  }

  bool _isFirstScreenCarField(CustomFieldModel field) {
    final label = (field.label ?? field.name ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return const {
      'regionalspecs',
      'year',
      'kilometers',
      'kilometres',
      'bodytype',
    }.contains(label);
  }

  Future<void> _loadMakes() async {
    final makes = await _carsRepository.fetchCarMakes();
    if (!mounted) return;
    setState(() {
      _makes = makes;
      final item = widget.item;
      if (item != null) {
        final targetMakeId = item.carMake;
        final targetMakeName =
            item.carMakeName?.toString().toLowerCase().trim();
        if (targetMakeId != null) {
          final match = _makes.where((m) => m.id == targetMakeId);
          if (match.isNotEmpty) _selectedMake = match.first;
        }
        if (_selectedMake == null &&
            targetMakeName != null &&
            targetMakeName.isNotEmpty) {
          final match = _makes
              .where((m) => m.name.toLowerCase().trim() == targetMakeName);
          if (match.isNotEmpty) _selectedMake = match.first;
        }
      }
      if (_selectedMake != null &&
          !_makes.any((make) => make.id == _selectedMake!.id)) {
        _makes = [_selectedMake!, ..._makes];
      }
      _isLoadingMakes = false;
    });
    if (_selectedMake != null) await _loadModels(_selectedMake!);
  }

  Future<void> _loadModels(CarMake make) async {
    setState(() => _isLoadingModels = true);
    final models =
        await _carsRepository.fetchCarModels(make.id, makeName: make.name);
    if (!mounted) return;
    setState(() {
      _models = models;
      final item = widget.item;
      if (item != null && _selectedModel == null) {
        final targetModelId = item.carModel;
        final targetModelName =
            item.carModelName?.toString().toLowerCase().trim();
        if (targetModelId != null) {
          final match = _models.where((m) => m.id == targetModelId);
          if (match.isNotEmpty) _selectedModel = match.first;
        }
        if (_selectedModel == null &&
            targetModelName != null &&
            targetModelName.isNotEmpty) {
          final match = _models
              .where((m) => m.name.toLowerCase().trim() == targetModelName);
          if (match.isNotEmpty) _selectedModel = match.first;
        }
      }
      if (_selectedModel != null &&
          !_models.any((model) => model.id == _selectedModel!.id)) {
        _models = [_selectedModel!, ..._models];
      }
      _isLoadingModels = false;
    });
    if (_selectedModel != null) await _loadTrims(_selectedModel!);
  }

  Future<void> _loadTrims(CarModelItem model) async {
    setState(() => _isLoadingTrims = true);
    final trims = await _carsRepository.fetchCarModelTrims(
      model.id,
      modelName: model.name,
    );
    if (!mounted) return;
    setState(() {
      _trims = trims;
      final item = widget.item;
      if (item != null && _selectedTrim == null) {
        final targetTrimId = item.carTrim;
        final targetTrimName =
            item.carTrimName?.toString().toLowerCase().trim();
        if (targetTrimId != null) {
          final match = _trims.where((t) => t.id == targetTrimId);
          if (match.isNotEmpty) _selectedTrim = match.first;
        }
        if (_selectedTrim == null &&
            targetTrimName != null &&
            targetTrimName.isNotEmpty) {
          final match = _trims
              .where((t) => t.name.toLowerCase().trim() == targetTrimName);
          if (match.isNotEmpty) _selectedTrim = match.first;
        }
      }
      if (_selectedTrim != null &&
          !_trims.any((trim) => trim.id == _selectedTrim!.id)) {
        _trims = [_selectedTrim!, ..._trims];
      }
      _isLoadingTrims = false;
    });
  }

  Future<void> _onMakeChanged(CarMake? make) async {
    if (make == null) return;
    setState(() {
      _selectedMake = make;
      _selectedModel = null;
      _selectedTrim = null;
      _models = [];
      _trims = [];
    });
    await _loadModels(make);
  }

  Future<void> _onModelChanged(CarModelItem? model) async {
    if (model == null) return;
    setState(() {
      _selectedModel = model;
      _selectedTrim = null;
      _trims = [];
    });
    await _loadTrims(model);
  }

  String _getBreadcrumbText() {
    if (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty) {
      return widget.breadcrumbs!.map((e) => e.name ?? '').join('  ›  ');
    }
    return widget.category?.name ?? 'Listing';
  }

  Future<void> _validateAndProceed() async {
    if (_selectedMake == null) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please select a car make",
        type: MessageType.warning,
      );
      return;
    }
    if (_selectedModel == null) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please select a car model",
        type: MessageType.warning,
      );
      return;
    }
    if (_trims.isNotEmpty && _selectedTrim == null) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please select a car trim",
        type: MessageType.warning,
      );
      return;
    }

    final price =
        double.tryParse(_priceController.text.replaceAll(',', '').trim());
    if (_priceController.text.trim().isEmpty || price == null || price <= 0) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a valid price in AED",
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

    final customFieldError = _adminFieldsController.validate();
    if (customFieldError != null) {
      HelperUtils.showSnackBarMessage(
        context,
        customFieldError,
        type: MessageType.warning,
      );
      return;
    }

    final customFields = _adminFieldsController.toSubmissionMap();
    final customFieldLabels = <String, String>{
      for (final field in _adminFieldsController.fields)
        if (field.id != null)
          field.id!.toString(): field.label ?? field.name ?? 'Field',
    };

    final specsData = CarSpecsData(
      category: widget.category,
      breadcrumbs: widget.breadcrumbs,
      emirate: _selectedEmirate,
      make: _selectedMake!,
      model: _selectedModel!,
      trim: _selectedTrim,
      price: price,
      phoneNumber: _phoneController.text.trim(),
      showPhoneNumber: _showPhoneNumber,
      customFields: customFields,
      customFieldLabels: customFieldLabels,
      remainingCustomFields: _remainingCustomFields,
      isEdit: widget.isEdit || widget.item != null,
      item: widget.item,
    );

    final wasUpdated = await Navigator.pushNamed(
      context,
      Routes.carPostingDetailsScreen,
      arguments: {
        'specsData': specsData,
      },
    );
    if (mounted && wasUpdated == true && specsData.isEdit) {
      Navigator.pop(context, true);
    }
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
                      const SizedBox(height: 14),

                      const PostingFieldLabel("Emirate *"),
                      _buildDropdown<String>(
                        value: _selectedEmirate,
                        items: _emirates,
                        itemLabel: (value) => value,
                        hint: "Select Emirate",
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedEmirate = value);
                          }
                        },
                      ),
                      const SizedBox(height: 18),

                      const PostingFieldLabel("Make *"),
                      _buildDropdown<CarMake>(
                        value: _selectedMake,
                        items: _makes,
                        itemLabel: (make) => make.name,
                        hint: _isLoadingMakes
                            ? "Loading makes..."
                            : "Select Make",
                        onChanged: _isLoadingMakes ? null : _onMakeChanged,
                      ),
                      const SizedBox(height: 18),

                      const PostingFieldLabel("Model *"),
                      _buildDropdown<CarModelItem>(
                        value: _selectedModel,
                        items: _models,
                        itemLabel: (model) => model.name,
                        hint: _isLoadingModels
                            ? "Loading models..."
                            : _selectedMake == null
                                ? "Select Make first"
                                : "Select Model",
                        onChanged: _selectedMake == null || _isLoadingModels
                            ? null
                            : _onModelChanged,
                      ),
                      const SizedBox(height: 18),

                      const PostingFieldLabel("Trim"),
                      _buildDropdown<CarTrim>(
                        value: _selectedTrim,
                        items: _trims,
                        itemLabel: (trim) => trim.name,
                        hint: _isLoadingTrims
                            ? "Loading trims..."
                            : _selectedModel == null
                                ? "Select Model first"
                                : _trims.isEmpty
                                    ? "No trims available"
                                    : "Select Trim",
                        onChanged: _selectedModel == null || _isLoadingTrims
                            ? null
                            : (value) => setState(() => _selectedTrim = value),
                      ),
                      const SizedBox(height: 18),

                      DynamicCustomFieldsForm(
                        controller: _adminFieldsController,
                        isLoading: _isLoadingCustomFields,
                      ),

                      // 9. Price
                      const PostingFieldLabel("Price *"),
                      _buildTextField(
                        controller: _priceController,
                        hint: "Price *",
                        keyboardType: TextInputType.number,
                        suffixText: "AED",
                      ),
                      const SizedBox(height: 18),

                      // 10. Phone number
                      const PostingFieldLabel("Phone number *"),
                      _buildPhoneField(context),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Show phone number on the ad"),
                        value: _showPhoneNumber,
                        onChanged: (value) =>
                            setState(() => _showPhoneNumber = value),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // 11. Bottom Next CTA Button
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
                      "Next",
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

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required String hint,
    required ValueChanged<T?>? onChanged,
  }) {
    T? effectiveValue;
    if (value != null && items.contains(value)) {
      effectiveValue = value;
    }
    return DropdownButtonFormField<T>(
      initialValue: effectiveValue,
      isExpanded: true,
      dropdownColor: context.color.secondaryColor,
      borderRadius: BorderRadius.circular(12),
      menuMaxHeight: 320,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      hint: Text(hint, overflow: TextOverflow.ellipsis),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: context.color.secondaryColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.borderColor),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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

  Widget _buildPhoneField(BuildContext context) {
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
}
