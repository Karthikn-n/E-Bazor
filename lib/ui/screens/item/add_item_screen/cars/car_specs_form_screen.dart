import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class CarSpecsFormScreen extends StatefulWidget {
  final CategoryModel? category;
  final List<CategoryModel>? breadcrumbs;
  final CarSpecsData? initialData;
  final List<CustomFieldModel>? customFields;

  const CarSpecsFormScreen({
    super.key,
    this.category,
    this.breadcrumbs,
    this.initialData,
    this.customFields,
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
      ),
    );
  }

  @override
  State<CarSpecsFormScreen> createState() => _CarSpecsFormScreenState();
}

class _CarSpecsFormScreenState extends State<CarSpecsFormScreen> {
  final CarsRepository _carsRepository = CarsRepository();

  // Controllers
  final TextEditingController _kilometersController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Selections
  String _selectedEmirate = "Dubai";
  CarMake? _selectedMake;
  CarModelItem? _selectedModel;
  CarTrim? _selectedTrim;
  String? _customTrimName;
  String _selectedRegionalSpecs = "GCC specs";
  int _selectedYear = 2025;
  String _selectedBodyType = "Sedan";

  // Data lists
  List<CarMake> _makesList = [];
  List<CarModelItem> _modelsList = [];
  List<CarTrim> _trimsList = [];

  bool _isLoadingMakes = true;
  bool _isLoadingModels = false;
  bool _isLoadingTrims = false;

  final List<String> _emirates = [
    "Dubai",
    "Abu Dhabi",
    "Sharjah",
    "Ajman",
    "Ras Al Khaimah",
    "Fujairah",
    "Umm Al Quwain",
    "Al Ain"
  ];

  final List<String> _regionalSpecsList = [
    "GCC specs",
    "American specs",
    "European specs",
    "Japanese specs",
    "Korean specs",
    "Chinese specs",
    "Other"
  ];

  final List<String> _bodyTypes = [
    "Coupe",
    "Sedan",
    "SUV",
    "Crossover",
    "Hatchback",
    "Convertible",
    "Sports Car",
    "Pickup Truck",
    "Van",
    "Other"
  ];

  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year + 1;
    _years = List.generate(currentYear - 1979, (index) => currentYear - index);

    final userPhone = HiveUtils.getUserDetails().mobile;
    _phoneController.text = (userPhone != null && userPhone.isNotEmpty)
        ? userPhone
        : "+9715056525";

    if (widget.initialData != null) {
      _populateFromInitial(widget.initialData!);
    }

    _loadMakes();
  }

  void _populateFromInitial(CarSpecsData data) {
    _selectedEmirate = data.emirate;
    _selectedMake = data.make;
    _selectedModel = data.model;
    _selectedTrim = data.trim;
    _customTrimName = data.customTrim;
    _selectedRegionalSpecs = data.regionalSpecs;
    _selectedYear = data.year;
    _selectedBodyType = data.bodyType;
    _kilometersController.text = data.kilometers > 0 ? data.kilometers.toString() : "";
    _priceController.text = data.price > 0 ? data.price.toStringAsFixed(0) : "";
    if (data.phoneNumber.isNotEmpty) {
      _phoneController.text = data.phoneNumber;
    }
  }

  @override
  void dispose() {
    _kilometersController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadMakes() async {
    setState(() => _isLoadingMakes = true);
    final list = await _carsRepository.fetchCarMakes();
    if (mounted) {
      setState(() {
        _makesList = list;
        _isLoadingMakes = false;
      });
    }
  }

  Future<void> _onMakeSelected(CarMake make) async {
    setState(() {
      _selectedMake = make;
      _selectedModel = null;
      _selectedTrim = null;
      _customTrimName = null;
      _modelsList = [];
      _trimsList = [];
      _isLoadingModels = true;
    });

    final models = await _carsRepository.fetchCarModels(make.id, makeName: make.name);
    if (mounted) {
      setState(() {
        _modelsList = models;
        _isLoadingModels = false;
      });
    }
  }

  Future<void> _onModelSelected(CarModelItem model) async {
    setState(() {
      _selectedModel = model;
      _selectedTrim = null;
      _customTrimName = null;
      _trimsList = [];
      _isLoadingTrims = true;
    });

    final trims = await _carsRepository.fetchCarModelTrims(model.id, modelName: model.name);
    if (mounted) {
      setState(() {
        _trimsList = trims;
        _isLoadingTrims = false;
      });
    }
  }

  String _getBreadcrumbText() {
    if (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty) {
      return widget.breadcrumbs!.map((e) => e.name ?? '').join('  ›  ');
    }
    final catName = widget.category?.name ?? 'Cars';
    return "Motors  ›  $catName";
  }

  void _validateAndProceed() {
    if (_selectedMake == null) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please select a Car Make",
        type: MessageType.warning,
      );
      return;
    }

    if (_selectedModel == null) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please select a Car Model",
        type: MessageType.warning,
      );
      return;
    }

    final km = int.tryParse(_kilometersController.text.replaceAll(',', '').trim());
    if (_kilometersController.text.trim().isEmpty || km == null || km < 0) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter vehicle mileage (Kilometers)",
        type: MessageType.warning,
      );
      return;
    }

    final price = double.tryParse(_priceController.text.replaceAll(',', '').trim());
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

    final specsData = CarSpecsData(
      category: widget.category,
      breadcrumbs: widget.breadcrumbs,
      emirate: _selectedEmirate,
      make: _selectedMake,
      model: _selectedModel,
      trim: _selectedTrim,
      customTrim: _customTrimName ?? (_selectedTrim?.name ?? "Base"),
      regionalSpecs: _selectedRegionalSpecs,
      year: _selectedYear,
      kilometers: km,
      bodyType: _selectedBodyType,
      price: price,
      phoneNumber: _phoneController.text.trim(),
    );

    Navigator.pushNamed(
      context,
      Routes.carPostingDetailsScreen,
      arguments: {
        'specsData': specsData,
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
                          "Tell us about your car",
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
                            Icons.directions_car_outlined,
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

                      // 1. Emirate
                      _buildFieldLabel("Emirate *"),
                      _buildDropdownTile(
                        title: _selectedEmirate,
                        onTap: () => _showPickerModal(
                          title: "Select Emirate",
                          items: _emirates,
                          selected: _selectedEmirate,
                          onSelect: (val) => setState(() => _selectedEmirate = val),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 2. Make
                      _buildFieldLabel("Make *"),
                      _buildDropdownTile(
                        title: _selectedMake?.name ?? "Select Make",
                        isLoading: _isLoadingMakes,
                        onTap: () => _showSearchablePickerModal<CarMake>(
                          title: "Select Make",
                          items: _makesList,
                          selectedItem: _selectedMake,
                          itemLabel: (m) => m.name,
                          onSelect: _onMakeSelected,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3. Model
                      _buildFieldLabel("Model *"),
                      _buildDropdownTile(
                        title: _selectedModel?.name ??
                            (_selectedMake == null
                                ? "Select Make first"
                                : "Select Model"),
                        isLoading: _isLoadingModels,
                        enabled: _selectedMake != null,
                        onTap: () {
                          if (_selectedMake == null) {
                            HelperUtils.showSnackBarMessage(
                              context,
                              "Please select a Make first",
                              type: MessageType.warning,
                            );
                            return;
                          }
                          _showSearchablePickerModal<CarModelItem>(
                            title: "Select Model",
                            items: _modelsList,
                            selectedItem: _selectedModel,
                            itemLabel: (m) => m.name,
                            onSelect: _onModelSelected,
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // 4. Trim
                      _buildFieldLabel("Trim *"),
                      _buildDropdownTile(
                        title: _selectedTrim?.name ??
                            _customTrimName ??
                            (_selectedModel == null
                                ? "Select Model first"
                                : "Select Trim"),
                        isLoading: _isLoadingTrims,
                        enabled: _selectedModel != null,
                        onTap: () {
                          if (_selectedModel == null) {
                            HelperUtils.showSnackBarMessage(
                              context,
                              "Please select a Model first",
                              type: MessageType.warning,
                            );
                            return;
                          }
                          _showTrimPickerModal();
                        },
                      ),
                      const SizedBox(height: 18),

                      // 5. Regional Specs
                      _buildFieldLabel("Regional Specs *"),
                      _buildDropdownTile(
                        title: _selectedRegionalSpecs,
                        onTap: () => _showPickerModal(
                          title: "Select Regional Specs",
                          items: _regionalSpecsList,
                          selected: _selectedRegionalSpecs,
                          onSelect: (val) =>
                              setState(() => _selectedRegionalSpecs = val),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 6. Year
                      _buildFieldLabel("Year *"),
                      _buildDropdownTile(
                        title: _selectedYear.toString(),
                        onTap: () => _showPickerModal(
                          title: "Select Manufacturing Year",
                          items: _years.map((e) => e.toString()).toList(),
                          selected: _selectedYear.toString(),
                          onSelect: (val) => setState(
                              () => _selectedYear = int.tryParse(val) ?? 2025),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 7. Kilometers
                      _buildFieldLabel("Kilometers *"),
                      _buildTextField(
                        controller: _kilometersController,
                        hint: "Kilometers *",
                        keyboardType: TextInputType.number,
                        suffixText: "km",
                      ),
                      const SizedBox(height: 18),

                      // 8. Body type
                      _buildFieldLabel("Body type *"),
                      _buildDropdownTile(
                        title: _selectedBodyType,
                        onTap: () => _showPickerModal(
                          title: "Select Body Type",
                          items: _bodyTypes,
                          selected: _selectedBodyType,
                          onSelect: (val) =>
                              setState(() => _selectedBodyType = val),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 9. Price
                      _buildFieldLabel("Price *"),
                      _buildTextField(
                        controller: _priceController,
                        hint: "Price *",
                        keyboardType: TextInputType.number,
                        suffixText: "AED",
                      ),
                      const SizedBox(height: 18),

                      // 10. Phone number
                      _buildFieldLabel("Phone number *"),
                      _buildPhoneField(context),
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
                      backgroundColor: const Color(0xFFD31027), // Red CTA matching web screenshot
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Next: Vehicle Details",
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

  Widget _buildDropdownTile({
    required String title,
    required VoidCallback onTap,
    bool isLoading = false,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: enabled
              ? context.color.secondaryColor
              : context.color.secondaryColor.withValues(alpha: 0.5),
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
                  color: enabled
                      ? context.color.textDefaultColor
                      : context.color.textLightColor,
                ),
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
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

  void _showSearchablePickerModal<T>({
    required String title,
    required List<T> items,
    required T? selectedItem,
    required String Function(T) itemLabel,
    required ValueChanged<T> onSelect,
  }) {
    final searchCtrl = TextEditingController();
    List<T> filteredItems = List.from(items);

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
                height: MediaQuery.of(context).size.height * 0.75,
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
                    TextField(
                      controller: searchCtrl,
                      onChanged: (query) {
                        setModalState(() {
                          filteredItems = items
                              .where((element) => itemLabel(element)
                                  .toLowerCase()
                                  .contains(query.toLowerCase()))
                              .toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: context.color.secondaryColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.color.borderColor
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Text(
                                "No results found",
                                style: TextStyle(
                                  color: context.color.textLightColor,
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: context.color.borderColor
                                    .withValues(alpha: 0.3),
                              ),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final isSelected = selectedItem == item;
                                return ListTile(
                                  onTap: () {
                                    onSelect(item);
                                    Navigator.pop(modalContext);
                                  },
                                  title: Text(
                                    itemLabel(item),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
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
      },
    );
  }

  void _showTrimPickerModal() {
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
                      "Select Trim",
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
                    itemCount: _trimsList.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: context.color.borderColor.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final trim = _trimsList[index];
                      final isSelected = _selectedTrim?.id == trim.id;
                      return ListTile(
                        onTap: () {
                          setState(() {
                            _selectedTrim = trim;
                            _customTrimName = null;
                          });
                          Navigator.pop(modalContext);
                        },
                        title: Text(
                          trim.name,
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
}
