import 'dart:async';
import 'dart:convert';
import 'package:Ebozor/data/model/item_filter_model.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/category/subcategory_filters_cubit.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/repositories/category_repository.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/constant.dart';

class FiltersPage extends StatefulWidget {
  final CategoryModel category;
  final ItemFilterModel? initialFilter;
  final bool isFromItemsList;
  final FilterCategory? initialFilterConfiguration;

  const FiltersPage({
    super.key,
    required this.category,
    this.initialFilter,
    this.isFromItemsList = false,
    this.initialFilterConfiguration,
  });

  static Route route(RouteSettings settings) {
    CategoryModel category;
    ItemFilterModel? initialFilter;
    bool isFromItemsList = false;
    FilterCategory? initialFilterConfiguration;

    if (settings.arguments is CategoryModel) {
      category = settings.arguments as CategoryModel;
    } else if (settings.arguments is Map) {
      final args = settings.arguments as Map;
      category = args['category'] as CategoryModel? ??
          CategoryModel(
            id: int.tryParse(args['catID']?.toString() ?? '65') ?? 65,
            name: args['catName']?.toString() ?? 'Properties',
            slug:
                args['categorySlug']?.toString() ?? args['catSlug']?.toString(),
          );
      initialFilter = args['appliedFilter'] as ItemFilterModel?;
      isFromItemsList = args['isFromItemsList'] == true;
      initialFilterConfiguration =
          args['filterConfiguration'] as FilterCategory?;
    } else {
      category = CategoryModel(id: 65, name: "Properties");
    }

    return MaterialPageRoute(
      builder: (context) => BlocProvider(
        create: (context) => FilterCubit(FilterRepository()),
        child: FiltersPage(
          category: category,
          initialFilter: initialFilter,
          isFromItemsList: isFromItemsList,
          initialFilterConfiguration: initialFilterConfiguration,
        ),
      ),
    );
  }

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  late FilterCubit cubit;
  String selectedSlug = "residential";

  // Tab: 0=Rent, 1=Buy, 2=Off-Plan
  int _selectedTab = 0;

  // Property Type index
  int _selectedPropertyType = 0;

  // Sub-category index
  int _selectedCategory = -1;

  // Price Range
  final TextEditingController _priceMinController =
      TextEditingController(text: '');
  final TextEditingController _priceMaxController =
      TextEditingController(text: '');

  // Dynamic filter state stored per filter name:
  // Multi-select stores Set<String>
  // Single-select stores String?
  final Map<String, dynamic> _selectedFilters = {};

  // Text / single numeric input dynamic filters stored per filter name
  final Map<String, TextEditingController> _filterTextControllers = {};

  // Range Min / Max controllers for numeric range filters (e.g. Size, Km, etc.)
  final Map<String, TextEditingController> _rangeMinControllers = {};
  final Map<String, TextEditingController> _rangeMaxControllers = {};
  final Map<String, RangeValues> _rangeSliderValues = {};

  // Location controller
  final TextEditingController _locationController = TextEditingController();

  // Live count state
  int _resultCount = 0;
  bool _isLoadingCount = false;
  Timer? _countDebounceTimer;
  int _countRequestId = 0;

  bool get _isPropertyCategory {
    const propertyIds = {65, 68, 139, 143};
    final id = widget.category.id;
    final value = '${widget.category.name ?? ''} '
            '${widget.category.slug ?? ''} '
            '${widget.initialFilterConfiguration?.slug ?? ''}'
        .toLowerCase();
    return propertyIds.contains(id) ||
        value.contains('property') ||
        value.contains('residential') ||
        value.contains('off-plan');
  }

  List<FilterItem> _sortedActiveFilters(FilterCategory category) {
    final filters =
        category.filters.where((filter) => filter.isActive).toList();
    filters.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return filters;
  }

  @override
  void initState() {
    super.initState();
    cubit = context.read<FilterCubit>();

    // Determine default tab based on category id, name, or slug:
    final catId = widget.category.id;
    final slugLower = (widget.category.slug ?? "").toLowerCase();
    final nameLower = (widget.category.name ?? "").toLowerCase();

    if (catId == 143 ||
        slugLower.contains("off-plan") ||
        nameLower.contains("off-plan")) {
      _selectedTab = 2; // Off-Plan
    } else if (catId == 139 ||
        slugLower.contains("sale") ||
        nameLower.contains("sale") ||
        nameLower.contains("buy")) {
      _selectedTab = 1; // Buy
    } else if (catId == 65 ||
        catId == 68 ||
        slugLower.contains("rent") ||
        nameLower.contains("rent")) {
      _selectedTab = 0; // Rent
    } else {
      _selectedTab = 0; // Default Rent
    }

    final selectedCategorySlug = widget.initialFilter?.categorySlug;
    final initialSlug =
        widget.initialFilterConfiguration?.slug?.isNotEmpty == true
            ? widget.initialFilterConfiguration!.slug!
            : (selectedCategorySlug != null && selectedCategorySlug.isNotEmpty)
                ? selectedCategorySlug
                : ((widget.category.children != null &&
                        widget.category.children!.isNotEmpty)
                    ? (widget.category.children!.first.slug ??
                        widget.category.slug ??
                        '')
                    : (widget.category.slug ?? ''));

    if (widget.category.children != null) {
      final propertyTypeIndex = widget.category.children!.indexWhere(
        (category) => category.slug == initialSlug,
      );
      if (propertyTypeIndex >= 0) _selectedPropertyType = propertyTypeIndex;
    }
    if (widget.initialFilterConfiguration != null &&
        selectedCategorySlug != null) {
      final categoryIndex = widget.initialFilterConfiguration!.children
          .indexWhere((category) => category.slug == selectedCategorySlug);
      if (categoryIndex >= 0) _selectedCategory = categoryIndex;
    }

    selectedSlug = initialSlug;
    if (initialSlug.isNotEmpty) cubit.fetchFilters(initialSlug);

    _locationController.text = widget.initialFilter?.city?.isNotEmpty == true
        ? widget.initialFilter!.city!
        : (HiveUtils.getCityName() ?? "");

    if (widget.initialFilter?.minPrice != null &&
        widget.initialFilter!.minPrice!.isNotEmpty) {
      _priceMinController.text = widget.initialFilter!.minPrice!;
    }
    if (widget.initialFilter?.maxPrice != null &&
        widget.initialFilter!.maxPrice!.isNotEmpty) {
      _priceMaxController.text = widget.initialFilter!.maxPrice!;
    }

    if (widget.initialFilter?.customFields != null) {
      widget.initialFilter!.customFields!.forEach((k, v) {
        if (v == null) return;
        String cleanKey = k;
        if (k.startsWith('filters[') && k.endsWith(']')) {
          cleanKey = k.substring(8, k.length - 1);
        }
        if (v is List) {
          _selectedFilters[cleanKey] = List<String>.from(
            v.map((e) => e.toString()),
          );
        } else if (v is Set) {
          _selectedFilters[cleanKey] =
              Set<String>.from(v.map((e) => e.toString()));
        } else {
          _selectedFilters[cleanKey] = v.toString();
        }
      });
    }
    for (final filterDefinition
        in widget.initialFilterConfiguration?.filters ?? const <FilterItem>[]) {
      final name = filterDefinition.name;
      if (name == null || filterDefinition.values.isEmpty) continue;
      final value = _selectedFilters[name];
      if (filterDefinition.multiSelect) {
        if (value is Iterable) {
          _selectedFilters[name] =
              Set<String>.from(value.map((item) => item.toString()));
        } else if (value != null && value.toString().isNotEmpty) {
          _selectedFilters[name] = <String>{value.toString()};
        }
      } else if (value is Iterable) {
        final values = value.map((item) => item.toString()).toList();
        _selectedFilters[name] = values.isEmpty ? '' : values.first;
      }
    }

    _priceMinController.addListener(_onFilterChanged);
    _priceMaxController.addListener(_onFilterChanged);
    _locationController.addListener(_onFilterChanged);

    _updateItemCount();
  }

  @override
  void dispose() {
    _countDebounceTimer?.cancel();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _locationController.dispose();
    for (var controller in _filterTextControllers.values) {
      controller.dispose();
    }
    for (var controller in _rangeMinControllers.values) {
      controller.dispose();
    }
    for (var controller in _rangeMaxControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFilterChanged() {
    _updateItemCount();
  }

  int get _appliedFiltersCount {
    int count = 0;
    if (_priceMinController.text.isNotEmpty ||
        _priceMaxController.text.isNotEmpty) count++;
    if (_locationController.text.isNotEmpty &&
        _locationController.text != (HiveUtils.getCityName() ?? "")) count++;
    _selectedFilters.forEach((_, val) {
      if (val is Set && val.isNotEmpty) count++;
      if (val is List && val.isNotEmpty) count++;
      if (val is String && val.isNotEmpty) count++;
    });
    _filterTextControllers.forEach((_, c) {
      if (c.text.isNotEmpty) count++;
    });
    _rangeMinControllers.forEach((k, minC) {
      final maxC = _rangeMaxControllers[k];
      if (minC.text.isNotEmpty || (maxC != null && maxC.text.isNotEmpty)) {
        count++;
      }
    });
    return count;
  }

  void _updateItemCount() {
    _countDebounceTimer?.cancel();
    final requestId = ++_countRequestId;
    _countDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isLoadingCount = true;
      });

      try {
        String activeCategorySlug = selectedSlug;
        final filterState = cubit.state;
        if (filterState is FilterLoaded) {
          if (_selectedCategory >= 0 &&
              _selectedCategory < filterState.data.children.length) {
            final childSlug = filterState.data.children[_selectedCategory].slug;
            if (childSlug != null &&
                childSlug.isNotEmpty &&
                !childSlug.endsWith('-all')) {
              activeCategorySlug = childSlug;
            }
          }
        }

        Map<String, dynamic> queryParams = {
          "page": 1,
          "sort_by": "new-to-old",
          if (_priceMinController.text.trim().isNotEmpty &&
              _priceMinController.text.trim() != '0')
            "min_price": _priceMinController.text.trim(),
          if (_priceMaxController.text.trim().isNotEmpty)
            "max_price": _priceMaxController.text.trim(),
          if (_locationController.text.trim().isNotEmpty)
            "city": _locationController.text.trim()
          else if (HiveUtils.getCityName() != null &&
              HiveUtils.getCityName()!.isNotEmpty)
            "city": HiveUtils.getCityName(),
          if (HiveUtils.getStateName() != null &&
              HiveUtils.getStateName()!.isNotEmpty)
            "state": HiveUtils.getStateName(),
          if (HiveUtils.getCountryName() != null &&
              HiveUtils.getCountryName()!.isNotEmpty)
            "country": HiveUtils.getCountryName(),
          "category_slug": activeCategorySlug,
        };

        // Add dynamic filters
        _selectedFilters.forEach((key, val) {
          if (val is Set<String> && val.isNotEmpty) {
            queryParams["filters[$key]"] = jsonEncode(val.toList());
          } else if (val is List<String> && val.isNotEmpty) {
            queryParams["filters[$key]"] = jsonEncode(val);
          } else if (val is String && val.isNotEmpty) {
            queryParams["filters[$key]"] = val;
          }
        });

        // Add text-based dynamic filters
        _filterTextControllers.forEach((key, controller) {
          if (controller.text.trim().isNotEmpty) {
            queryParams["filters[$key]"] = controller.text.trim();
          }
        });

        // Add range dynamic filters
        _rangeMinControllers.forEach((key, minController) {
          final maxController = _rangeMaxControllers[key];
          final minVal = minController.text.trim();
          final maxVal = maxController?.text.trim() ?? "";
          if (minVal.isNotEmpty && maxVal.isNotEmpty) {
            queryParams["filters[$key]"] = jsonEncode([minVal, maxVal]);
          } else if (minVal.isNotEmpty) {
            queryParams["filters[$key]"] = minVal;
          } else if (maxVal.isNotEmpty) {
            queryParams["filters[$key]"] = maxVal;
          }
        });

        final dio = Dio(
          BaseOptions(
            baseUrl: Constant.baseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

        final response =
            await dio.get(Api.getItemCountApi, queryParameters: queryParams);

        if (response.statusCode == 200 &&
            mounted &&
            requestId == _countRequestId) {
          final data = response.data['data'];
          final rawCount = data is Map
              ? (data['count'] ?? data['total'])
              : response.data is Map
                  ? (response.data['count'] ?? response.data['total'])
                  : null;
          final total = int.tryParse(rawCount?.toString() ?? '') ?? 0;

          setState(() {
            _resultCount = total;
            _isLoadingCount = false;
          });
        }
      } catch (e) {
        if (mounted && requestId == _countRequestId) {
          setState(() {
            _isLoadingCount = false;
          });
        }
      }
    });
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        String locName = place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            place.name ??
            "Dubai";

        setState(() {
          _locationController.text = locName;
        });
        _onFilterChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch location: $e')),
        );
      }
    }
  }

  void _resetAllFilters() {
    setState(() {
      _selectedTab = 0;
      _selectedPropertyType = 0;
      _selectedCategory = -1;
      _priceMinController.clear();
      _priceMaxController.clear();
      _locationController.text = HiveUtils.getCityName() ?? "";
      _selectedFilters.clear();
      _rangeSliderValues.clear();
      for (var controller in _filterTextControllers.values) {
        controller.clear();
      }
      for (var controller in _rangeMinControllers.values) {
        controller.clear();
      }
      for (var controller in _rangeMaxControllers.values) {
        controller.clear();
      }
    });
    final initialSlug = (widget.category.children != null &&
            widget.category.children!.isNotEmpty)
        ? (widget.category.children!.first.slug ??
            widget.category.slug ??
            selectedSlug)
        : (widget.category.slug ?? selectedSlug);
    selectedSlug = initialSlug;
    if (initialSlug.isNotEmpty) cubit.fetchFilters(initialSlug);
    _onFilterChanged();
  }

  void _applyFiltersAndNavigate() {
    String activeCategoryId = widget.category.id.toString();
    String activeCategoryName = widget.category.name ?? "Properties";
    String activeCategorySlug = selectedSlug;
    final filterState = cubit.state;
    if (filterState is FilterLoaded) {
      if (_selectedCategory >= 0 &&
          _selectedCategory < filterState.data.children.length) {
        final child = filterState.data.children[_selectedCategory];
        if (child.slug != null &&
            child.slug!.isNotEmpty &&
            !child.slug!.endsWith('-all')) {
          activeCategoryId = child.id.toString();
          activeCategoryName = child.name ?? activeCategoryName;
          activeCategorySlug = child.slug!;
        }
      }
    }

    Map<String, dynamic> customFieldFilterMap = {};
    _selectedFilters.forEach((key, val) {
      if (val is Set<String> && val.isNotEmpty) {
        customFieldFilterMap[key] = val.toList();
      } else if (val is List<String> && val.isNotEmpty) {
        customFieldFilterMap[key] = val;
      } else if (val is String && val.isNotEmpty) {
        customFieldFilterMap[key] = val;
      }
    });

    _filterTextControllers.forEach((key, controller) {
      if (controller.text.trim().isNotEmpty) {
        customFieldFilterMap[key] = controller.text.trim();
      }
    });

    _rangeMinControllers.forEach((key, minController) {
      final maxController = _rangeMaxControllers[key];
      final minVal = minController.text.trim();
      final maxVal = maxController?.text.trim() ?? "";
      if (minVal.isNotEmpty || maxVal.isNotEmpty) {
        customFieldFilterMap[key] = [
          if (minVal.isNotEmpty) minVal else "0",
          if (maxVal.isNotEmpty) maxVal else "999999999"
        ];
      }
    });

    ItemFilterModel appliedFilter = ItemFilterModel(
      categoryId: activeCategoryId,
      categorySlug: activeCategorySlug,
      minPrice: _priceMinController.text.trim().isNotEmpty &&
              _priceMinController.text.trim() != '0'
          ? _priceMinController.text.trim()
          : null,
      maxPrice: _priceMaxController.text.trim().isNotEmpty
          ? _priceMaxController.text.trim()
          : null,
      city: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : (HiveUtils.getCityName() ?? ""),
      state: HiveUtils.getStateName() ?? "",
      country: HiveUtils.getCountryName() ?? "",
      customFields:
          customFieldFilterMap.isNotEmpty ? customFieldFilterMap : null,
    );

    Constant.itemFilter = appliedFilter;

    List<CategoryModel> categoryChain = [widget.category];
    List<String> categoryIds = [widget.category.id.toString()];

    if (activeCategoryId != widget.category.id.toString()) {
      categoryChain.add(CategoryModel(
        id: int.tryParse(activeCategoryId) ?? 0,
        name: activeCategoryName,
        slug: activeCategorySlug,
        children: [],
        subcategoriesCount: 0,
      ));
      categoryIds.add(activeCategoryId);
    }

    if (widget.isFromItemsList && Navigator.canPop(context)) {
      Navigator.pop(context, {
        "catID": activeCategoryId,
        "catName": activeCategoryName,
        "categorySlug": activeCategorySlug,
        "categoryIds": categoryIds,
        "selectedCategoryChain": categoryChain,
        "appliedFilter": appliedFilter,
        "filterConfiguration":
            filterState is FilterLoaded ? filterState.data : null,
      });
      return;
    }

    Navigator.pushNamed(
      context,
      Routes.itemsList,
      arguments: {
        "catID": activeCategoryId,
        "catName": activeCategoryName,
        "categorySlug": activeCategorySlug,
        "categoryIds": categoryIds,
        "selectedCategoryChain": categoryChain,
        "appliedFilter": appliedFilter,
        "filterConfiguration":
            filterState is FilterLoaded ? filterState.data : null,
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final activeCount = _appliedFiltersCount;

    return AppBar(
      backgroundColor: context.color.secondaryColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: context.color.textDefaultColor,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Filters".translate(context),
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (activeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: context.color.territoryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$activeCount",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: _resetAllFilters,
          child: Text(
            "Reset".translate(context),
            style: TextStyle(
              color: context.color.territoryColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Rent', 'Buy', 'Off-Plan'];

    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border(
          bottom: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedTab != i) {
                  setState(() {
                    _selectedTab = i;
                    _selectedCategory = -1;
                    _selectedPropertyType = 0;
                    _selectedFilters.clear();
                    _filterTextControllers.clear();
                    _rangeMinControllers.clear();
                    _rangeMaxControllers.clear();
                  });

                  String tabSlug = "property-for-rent";
                  if (i == 1) tabSlug = "property-for-sale";
                  if (i == 2) tabSlug = "property-for-sale-off-plan";

                  selectedSlug = tabSlug;
                  cubit.fetchFilters(tabSlug);
                  _onFilterChanged();
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      tabs[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? context.color.territoryColor
                            : context.color.textLightColor,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 2.5,
                    width: double.infinity,
                    color: isSelected
                        ? context.color.territoryColor
                        : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: context.color.textDefaultColor,
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Location'.translate(context)),
        Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.6),
            ),
          ),
          child: TextField(
            controller: _locationController,
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Dubai Marina, Deira...'.translate(context),
              hintStyle: TextStyle(
                color: context.color.textLightColor,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.location_on_rounded,
                color: context.color.territoryColor,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.my_location_rounded,
                  color: context.color.territoryColor,
                  size: 20,
                ),
                tooltip: 'Use current location'.translate(context),
                onPressed: _fetchCurrentLocation,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyTypeSection(List<dynamic> propertyTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Property Type'.translate(context)),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: propertyTypes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = propertyTypes[i];
              final isSelected = _selectedPropertyType == i;

              return GestureDetector(
                onTap: () {
                  if (_selectedPropertyType != i) {
                    setState(() {
                      _selectedPropertyType = i;
                      _selectedCategory = -1;
                    });
                    final slug = item.slug ?? "residential";
                    selectedSlug = slug;
                    cubit.fetchFilters(slug);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 96,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.color.territoryColor.withValues(alpha: 0.12)
                        : context.color.secondaryColor,
                    border: Border.all(
                      color: isSelected
                          ? context.color.territoryColor
                          : context.color.borderColor.withValues(alpha: 0.6),
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCategoryImage(item.url, item.name, isSelected),
                      const SizedBox(height: 5),
                      Text(
                        item.name ?? '',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? context.color.territoryColor
                              : context.color.textDefaultColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getIcon(String? name) {
    switch (name?.toLowerCase()) {
      case 'residential':
        return Icons.home_rounded;
      case 'commercial':
        return Icons.business_rounded;
      case 'rooms for rent':
        return Icons.meeting_room_rounded;
      case 'monthly short term':
        return Icons.calendar_month_rounded;
      case 'daily short term':
        return Icons.today_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildCategoryImage(String? image, String? name, bool isSelected) {
    final activeColor = isSelected
        ? context.color.territoryColor
        : context.color.textLightColor;

    if (image != null && image.isNotEmpty) {
      return Image.network(
        image,
        height: 26,
        width: 26,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(_getIcon(name), size: 24, color: activeColor);
        },
      );
    } else {
      return Icon(_getIcon(name), size: 24, color: activeColor);
    }
  }

  Widget _buildSubCategoriesSection(
      List<FilterSubCategory> categories, String title) {
    if (categories.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("${title} Categories".translate(context)),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final item = categories[i];
              final isSelected = _selectedCategory == i;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = i;
                  });
                  _onFilterChanged();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.color.territoryColor
                        : context.color.secondaryColor,
                    border: Border.all(
                      color: isSelected
                          ? context.color.territoryColor
                          : context.color.borderColor.withValues(alpha: 0.6),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.name ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : context.color.textDefaultColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRangeSection() {
    return _buildRangeInputs(
      fieldKey: "price",
      title: "Price Range".translate(context),
      minController: _priceMinController,
      maxController: _priceMaxController,
      unit: "AED",
      maxLimit: 1000000,
    );
  }

  Widget _buildRangeInputs({
    required String fieldKey,
    required String title,
    required TextEditingController minController,
    required TextEditingController maxController,
    required String unit,
    double maxLimit = 100000,
  }) {
    double currentMin = double.tryParse(minController.text.trim()) ?? 0;
    double currentMax = double.tryParse(maxController.text.trim()) ?? maxLimit;
    if (currentMin < 0) currentMin = 0;
    if (currentMax > maxLimit) currentMax = maxLimit;
    if (currentMax < currentMin) currentMax = currentMin;

    final sliderRange =
        _rangeSliderValues[fieldKey] ?? RangeValues(currentMin, currentMax);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        Row(
          children: [
            Expanded(
              child: _buildEditableRangeField(
                minController,
                'Min'.translate(context),
                unit,
                onChanged: (val) {
                  final v = double.tryParse(val) ?? 0;
                  setState(() {
                    _rangeSliderValues[fieldKey] = RangeValues(
                      v.clamp(0, sliderRange.end),
                      sliderRange.end,
                    );
                  });
                  _onFilterChanged();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'to'.translate(context),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.color.textLightColor,
                ),
              ),
            ),
            Expanded(
              child: _buildEditableRangeField(
                maxController,
                'Max'.translate(context),
                unit,
                onChanged: (val) {
                  final v = double.tryParse(val) ?? maxLimit;
                  setState(() {
                    _rangeSliderValues[fieldKey] = RangeValues(
                      sliderRange.start,
                      v.clamp(sliderRange.start, maxLimit),
                    );
                  });
                  _onFilterChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Range Slider
        RangeSlider(
          values: RangeValues(
            sliderRange.start.clamp(0, maxLimit),
            sliderRange.end.clamp(0, maxLimit),
          ),
          min: 0,
          max: maxLimit,
          activeColor: context.color.territoryColor,
          inactiveColor: context.color.territoryColor.withValues(alpha: 0.2),
          onChanged: (values) {
            setState(() {
              _rangeSliderValues[fieldKey] = values;
              minController.text = values.start.round().toString();
              maxController.text = values.end.round().toString();
            });
            _onFilterChanged();
          },
        ),
      ],
    );
  }

  Widget _buildEditableRangeField(
    TextEditingController controller,
    String hint,
    String suffix, {
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: context.color.textLightColor,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.color.textDefaultColor,
              ),
            ),
          ),
          Text(
            suffix,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.color.textLightColor,
            ),
          ),
        ],
      ),
    );
  }

  bool _isRangeField(String name) {
    final lower = name.toLowerCase();
    return lower.contains('size') ||
        lower.contains('area') ||
        lower.contains('sqft') ||
        lower.contains('kilometer') ||
        lower.contains('km') ||
        lower.contains('year') ||
        lower.contains('capacity') ||
        lower.contains('horsepower') ||
        lower.contains('price');
  }

  String _getFieldUnit(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sqft') || lower.contains('size')) return 'Sqft';
    if (lower.contains('km') || lower.contains('kilometer')) return 'Km';
    if (lower.contains('year')) return 'Yr';
    if (lower.contains('cc')) return 'cc';
    if (lower.contains('hp') || lower.contains('horsepower')) return 'HP';
    return '';
  }

  double _getFieldMaxLimit(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sqft') || lower.contains('size')) return 20000;
    if (lower.contains('km') || lower.contains('kilometer')) return 300000;
    if (lower.contains('price')) return 1000000;
    if (lower.contains('cc')) return 6000;
    if (lower.contains('hp') || lower.contains('horsepower')) return 1000;
    return 10000;
  }

  Widget _buildDynamicFilterSection(FilterItem filter) {
    final filterName = filter.name ?? '';
    if (filterName.isEmpty) return const SizedBox();

    // Check if numeric field qualifies for Range Picker Slider
    if (filter.type == 'number' && _isRangeField(filterName)) {
      _rangeMinControllers.putIfAbsent(
          filterName, () => TextEditingController());
      _rangeMaxControllers.putIfAbsent(
          filterName, () => TextEditingController());

      final minC = _rangeMinControllers[filterName]!;
      final maxC = _rangeMaxControllers[filterName]!;
      final initialValue = _selectedFilters.remove(filterName);
      if (initialValue is Iterable) {
        final values = initialValue.map((e) => e.toString()).toList();
        if (minC.text.isEmpty && values.isNotEmpty) minC.text = values.first;
        if (maxC.text.isEmpty && values.length > 1) maxC.text = values[1];
      } else if (initialValue != null && minC.text.isEmpty) {
        minC.text = initialValue.toString();
      }

      return _buildRangeInputs(
        fieldKey: filterName,
        title: filterName,
        minController: minC,
        maxController: maxC,
        unit: _getFieldUnit(filterName),
        maxLimit: _getFieldMaxLimit(filterName),
      );
    }

    // Text or generic Number input filter
    if (filter.type == 'text' || filter.type == 'number') {
      _filterTextControllers.putIfAbsent(
          filterName, () => TextEditingController());
      final controller = _filterTextControllers[filterName]!;
      final initialValue = _selectedFilters.remove(filterName);
      if (controller.text.isEmpty && initialValue != null) {
        if (initialValue is Iterable) {
          final values = initialValue.map((e) => e.toString()).toList();
          if (values.isNotEmpty) controller.text = values.first;
        } else {
          controller.text = initialValue.toString();
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(filterName),
          Container(
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.6),
              ),
            ),
            child: TextField(
              controller: controller,
              keyboardType: filter.type == 'number'
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: filter.type == 'number'
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              onChanged: (_) => _onFilterChanged(),
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: filter.placeholder ?? 'Enter $filterName',
                hintStyle: TextStyle(
                  color: context.color.textLightColor,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (filter.values.isEmpty) return const SizedBox();

    // Multi-select filter (e.g. Amenities, Listed By, Regional Specs, etc.)
    if (filter.multiSelect) {
      final initialValue = _selectedFilters[filterName];
      if (initialValue is! Set<String>) {
        if (initialValue is Iterable) {
          _selectedFilters[filterName] =
              Set<String>.from(initialValue.map((e) => e.toString()));
        } else if (initialValue != null && initialValue.toString().isNotEmpty) {
          _selectedFilters[filterName] = <String>{initialValue.toString()};
        } else {
          _selectedFilters[filterName] = <String>{};
        }
      }
      final selectedSet = _selectedFilters[filterName] as Set<String>;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(filterName),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filter.values.map((val) {
              final isSelected = selectedSet.contains(val);
              return _buildFilterPill(
                label: val,
                isSelected: isSelected,
                isMulti: true,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedSet.remove(val);
                    } else {
                      selectedSet.add(val);
                    }
                  });
                  _onFilterChanged();
                },
              );
            }).toList(),
          ),
        ],
      );
    }

    // Single-select filter (e.g. Bedrooms, Bathrooms, Furnishing, Rent is paid)
    final initialValue = _selectedFilters[filterName];
    final String? selectedVal;
    if (initialValue is Iterable) {
      final values = initialValue.map((e) => e.toString()).toList();
      selectedVal = values.isEmpty ? null : values.first;
    } else {
      selectedVal = initialValue?.toString();
    }
    _selectedFilters[filterName] = selectedVal ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(filterName),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filter.values.map((val) {
            final isSelected = selectedVal == val;
            return _buildFilterPill(
              label: val,
              isSelected: isSelected,
              isMulti: false,
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedFilters.remove(filterName);
                  } else {
                    _selectedFilters[filterName] = val;
                  }
                });
                _onFilterChanged();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required bool isMulti,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.color.territoryColor.withValues(alpha: 0.12)
              : context.color.secondaryColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? context.color.territoryColor
                : context.color.borderColor.withValues(alpha: 0.6),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? context.color.territoryColor
                    : context.color.textDefaultColor,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: context.color.territoryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShowResultsButton() {
    final countFormatted = _resultCount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _applyFiltersAndNavigate,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.color.territoryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
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
                    'Show $countFormatted Results'.translate(context),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final propertyTypes = (widget.category.children != null &&
            widget.category.children!.isNotEmpty)
        ? widget.category.children!
        : [widget.category];

    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isPropertyCategory) _buildTabBar(),
          Expanded(
            child: BlocConsumer<FilterCubit, FilterState>(
              listener: (context, state) {
                if (state is FilterLoaded) {
                  _onFilterChanged();
                }
              },
              builder: (context, state) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Location Section
                      _buildLocationSection(),
                      const SizedBox(height: 20),

                      if (_isPropertyCategory) ...[
                        _buildPropertyTypeSection(propertyTypes),
                        const SizedBox(height: 20),
                      ],

                      if (state is FilterLoading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: context.color.territoryColor,
                            ),
                          ),
                        )
                      else if (state is FilterError)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              state.message,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        )
                      else if (state is FilterLoaded) ...[
                        // Sub-categories Chips
                        if (state.data.children.isNotEmpty) ...[
                          _buildSubCategoriesSection(
                            state.data.children,
                            state.data.name ?? 'Categories',
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Price Range Section with RangeSlider
                        _buildPriceRangeSection(),
                        const SizedBox(height: 20),

                        // API-driven Dynamic Filters with RangeSliders
                        ..._sortedActiveFilters(state.data).map((filter) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildDynamicFilterSection(filter),
                          );
                        }),
                      ],

                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildShowResultsButton(),
        ],
      ),
    );
  }
}
