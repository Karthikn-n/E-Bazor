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
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/ad_creation_stepper.dart';

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
  final TextEditingController _mileageController = TextEditingController();

  String _selectedEmirate = 'Dushanbe';
  CarMake? _selectedMake;
  CarModelItem? _selectedModel;
  CarTrim? _selectedTrim;
  List<CarMake> _makes = [];
  List<CarModelItem> _models = [];
  List<CarTrim> _trims = [];
  bool _isLoadingMakes = true;
  bool _isLoadingModels = false;
  bool _showPhoneNumber = true;
  bool _isLoadingCustomFields = false;
  List<CustomFieldModel> _remainingCustomFields = const [];
  final DynamicCustomFieldsController _adminFieldsController =
      DynamicCustomFieldsController();

  // Specs attributes
  String? _selectedYear;
  String _selectedCondition = 'Used';
  String? _selectedBodyType = 'SUV';
  String? _selectedFuelType = 'Petrol';
  String? _selectedTransmission = 'Automatic';
  String? _selectedDriveType = '4WD';

  @override
  void initState() {
    super.initState();
    final savedCity = HiveUtils.getCityName()?.toString().trim() ?? '';
    if (savedCity.isNotEmpty) {
      _selectedEmirate = savedCity;
    }

    final savedCode = HiveUtils.getCountryCode();
    final countryCode = savedCode != null && savedCode.isNotEmpty
        ? (savedCode.startsWith('+') ? savedCode : '+$savedCode')
        : '+992';
    final user = HiveUtils.getUserDetails();
    final userMobile = user.mobile?.trim() ?? '';

    if (userMobile.isNotEmpty) {
      if (userMobile.startsWith('+')) {
        _phoneController.text = userMobile;
      } else {
        _phoneController.text = '$countryCode $userMobile';
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
      if (initialData.year != null && initialData.year!.isNotEmpty) {
        _selectedYear = initialData.year;
      }
      if (initialData.mileage != null && initialData.mileage!.isNotEmpty) {
        _mileageController.text = initialData.mileage!;
      }
      if (initialData.condition != null && initialData.condition!.isNotEmpty) {
        _selectedCondition = initialData.condition!;
      }
      if (initialData.bodyType != null && initialData.bodyType!.isNotEmpty) {
        _selectedBodyType = initialData.bodyType;
      }
      if (initialData.fuelType != null && initialData.fuelType!.isNotEmpty) {
        _selectedFuelType = initialData.fuelType;
      }
      if (initialData.transmission != null && initialData.transmission!.isNotEmpty) {
        _selectedTransmission = initialData.transmission;
      }
      if (initialData.driveType != null && initialData.driveType!.isNotEmpty) {
        _selectedDriveType = initialData.driveType;
      }
      _priceController.text =
          initialData.price > 0 ? initialData.price.toStringAsFixed(0) : "185000";
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
    _mileageController.dispose();
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
    if (const {'year', 'kilometers', 'kilometres', 'mileage', 'bodytype', 'make', 'model'}.contains(label)) return false;
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
      if (false) {
        final toyota = _makes.firstWhere(
          (m) => m.name.toLowerCase() == 'toyota',
          orElse: () => _makes.first,
        );
        _selectedMake = toyota;
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
      if (false) {
        final lc = _models.firstWhere(
          (m) => m.name.toLowerCase().contains('land cruiser'),
          orElse: () => _models.first,
        );
        _selectedModel = lc;
      }
      _isLoadingModels = false;
    });
    if (_selectedModel != null) await _loadTrims(_selectedModel!);
  }

  Future<void> _loadTrims(CarModelItem model) async {
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

  void _saveDraftAndExit() {
    HelperUtils.showSnackBarMessage(
      context,
      "Draft saved successfully",
      type: MessageType.success,
    );
    Navigator.pop(context);
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

    final price = double.tryParse(_priceController.text.replaceAll(',', '').trim()) ?? 185000.0;
    final contactDigits = _phoneController.text.replaceAll(RegExp(r'[^0-9+]'), '');

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
      phoneNumber: contactDigits.isNotEmpty ? contactDigits : "+992900000000",
      showPhoneNumber: _showPhoneNumber,
      customFields: customFields,
      customFieldLabels: customFieldLabels,
      remainingCustomFields: _remainingCustomFields,
      isEdit: widget.isEdit || widget.item != null,
      item: widget.item,
      year: _selectedYear ?? '2022',
      mileage: _mileageController.text.trim().isNotEmpty ? _mileageController.text.trim() : '48,000',
      condition: _selectedCondition,
      bodyType: _selectedBodyType ?? 'SUV',
      fuelType: _selectedFuelType ?? 'Petrol',
      transmission: _selectedTransmission ?? 'Automatic',
      driveType: _selectedDriveType ?? '4WD',
      isNegotiable: true,
    );

    final editResult = await Navigator.pushNamed(
      context,
      Routes.carPostingDetailsScreen,
      arguments: {
        'specsData': specsData,
      },
    );
    if (mounted && editResult is ItemModel && specsData.isEdit) {
      Navigator.pop(context, editResult);
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
          appBar: AppBar(
            backgroundColor: context.color.secondaryColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: context.color.textDefaultColor,
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              "Post a vehicle",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.color.textDefaultColor,
              ),
            ),
            actions: [
              TextButton(
                onPressed: _saveDraftAndExit,
                child: const Text(
                  "Save & exit",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              const AdCreationStepper(currentStep: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_done_outlined,
                    size: 15,
                    color: context.color.textLightColor.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "Auto-saved just now",
                    style: TextStyle(
                      fontSize: 12,
                      color: context.color.textLightColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Title
                      Text(
                        "Tell us about your car",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Basic information
                      Text(
                        "Basic information",
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Row 1: Make & Model
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridDropdown<CarMake>(
                              icon: Icons.directions_car_outlined,
                              value: _selectedMake,
                              items: _makes,
                              itemLabel: (m) => m.name,
                              hint: _isLoadingMakes ? "Loading..." : "Make",
                              onChanged: _isLoadingMakes ? null : _onMakeChanged,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGridDropdown<CarModelItem>(
                              icon: null,
                              value: _selectedModel,
                              items: _models,
                              itemLabel: (m) => m.name,
                              hint: _isLoadingModels
                                  ? "Loading..."
                                  : (_selectedMake == null ? "Select Make" : "Model"),
                              onChanged: _selectedMake == null || _isLoadingModels
                                  ? null
                                  : _onModelChanged,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Row 2: Year & Mileage
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridDropdown<String>(
                              icon: Icons.calendar_today_outlined,
                              value: _selectedYear,
                              items: List.generate(
                                  35,
                                  (i) => (DateTime.now().year + 1 - i).toString()),
                              itemLabel: (y) => y,
                              hint: "Year",
                              onChanged: (y) {
                                if (y != null) setState(() => _selectedYear = y);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGridInputField(
                              icon: Icons.speed_outlined,
                              controller: _mileageController,
                              hint: "Mileage",
                              suffixText: "km",
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Condition
                      Text(
                        "Condition",
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: ['New', 'Used', 'Like new'].map((cond) {
                          final isSelected = _selectedCondition == cond;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  setState(() => _selectedCondition = cond);
                                },
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF007AFF)
                                        : context.color.secondaryColor,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF007AFF)
                                          : const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      cond,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : context.color.textDefaultColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),

                      // More details
                      Text(
                        "More details",
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Row 1: Body type & Fuel type
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridDropdown<String>(
                              icon: Icons.directions_car_filled_outlined,
                              value: _selectedBodyType,
                              items: const [
                                'SUV',
                                'Sedan',
                                'Hatchback',
                                'Pickup',
                                'Coupe',
                                'Convertible',
                                'Van',
                                'Wagon',
                                'Other'
                              ],
                              itemLabel: (b) => b,
                              hint: "Body type",
                              onChanged: (b) {
                                if (b != null) setState(() => _selectedBodyType = b);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGridDropdown<String>(
                              icon: Icons.local_gas_station_outlined,
                              value: _selectedFuelType,
                              items: const [
                                'Petrol',
                                'Diesel',
                                'Hybrid',
                                'Electric'
                              ],
                              itemLabel: (f) => f,
                              hint: "Fuel type",
                              onChanged: (f) {
                                if (f != null) setState(() => _selectedFuelType = f);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Row 2: Transmission & Drive type
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridDropdown<String>(
                              icon: Icons.settings_outlined,
                              value: _selectedTransmission,
                              items: const ['Automatic', 'Manual'],
                              itemLabel: (t) => t,
                              hint: "Transmission",
                              onChanged: (t) {
                                if (t != null) {
                                  setState(() => _selectedTransmission = t);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGridDropdown<String>(
                              icon: Icons.swap_calls_rounded,
                              value: _selectedDriveType,
                              items: const ['4WD', 'AWD', 'FWD', 'RWD'],
                              itemLabel: (d) => d,
                              hint: "Drive type",
                              onChanged: (d) {
                                if (d != null) {
                                  setState(() => _selectedDriveType = d);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      if (_remainingCustomFields.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        DynamicCustomFieldsForm(
                          controller: _adminFieldsController,
                          isLoading: _isLoadingCustomFields,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Continue Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  border: Border(
                    top: BorderSide(
                      color: context.color.borderColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _validateAndProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
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

  Widget _buildGridDropdown<T>({
    IconData? icon,
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
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: effectiveValue,
                isExpanded: true,
                dropdownColor: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(12),
                menuMaxHeight: 300,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                hint: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                items: items
                    .map(
                      (item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(
                          itemLabel(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridInputField({
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    String? suffixText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.color.textDefaultColor,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
                suffixText: suffixText,
                suffixStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
