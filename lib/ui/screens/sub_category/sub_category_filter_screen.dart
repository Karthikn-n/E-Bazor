import 'dart:async';
import 'dart:convert';
import 'package:Ebozor/data/model/item_filter_model.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
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

  const FiltersPage({super.key, required this.category});

  static Route route(RouteSettings settings) {
    final category = settings.arguments as CategoryModel;

    return MaterialPageRoute(
      builder: (context) => BlocProvider(
        create: (context) => FilterCubit(FilterRepository()),
        child: FiltersPage(category: category),
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

  // Sub-category (e.g., All, Apartment, Villa) index
  int _selectedCategory = 0;

  // Price Range
  final TextEditingController _priceMinController =
      TextEditingController(text: '');
  final TextEditingController _priceMaxController =
      TextEditingController(text: '');

  // Area/Size Range
  final TextEditingController _areaMinController =
      TextEditingController(text: '');
  final TextEditingController _areaMaxController =
      TextEditingController(text: '');

  // Dynamic filter state stored per filter name:
  // Multi-select stores Set<String>
  // Single-select stores String?
  final Map<String, dynamic> _selectedFilters = {};

  // Text / numeric input dynamic filters stored per filter name
  final Map<String, TextEditingController> _filterTextControllers = {};

  // Location & keywords
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _excludeLocationController =
      TextEditingController();
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _agencyController = TextEditingController();

  // More Filters static toggles
  final Set<String> _selectedMoreFilters = {};

  // Live count state
  int _resultCount = 0;
  bool _isLoadingCount = false;
  Timer? _countDebounceTimer;

  static const Color _redColor = Color(0xFFE02020);
  static const Color _borderColor = Color(0xFFDDDDDD);
  static const Color _greyText = Color(0xFF888888);

  @override
  void initState() {
    super.initState();
    cubit = context.read<FilterCubit>();

    final initialSlug = (widget.category.children != null &&
            widget.category.children!.isNotEmpty)
        ? (widget.category.children!.first.slug ?? "residential")
        : (widget.category.slug ?? "residential");

    selectedSlug = initialSlug;
    cubit.fetchFilters(initialSlug);

    _priceMinController.addListener(_onFilterChanged);
    _priceMaxController.addListener(_onFilterChanged);
    _areaMinController.addListener(_onFilterChanged);
    _areaMaxController.addListener(_onFilterChanged);
    _locationController.addListener(_onFilterChanged);
    _keywordController.addListener(_onFilterChanged);
    _agencyController.addListener(_onFilterChanged);

    _updateItemCount();
  }

  @override
  void dispose() {
    _countDebounceTimer?.cancel();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _areaMinController.dispose();
    _areaMaxController.dispose();
    _locationController.dispose();
    _excludeLocationController.dispose();
    _keywordController.dispose();
    _agencyController.dispose();
    for (var controller in _filterTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFilterChanged() {
    _updateItemCount();
  }

  void _updateItemCount() {
    _countDebounceTimer?.cancel();
    _countDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() {
        _isLoadingCount = true;
      });

      try {
        String activeCategorySlug = selectedSlug;
        final filterState = cubit.state;
        if (filterState is FilterLoaded) {
          if (_selectedCategory > 0 &&
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
            "city": _locationController.text.trim(),
          "category_slug": activeCategorySlug,
        };

        // Add dynamic filters: filters[Key]=Value or filters[Key]=["Val1", "Val2"]
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

        final dio = Dio(
          BaseOptions(
            baseUrl: Constant.baseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

        final response =
            await dio.get(Api.getItemApi, queryParameters: queryParams);

        if (response.statusCode == 200 && mounted) {
          final data = response.data['data'];
          int total = 0;
          if (data is Map && data.containsKey('total')) {
            total = data['total'] is int
                ? data['total']
                : int.tryParse(data['total'].toString()) ?? 0;
          } else if (response.data is Map &&
              response.data.containsKey('total')) {
            total = response.data['total'] is int
                ? response.data['total']
                : int.tryParse(response.data['total'].toString()) ?? 0;
          }

          setState(() {
            _resultCount = total;
            _isLoadingCount = false;
          });
        }
      } catch (e) {
        if (mounted) {
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
        desiredAccuracy: LocationAccuracy.medium,
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
      _selectedCategory = 0;
      _priceMinController.clear();
      _priceMaxController.clear();
      _areaMinController.clear();
      _areaMaxController.clear();
      _locationController.clear();
      _excludeLocationController.clear();
      _keywordController.clear();
      _agencyController.clear();
      _selectedFilters.clear();
      _selectedMoreFilters.clear();
      for (var controller in _filterTextControllers.values) {
        controller.clear();
      }
    });
    final initialSlug = (widget.category.children != null &&
            widget.category.children!.isNotEmpty)
        ? (widget.category.children!.first.slug ?? "residential")
        : (widget.category.slug ?? "residential");
    selectedSlug = initialSlug;
    cubit.fetchFilters(initialSlug);
    _onFilterChanged();
  }

  void _applyFiltersAndNavigate() {
    String activeCategoryId = widget.category.id.toString();
    String activeCategoryName = widget.category.name ?? "Properties";
    final filterState = cubit.state;
    if (filterState is FilterLoaded) {
      if (_selectedCategory > 0 &&
          _selectedCategory < filterState.data.children.length) {
        final child = filterState.data.children[_selectedCategory];
        if (child.slug != null &&
            child.slug!.isNotEmpty &&
            !child.slug!.endsWith('-all')) {
          activeCategoryId = child.id.toString();
          activeCategoryName = child.name ?? activeCategoryName;
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
        customFieldFilterMap[key] = [val];
      }
    });

    _filterTextControllers.forEach((key, controller) {
      if (controller.text.trim().isNotEmpty) {
        customFieldFilterMap[key] = [controller.text.trim()];
      }
    });

    ItemFilterModel appliedFilter = ItemFilterModel(
      categoryId: activeCategoryId,
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
        children: [],
        subcategoriesCount: 0,
      ));
      categoryIds.add(activeCategoryId);
    }

    Navigator.pushNamed(
      context,
      Routes.itemsList,
      arguments: {
        "catID": activeCategoryId,
        "catName": activeCategoryName,
        "categoryIds": categoryIds,
        "selectedCategoryChain": categoryChain,
        "appliedFilter": appliedFilter,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final propertyTypes = (widget.category.children != null &&
            widget.category.children!.isNotEmpty)
        ? widget.category.children!
        : [widget.category];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),
          _buildTabBar(),
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
                      const SizedBox(height: 20),

                      // Location Section
                      _buildLocationSection(),
                      const SizedBox(height: 24),

                      // Property Type Section
                      _buildPropertyTypeSection(propertyTypes),
                      const SizedBox(height: 24),

                      if (state is FilterLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: CircularProgressIndicator(color: _redColor),
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
                        // Sub-categories Chips (e.g. All, Apartment, Villa, etc.)
                        if (state.data.children.isNotEmpty) ...[
                          _buildResidentialCategoriesSection(
                            state.data.children,
                            state.data.name ?? 'Categories',
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Price Range Section
                        _buildPriceRangeSection(),
                        const SizedBox(height: 24),

                        // Dynamic API Filters (Bedrooms, Bathrooms, Furnishing, Amenities, etc.)
                        ...state.data.filters
                            .map((filter) => _buildDynamicFilterSection(filter))
                            .where((w) => w is! SizedBox)
                            .expand((w) => [w, const SizedBox(height: 24)]),

                        // Static filters commented out - Filter screen now only contains API-driven filters
                        // // Static Exclude Locations
                        // _buildExcludeLocationsSection(),
                        // const SizedBox(height: 24),

                        // // Static Keyword Section
                        // _buildKeywordSection(),
                        // const SizedBox(height: 24),

                        // // Static Real Estate Agencies Section
                        // _buildRealEstateAgenciesSection(),
                        // const SizedBox(height: 24),

                        // // Static More Filters
                        // _buildMoreFiltersSection(),
                        // const SizedBox(height: 24),
                      ],
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

  Widget _buildAppBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: _redColor, size: 24),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: _resetAllFilters,
              child: const Text(
                'Reset',
                style: TextStyle(
                  fontSize: 16,
                  color: _greyText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Rent', 'Buy', 'Off-Plan'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedTab != i) {
                  setState(() => _selectedTab = i);
                  _onFilterChanged();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFFEEEEEE),
                  border: isSelected
                      ? const Border(
                          bottom: BorderSide(color: _redColor, width: 2.5),
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? Colors.black : _greyText,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Location'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: 'e.g. Dubai Marina',
              hintStyle: const TextStyle(color: _greyText, fontSize: 15),
              prefixIcon: const Icon(Icons.location_on_outlined,
                  color: _greyText, size: 22),
              suffixIcon: IconButton(
                icon: const Icon(Icons.my_location,
                    color: _redColor, size: 20),
                tooltip: 'Use current location',
                onPressed: _fetchCurrentLocation,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select the cities, neighborhoods or buildings that you want to search properties in.',
          style: TextStyle(fontSize: 13, color: _greyText, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildPropertyTypeSection(List<dynamic> propertyTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Property Type'),
        SizedBox(
          height: 90,
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
                      _selectedCategory = 0; // reset subcategory
                    });
                    final slug = item.slug ?? "residential";
                    selectedSlug = slug;
                    cubit.fetchFilters(slug);
                  }
                },
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.black : _borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? Colors.black.withValues(alpha: 0.04)
                        : Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCategoryImage(item.url, item.name, isSelected),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          item.name ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isSelected ? Colors.black : _greyText,
                          ),
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
        return Icons.home_outlined;
      case 'commercial':
        return Icons.business_outlined;
      case 'rooms for rent':
        return Icons.meeting_room_outlined;
      case 'monthly short term':
        return Icons.calendar_month;
      case 'daily short term':
        return Icons.today;
      default:
        return Icons.category_outlined;
    }
  }

  Widget _buildCategoryImage(String? image, String? name, bool isSelected) {
    if (image != null && image.isNotEmpty) {
      return Image.network(
        image,
        height: 30,
        width: 30,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            _getIcon(name),
            size: 26,
            color: isSelected ? Colors.black : _greyText,
          );
        },
      );
    } else {
      return Icon(
        _getIcon(name),
        size: 26,
        color: isSelected ? Colors.black : _greyText,
      );
    }
  }

  Widget _buildResidentialCategoriesSection(
      List<FilterSubCategory> categories, String title) {
    if (categories.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("${title} Categories"),
        SizedBox(
          height: 44,
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.black : _borderColor,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    item.name ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? Colors.white : Colors.black87,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Price Range'),
        Row(
          children: [
            Expanded(
              child: _buildEditableRangeField(
                  _priceMinController, '0', 'AED'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('to',
                  style: TextStyle(fontSize: 15, color: Colors.black)),
            ),
            Expanded(
              child: _buildEditableRangeField(
                  _priceMaxController, 'Any', 'AED'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditableRangeField(
      TextEditingController controller, String hint, String suffix) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: _greyText, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
            ),
          ),
          Text(suffix,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _greyText)),
        ],
      ),
    );
  }

  Widget _buildDynamicFilterSection(FilterItem filter) {
    final filterName = filter.name ?? '';
    if (filterName.isEmpty) return const SizedBox();

    // Text or Number input filter
    if (filter.type == 'text' || filter.type == 'number') {
      _filterTextControllers.putIfAbsent(
          filterName, () => TextEditingController());
      final controller = _filterTextControllers[filterName]!;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(filterName),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(8),
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
              decoration: InputDecoration(
                hintText: filter.placeholder ?? 'Enter $filterName',
                hintStyle: const TextStyle(color: _greyText, fontSize: 15),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    if (filter.values.isEmpty) return const SizedBox();

    // Multi-select filter (e.g. Amenities, Listed By)
    if (filter.multiSelect) {
      if (!_selectedFilters.containsKey(filterName) ||
          _selectedFilters[filterName] is! Set<String>) {
        _selectedFilters[filterName] = <String>{};
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
              return _buildToggleChip(
                val,
                isSelected,
                () {
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
    final selectedVal = _selectedFilters[filterName] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(filterName),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filter.values.map((val) {
            final isSelected = selectedVal == val;
            return GestureDetector(
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
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.black : _borderColor,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  val,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildToggleChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.black : _borderColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildExcludeLocationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Exclude locations'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _excludeLocationController,
            decoration: const InputDecoration(
              hintText: 'e.g. Dubai Marina',
              hintStyle: TextStyle(color: _greyText, fontSize: 15),
              prefixIcon: Icon(Icons.location_off_outlined,
                  color: _greyText, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Keyword'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _keywordController,
            decoration: const InputDecoration(
              hintText: 'e.g. Pool, Security, Ref ID',
              hintStyle: TextStyle(color: _greyText, fontSize: 15),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRealEstateAgenciesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Real Estate Agencies'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _agencyController,
            decoration: const InputDecoration(
              hintText: 'e.g. Agency name',
              hintStyle: TextStyle(color: _greyText, fontSize: 15),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoreFiltersSection() {
    final filters = [
      {'icon': Icons.abc, 'label': 'Ads in\nEnglish'},
      {'icon': Icons.play_circle_outline, 'label': 'Ads with\nVideo'},
      {'icon': Icons.rotate_left, 'label': 'Ads with\n360 View'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('More Filters'),
        Row(
          children: filters.map((f) {
            final label = f['label'] as String;
            final isSelected = _selectedMoreFilters.contains(label);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedMoreFilters.remove(label);
                    } else {
                      _selectedMoreFilters.add(label);
                    }
                  });
                  _onFilterChanged();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.black.withValues(alpha: 0.05)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.black : _borderColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        f['icon'] as IconData,
                        size: 28,
                        color: isSelected ? Colors.black : _greyText,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.black : _greyText,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildShowResultsButton() {
    final countFormatted = _resultCount
        .toString()
        .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _applyFiltersAndNavigate,
          style: ElevatedButton.styleFrom(
            backgroundColor: _redColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: _isLoadingCount
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Show $countFormatted Results',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}