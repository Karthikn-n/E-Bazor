import 'dart:async';
import 'dart:convert';
import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';
import 'package:Ebozor/data/model/property_filter_category_resolver.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
            id: int.tryParse(args['catID']?.toString() ?? ''),
            name: args['catName']?.toString() ?? 'Properties',
            slug:
                args['categorySlug']?.toString() ?? args['catSlug']?.toString(),
          );
      initialFilter = args['appliedFilter'] as ItemFilterModel?;
      isFromItemsList = args['isFromItemsList'] == true;
      initialFilterConfiguration =
          args['filterConfiguration'] as FilterCategory?;
    } else {
      category = CategoryModel(name: "Properties");
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
  String selectedSlug = '';

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
  final Map<String, dynamic> _selectedFilters = {};
  final Set<String> _expandedMultiselectFilters = {};
  final List<FilterCategory> _genericCategoryHistory = [];

  // Text / single numeric input dynamic filters stored per filter name
  final Map<String, TextEditingController> _filterTextControllers = {};

  // Range Min / Max controllers for numeric range filters
  final Map<String, TextEditingController> _rangeMinControllers = {};
  final Map<String, TextEditingController> _rangeMaxControllers = {};
  final Map<String, RangeValues> _rangeSliderValues = {};
  final List<TextEditingController> _retiredFilterControllers = [];

  // Location fields
  final TextEditingController _locationController = TextEditingController();
  String _selectedCountry = "";
  String _selectedState = "";
  String _selectedCity = "";
  String _selectedArea = "";
  int? _selectedAreaId;
  int? _selectedRadius;
  double? _selectedLat;
  double? _selectedLong;

  // More Filters section
  bool _adsInEnglish = false;
  bool _adsWithVideo = false;
  bool _adsWith360Tour = false;

  // Live count state
  int _resultCount = 0;
  bool _isLoadingCount = false;
  Timer? _countDebounceTimer;
  int _countRequestId = 0;

  bool get _isPropertyCategory {
    return PropertyFilterCategoryResolver.isPropertyCategory(
      CategoryModel(
        name: widget.category.name,
        slug: widget.initialFilterConfiguration?.slug ??
            widget.initialFilter?.categorySlug ??
            widget.category.slug,
      ),
    );
  }

  String get _defaultLocationLabel {
    final values = [
      HiveUtils.getCityName(),
      HiveUtils.getStateName(),
      HiveUtils.getCountryName(),
    ];
    return values
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .firstOrNull ??
        '';
  }

  bool get _hasSelectedSubcategory {
    if (!_isPropertyCategory) {
      return _genericCategoryHistory.isNotEmpty && selectedSlug.isNotEmpty;
    }

    final state = cubit.state;
    if (state is! FilterLoaded ||
        _selectedCategory < 0 ||
        _selectedCategory >= state.data.children.length) {
      return false;
    }
    final category = state.data.children[_selectedCategory];
    final name = category.name?.trim().toLowerCase() ?? '';
    final slug = category.slug?.trim().toLowerCase() ?? '';
    return !name.startsWith('all') && !slug.endsWith('-all');
  }

  List<CategoryModel> get _categoryTrees {
    final state = context.read<FetchCategoryCubit>().state;
    return state is FetchCategorySuccess
        ? state.categories
        : const <CategoryModel>[];
  }

  CategoryModel? _getRootCategoryForTab(int tabIndex) {
    return PropertyFilterCategoryResolver.rootFor(
      tab: PropertyFilterTab.values[tabIndex],
      categoryTrees: _categoryTrees,
      currentCategory: widget.category,
    );
  }

  List<CategoryModel> _getPropertyTypesForTab(int tabIndex) {
    return PropertyFilterCategoryResolver.propertyTypesFor(
      tab: PropertyFilterTab.values[tabIndex],
      categoryTrees: _categoryTrees,
      currentCategory: widget.category,
    );
  }

  List<FilterItem> _sortedActiveFilters(FilterCategory category) {
    final filters = category.filters
        .where((filter) =>
            filter.isActive &&
            filter.name != null &&
            filter.name!.trim().isNotEmpty)
        .toList();
    filters.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return filters;
  }

  @override
  void initState() {
    super.initState();
    cubit = context.read<FilterCubit>();

    final selectedCategorySlug =
        widget.initialFilter?.categorySlug ?? widget.category.slug;
    if (_isPropertyCategory) {
      final requestedCategory = CategoryModel(
        name: widget.category.name,
        slug: widget.initialFilterConfiguration?.slug ??
            selectedCategorySlug ??
            widget.category.slug,
      );
      _selectedTab =
          PropertyFilterCategoryResolver.tabFor(requestedCategory).index;

      final tabPropertyTypes = _getPropertyTypesForTab(_selectedTab);
      final initialSlug =
          widget.initialFilterConfiguration?.slug?.isNotEmpty == true
              ? widget.initialFilterConfiguration!.slug!
              : (selectedCategorySlug?.isNotEmpty == true)
                  ? selectedCategorySlug!
                  : (tabPropertyTypes.isNotEmpty
                      ? (tabPropertyTypes.first.slug ?? '')
                      : (_getRootCategoryForTab(_selectedTab)?.slug ?? ''));

      final propertyTypeIndex = tabPropertyTypes.indexWhere(
        (category) =>
            category.slug == initialSlug || category.id == widget.category.id,
      );
      if (propertyTypeIndex >= 0) {
        _selectedPropertyType = propertyTypeIndex;
        selectedSlug = tabPropertyTypes[propertyTypeIndex].slug ?? initialSlug;
      } else {
        _selectedPropertyType = 0;
        selectedSlug = tabPropertyTypes.isNotEmpty
            ? (tabPropertyTypes.first.slug ?? initialSlug)
            : initialSlug;
      }
    } else {
      selectedSlug =
          widget.initialFilterConfiguration?.slug?.trim().isNotEmpty == true
              ? widget.initialFilterConfiguration!.slug!.trim()
              : (selectedCategorySlug ?? '').trim();
    }

    final appliedCategorySlug = widget.initialFilter?.categorySlug;
    if (widget.initialFilterConfiguration != null &&
        appliedCategorySlug != null) {
      _selectedCategory = widget.initialFilterConfiguration!.children
          .indexWhere((category) => category.slug == appliedCategorySlug);
      if (!_isPropertyCategory &&
          appliedCategorySlug != widget.initialFilterConfiguration!.slug) {
        _genericCategoryHistory.add(widget.initialFilterConfiguration!);
      }
    }

    if (selectedSlug.isNotEmpty) cubit.fetchFilters(selectedSlug);

    _selectedCity = widget.initialFilter?.city ?? HiveUtils.getCityName() ?? "";
    _selectedState =
        widget.initialFilter?.state ?? HiveUtils.getStateName() ?? "";
    _selectedCountry =
        widget.initialFilter?.country ?? HiveUtils.getCountryName() ?? "";
    _selectedArea = widget.initialFilter?.area ?? "";
    _selectedAreaId = widget.initialFilter?.areaId;
    _selectedRadius = widget.initialFilter?.radius;
    _selectedLat = widget.initialFilter?.latitude;
    _selectedLong = widget.initialFilter?.longitude;

    _locationController.text = _selectedArea.isNotEmpty
        ? _selectedArea
        : _selectedCity.isNotEmpty
            ? _selectedCity
            : _selectedCountry;

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
        if (k == 'ads_in_english' || k == 'language') {
          _adsInEnglish = true;
        } else if (k == 'has_video' || k == 'video_link' || k == 'with_video') {
          _adsWithVideo = true;
        } else if (k == 'has_360_tour' ||
            k == 'threeD_image' ||
            k == 'virtual_tour') {
          _adsWith360Tour = true;
        } else if (v is List) {
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
    for (var controller in _retiredFilterControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFilterChanged() {
    _updateItemCount();
  }

  void _clearDynamicFilterSelections() {
    final controllersToDispose = <TextEditingController>[
      ..._filterTextControllers.values,
      ..._rangeMinControllers.values,
      ..._rangeMaxControllers.values,
    ];
    _selectedFilters.clear();
    _expandedMultiselectFilters.clear();
    _filterTextControllers.clear();
    _rangeMinControllers.clear();
    _rangeMaxControllers.clear();
    _rangeSliderValues.clear();
    _retiredFilterControllers.addAll(controllersToDispose);
  }

  void _openGenericCategory(FilterSubCategory category) {
    final slug = category.slug?.trim() ?? '';
    final state = cubit.state;
    if (_isPropertyCategory || slug.isEmpty || state is FilterLoading) return;

    final FilterCategory? visibleParent = state is FilterLoaded
        ? (state.data.children.isNotEmpty
            ? state.data
            : (_genericCategoryHistory.isNotEmpty
                ? _genericCategoryHistory.last
                : state.data))
        : (_genericCategoryHistory.isNotEmpty
            ? _genericCategoryHistory.last
            : null);
    if (visibleParent == null) return;
    final currentParentSlug = visibleParent.slug?.trim() ?? '';
    final lastHistorySlug = _genericCategoryHistory.isNotEmpty
        ? (_genericCategoryHistory.last.slug?.trim() ?? '')
        : '';
    if (_genericCategoryHistory.isEmpty ||
        currentParentSlug != lastHistorySlug) {
      _genericCategoryHistory.add(visibleParent);
    }
    _clearDynamicFilterSelections();
    setState(() {
      selectedSlug = slug;
      _selectedCategory = -1;
    });
    cubit.fetchFilters(slug);
    _onFilterChanged();
  }

  void _returnToPreviousGenericCategory() {
    if (_genericCategoryHistory.isEmpty) return;
    final previous = _genericCategoryHistory.removeLast();
    final slug = previous.slug?.trim() ?? '';
    if (slug.isEmpty) return;

    _clearDynamicFilterSelections();
    setState(() {
      selectedSlug = slug;
      _selectedCategory = -1;
    });
    cubit.fetchFilters(slug);
    _onFilterChanged();
  }

  List<FilterSubCategory> _visibleGenericCategories(FilterState state) {
    if (state is FilterLoaded && state.data.children.isNotEmpty) {
      return state.data.children;
    }
    if (_genericCategoryHistory.isNotEmpty) {
      return _genericCategoryHistory.last.children;
    }
    return state is FilterLoaded
        ? state.data.children
        : const <FilterSubCategory>[];
  }

  String _visibleGenericCategoryTitle(FilterState state) {
    if (state is FilterLoaded && state.data.children.isNotEmpty) {
      return state.data.name ?? 'Categories';
    }
    if (_genericCategoryHistory.isNotEmpty) {
      return _genericCategoryHistory.last.name ?? 'Categories';
    }
    return state is FilterLoaded
        ? (state.data.name ?? 'Categories')
        : 'Categories';
  }

  Widget _buildGenericBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _returnToPreviousGenericCategory,
        icon: const Icon(Icons.arrow_back_rounded),
        label: Text(
          'Back to ${_genericCategoryHistory.last.name ?? 'Categories'}',
        ),
      ),
    );
  }

  int get _appliedFiltersCount {
    int count = 0;
    if (_hasSelectedSubcategory) count++;
    if (_priceMinController.text.isNotEmpty ||
        _priceMaxController.text.isNotEmpty) count++;
    if (_selectedArea.isNotEmpty ||
        (_locationController.text.isNotEmpty &&
            _locationController.text != _defaultLocationLabel)) {
      count++;
    }
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
    if (_adsInEnglish) count++;
    if (_adsWithVideo) count++;
    if (_adsWith360Tour) count++;
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
          if (_selectedCity.isNotEmpty)
            "city": _selectedCity
          else if (_selectedCountry.isEmpty &&
              _selectedState.isEmpty &&
              _locationController.text.trim().isNotEmpty &&
              _locationController.text.trim() != _defaultLocationLabel)
            "city": _locationController.text.trim()
          else if (_selectedCountry.isEmpty &&
              _selectedState.isEmpty &&
              HiveUtils.getCityName() != null &&
              HiveUtils.getCityName()!.isNotEmpty)
            "city": HiveUtils.getCityName(),
          if (_selectedState.isNotEmpty)
            "state": _selectedState
          else if (_selectedCountry.isEmpty &&
              HiveUtils.getStateName() != null &&
              HiveUtils.getStateName()!.isNotEmpty)
            "state": HiveUtils.getStateName(),
          if (_selectedCountry.isNotEmpty)
            "country": _selectedCountry
          else if (HiveUtils.getCountryName() != null &&
              HiveUtils.getCountryName()!.isNotEmpty)
            "country": HiveUtils.getCountryName(),
          if (_selectedAreaId != null) "area_id": _selectedAreaId,
          if (_selectedRadius != null) "radius": _selectedRadius,
          if (_selectedLat != null) "latitude": _selectedLat,
          if (_selectedLong != null) "longitude": _selectedLong,
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

        // Add More Filters parameters
        if (_adsInEnglish) {
          queryParams["language"] = "English";
          queryParams["ads_in_english"] = "1";
        }
        if (_adsWithVideo) {
          queryParams["video_link"] = "1";
          queryParams["has_video"] = "1";
        }
        if (_adsWith360Tour) {
          queryParams["threeD_image"] = "1";
          queryParams["has_360_tour"] = "1";
        }

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

  void _onTapChooseLocation() async {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pushNamed(context, Routes.countriesScreen,
        arguments: {"from": "filter"}).then((value) {
      if (value != null) {
        Map<String, dynamic> location = value as Map<String, dynamic>;

        setState(() {
          _selectedArea = location["area"] ?? "";
          _selectedCity = location["city"] ?? "";
          _selectedAreaId = location["area_id"] != null
              ? int.tryParse(location["area_id"].toString())
              : null;
          _selectedRadius = location["radius"] != null
              ? int.tryParse(location["radius"].toString())
              : null;
          _selectedCountry = location["country"] ?? "";
          _selectedState = location["state"] ?? "";
          _selectedLat = location["latitude"] != null
              ? double.tryParse(location["latitude"].toString())
              : null;
          _selectedLong = location["longitude"] != null
              ? double.tryParse(location["longitude"].toString())
              : null;

          final displayLoc = _selectedArea.isNotEmpty
              ? _selectedArea
              : _selectedCity.isNotEmpty
                  ? _selectedCity
                  : _selectedState.isNotEmpty
                      ? _selectedState
                      : _selectedCountry;

          _locationController.text = displayLoc;
        });
        _onFilterChanged();
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
          _selectedCity = locName;
          _selectedLat = position.latitude;
          _selectedLong = position.longitude;
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
    final genericRoot =
        !_isPropertyCategory && _genericCategoryHistory.isNotEmpty
            ? _genericCategoryHistory.first
            : null;
    _clearDynamicFilterSelections();
    setState(() {
      _selectedCategory = -1;
      if (genericRoot != null) {
        _genericCategoryHistory.clear();
        selectedSlug = genericRoot.slug?.trim() ?? selectedSlug;
      }
      _priceMinController.clear();
      _priceMaxController.clear();
      _selectedCity = HiveUtils.getCityName() ?? "";
      _selectedState = HiveUtils.getStateName() ?? "";
      _selectedCountry = HiveUtils.getCountryName() ?? "";
      _selectedArea = "";
      _selectedAreaId = null;
      _selectedLat = null;
      _selectedLong = null;
      _selectedRadius = null;
      _locationController.text = _defaultLocationLabel;
      _adsInEnglish = false;
      _adsWithVideo = false;
      _adsWith360Tour = false;
    });
    if (genericRoot != null && selectedSlug.isNotEmpty) {
      cubit.fetchFilters(selectedSlug);
    }
    _onFilterChanged();
  }

  void _applyFiltersAndNavigate() {
    final propertyTypes = _isPropertyCategory
        ? _getPropertyTypesForTab(_selectedTab)
        : const <CategoryModel>[];
    final selectedBaseCategory = _isPropertyCategory
        ? (_selectedPropertyType >= 0 &&
                _selectedPropertyType < propertyTypes.length
            ? propertyTypes[_selectedPropertyType]
            : _getRootCategoryForTab(_selectedTab) ?? widget.category)
        : CategoryModel(
            id: widget.initialFilterConfiguration?.id ?? widget.category.id,
            name:
                widget.initialFilterConfiguration?.name ?? widget.category.name,
            slug: widget.initialFilterConfiguration?.slug ??
                (selectedSlug.isNotEmpty
                    ? selectedSlug
                    : widget.category.slug ?? ''),
          );
    String activeCategoryId = selectedBaseCategory.id?.toString() ?? '';
    String activeCategoryName = selectedBaseCategory.name ?? "Category";
    String activeCategorySlug = selectedBaseCategory.slug ?? selectedSlug;
    final filterState = cubit.state;
    if (filterState is FilterLoaded && filterState.data.slug == selectedSlug) {
      activeCategoryId = filterState.data.id?.toString() ?? activeCategoryId;
      activeCategoryName = filterState.data.name ?? activeCategoryName;
      activeCategorySlug = filterState.data.slug ?? activeCategorySlug;
      if (_selectedCategory >= 0 &&
          _selectedCategory < filterState.data.children.length) {
        final child = filterState.data.children[_selectedCategory];
        if (child.slug != null &&
            child.slug!.isNotEmpty &&
            !child.slug!.endsWith('-all')) {
          activeCategoryId = child.id?.toString() ?? activeCategoryId;
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

    if (_adsInEnglish) {
      customFieldFilterMap["ads_in_english"] = "1";
      customFieldFilterMap["language"] = "English";
    }
    if (_adsWithVideo) {
      customFieldFilterMap["has_video"] = "1";
      customFieldFilterMap["video_link"] = "1";
    }
    if (_adsWith360Tour) {
      customFieldFilterMap["has_360_tour"] = "1";
      customFieldFilterMap["threeD_image"] = "1";
    }

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
      city: _selectedCity.isNotEmpty
          ? _selectedCity
          : (_selectedCountry.isEmpty &&
                  _selectedState.isEmpty &&
                  _locationController.text.trim().isNotEmpty &&
                  _locationController.text.trim() != _defaultLocationLabel)
              ? _locationController.text.trim()
              : (_selectedCountry.isEmpty && _selectedState.isEmpty
                  ? (HiveUtils.getCityName() ?? "")
                  : ""),
      state: _selectedState.isNotEmpty
          ? _selectedState
          : (_selectedCountry.isEmpty ? (HiveUtils.getStateName() ?? "") : ""),
      country: _selectedCountry.isNotEmpty
          ? _selectedCountry
          : (HiveUtils.getCountryName() ?? ""),
      area: _selectedArea,
      areaId: _selectedAreaId,
      radius: _selectedRadius,
      latitude: _selectedLat,
      longitude: _selectedLong,
      customFields:
          customFieldFilterMap.isNotEmpty ? customFieldFilterMap : null,
    );

    Constant.itemFilter = appliedFilter;

    final categoryChain = <CategoryModel>[];
    final categoryIds = <String>[];
    void addToChain(CategoryModel category) {
      final id = category.id?.toString();
      final slug = category.slug;
      if (categoryChain.any((existing) =>
          (id != null && existing.id?.toString() == id) ||
          (slug != null && slug.isNotEmpty && existing.slug == slug))) {
        return;
      }
      categoryChain.add(category);
      if (id != null && id.isNotEmpty) categoryIds.add(id);
    }

    if (_isPropertyCategory) {
      final tabRoot = _getRootCategoryForTab(_selectedTab);
      if (tabRoot != null) addToChain(tabRoot);
    } else {
      addToChain(widget.category);
      for (final category in _genericCategoryHistory) {
        addToChain(CategoryModel(
          id: category.id,
          name: category.name,
          slug: category.slug,
        ));
      }
    }
    addToChain(selectedBaseCategory);
    addToChain(CategoryModel(
      id: int.tryParse(activeCategoryId),
      name: activeCategoryName,
      slug: activeCategorySlug,
      children: const [],
      subcategoriesCount: 0,
    ));

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
                  final tabPropertyTypes = _getPropertyTypesForTab(i);
                  final rootCategory = _getRootCategoryForTab(i);
                  final targetCategory = tabPropertyTypes.isNotEmpty
                      ? tabPropertyTypes.first
                      : rootCategory;
                  final targetSlug = targetCategory?.slug ?? '';
                  if (targetSlug.isEmpty) return;

                  _clearDynamicFilterSelections();
                  setState(() {
                    _selectedTab = i;
                    _selectedPropertyType = 0;
                    _selectedCategory = -1;
                    selectedSlug = targetSlug;
                  });
                  cubit.fetchFilters(targetSlug);
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
        InkWell(
          onTap: _onTapChooseLocation,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.6),
              ),
            ),
            child: IgnorePointer(
              ignoring: true,
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
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyTypeSection(List<CategoryModel> propertyTypes) {
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
                    final slug = item.slug ?? '';
                    if (slug.isEmpty) return;
                    _clearDynamicFilterSelections();
                    setState(() {
                      _selectedPropertyType = i;
                      _selectedCategory = -1;
                      selectedSlug = slug;
                    });
                    cubit.fetchFilters(slug);
                    _onFilterChanged();
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
      case 'new projects':
        return Icons.apartment_rounded;
      case 'off-plan':
        return Icons.architecture_rounded;
      case 'land':
        return Icons.landscape_rounded;
      case 'multiple units':
        return Icons.holiday_village_rounded;
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
              final isSelected = _isPropertyCategory
                  ? _selectedCategory == i
                  : item.slug?.trim() == selectedSlug.trim();

              return GestureDetector(
                onTap: () {
                  if (!_isPropertyCategory) {
                    _openGenericCategory(item);
                    return;
                  }
                  final name = item.name?.trim().toLowerCase() ?? '';
                  final slug = item.slug?.trim().toLowerCase() ?? '';
                  final selectsAll =
                      name.startsWith('all') || slug.endsWith('-all');
                  setState(() {
                    _selectedCategory =
                        selectsAll || _selectedCategory == i ? -1 : i;
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
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: context.color.textDefaultColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: context.color.textLightColor,
            fontSize: 13,
          ),
          suffixText: suffix,
          suffixStyle: TextStyle(
            color: context.color.textLightColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicFilterSection(FilterItem filter) {
    final filterName = filter.name;
    if (filterName == null || filterName.isEmpty) return const SizedBox();

    final filterType = filter.type?.toLowerCase() ?? '';

    if (filterType == 'range' ||
        filterType == 'number_range' ||
        filterType == 'numeric_range') {
      final initialValue = _selectedFilters.remove(filterName);
      final initialValues = initialValue is Iterable
          ? initialValue.map((value) => value.toString()).toList()
          : const <String>[];
      _rangeMinControllers.putIfAbsent(
        filterName,
        () => TextEditingController(
          text: initialValues.isNotEmpty ? initialValues.first : '',
        ),
      );
      _rangeMaxControllers.putIfAbsent(
        filterName,
        () => TextEditingController(
          text: initialValues.length > 1 ? initialValues[1] : '',
        ),
      );
      return _buildRangeInputs(
        fieldKey: filterName,
        title: filterName,
        minController: _rangeMinControllers[filterName]!,
        maxController: _rangeMaxControllers[filterName]!,
        unit: filterName.toLowerCase().contains('sqft')
            ? 'Sqft'
            : filterName.toLowerCase().contains('km')
                ? 'Km'
                : '',
        maxLimit: filterName.toLowerCase().contains('sqft') ? 50000 : 500000,
      );
    }

    if (filterType == 'text' || filterType == 'number') {
      final initialValue = _selectedFilters.remove(filterName);
      final initialText = initialValue is Iterable
          ? (initialValue.isEmpty ? '' : initialValue.first.toString())
          : initialValue?.toString() ?? '';
      _filterTextControllers.putIfAbsent(
        filterName,
        () => TextEditingController(text: initialText),
      );
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
              controller: _filterTextControllers[filterName],
              keyboardType: filterType == 'number'
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontSize: 14,
              ),
              onChanged: (_) {
                setState(() {});
                _onFilterChanged();
              },
              decoration: InputDecoration(
                hintText: filter.placeholder?.trim().isNotEmpty == true
                    ? filter.placeholder
                    : "Enter $filterName",
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

    if (filter.multiSelect) {
      final initialVal = _selectedFilters[filterName];
      final Set<String> selectedSet;
      if (initialVal is Set<String>) {
        selectedSet = initialVal;
      } else if (initialVal is Iterable) {
        selectedSet = Set<String>.from(initialVal.map((e) => e.toString()));
      } else if (initialVal != null && initialVal.toString().isNotEmpty) {
        selectedSet = {initialVal.toString()};
      } else {
        selectedSet = <String>{};
      }
      _selectedFilters[filterName] = selectedSet;
      final canExpand = filterType == 'button' && filter.values.length > 5;
      final isExpanded = _expandedMultiselectFilters.contains(filterName);
      final visibleValues = canExpand && !isExpanded
          ? filter.values.take(5).toList()
          : filter.values;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(filterName),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleValues.map((val) {
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
          if (canExpand) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (isExpanded) {
                    _expandedMultiselectFilters.remove(filterName);
                  } else {
                    _expandedMultiselectFilters.add(filterName);
                  }
                });
              },
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 19,
              ),
              label: Text(
                isExpanded
                    ? 'Show less'
                    : 'Show more (${filter.values.length - 5})',
              ),
              style: TextButton.styleFrom(
                foregroundColor: context.color.territoryColor,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      );
    }

    final initialValue = _selectedFilters[filterName];
    final String? selectedVal;
    if (initialValue is Iterable) {
      final values = initialValue.map((e) => e.toString()).toList();
      selectedVal = values.isEmpty ? null : values.first;
    } else {
      selectedVal = initialValue?.toString();
    }
    _selectedFilters[filterName] = selectedVal ?? '';

    if (filterType == 'dropdown') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(filterName),
          DropdownButtonFormField<String>(
            key: ValueKey('$filterName-$selectedVal'),
            initialValue:
                filter.values.contains(selectedVal) ? selectedVal : null,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: filter.placeholder?.trim().isNotEmpty == true
                  ? filter.placeholder
                  : 'Select $filterName',
              filled: true,
              fillColor: context.color.secondaryColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: context.color.borderColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            items: filter.values
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                if (value == null || value.isEmpty) {
                  _selectedFilters.remove(filterName);
                } else {
                  _selectedFilters[filterName] = value;
                }
              });
              _onFilterChanged();
            },
          ),
        ],
      );
    }

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

  Widget _buildMoreFiltersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('More Filters'.translate(context)),
        Row(
          children: [
            // Expanded(
            //   child: _buildMoreFilterCard(
            //     iconWidget: const Text(
            //       "ABC",
            //       style: TextStyle(
            //         fontSize: 14,
            //         fontWeight: FontWeight.w900,
            //         letterSpacing: 1.1,
            //       ),
            //     ),
            //     label: "Ads in\nEnglish".translate(context),
            //     isSelected: _adsInEnglish,
            //     onTap: () {
            //       setState(() => _adsInEnglish = !_adsInEnglish);
            //       _onFilterChanged();
            //     },
            //   ),
            // ),
            // const SizedBox(width: 10),
            Expanded(
              child: _buildMoreFilterCard(
                iconWidget: const Icon(
                  Icons.play_circle_outline_rounded,
                  size: 26,
                ),
                label: "Ads with\nVideo".translate(context),
                isSelected: _adsWithVideo,
                onTap: () {
                  setState(() => _adsWithVideo = !_adsWithVideo);
                  _onFilterChanged();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMoreFilterCard(
                iconWidget: const Icon(
                  Icons.rotate_right_rounded,
                  size: 28,
                ),
                label: "Ads with\n360 Tour".translate(context),
                isSelected: _adsWith360Tour,
                onTap: () {
                  setState(() => _adsWith360Tour = !_adsWith360Tour);
                  _onFilterChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoreFilterCard({
    required Widget iconWidget,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? context.color.territoryColor.withValues(alpha: 0.12)
              : context.color.secondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.color.territoryColor
                : context.color.borderColor.withValues(alpha: 0.6),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DefaultTextStyle(
              style: TextStyle(
                color: isSelected
                    ? context.color.territoryColor
                    : context.color.textDefaultColor,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: isSelected
                      ? context.color.territoryColor
                      : context.color.textDefaultColor,
                ),
                child: iconWidget,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? context.color.territoryColor
                    : context.color.textDefaultColor,
                height: 1.2,
              ),
            ),
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
    final propertyTypes = _getPropertyTypesForTab(_selectedTab);

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
                final genericCategories = _isPropertyCategory
                    ? const <FilterSubCategory>[]
                    : _visibleGenericCategories(state);
                final genericCategoryTitle = _isPropertyCategory
                    ? 'Categories'
                    : _visibleGenericCategoryTitle(state);
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

                      if (!_isPropertyCategory &&
                          (genericCategories.isNotEmpty ||
                              _genericCategoryHistory.isNotEmpty)) ...[
                        if (genericCategories.isNotEmpty)
                          _buildSubCategoriesSection(
                            genericCategories,
                            genericCategoryTitle,
                          ),
                        if (_genericCategoryHistory.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _buildGenericBackButton(),
                        ],
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
                        if (_isPropertyCategory &&
                            state.data.children.isNotEmpty) ...[
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

                      // More Filters Section (Ads in English, Ads with Video, Ads with 360 Tour)
                      const SizedBox(height: 10),
                      _buildMoreFiltersSection(),

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
