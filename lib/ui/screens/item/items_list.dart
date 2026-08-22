import 'dart:async';
import 'dart:math';
import 'package:Ebozor/utils/string_extenstion.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/item/fetch_item_from_category_cubit.dart';
import 'package:Ebozor/data/cubits/category/fetch_sub_categories_cubit.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';

import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/home/widgets/home_sections_adapter.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/home/widgets/item_horizontal_card.dart';
import 'package:Ebozor/ui/screens/main_activity.dart';
import 'package:Ebozor/ui/screens/native_ads_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';

class ItemsList extends StatefulWidget {
  final String categoryId, categoryName;
  final List<String>? categoryIds;
  final List<CategoryModel>? selectedCategoryChain;
  final ItemFilterModel? appliedFilter;

  const ItemsList(
      {super.key,
        required this.categoryId,
        required this.categoryName,
        this.categoryIds,
        this.selectedCategoryChain,
        this.appliedFilter});

  @override
  ItemsListState createState() => ItemsListState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ItemsList(
        categoryId: (arguments?['catID'] ?? "").toString(),
        categoryName: (arguments?['catName'] ?? "").toString(),
        categoryIds: arguments?['categoryIds'] != null
            ? List<String>.from(arguments!['categoryIds'])
            : [],
        selectedCategoryChain: arguments?['selectedCategoryChain'] as List<CategoryModel>?,
        appliedFilter: arguments?['appliedFilter'] as ItemFilterModel?,
      ),
    );
  }
}

class ItemsListState extends State<ItemsList> {
  late ScrollController controller;
  static TextEditingController searchController = TextEditingController();
  bool isFocused = false;
  bool isList = true;
  String previousSearchQuery = "";
  Timer? _searchDelay;
  String? sortBy;
  ItemFilterModel? filter;

  // For dynamic filtering
  late List<CategoryModel> _currentChain;
  late final FetchSubCategoriesCubit _chipFilterCubit;
  List<String> _currentCategoryIds = [];

  bool _showVerifiedOnly = false;
  int _segmentFilterIndex = 0; // 0: All, 1: Furnished, 2: Unfurnished

  void _launchCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(context, "Phone number not available");
      return;
    }
    final url = Uri.parse("tel:${phone.trim()}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      HelperUtils.showSnackBarMessage(context, "Could not launch phone call");
    }
  }

  void _launchWhatsApp(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(context, "WhatsApp number not available");
      return;
    }
    String cleanNumber = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse("https://wa.me/$cleanNumber");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      HelperUtils.showSnackBarMessage(context, "Could not open WhatsApp");
    }
  }

  Widget _favButton(BuildContext context, ItemModel item) {
    if (item.id == null) return const SizedBox.shrink();
    bool isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);

    return BlocProvider(
      create: (context) => UpdateFavoriteCubit(FavoriteRepository()),
      child: BlocConsumer<FavoriteCubit, FavoriteState>(
        bloc: context.read<FavoriteCubit>(),
        listener: ((context, state) {
          if (state is FavoriteFetchSuccess) {
            isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);
          }
        }),
        builder: (context, likeAndDislikeState) {
          return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
            bloc: context.read<UpdateFavoriteCubit>(),
            listener: ((context, state) {
              if (state is UpdateFavoriteSuccess) {
                if (state.wasProcess) {
                  context.read<FavoriteCubit>().addFavoriteitem(state.item);
                } else {
                  context.read<FavoriteCubit>().removeFavoriteItem(state.item);
                }
              }
            }),
            builder: (context, state) {
              return InkWell(
                onTap: () {
                  UiUtils.checkUser(
                    onNotGuest: () {
                      context.read<UpdateFavoriteCubit>().setFavoriteItem(
                            item: item,
                            type: isLike ? 0 : 1,
                          );
                    },
                    context: context,
                  );
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: state is UpdateFavoriteInProgress
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isLike ? Icons.favorite : Icons.favorite_border,
                            size: 19,
                            color: isLike ? Colors.red : Colors.white,
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _chipFilterCubit = FetchSubCategoriesCubit();
    // Initialize chain from arguments or empty
    _currentChain = widget.selectedCategoryChain != null
        ? List.from(widget.selectedCategoryChain!)
        : [];
    if (_currentChain.isEmpty && widget.categoryId.isNotEmpty) {
      _currentChain.add(CategoryModel(
          id: int.tryParse(widget.categoryId) ?? 0,
          name: widget.categoryName,
          children: [],
          subcategoriesCount: 0
      ));
    }

    _currentCategoryIds = widget.categoryIds != null
        ? List.from(widget.categoryIds!)
        : [];
    searchbody = {};
    filter = widget.appliedFilter ?? Constant.itemFilter;
    searchController = TextEditingController();
    searchController.addListener(searchItemListener);
    controller = ScrollController()..addListener(_loadMore);

    ItemFilterModel initialFilter = filter ??
        ItemFilterModel(
            country: HiveUtils.getCountryName() ?? "",
            areaId: HiveUtils.getAreaId() != null
                ? int.parse(HiveUtils.getAreaId().toString())
                : null,
            city: HiveUtils.getCityName() ?? "",
            state: HiveUtils.getStateName() ?? "",
            categoryId: widget.categoryId,
            radius: HiveUtils.getNearbyRadius() ?? null,
            latitude: HiveUtils.getLatitude() ?? null,
            longitude: HiveUtils.getLongitude() ?? null);

    filter = initialFilter;
    Constant.itemFilter = initialFilter;

    final catIdInt = int.tryParse(widget.categoryId) ?? 0;
    if (catIdInt != 0) {
      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: catIdInt,
          search: "",
          filter: initialFilter);
    }

    Future.delayed(Duration.zero, () {
      selectedcategoryId = widget.categoryId;
      selectedcategoryName = widget.categoryName;
      searchbody[Api.categoryId] = widget.categoryId;
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.removeListener(_loadMore);
    controller.dispose();
    searchController.dispose();
    _chipFilterCubit.close();
    super.dispose();
  }

  //this will listen and manage search
  void searchItemListener() {
    _searchDelay?.cancel();
    searchCallAfterDelay();
  }

//This will create delay so we don't face rapid api call
  void searchCallAfterDelay() {
    _searchDelay = Timer(const Duration(milliseconds: 500), itemSearch);
  }

  ///This will call api after some delay
  void itemSearch() {
    // if (searchController.text.isNotEmpty) {
    if (previousSearchQuery != searchController.text) {
      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: int.parse(
            widget.categoryId,
          ),
          search: searchController.text);
      previousSearchQuery = searchController.text;
      sortBy = null;
      setState(() {});
    }
  }

  void _loadMore() async {
    if (controller.isEndReached()) {
      if (context.read<FetchItemFromCategoryCubit>().hasMoreData()) {
        context.read<FetchItemFromCategoryCubit>().fetchItemFromCategoryMore(
            catId: int.parse(
              widget.categoryId,
            ),
            search: searchController.text,
            sortBy: sortBy,
            filter: ItemFilterModel(
              country: HiveUtils.getCountryName() ?? "",
              areaId: HiveUtils.getAreaId() != null
                  ? int.parse(HiveUtils.getAreaId().toString())
                  : null,
              city: HiveUtils.getCityName() ?? "",
              state: HiveUtils.getStateName() ?? "",
              categoryId: widget.categoryId,
            ));
      }
    }
  }

  Widget _buildLocationHeader() {
    return Container(
      color: context.color.backgroundColor,
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: context.color.textDefaultColor,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 1,
                  color: context.color.borderColor.withValues(alpha: 0.7),
                ),
                borderRadius: BorderRadius.circular(10),
                color: context.color.secondaryColor,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    Icons.location_on,
                    size: 20,
                    color: context.color.textDefaultColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: searchController,
                      style: TextStyle(
                        color: context.color.textDefaultColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: "Enter Neighborhood or Building",
                        hintStyle: TextStyle(
                          color: context.color.textLightColor,
                          fontSize: 13,
                        ),
                      ),
                      onEditingComplete: () {
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: context.color.textLightColor,
                      ),
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                        final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                        if (catIdInt != 0) {
                          context
                              .read<FetchItemFromCategoryCubit>()
                              .fetchItemFromCategory(
                                categoryId: catIdInt,
                                search: "",
                                filter: filter,
                              );
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _selectedSegmentValue;
  String? _detectedFilterFieldName;

  List<String> _extractDynamicSegments(List<ItemModel> items) {
    if (items.isEmpty) return [];

    Map<String, Set<String>> fieldValues = {};

    for (var item in items) {
      if (item.customFields == null) continue;
      for (var cf in item.customFields!) {
        final fieldName = (cf.name ?? "").trim();
        if (fieldName.isEmpty) continue;

        dynamic rawVal = cf.value;
        String val = "";
        if (rawVal is List && rawVal.isNotEmpty) {
          val = rawVal.first?.toString() ?? "";
        } else if (rawVal != null) {
          val = rawVal.toString();
        }
        val = val.trim();
        if (val.isNotEmpty && val.length < 25) {
          fieldValues.putIfAbsent(fieldName, () => {}).add(val);
        }
      }
    }

    final priorityKeys = [
      "furnished",
      "transmission",
      "condition",
      "fuel type",
      "fuel",
      "body type",
      "job type",
      "property type",
      "type",
    ];

    for (var key in priorityKeys) {
      for (var entry in fieldValues.entries) {
        if (entry.key.toLowerCase().contains(key) &&
            entry.value.length >= 2 &&
            entry.value.length <= 6) {
          _detectedFilterFieldName = entry.key;
          return entry.value.toList();
        }
      }
    }

    for (var entry in fieldValues.entries) {
      if (entry.value.length >= 2 && entry.value.length <= 5) {
        _detectedFilterFieldName = entry.key;
        return entry.value.toList();
      }
    }

    return [];
  }

  Widget _buildDynamicSegmentTabs(List<ItemModel> items) {
    final segmentOptions = _extractDynamicSegments(items);
    if (segmentOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    List<String> allTabs = ["All", ...segmentOptions];

    return Container(
      color: context.color.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: allTabs.map((tabTitle) {
            final isSelected = (tabTitle == "All" && _selectedSegmentValue == null) ||
                (_selectedSegmentValue == tabTitle);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    if (tabTitle == "All") {
                      _selectedSegmentValue = null;
                    } else {
                      _selectedSegmentValue = tabTitle;
                    }
                  });
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE8F1FD)
                        : context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2979FF).withValues(alpha: 0.6)
                          : context.color.borderColor.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      tabTitle,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF1565C0)
                            : context.color.textDefaultColor,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    int activeFilterCount = _currentCategoryIds.length;
    if (activeFilterCount == 0) activeFilterCount = 2;

    return Container(
      color: context.color.backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Filters Badge Button
            GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    Routes.filterScreen,
                    arguments: {
                      "update": getFilterValue,
                      "from": "itemsList",
                      "categoryIds": _currentCategoryIds
                    },
                  ).then((value) {
                    if (value == true && filter != null) {
                      ItemFilterModel updatedFilter =
                          filter!.copyWith(categoryId: widget.categoryId);

                      final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                      if (catIdInt != 0) {
                        context
                            .read<FetchItemFromCategoryCubit>()
                            .fetchItemFromCategory(
                              categoryId: catIdInt,
                              search: searchController.text,
                              filter: updatedFilter,
                            );
                      }
                      setState(() {});
                    }
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.7),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: const Color(0xFFE53935),
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Filters",
                        style: TextStyle(
                          color: context.color.textDefaultColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "$activeFilterCount",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(width: 8),

            // Dynamic Chips
            ...List.generate(_currentChain.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildDynamicChip(index),
              );
            }),

            // All Fields Chip
            _buildChip(
                label: "All Fields",
                isActive: _isAllFieldsSelected,
                showDropdown: false,
                onTap: _onAllFieldsTap),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicChip(int chainIndex) {
    CategoryModel currentModel = _currentChain[chainIndex];
    return _buildChip(
      label: currentModel.name ?? "",
      isActive: !_isAllFieldsSelected, // Inactive if All Fields is selected
      showDropdown: true,
      onTap: () {
        if (_isAllFieldsSelected) {
          _restoreSelection(chainIndex);
        } else {
          _showDynamicFilterBottomSheet(chainIndex);
        }
      },
    );
  }

  bool _isAllFieldsSelected = false;
  final Map<int, List<CategoryModel>> _selectionHistory = {};

  void _onAllFieldsTap() {
    setState(() {
      // Do not clear the chain, just reset the search to root
      _isAllFieldsSelected = true;
      int rootId = int.tryParse((widget.categoryIds != null && widget.categoryIds!.isNotEmpty)
              ? widget.categoryIds![0]
              : widget.categoryId) ??
          0;
      _currentCategoryIds = [rootId.toString()];

      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: rootId,
          search: searchController.text,
          filter: filter);
    });
  }

  void _restoreSelection(int chainIndex) {
    setState(() {
      _isAllFieldsSelected = false;

      // Truncate chain after chainIndex
      if (_currentChain.length > chainIndex + 1) {
        _currentChain.removeRange(chainIndex + 1, _currentChain.length);
      }

      List<String> newIds = [];
      if (widget.categoryIds != null &&
          widget.categoryIds!.isNotEmpty &&
          widget.categoryIds!.length > 1) {
        newIds.add(widget.categoryIds![0]);
      }
      for (var cat in _currentChain) {
        if (cat.id != null && !newIds.contains(cat.id.toString())) {
          newIds.add(cat.id.toString());
        }
      }
      _currentCategoryIds = newIds;

      // Fetch
      CategoryModel? targetCat =
          _currentChain.isNotEmpty ? _currentChain.last : null;
      int targetId = targetCat?.id ?? int.tryParse(widget.categoryId) ?? 0;

      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: targetId,
          search: searchController.text,
          filter: filter);
    });
  }

  CategoryModel? _findCategoryInTree(List<CategoryModel> categories, int targetId) {
    for (var cat in categories) {
      if (cat.id == targetId) return cat;
      if (cat.children != null && cat.children!.isNotEmpty) {
        final found = _findCategoryInTree(cat.children!, targetId);
        if (found != null) return found;
      }
    }
    return null;
  }

  void _showDynamicFilterBottomSheet(int chainIndex) {
    int parentId = 0;
    if (chainIndex == 0) {
      if (widget.categoryIds != null && widget.categoryIds!.length > 1) {
        parentId = int.tryParse(widget.categoryIds![0]) ?? 0;
      } else if (_currentChain.isNotEmpty) {
        parentId = _currentChain[0].id ?? int.tryParse(widget.categoryId) ?? 0;
      } else {
        parentId = int.tryParse(widget.categoryId) ?? 0;
      }
    } else {
      if (chainIndex - 1 < _currentChain.length) {
        parentId = _currentChain[chainIndex - 1].id ?? 0;
      }
    }

    if (parentId != 0) {
      _chipFilterCubit.fetchSubCategories(categoryId: parentId);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        CategoryModel? selectedCategory;
        if (_currentChain.length > chainIndex) {
          selectedCategory = _currentChain[chainIndex];
        }

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Material(
                  color: context.color.secondaryColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: context.color.borderColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Select Category",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: context.color.textDefaultColor)),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Icon(Icons.close,
                                  color: context.color.textDefaultColor),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: BlocProvider.value(
                            value: _chipFilterCubit,
                            child: BlocBuilder<FetchSubCategoriesCubit,
                                FetchSubCategoriesState>(
                              builder: (context, state) {
                                if (state is FetchSubCategoriesInProgress) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                if (state is FetchSubCategoriesSuccess) {
                                  List<CategoryModel> displayCategories = [];
                                  bool isMainCategory = false;

                                  if (parentId != 0) {
                                    final parentModel = _findCategoryInTree(
                                        state.categories, parentId);
                                    if (parentModel != null &&
                                        parentModel.children != null &&
                                        parentModel.children!.isNotEmpty) {
                                      displayCategories = parentModel.children!;
                                      isMainCategory = false;
                                    } else {
                                      displayCategories = state.categories;
                                      isMainCategory = true;
                                    }
                                  } else {
                                    displayCategories = state.categories;
                                    isMainCategory = true;
                                  }

                                  if (displayCategories.isEmpty) {
                                    return Center(
                                      child: Text(
                                        "No subcategories available",
                                        style: TextStyle(
                                            color: context.color.textLightColor),
                                      ),
                                    );
                                  }

                                  if (isMainCategory) {
                                    // Grid View for Main Categories
                                    return GridView.builder(
                                      controller: scrollController,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: displayCategories.length,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.92,
                                      ),
                                      itemBuilder: (context, index) {
                                        CategoryModel cat =
                                            displayCategories[index];
                                        bool isSelected =
                                            selectedCategory?.id == cat.id;

                                        return Material(
                                          color: isSelected
                                              ? context.color.territoryColor
                                                  .withValues(alpha: 0.1)
                                              : context.color.backgroundColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () {
                                              setModalState(() {
                                                selectedCategory = cat;
                                              });
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? context
                                                          .color.territoryColor
                                                      : context.color.borderColor,
                                                  width: isSelected ? 1.5 : 1,
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 8),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 44,
                                                    height: 44,
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: isSelected
                                                          ? context.color
                                                              .territoryColor
                                                              .withValues(
                                                                  alpha: 0.15)
                                                          : context.color
                                                              .territoryColor
                                                              .withValues(
                                                                  alpha: 0.06),
                                                    ),
                                                    child: (cat.url != null &&
                                                            cat.url!
                                                                .trim()
                                                                .isNotEmpty)
                                                        ? UiUtils.imageType(
                                                            cat.url!,
                                                            fit: BoxFit.contain,
                                                            color: isSelected
                                                                ? context.color
                                                                    .territoryColor
                                                                : null,
                                                          )
                                                        : Icon(
                                                            Icons
                                                                .category_outlined,
                                                            size: 22,
                                                            color: context
                                                                .color
                                                                .territoryColor,
                                                          ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    cat.name ?? "",
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isSelected
                                                          ? context.color
                                                              .territoryColor
                                                          : context.color
                                                              .textDefaultColor,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }

                                  // List View for Subcategories
                                  return ListView.separated(
                                    controller: scrollController,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: displayCategories.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      CategoryModel cat =
                                          displayCategories[index];
                                      bool isSelected =
                                          selectedCategory?.id == cat.id;

                                      return Material(
                                        color: isSelected
                                            ? context.color.territoryColor
                                                .withValues(alpha: 0.08)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        clipBehavior: Clip.antiAlias,
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          leading: Container(
                                            width: 40,
                                            height: 40,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected
                                                  ? context.color.territoryColor
                                                      .withValues(alpha: 0.15)
                                                  : context.color.territoryColor
                                                      .withValues(alpha: 0.06),
                                            ),
                                            child: (cat.url != null &&
                                                    cat.url!.trim().isNotEmpty)
                                                ? UiUtils.imageType(
                                                    cat.url!,
                                                    fit: BoxFit.contain,
                                                    color: isSelected
                                                        ? context.color
                                                            .territoryColor
                                                        : null,
                                                  )
                                                : Icon(
                                                    Icons.category_outlined,
                                                    size: 20,
                                                    color: context
                                                        .color.territoryColor,
                                                  ),
                                          ),
                                          title: Text(
                                            cat.name ?? "",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isSelected
                                                  ? context.color.territoryColor
                                                  : context.color.textDefaultColor,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          trailing: isSelected
                                              ? Icon(Icons.check_circle_rounded,
                                                  color:
                                                      context.color.territoryColor,
                                                  size: 22)
                                              : Icon(Icons.radio_button_unchecked,
                                                  color:
                                                      context.color.borderColor,
                                                  size: 22),
                                          onTap: () {
                                            setModalState(() {
                                              selectedCategory = cat;
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SafeArea(
                          top: false,
                          child: UiUtils.buildButton(context, onPressed: () {
                            if (selectedCategory != null) {
                              Navigator.pop(context);
                              _updateSelection(chainIndex, selectedCategory!);
                            }
                          },
                              buttonTitle: "Show Results",
                              textColor: context.color.secondaryColor,
                              buttonColor: context.color.territoryColor,
                              radius: 10),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _updateSelection(int chainIndex, CategoryModel newSelection) {
    setState(() {
      _isAllFieldsSelected = false;

      // Update the chain at this index
      if (_currentChain.length > chainIndex) {
        _currentChain[chainIndex] = newSelection;
      } else {
        _currentChain.add(newSelection);
      }

      // Truncate any existing children
      if (_currentChain.length > chainIndex + 1) {
        _currentChain.removeRange(chainIndex + 1, _currentChain.length);
      }

      // Re-calculate categoryIds chain
      List<String> newIds = [];
      if (widget.categoryIds != null &&
          widget.categoryIds!.isNotEmpty &&
          widget.categoryIds!.length > 1) {
        newIds.add(widget.categoryIds![0]);
      }
      for (var cat in _currentChain) {
        if (cat.id != null && !newIds.contains(cat.id.toString())) {
          newIds.add(cat.id.toString());
        }
      }
      _currentCategoryIds = newIds;

      int targetId = newSelection.id ?? int.tryParse(widget.categoryId) ?? 0;

      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
            categoryId: targetId,
            search: searchController.text,
            filter: filter,
          );
    });
  }

  Widget _buildChip(
      {required String label,
      required bool isActive,
      bool showDropdown = true,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? context.color.territoryColor.withValues(alpha: 0.12)
              : context.color.secondaryColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive
                  ? context.color.territoryColor
                  : context.color.borderColor.withValues(alpha: 0.7),
              width: isActive ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: isActive
                        ? context.color.territoryColor
                        : context.color.textDefaultColor,
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.w600)),
            if (showDropdown) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isActive
                      ? context.color.territoryColor
                      : context.color.textDefaultColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Show Verified Properties First",
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          CupertinoSwitch(
            value: _showVerifiedOnly,
            activeColor: context.color.territoryColor,
            onChanged: (val) {
              setState(() {
                _showVerifiedOnly = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Verified Toggle Button
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _showVerifiedOnly = !_showVerifiedOnly;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showVerifiedOnly
                        ? Icons.check_circle_rounded
                        : Icons.verified_outlined,
                    size: 16,
                    color: _showVerifiedOnly
                        ? context.color.territoryColor
                        : context.color.textDefaultColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Verified",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _showVerifiedOnly
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: _showVerifiedOnly
                          ? context.color.territoryColor
                          : context.color.textDefaultColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            height: 18,
            width: 1,
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),

          // Sort Button
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: showSortByBottomSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_vert_rounded,
                    size: 17,
                    color: context.color.textDefaultColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Sort",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            height: 18,
            width: 1,
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),

          // Filter Button
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.pushNamed(
                context,
                Routes.filterScreen,
                arguments: {
                  "update": getFilterValue,
                  "from": "itemsList",
                  "categoryIds": _currentCategoryIds,
                },
              ).then((value) {
                if (value == true && filter != null) {
                  ItemFilterModel updatedFilter =
                      filter!.copyWith(categoryId: widget.categoryId);

                  final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                          categoryId: catIdInt,
                          search: searchController.text,
                          filter: updatedFilter,
                        );
                  }
                }
                setState(() {});
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: context.color.textDefaultColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Filter",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.color.textDefaultColor,
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

  String? _getPricePeriod(ItemModel item) {
    if (item.customFields != null) {
      for (var cf in item.customFields!) {
        final name = (cf.name ?? "").toLowerCase();
        final val = (cf.value?.toString() ?? "").toLowerCase();
        if (name.contains("period") || name.contains("rent type")) {
          return cf.value?.toString();
        }
        if (val == "yearly" || val == "monthly" || val == "daily" || val == "weekly") {
          return cf.value?.toString();
        }
      }
    }
    final catName = widget.categoryName.toLowerCase();
    if (catName.contains("rent") || catName.contains("property")) {
      return "Yearly";
    }
    return null;
  }

  Widget _buildPropertyFeatures(ItemModel item) {
    List<Widget> features = [];

    if (item.customFields != null && item.customFields!.isNotEmpty) {
      for (var field in item.customFields!) {
        final name = (field.name ?? "").toLowerCase();
        dynamic rawVal = field.value;
        String val = "";
        if (rawVal is List && rawVal.isNotEmpty) {
          val = rawVal.join(", ");
        } else if (rawVal != null) {
          val = rawVal.toString();
        }
        val = val.trim();
        if (val.isEmpty) continue;

        IconData iconData = Icons.label_outline_rounded;

        if (name.contains("bed") || name.contains("room")) {
          iconData = Icons.bed_outlined;
          if (!val.toLowerCase().contains("bed")) val = "$val bed";
        } else if (name.contains("bath")) {
          iconData = Icons.bathtub_outlined;
          if (!val.toLowerCase().contains("bath")) val = "$val bath";
        } else if (name.contains("sqft") ||
            name.contains("size") ||
            name.contains("area")) {
          iconData = Icons.crop_square_rounded;
          if (!val.toLowerCase().contains("sqft") &&
              !val.toLowerCase().contains("sq")) {
            val = "$val sqft";
          }
        } else if (name.contains("kilometer") ||
            name.contains("km") ||
            name.contains("mileage")) {
          iconData = Icons.speed_rounded;
          if (!val.toLowerCase().contains("km")) val = "$val km";
        } else if (name.contains("year") || name.contains("model")) {
          iconData = Icons.calendar_today_outlined;
        } else if (name.contains("transmission") || name.contains("gear")) {
          iconData = Icons.settings_suggest_outlined;
        } else if (name.contains("fuel")) {
          iconData = Icons.local_gas_station_outlined;
        } else if (name.contains("storage") ||
            name.contains("ram") ||
            name.contains("memory")) {
          iconData = Icons.memory_outlined;
        } else if (name.contains("condition")) {
          iconData = Icons.star_border_rounded;
        } else if (name.contains("furnished")) {
          iconData = Icons.chair_outlined;
        }

        if (features.isNotEmpty) {
          features.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                "•",
                style: TextStyle(
                  color: context.color.textLightColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        features.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 15, color: context.color.textDefaultColor),
              const SizedBox(width: 4),
              Text(
                val,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
        );

        if (features.length >= 7) break;
      }
    }

    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: features),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, ItemModel item) {
    final hasGallery =
        item.galleryImages != null && item.galleryImages!.isNotEmpty;
    final totalPhotos = hasGallery ? item.galleryImages!.length + 1 : 1;
    final pricePeriod = _getPricePeriod(item);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToDetails(context, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE STACK
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  child: SizedBox(
                    height: 210,
                    width: double.infinity,
                    child: UiUtils.getImage(
                      item.image ?? "",
                      fit: BoxFit.cover,
                      height: 210,
                      width: double.infinity,
                    ),
                  ),
                ),

                // Top-Left Verified Badge
                if (item.isFeature == true ||
                    item.status == "approved" ||
                    item.status == "1")
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 14,
                            color: Colors.black,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Verified",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Top-Right Favorite Button
                Positioned(
                  top: 10,
                  right: 10,
                  child: _favButton(context, item),
                ),

                // Bottom-Left Photos Count Badge
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "1/$totalPhotos",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom-Center Indicator dots
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      min(totalPhotos, 5),
                      (dotIdx) => Container(
                        width: dotIdx == 0 ? 8 : 6,
                        height: dotIdx == 0 ? 8 : 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotIdx == 0
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 2. CONTENT DETAILS
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price Line
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "${Constant.currencySymbol} ${item.price != null ? item.price!.toString().priceFormate(disabled: Constant.isNumberWithSuffix == false) : '0'}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      if (pricePeriod != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          pricePeriod,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Features row (beds, baths, sqft)
                  _buildPropertyFeatures(item),

                  // Title
                  Text(
                    item.name?.firstUpperCase() ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Location
                  if (item.address != null &&
                      item.address!.trim().isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: context.color.textLightColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.address?.trim() ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ] else
                    const SizedBox(height: 8),

                  // Action Buttons (Call & WhatsApp)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _launchCall(
                              item.contact ?? item.user?.mobile),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFFD5D5),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 18,
                                  color: Color(0xFFE53935),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Call",
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _launchWhatsApp(
                              item.contact ?? item.user?.mobile),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFDCFCE7),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: Color(0xFF16A34A),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "WhatsApp",
                                  style: TextStyle(
                                    color: Color(0xFF16A34A),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return bodyWidget();
  }

  Widget bodyWidget() {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: PopScope(
        canPop: true,
        onPopInvoked: (isPop) {
          Constant.itemFilter = null;
        },
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          floatingActionButton: _buildFloatingBottomBar(),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              backgroundColor: context.color.backgroundColor,
              onRefresh: () async {
                searchbody = {};
                Constant.itemFilter = null;

                final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                if (catIdInt != 0) {
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                        categoryId: catIdInt,
                        search: "",
                      );
                }
              },
              color: context.color.territoryColor,
              child: SingleChildScrollView(
                controller: controller,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    _buildLocationHeader(),
                    const SizedBox(height: 6),
                    _buildFilterChips(),
                    _buildVerifiedToggle(),
                    const SizedBox(height: 4),
                    fetchItems(),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  getFilterValue(ItemFilterModel model) {
    filter = model;
    setState(() {});
  }

  Widget bottomWidget() {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border(
          top: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: filterByWidget(),
          ),
          SizedBox(
            height: 24,
            child: VerticalDivider(
              color: context.color.borderColor.withValues(alpha: 0.5),
              thickness: 1,
            ),
          ),
          Expanded(
            child: sortByWidget(),
          ),
        ],
      ),
    );
  }

  Widget filterByWidget() {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          Routes.filterScreen,
          arguments: {
            "update": getFilterValue,
            "from": "itemsList",
            "categoryIds": _currentCategoryIds
          },
        ).then((value) {
          if (value == true && filter != null) {
            ItemFilterModel updatedFilter =
            filter!.copyWith(categoryId: widget.categoryId);

            context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
              categoryId: int.parse(widget.categoryId),
              search: searchController.text,
              filter: updatedFilter,
            );
          }
          setState(() {});
        });
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 16, // smaller icon height
              width: 16,  // smaller icon width
              child: UiUtils.getSvg(
                AppIcons.filterByIcon,
                color: context.color.textDefaultColor,
              ),
            ),
            const SizedBox(width: 7),
            Text("filterTitle".translate(context)),
          ],
        ),
      ),

    );
  }

  Widget sortByWidget() {
    return InkWell(
      onTap: showSortByBottomSheet,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiUtils.getSvg(AppIcons.sortByIcon,
                color: context.color.textDefaultColor),
            const SizedBox(width: 7),
            Text("sortBy".translate(context)),
          ],
        ),
      ),
    );
  }






  showSortByBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8.0),
          topRight: Radius.circular(8.0),
        ),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Material(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: context.color.borderColor,
                    ),
                    height: 6,
                    width: 60,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 20),
                child: Text(
                  'sortBy'.translate(context),
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ),

              Divider(height: 1, color: context.color.borderColor.withValues(alpha: 0.35)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'default'.translate(context),
                  style: TextStyle(color: context.color.textDefaultColor, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                        categoryId: catIdInt,
                        search: searchController.text.toString(),
                        sortBy: null);
                  }

                  setState(() {
                    sortBy = null;
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(height: 1, color: context.color.borderColor.withValues(alpha: 0.35)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'newToOld'.translate(context),
                  style: TextStyle(color: context.color.textDefaultColor, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                        categoryId: catIdInt,
                        search: searchController.text.toString(),
                        sortBy: "new-to-old");
                  }
                  setState(() {
                    sortBy = "new-to-old";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(height: 1, color: context.color.borderColor.withValues(alpha: 0.35)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'oldToNew'.translate(context),
                  style: TextStyle(color: context.color.textDefaultColor, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                        categoryId: catIdInt,
                        search: searchController.text.toString(),
                        sortBy: "old-to-new");
                  }
                  setState(() {
                    sortBy = "old-to-new";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(height: 1, color: context.color.borderColor.withValues(alpha: 0.35)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'priceHighToLow'.translate(context),
                  style: TextStyle(color: context.color.textDefaultColor, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                        categoryId: catIdInt,
                        search: searchController.text.toString(),
                        sortBy: "price-high-to-low");
                  }
                  setState(() {
                    sortBy = "price-high-to-low";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(height: 1, color: context.color.borderColor.withValues(alpha: 0.35)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(
                  'priceLowToHigh'.translate(context),
                  style: TextStyle(color: context.color.textDefaultColor, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                  if (catIdInt != 0) {
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                        categoryId: catIdInt,
                        search: searchController.text.toString(),
                        sortBy: "price-low-to-high");
                  }
                  setState(() {
                    sortBy = "price-low-to-high";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget fetchItems() {
    return BlocBuilder<FetchItemFromCategoryCubit, FetchItemFromCategoryState>(
        builder: (context, state) {
          if (state is FetchItemFromCategoryInProgress) {
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              itemCount: 5,
              itemBuilder: (context, index) {
                return buildItemsShimmer(context);
              },
            );
          }

          if (state is FetchItemFromCategoryFailure) {
            return Center(
              child: Text(state.errorMessage),
            );
          }
          if (state is FetchItemFromCategorySuccess) {
            if (state.itemModel.isEmpty) {
              return Center(
                child: NoDataFound(
                  onTap: () {
                    final catIdInt = int.tryParse(widget.categoryId) ?? 0;
                    if (catIdInt != 0) {
                      context
                          .read<FetchItemFromCategoryCubit>()
                          .fetchItemFromCategory(
                          categoryId: catIdInt,
                          search: searchController.text.toString());
                    }
                  },
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDynamicSegmentTabs(state.itemModel),
                const SizedBox(height: 4),
                mainChildren(state.itemModel),
                if (state.isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: UiUtils.progress()),
                  ),
              ],
            );
          }
          return const SizedBox.shrink();
        });
  }

  void _navigateToDetails(BuildContext context, ItemModel item) {
    Navigator.pushNamed(
      context,
      Routes.adDetailsScreen,
      arguments: {'model': item},
    );
  }

  Widget mainChildren(List<ItemModel> items) {
    List<ItemModel> filteredItems = List.from(items);

    if (_showVerifiedOnly) {
      filteredItems = filteredItems
          .where((i) =>
              i.isFeature == true ||
              i.status == "approved" ||
              i.status == "1")
          .toList();
    }

    if (_selectedSegmentValue != null && _detectedFilterFieldName != null) {
      filteredItems = filteredItems.where((i) {
        if (i.customFields == null) return false;
        return i.customFields!.any((cf) {
          final isSameField = (cf.name ?? "").trim().toLowerCase() ==
              _detectedFilterFieldName!.trim().toLowerCase();
          if (!isSameField) return false;

          final val = cf.value;
          if (val is List) {
            return val.any((v) =>
                v.toString().trim().toLowerCase() ==
                _selectedSegmentValue!.trim().toLowerCase());
          }
          return val.toString().trim().toLowerCase() ==
              _selectedSegmentValue!.trim().toLowerCase();
        });
      }).toList();
    }

    if (filteredItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text(
            "No items found matching criteria",
            style: TextStyle(
              color: context.color.textLightColor,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        ItemModel item = filteredItems[index];
        return _buildPropertyCard(context, item);
      },
    );
  }

  Widget _buildGridViewSection(BuildContext context, int startIndex,
      int itemCount, List<ItemModel> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
          crossAxisCount: 2,
          height: MediaQuery.of(context).size.height / 3.5.rh(context),
          mainAxisSpacing: 7,
          crossAxisSpacing: 10),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        ItemModel item = items[startIndex + index];
        return GestureDetector(
          onTap: () => _navigateToDetails(context, item),
          child: ItemCard(item: item),
        );
      },
    );
  }

  Widget buildItemsShimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        height: 120.rh(context),
        decoration: BoxDecoration(
            border: Border.all(width: 1.5, color: context.color.borderColor),
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            CustomShimmer(
              height: 120.rh(context),
              width: 100.rw(context),
            ),
            SizedBox(
              width: 10.rw(context),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CustomShimmer(
                  width: 100.rw(context),
                  height: 10,
                  borderRadius: 7,
                ),
                CustomShimmer(
                  width: 150.rw(context),
                  height: 10,
                  borderRadius: 7,
                ),
                CustomShimmer(
                  width: 120.rw(context),
                  height: 10,
                  borderRadius: 7,
                ),
                CustomShimmer(
                  width: 80.rw(context),
                  height: 10,
                  borderRadius: 7,
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
