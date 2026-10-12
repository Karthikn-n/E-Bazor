// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/custom_field/fetch_custom_fields_cubit.dart';
import 'package:Ebozor/data/cubits/system/location_change_cubit.dart';
import 'package:Ebozor/data/model/cars/car_models.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';
import 'package:Ebozor/data/repositories/cars_repository.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/dynamic_field/dynamic_field.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';

class FilterScreen extends StatefulWidget {
  final Function update;
  final String from;
  final List<String>? categoryIds;
  final List<CategoryModel>? categoryList;

  const FilterScreen({
    super.key,
    required this.update,
    required this.from,
    this.categoryIds,
    this.categoryList,
  });

  @override
  FilterScreenState createState() => FilterScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => BlocProvider(
        create: (context) => FetchCustomFieldsCubit(),
        child: FilterScreen(
          update: arguments?['update'] ?? (_) {},
          from: arguments?['from'] ?? '',
          categoryIds: arguments?['categoryIds'] ?? [],
          categoryList: arguments?['categoryList'] ?? [],
        ),
      ),
    );
  }
}

class FilterScreenState extends State<FilterScreen> {
  // Categories
  List<String> selectedCategories = [];
  late List<CategoryModel> categoryList = widget.categoryList ?? [];

  // Controllers for Price
  final TextEditingController minController = TextEditingController();
  final TextEditingController maxController = TextEditingController();

  // Price Slider state
  static const double _maxPriceLimit = 2000000;
  RangeValues _priceRangeValues = const RangeValues(0, _maxPriceLimit);

  // Automotive: Make & Model
  final CarsRepository _carsRepository = CarsRepository();
  List<CarMake> _carMakes = [];
  List<CarModelItem> _carModels = [];
  CarMake? selectedCarMake;
  CarModelItem? selectedCarModel;
  bool _isLoadingMakes = false;
  bool _isLoadingModels = false;

  // Year & Mileage
  String? minYear;
  String? maxYear;
  String? minMileage;
  String? maxMileage;

  // Segmented Pill Filters
  String selectedTransmission = 'Any';
  String selectedBodyType = 'Any';
  String selectedCondition = 'Any';
  String selectedSellerType = 'Any';

  // Location fields
  String city = "";
  String area = "";
  int? areaId;
  int? radius;
  String _state = "";
  String country = "";
  double? latitude;
  double? longitude;

  // Posted Since
  String postedOn = Constant.postedSince[0].value;

  // Dynamic Custom Fields
  List<CustomFieldBuilder> moreDetailDynamicFields = [];

  // Live Result Count
  int _resultCount = 0;
  bool _isLoadingCount = false;
  Timer? _countDebounceTimer;
  int _countRequestId = 0;

  static const Color _brandBlue = Color(0xFF007AFF);

  bool get isMotorsCategory {
    if (selectedCategories.isEmpty) return false;
    if (selectedCategories.contains("1")) return true;
    for (var cat in categoryList) {
      final name = (cat.name ?? "").toLowerCase();
      final slug = (cat.slug ?? "").toLowerCase();
      if (name.contains("car") ||
          name.contains("motor") ||
          name.contains("auto") ||
          slug.contains("car") ||
          slug.contains("motor") ||
          slug.contains("auto")) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _initCategories();
    _initValuesFromFilter();
    _fetchCustomFields();
    if (isMotorsCategory) {
      _loadCarMakes();
    }
    _fetchItemCount();
  }

  @override
  void dispose() {
    _countDebounceTimer?.cancel();
    minController.dispose();
    maxController.dispose();
    super.dispose();
  }

  void _initCategories() {
    if (widget.categoryIds != null && widget.categoryIds!.isNotEmpty) {
      selectedCategories.addAll(widget.categoryIds!);
    }
    if (widget.categoryList != null && widget.categoryList!.isNotEmpty) {
      for (var cat in widget.categoryList!) {
        final idStr = cat.id?.toString();
        if (idStr != null && !selectedCategories.contains(idStr)) {
          selectedCategories.add(idStr);
        }
      }
    }
  }

  void _initValuesFromFilter() {
    final existingFilter = Constant.itemFilter;
    if (existingFilter != null) {
      minController.text = existingFilter.minPrice ?? "";
      maxController.text = existingFilter.maxPrice ?? "";
      city = existingFilter.city ?? "";
      area = existingFilter.area ?? "";
      areaId = existingFilter.areaId;
      radius = existingFilter.radius;
      _state = existingFilter.state ?? "";
      country = existingFilter.country ?? "";
      latitude = existingFilter.latitude;
      longitude = existingFilter.longitude;
      postedOn = existingFilter.postedSince ?? Constant.postedSince[0].value;

      double min = double.tryParse(minController.text.replaceAll(',', '')) ?? 0;
      double max =
          double.tryParse(maxController.text.replaceAll(',', '')) ?? _maxPriceLimit;
      if (max < min) max = min;
      if (max > _maxPriceLimit) max = _maxPriceLimit;
      _priceRangeValues = RangeValues(min, max);

      // Restore custom field selections if present
      if (existingFilter.customFields != null) {
        final cf = existingFilter.customFields!;
        if (cf.containsKey('car_make_name')) {
          selectedCarMake = CarMake(
            id: int.tryParse(cf['car_make']?.toString() ?? '0') ?? 0,
            name: cf['car_make_name']?.toString() ?? '',
          );
        }
        if (cf.containsKey('car_model_name')) {
          selectedCarModel = CarModelItem(
            id: int.tryParse(cf['car_model']?.toString() ?? '0') ?? 0,
            name: cf['car_model_name']?.toString() ?? '',
          );
        }
        if (cf.containsKey('min_year')) minYear = cf['min_year']?.toString();
        if (cf.containsKey('max_year')) maxYear = cf['max_year']?.toString();
        if (cf.containsKey('min_mileage')) minMileage = cf['min_mileage']?.toString();
        if (cf.containsKey('max_mileage')) maxMileage = cf['max_mileage']?.toString();
        if (cf.containsKey('transmission')) {
          selectedTransmission = cf['transmission']?.toString() ?? 'Any';
        }
        if (cf.containsKey('body_type')) {
          selectedBodyType = cf['body_type']?.toString() ?? 'Any';
        }
        if (cf.containsKey('condition')) {
          selectedCondition = cf['condition']?.toString() ?? 'Any';
        }
        if (cf.containsKey('seller_type')) {
          selectedSellerType = cf['seller_type']?.toString() ?? 'Any';
        }
      }
    } else {
      city = HiveUtils.getCityName() ?? "";
      areaId = HiveUtils.getAreaId() != null
          ? int.tryParse(HiveUtils.getAreaId().toString())
          : null;
      area = HiveUtils.getAreaName() ?? "";
      _state = HiveUtils.getStateName() ?? "";
      country = HiveUtils.getCountryName() ?? "";
      latitude = HiveUtils.getLatitude();
      longitude = HiveUtils.getLongitude();
    }
  }

  void _fetchCustomFields() {
    if (Constant.itemFilter == null) {
      AbstractField.fieldsData.clear();
    }
    if (selectedCategories.isNotEmpty) {
      context.read<FetchCustomFieldsCubit>().fetchCustomFields(
            categoryIds: selectedCategories.join(','),
          );
    }
  }

  Future<void> _loadCarMakes() async {
    if (_carMakes.isNotEmpty) return;
    setState(() => _isLoadingMakes = true);
    try {
      final list = await _carsRepository.fetchCarMakes();
      if (mounted) {
        setState(() {
          _carMakes = list;
          _isLoadingMakes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMakes = false);
    }
  }

  Future<void> _loadCarModels(int makeId) async {
    setState(() {
      _isLoadingModels = true;
      _carModels = [];
      selectedCarModel = null;
    });
    try {
      final list = await _carsRepository.fetchCarModels(makeId);
      if (mounted) {
        setState(() {
          _carModels = list;
          _isLoadingModels = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingModels = false);
    }
  }

  void _fetchItemCount() {
    _countDebounceTimer?.cancel();
    final requestId = ++_countRequestId;
    _countDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isLoadingCount = true;
      });

      try {
        final queryParams = <String, dynamic>{
          "page": 1,
          "sort_by": "new-to-old",
        };

        final minPriceVal = minController.text.trim();
        final maxPriceVal = maxController.text.trim();
        if (minPriceVal.isNotEmpty && minPriceVal != '0') {
          queryParams["min_price"] = minPriceVal;
        }
        if (maxPriceVal.isNotEmpty) {
          queryParams["max_price"] = maxPriceVal;
        }
        if (city.isNotEmpty) {
          queryParams["city"] = city;
        } else if (HiveUtils.getCityName() != null &&
            HiveUtils.getCityName()!.isNotEmpty) {
          queryParams["city"] = HiveUtils.getCityName();
        }
        if (_state.isNotEmpty) queryParams["state"] = _state;
        if (country.isNotEmpty) queryParams["country"] = country;
        if (areaId != null) queryParams["area_id"] = areaId;
        if (radius != null) queryParams["radius"] = radius;
        if (latitude != null) queryParams["latitude"] = latitude;
        if (longitude != null) queryParams["longitude"] = longitude;

        if (selectedCategories.isNotEmpty) {
          queryParams["category_id"] = selectedCategories.last;
        }
        if (selectedCarMake != null) {
          queryParams["car_make"] = selectedCarMake!.id;
        }
        if (selectedCarModel != null) {
          queryParams["car_model"] = selectedCarModel!.id;
        }

        // Custom fields parameters
        AbstractField.fieldsData.forEach((key, val) {
          if (val != null) {
            if (val is List && val.isNotEmpty) {
              queryParams["filters[$key]"] = jsonEncode(val);
            } else if (val is String && val.isNotEmpty) {
              queryParams["filters[$key]"] = val;
            }
          }
        });

        final response = await Api.get(
          url: Api.getItemCountApi,
          queryParameters: queryParams,
        );

        if (mounted && requestId == _countRequestId) {
          final data = response['data'];
          final rawCount = data is Map
              ? (data['count'] ?? data['total'])
              : (response['count'] ?? response['total']);
          final total = int.tryParse(rawCount?.toString() ?? '') ?? 0;

          setState(() {
            _resultCount = total;
            _isLoadingCount = false;
          });
        }
      } catch (_) {
        if (mounted && requestId == _countRequestId) {
          setState(() {
            _isLoadingCount = false;
          });
        }
      }
    });
  }

  void _resetAllFilters() {
    setState(() {
      postedOn = Constant.postedSince[0].value;
      Constant.itemFilter = null;
      selectedCarMake = null;
      selectedCarModel = null;
      _carModels = [];
      minYear = null;
      maxYear = null;
      minMileage = null;
      maxMileage = null;
      selectedTransmission = 'Any';
      selectedBodyType = 'Any';
      selectedCondition = 'Any';
      selectedSellerType = 'Any';

      minController.clear();
      maxController.clear();
      _priceRangeValues = const RangeValues(0, _maxPriceLimit);

      AbstractField.fieldsData.clear();
      AbstractField.files.clear();
      moreDetailDynamicFields.clear();
    });
    _fetchItemCount();
  }

  void _onTapChooseLocation() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Navigator.pushNamed(
      context,
      Routes.citiesScreen,
      arguments: {"from": "filter"},
    );

    if (result != null) {
      Map<String, dynamic> location = result as Map<String, dynamic>;
      if (location['clear'] == true) {
        setState(() {
          area = '';
          city = '';
          areaId = null;
          radius = null;
          country = '';
          _state = '';
          latitude = null;
          longitude = null;
        });
        context.read<LocationChangeCubit>().clearLocation();
      } else {
        final newCity = location["city"]?.toString() ?? "";
        final newArea = location["area"]?.toString() ?? "";
        final newAreaId = location["area_id"] != null
            ? int.tryParse(location["area_id"].toString())
            : null;
        final newLat = location["latitude"] != null
            ? double.tryParse(location["latitude"].toString())
            : null;
        final newLong = location["longitude"] != null
            ? double.tryParse(location["longitude"].toString())
            : null;
        final newCountry = location["country"]?.toString() ?? "";
        final newState = location["state"]?.toString() ?? "";

        setState(() {
          city = newCity;
          area = newArea;
          areaId = newAreaId;
          country = newCountry;
          _state = newState;
          latitude = newLat;
          longitude = newLong;
        });

        context.read<LocationChangeCubit>().setLocation(
              city: newCity,
              state: newState,
              country: newCountry,
              area: newArea,
              areaId: newAreaId,
              latitude: newLat,
              longitude: newLong,
            );
      }
      _fetchItemCount();
    }
  }

  void _applyFilterAndExit() {
    Map<String, dynamic> customFields = {};
    AbstractField.fieldsData.forEach((key, val) {
      customFields['custom_fields[$key]'] = val;
    });

    if (selectedCarMake != null) {
      customFields['car_make'] = selectedCarMake!.id;
      customFields['car_make_name'] = selectedCarMake!.name;
    }
    if (selectedCarModel != null) {
      customFields['car_model'] = selectedCarModel!.id;
      customFields['car_model_name'] = selectedCarModel!.name;
    }
    if (minYear != null && minYear != 'Any') customFields['min_year'] = minYear;
    if (maxYear != null && maxYear != 'Any') customFields['max_year'] = maxYear;
    if (minMileage != null && minMileage != 'Any') {
      customFields['min_mileage'] = minMileage;
    }
    if (maxMileage != null && maxMileage != 'Any') {
      customFields['max_mileage'] = maxMileage;
    }
    if (selectedTransmission != 'Any') {
      customFields['transmission'] = selectedTransmission;
    }
    if (selectedBodyType != 'Any') {
      customFields['body_type'] = selectedBodyType;
    }
    if (selectedCondition != 'Any') {
      customFields['condition'] = selectedCondition;
    }
    if (selectedSellerType != 'Any') {
      customFields['seller_type'] = selectedSellerType;
    }

    final appliedFilter = ItemFilterModel(
      maxPrice: maxController.text.trim().isNotEmpty ? maxController.text.trim() : null,
      minPrice: minController.text.trim().isNotEmpty ? minController.text.trim() : null,
      categoryId: selectedCategories.isNotEmpty ? selectedCategories.last : "",
      categorySlug: categoryList.isNotEmpty ? categoryList.last.slug : null,
      postedSince: postedOn,
      city: city,
      area: area,
      areaId: areaId,
      radius: radius,
      state: _state,
      country: country,
      latitude: latitude,
      longitude: longitude,
      customFields: customFields,
    );

    Constant.itemFilter = appliedFilter;
    widget.update(appliedFilter);
    Navigator.pop(context, true);
  }

  String _formatPriceNumber(double value) {
    final rounded = value.round();
    final str = rounded.toString();
    final formatted = str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted ${Constant.currencySymbol}';
  }

  // --- Searchable Modals ---

  void _showMakePicker() {
    if (_carMakes.isEmpty && _isLoadingMakes) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _carMakes
                .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Make',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (selectedCarMake != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                selectedCarMake = null;
                                selectedCarModel = null;
                                _carModels = [];
                              });
                              Navigator.pop(ctx);
                              _fetchItemCount();
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: _brandBlue),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: TextField(
                      onChanged: (val) => setModalState(() => query = val),
                      decoration: InputDecoration(
                        hintText: 'Search make...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: context.color.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final make = filtered[index];
                        final isSelected = selectedCarMake?.id == make.id;
                        return ListTile(
                          title: Text(
                            make.name,
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? _brandBlue
                                  : context.color.textDefaultColor,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: _brandBlue, size: 20)
                              : null,
                          onTap: () {
                            setState(() {
                              selectedCarMake = make;
                              selectedCarModel = null;
                            });
                            Navigator.pop(ctx);
                            _loadCarModels(make.id);
                            _fetchItemCount();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showModelPicker() {
    if (selectedCarMake == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Make first')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = "";
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _carModels
                .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedCarMake!.name} Models',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (selectedCarModel != null)
                          TextButton(
                            onPressed: () {
                              setState(() => selectedCarModel = null);
                              Navigator.pop(ctx);
                              _fetchItemCount();
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: _brandBlue),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: TextField(
                      onChanged: (val) => setModalState(() => query = val),
                      decoration: InputDecoration(
                        hintText: 'Search model...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: context.color.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoadingModels
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _brandBlue,
                            ),
                          )
                        : filtered.isEmpty
                            ? const Center(child: Text('No models found'))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(
                                    height: 1, color: Colors.grey.shade100),
                                itemBuilder: (context, index) {
                                  final model = filtered[index];
                                  final isSelected = selectedCarModel?.id == model.id;
                                  return ListTile(
                                    title: Text(
                                      model.name,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? _brandBlue
                                            : context.color.textDefaultColor,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: _brandBlue,
                                            size: 20)
                                        : null,
                                    onTap: () {
                                      setState(() => selectedCarModel = model);
                                      Navigator.pop(ctx);
                                      _fetchItemCount();
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSingleChoicePicker({
    required String title,
    required List<String> items,
    required String? currentVal,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = (currentVal == item) ||
                          (currentVal == null && item == 'Any');
                      return ListTile(
                        title: Text(
                          item,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? _brandBlue
                                : context.color.textDefaultColor,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: _brandBlue, size: 20)
                            : null,
                        onTap: () {
                          onSelected(item);
                          Navigator.pop(ctx);
                          _fetchItemCount();
                        },
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationChangeCubit, LocationChangeState>(
      listener: (context, locState) {
        if (locState.city != null && locState.city != city) {
          setState(() {
            city = locState.city ?? "";
            _state = locState.state ?? "";
            country = locState.country ?? "";
            area = locState.area ?? "";
            areaId = locState.areaId;
            latitude = locState.latitude;
            longitude = locState.longitude;
          });
          _fetchItemCount();
        }
      },
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: _buildTopAppBar(),
        bottomNavigationBar: _buildBottomStickyBar(),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHierarchyCard(),
              const SizedBox(height: 12),
              _buildPriceCard(),
              if (isMotorsCategory) ...[
                const SizedBox(height: 12),
                _buildYearCard(),
                const SizedBox(height: 12),
                _buildMileageCard(),
              ],
              const SizedBox(height: 12),
              _buildLocationCard(),
              _buildDynamicCustomFieldsSection(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      backgroundColor: context.color.secondaryColor,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: Icon(
          Icons.close_rounded,
          color: context.color.textDefaultColor,
          size: 24,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        'Advanced filters',
        style: TextStyle(
          color: context.color.textDefaultColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetAllFilters,
          child: const Text(
            'Reset',
            style: TextStyle(
              color: _brandBlue,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHierarchyCard() {
    final catName = categoryList.isNotEmpty
        ? categoryList.map((e) => e.name).join(' > ')
        : 'All Categories';

    return _buildCardContainer(
      child: Column(
        children: [
          // Category Row
          _buildRowSelector(
            icon: isMotorsCategory
                ? Icons.directions_car_outlined
                : Icons.grid_view_rounded,
            title: 'Category',
            value: catName,
            onTap: () {
              categoryList.clear();
              Navigator.pushNamed(
                context,
                Routes.categoryFilterScreen,
                arguments: {"categoryList": categoryList},
              ).then((_) {
                if (categoryList.isNotEmpty) {
                  setState(() {
                    selectedCategories.clear();
                    selectedCategories.addAll(
                      categoryList.map<String>((e) => e.id.toString()).toList(),
                    );
                  });
                  _fetchCustomFields();
                  if (isMotorsCategory) {
                    _loadCarMakes();
                  }
                  _fetchItemCount();
                }
              });
            },
          ),
          if (isMotorsCategory) ...[
            Divider(height: 24, color: Colors.grey.shade100),
            // Make Row
            _buildRowSelector(
              icon: Icons.album_outlined,
              title: 'Make',
              value: selectedCarMake?.name ?? 'Any',
              onTap: _showMakePicker,
            ),
            Divider(height: 24, color: Colors.grey.shade100),
            // Model Row
            _buildRowSelector(
              icon: Icons.directions_car_filled_outlined,
              title: 'Model',
              value: selectedCarModel?.name ?? 'Any',
              onTap: _showModelPicker,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRowSelector({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _brandBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _brandBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.color.textDefaultColor,
              ),
            ),
            const Spacer(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.45,
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _brandBlue,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.color.textLightColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _brandBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: _brandBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Price (${Constant.currencySymbol})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Price Range Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatPriceNumber(_priceRangeValues.start),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.color.textDefaultColor,
                ),
              ),
              Text(
                _formatPriceNumber(_priceRangeValues.end),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Range Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _brandBlue,
              inactiveTrackColor: _brandBlue.withValues(alpha: 0.15),
              trackHeight: 4.0,
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 10,
                elevation: 3,
              ),
              overlayColor: _brandBlue.withValues(alpha: 0.2),
            ),
            child: RangeSlider(
              values: _priceRangeValues,
              min: 0,
              max: _maxPriceLimit,
              divisions: 200,
              onChanged: (RangeValues values) {
                setState(() {
                  _priceRangeValues = values;
                  minController.text = values.start.round().toString();
                  maxController.text = values.end.round().toString();
                });
                _fetchItemCount();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearCard() {
    final currentYear = DateTime.now().year;
    final yearList = [
      'Any',
      ...List.generate(35, (index) => (currentYear - index).toString()),
    ];

    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _brandBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: _brandBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Year',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildDropdownPill(
                  label: minYear ?? 'Any',
                  onTap: () {
                    _showSingleChoicePicker(
                      title: 'Select Min Year',
                      items: yearList,
                      currentVal: minYear,
                      onSelected: (val) {
                        setState(() => minYear = val == 'Any' ? null : val);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownPill(
                  label: maxYear ?? 'Any',
                  onTap: () {
                    _showSingleChoicePicker(
                      title: 'Select Max Year',
                      items: yearList,
                      currentVal: maxYear,
                      onSelected: (val) {
                        setState(() => maxYear = val == 'Any' ? null : val);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMileageCard() {
    final minMileageOptions = [
      'Any',
      '0',
      '10 000',
      '25 000',
      '50 000',
      '75 000',
      '100 000',
      '150 000',
      '200 000'
    ];
    final maxMileageOptions = [
      'Any',
      '25 000',
      '50 000',
      '75 000',
      '100 000',
      '150 000',
      '200 000',
      '300 000',
      '500 000+'
    ];

    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _brandBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.speed_outlined,
                  color: _brandBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Mileage (km)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildDropdownPill(
                  label: minMileage ?? 'Any',
                  onTap: () {
                    _showSingleChoicePicker(
                      title: 'Select Min Mileage',
                      items: minMileageOptions,
                      currentVal: minMileage,
                      onSelected: (val) {
                        setState(() => minMileage = val == 'Any' ? null : val);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownPill(
                  label: maxMileage ?? 'Any',
                  onTap: () {
                    _showSingleChoicePicker(
                      title: 'Select Max Mileage',
                      items: maxMileageOptions,
                      currentVal: maxMileage,
                      onSelected: (val) {
                        setState(() => maxMileage = val == 'Any' ? null : val);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownPill({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.color.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.color.textDefaultColor,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: context.color.textLightColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final locationLabel = [city, _state]
        .where((element) => element.trim().isNotEmpty)
        .join(', ');

    final displayLoc =
        locationLabel.isNotEmpty ? locationLabel : (HiveUtils.getCityName() ?? 'Dushanbe');

    return _buildCardContainer(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _brandBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: _brandBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Location',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.color.textDefaultColor,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: _onTapChooseLocation,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: context.color.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.color.borderColor.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.35,
                    ),
                    child: Text(
                      displayLoc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: context.color.textLightColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicCustomFieldsSection() {
    return BlocConsumer<FetchCustomFieldsCubit, FetchCustomFieldState>(
      listener: (context, state) {
        if (state is FetchCustomFieldSuccess) {
          moreDetailDynamicFields = context
              .read<FetchCustomFieldsCubit>()
              .getFields()
              .where((field) {
            // Avoid duplicating car make and car model because they are fetched dynamically via CarsRepository
            final name = (field.name ?? "").toLowerCase();
            if (isMotorsCategory &&
                (name == 'make' ||
                    name == 'model' ||
                    name.contains('car make') ||
                    name.contains('car model'))) {
              return false;
            }
            return field.type != "fileinput";
          }).map((field) {
            Map<String, dynamic> fieldData = field.toMap();
            if (Constant.itemFilter != null &&
                Constant.itemFilter!.customFields != null) {
              String customFieldKey = 'custom_fields[${fieldData['id']}]';
              if (Constant.itemFilter!.customFields!
                  .containsKey(customFieldKey)) {
                fieldData['value'] =
                    Constant.itemFilter!.customFields![customFieldKey];
                fieldData['isEdit'] = true;
              }
            }
            CustomFieldBuilder customFieldBuilder =
                CustomFieldBuilder(fieldData);
            customFieldBuilder.stateUpdater(setState);
            customFieldBuilder.init();
            return customFieldBuilder;
          }).toList();
          setState(() {});
        }
      },
      builder: (context, state) {
        if (moreDetailDynamicFields.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: moreDetailDynamicFields.map((field) {
              field.stateUpdater(setState);
              return Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _buildCardContainer(child: field.build(context)),
              );
            }).toList(),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBottomStickyBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border(
          top: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              side: BorderSide(
                color: context.color.borderColor.withValues(alpha: 0.8),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _resetAllFilters,
            child: Text(
              'Reset',
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _applyFilterAndExit,
              child: _isLoadingCount
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _resultCount > 0
                          ? 'Show $_resultCount results'
                          : 'Show results',
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
    );
  }
}

class PostedSinceItem {
  final String status;
  final String value;

  PostedSinceItem({
    required this.status,
    required this.value,
  });
}
