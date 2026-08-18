import 'dart:async';
import 'dart:math';

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
  final List<String> categoryIds;
  final List<CategoryModel>? selectedCategoryChain;
  final ItemFilterModel? appliedFilter;

  const ItemsList(
      {super.key,
        required this.categoryId,
        required this.categoryName,
        required this.categoryIds,
        this.selectedCategoryChain,
        this.appliedFilter});

  @override
  ItemsListState createState() => ItemsListState();

  static Route route(RouteSettings routeSettings) {
    Map? arguments = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => ItemsList(
        categoryId: arguments?['catID'] as String,
        categoryName: arguments?['catName'],
        categoryIds: arguments?['categoryIds'],
        selectedCategoryChain: arguments?['selectedCategoryChain'],
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

  @override
  void initState() {
    super.initState();
    _chipFilterCubit = FetchSubCategoriesCubit();
    // Initialize chain from arguments or empty
    _currentChain = widget.selectedCategoryChain ?? [];
    if (_currentChain.isEmpty && widget.categoryId.isNotEmpty) {
      _currentChain.add(CategoryModel(
          id: int.tryParse(widget.categoryId) ?? 0,
          name: widget.categoryName,
          children: [],
          subcategoriesCount: 0
      ));
    }

    _currentCategoryIds = List.from(widget.categoryIds);
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

    context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
        categoryId: int.parse(
          widget.categoryId,
        ),
        search: "",
        filter: initialFilter);

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

  Widget searchBarWidget() {
    return Container(
      color: context.color.secondaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          /// 🔍 SEARCH FIELD
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 0.1,
                  color: context.color.borderColor.darken(30),
                ),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                color: context.color.backgroundColor,
              ),
              child: TextFormField(
                controller: searchController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  hintText: "Search any items ..",
                  prefixIcon: setSearchIcon(),
                  prefixIconConstraints:
                  const BoxConstraints(minHeight: 5, minWidth: 5),
                ),
                enableSuggestions: true,
                onEditingComplete: () {
                  setState(() {
                    isFocused = false;
                    FocusScope.of(context).unfocus();
                  });
                },
                onTap: () {
                  setState(() {
                    isFocused = true;
                  });
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          /// 🔲 GRID VIEW ONLY
          GestureDetector(
            onTap: () {
              setState(() {
                isList = false; // 🔥 always GRID
              });
            },
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 1,
                  color: context.color.borderColor.darken(30),
                ),
                color: !isList
                    ? context.color.backgroundColor
                    : context.color.secondaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: UiUtils.getSvg(
                  AppIcons.gridViewIcon,
                  color: !isList
                      ? context.color.blackColor
                      : context.color.textDefaultColor.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          /// ☰ MENU → LIST VIEW ONLY
          GestureDetector(
            onTap: () {
              setState(() {
                isList = true; // 🔥 always LIST
              });
            },
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 1,
                  color: context.color.borderColor.darken(30),
                ),
                color: isList
                    ? context.color.backgroundColor
                    : context.color.secondaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.menu,
                  color: isList
                      ? context.color.blackColor
                      : context.color.textDefaultColor.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildFilterChips() {
    return Container(
      color: context.color.secondaryColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
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

                      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
                        categoryId: int.parse(widget.categoryId),
                        search: searchController.text,
                        filter: updatedFilter,
                      );
                      setState(() {});
                    }
                  });
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.color.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.color.borderColor),
                  ),
                  child: Row(
                    children: [
                      UiUtils.getSvg(AppIcons.filterByIcon,
                          color: context.color.textDefaultColor,
                          height: 16,
                          width: 16),
                      const SizedBox(width: 6),
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
      int rootId = int.tryParse(widget.categoryIds.isNotEmpty
              ? widget.categoryIds[0]
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
      if (widget.categoryIds.isNotEmpty && widget.categoryIds.length > 1) {
        newIds.add(widget.categoryIds[0]);
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
      if (widget.categoryIds.length > 1) {
        parentId = int.tryParse(widget.categoryIds[0]) ?? 0;
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
      if (widget.categoryIds.isNotEmpty && widget.categoryIds.length > 1) {
        newIds.add(widget.categoryIds[0]);
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? context.color.territoryColor.withValues(alpha: 0.12)
              : context.color.primaryColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive
                  ? context.color.territoryColor
                  : context.color.borderColor,
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
                        isActive ? FontWeight.bold : FontWeight.normal)),
            if (showDropdown) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.color.borderColor,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Show verified properties first",
            style: TextStyle(
              color: context.color.textDefaultColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          /// 🍎 iOS style toggle
          CupertinoSwitch(
            value: _showVerifiedOnly,
            activeColor: context.color.territoryColor, // green when ON
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

  Widget setSearchIcon() {
    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: UiUtils.getSvg(AppIcons.search,
            color: context.color.territoryColor));
  }

  Widget setSuffixIcon() {
    return GestureDetector(
      onTap: () {
        searchController.clear();
        isFocused = false; //set icon color to black back
        FocusScope.of(context).unfocus(); //dismiss keyboard
        setState(() {});
      },
      child: Icon(
        Icons.close_rounded,
        color: Theme.of(context).colorScheme.blackColor,
        size: 30,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return bodyWidget();
  }

/////////////////////////////
  //////////////////////////////
  //// ethu tha all categries short agi show agura screen
  Widget bodyWidget() {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.backgroundColor,
      ),
      child: PopScope(
        canPop: true,
        onPopInvoked: (isPop) {
          Constant.itemFilter = null;
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: UiUtils.buildAppBar(

              context,
              showBackButton: true,
              title: selectedcategoryName == ""
                  ? widget.categoryName
                  : selectedcategoryName
          ),
          bottomNavigationBar: bottomWidget(),
          body: RefreshIndicator(
            backgroundColor: context.color.backgroundColor,
            onRefresh: () async {
              // Debug log to check if onRefresh is triggered

              searchbody = {};
              Constant.itemFilter = null;

              context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
                categoryId: int.parse(widget.categoryId),
                search: "",
              );
            },
            color: context.color.territoryColor,
            child: Column(
              children: [
                SizedBox(height: 8,),
                SizedBox(height: 8,),
                 searchBarWidget(),
                 SizedBox(height: 8,),
                 _buildFilterChips(),
                 _buildVerifiedToggle(),
                 SizedBox(height: 8,),
                Expanded(child: fetchItems()),
              ],
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

  Container bottomWidget() {
    return Container(
      color: context.color.secondaryColor,
      padding: const EdgeInsets.only(top: 3, bottom: 15),
      height: 70,
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: filterByWidget(),
          ),
          SizedBox(
            height: 40,
            child: VerticalDivider(
              color: context.color.borderColor.darken(50),
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
            "categoryIds": widget.categoryIds
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
                padding: EdgeInsets.symmetric(vertical: 17, horizontal: 20),
                child: Text(
                  'sortBy'.translate(context),
                  textAlign: TextAlign.start,
                ).bold(weight: FontWeight.bold).size(context.font.large),
              ),

              Divider(height: 1), // Add some space between title and options
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text('default'.translate(context)),
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                      categoryId: int.parse(
                        widget.categoryId,
                      ),
                      search: searchController.text.toString(),
                      sortBy: null);

                  setState(() {
                    sortBy = null;
                    print("isfocus$isFocused");

                    FocusManager.instance.primaryFocus?.unfocus();

                  });

                  // Handle option 1 selection
                },
              ),
              Divider(height: 1), // Divider between option 1 and option 2
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text('newToOld'.translate(context)),
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                      categoryId: int.parse(
                        widget.categoryId,
                      ),
                      search: searchController.text.toString(),
                      sortBy: "new-to-old");
                  setState(() {
                    sortBy = "new-to-old";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(height: 1), // Divider between option 2 and option 3
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text('oldToNew'.translate(context)),
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                      categoryId: int.parse(
                        widget.categoryId,
                      ),
                      search: searchController.text.toString(),
                      sortBy: "old-to-new");
                  setState(() {
                    sortBy = "old-to-new";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(height: 1), // Divider between option 3 and option 4
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text('priceHighToLow'.translate(context)),
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                      categoryId: int.parse(
                        widget.categoryId,
                      ),
                      search: searchController.text.toString(),
                      sortBy: "price-high-to-low");
                  setState(() {
                    sortBy = "price-high-to-low";
                    FocusManager.instance.primaryFocus?.unfocus();
                  });
                },
              ),
              Divider(height: 1), // Divider between option 4 and option 5
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
                title: Text('priceLowToHigh'.translate(context)),
                onTap: () {
                  Navigator.pop(context);
                  context
                      .read<FetchItemFromCategoryCubit>()
                      .fetchItemFromCategory(
                      categoryId: int.parse(
                        widget.categoryId,
                      ),
                      search: searchController.text.toString(),
                      sortBy: "price-low-to-high");
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
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              itemCount: 10,
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
                    context
                        .read<FetchItemFromCategoryCubit>()
                        .fetchItemFromCategory(
                        categoryId: int.parse(
                          widget.categoryId,
                        ),
                        search: searchController.text.toString());
                  },
                ),
              );
            }
            return Column(
              children: [
                Expanded(child: mainChildren(state.itemModel)
                  /* isList
                  ? ListView.builder(
                      shrinkWrap: true,
                      controller: controller,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 3),
                      itemCount: calculateItemCount(state.itemModel.length),
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        if ((index + 1) % 4 == 0) {
                          return NativeAdWidget(type: TemplateType.medium);
                        }

                        int itemIndex = index - (index ~/ 4);
                        ItemModel item = state.itemModel[itemIndex];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              Routes.adDetailsScreen,
                              arguments: {
                                'model': item,
                              },
                            );
                          },
                          child: ItemHorizontalCard(
                            item: item,
                          ),
                        );
                      },
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      controller: controller,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 5),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
                              crossAxisCount: 2,
                              height: MediaQuery.of(context).size.height /
                                  3.5.rh(context),
                              mainAxisSpacing: 7,
                              crossAxisSpacing: 10),
                      itemCount: calculateItemCount(state.itemModel.length),
                      itemBuilder: (context, index) {
                        if ((index + 1) % 4 == 0) {
                          return NativeAdWidget(type: TemplateType.medium);
                        }

                        int itemIndex = index - (index ~/ 4);
                        ItemModel item = state.itemModel[itemIndex];

                        return GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                Routes.adDetailsScreen,
                                arguments: {
                                  'model': item,
                                },
                              );
                            },
                            child: ItemCard(
                              item: item,
                            ));
                      },
                    ),*/
                ),
                if (state.isLoadingMore) UiUtils.progress()
              ],
            );
          }
          return Container();
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
    List<Widget> children = [];
    int gridCount = Constant.nativeAdsAfterItemNumber;
    int total = items.length;

    for (int i = 0; i < total; i += gridCount /* + listCount*/) {
      if (isList) {
        children.add(_buildListViewSection(
            context, i, min(gridCount, total - i), items));
      } else {
        children.add(_buildGridViewSection(
            context, i, min(gridCount, total - i), items));
      }

      int remainingItems = total - i - gridCount;
      if (remainingItems > 0) {
        children.add(NativeAdWidget(type: TemplateType.medium));
      }
    }

    return SingleChildScrollView(
      controller: controller,
      physics: BouncingScrollPhysics(),
      child: Column(children: children),
    );
  }

  Widget _buildListViewSection(BuildContext context, int startIndex,
      int itemCount, List<ItemModel> items) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        ItemModel item = items[startIndex + index];
        return GestureDetector(
          onTap: () => _navigateToDetails(context, item),
          child: ItemHorizontalCard(item: item),
        );
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
