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

  const ItemsList(
      {super.key,
        required this.categoryId,
        required this.categoryName,
        required this.categoryIds,
        this.selectedCategoryChain});

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
    // Fallback: If chain is empty but we have a main category and it's not "Property" (which is root), add it.
    // Actually, simply relying on arguments is safer.
    // If empty & we have categoryName, maybe add it?
    if (_currentChain.isEmpty && widget.categoryId.isNotEmpty) {
      // Basic fallback
      _currentChain.add(CategoryModel(
          id: int.tryParse(widget.categoryId) ?? 0,
          name: widget.categoryName,
          children: [],
          subcategoriesCount: 0
      ));
    }

    _currentCategoryIds = List.from(widget.categoryIds);
    searchbody = {};
    Constant.itemFilter = null;
    searchController = TextEditingController();
    searchController.addListener(searchItemListener);
    controller = ScrollController()..addListener(_loadMore);

    context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
        categoryId: int.parse(
          widget.categoryId,
        ),
        search: "",
        filter: ItemFilterModel(
            country: HiveUtils.getCountryName() ?? "",
            areaId: HiveUtils.getAreaId() != null
                ? int.parse(HiveUtils.getAreaId().toString())
                : null,
            city: HiveUtils.getCityName() ?? "",
            state: HiveUtils.getStateName() ?? "",
            categoryId: widget.categoryId,
            radius: HiveUtils.getNearbyRadius() ?? null,
            latitude: HiveUtils.getLatitude() ?? null,
            longitude: HiveUtils.getLongitude() ?? null));

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
                onTap: _onAllFieldsTap
            ),
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
      _currentCategoryIds = [widget.categoryId];

      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: int.tryParse(widget.categoryId) ?? 0,
          search: searchController.text
      );
    });
  }

  void _restoreSelection(int chainIndex) {
    setState(() {
      _isAllFieldsSelected = false;

      // Truncate chain after chainIndex
      if (_currentChain.length > chainIndex + 1) {
         _currentChain.removeRange(chainIndex + 1, _currentChain.length);
      }

      List<String> newIds = [widget.categoryId];
      for (var cat in _currentChain) {
        newIds.add(cat.id.toString());
      }
      _currentCategoryIds = newIds;

      // Fetch
      CategoryModel? targetCat = _currentChain.isNotEmpty ? _currentChain.last : null;
      int targetId = targetCat?.id ?? int.tryParse(widget.categoryId) ?? 0;

      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: targetId,
          search: searchController.text
      );
    });
  }

  void _showDynamicFilterBottomSheet(int chainIndex) {
    // Determine the Parent ID to fetch siblings from.
    // Index 0 in chain corresponds to Level 1 (Rent). Its parent is Level 0 (Property).
    
    // Robust way:
    String parentId;
    if (chainIndex == 0) {
      // Index 0 in chain is Level 1 (e.g., Rent). Its parent is Level 0 (Property).
      // Level 0 ID is stored at index 0 of the full ID list passed to this screen.
      parentId = widget.categoryIds.isNotEmpty ? widget.categoryIds[0] : "0";
    } else {
      // Parent is the previous item in the chain
      if (chainIndex - 1 < _currentChain.length) {
         parentId = _currentChain[chainIndex - 1].id.toString();
      } else {
         return; // Error state
      }
    }

    _chipFilterCubit.fetchSubCategories(categoryId: int.tryParse(parentId) ?? 0);

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        CategoryModel? selectedCategory;
        // Initialize with current selection if available
        if (_currentChain.length > chainIndex) {
          selectedCategory = _currentChain[chainIndex];
        }

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        child: Icon(Icons.close, color: context.color.textDefaultColor),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  BlocProvider.value(
                    value: _chipFilterCubit,
                    child: BlocBuilder<FetchSubCategoriesCubit,
                        FetchSubCategoriesState>(
                      builder: (context, state) {
                        if (state is FetchSubCategoriesInProgress) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (state is FetchSubCategoriesSuccess) {
                          return Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.5,
                            ),
                            child: SingleChildScrollView(
                               child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.categories.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.9,
                                ),
                                itemBuilder: (context, index) {
                                  CategoryModel cat = state.categories[index];
                                  bool isSelected = selectedCategory?.id == cat.id;

                                  return InkWell(
                                    onTap: () {
                                      setModalState(() {
                                        selectedCategory = cat;
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? context.color.territoryColor
                                                .withValues(alpha: 0.1)
                                            : context.color.backgroundColor,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? context.color.territoryColor
                                              : context.color.borderColor,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: 30,
                                            width: 30,
                                            child: UiUtils.imageType(
                                              cat.url ?? "",
                                              color: isSelected
                                                  ? context.color.territoryColor
                                                  : context.color.textDefaultColor,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            cat.name ?? "",
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isSelected
                                                  ? context.color.territoryColor
                                                  : context.color.textDefaultColor,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }
                        return Text("No options available");
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  UiUtils.buildButton(context, onPressed: () {
                    if (selectedCategory != null) {
                      Navigator.pop(context);
                      _updateSelection(chainIndex, selectedCategory!);
                    }
                  },
                      buttonTitle: "Show Results",
                      textColor: context.color.secondaryColor,
                      buttonColor: context.color.territoryColor,
                      radius: 10)
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updateSelection(int chainIndex, CategoryModel newSelection) {
    final oldId = _currentChain.length > chainIndex ? _currentChain[chainIndex].id : -1;
    // If selection is same AND All Fields is NOT selected, then no change.
    // If All Fields IS selected, we must proceed to deactivate it and restore this selection.
    if (oldId == newSelection.id && !_isAllFieldsSelected) return;

    setState(() {
      _isAllFieldsSelected = false; // Reset All Fields flag

      // 1. Save History for the OLD item being replaced
      if (_currentChain.length > chainIndex) {
         int currentOldId = _currentChain[chainIndex].id!;
         // If there are children (tail), save them
         if (_currentChain.length > chainIndex + 1) {
            _selectionHistory[currentOldId] = List.from(_currentChain.sublist(chainIndex + 1));
         }
      }

      // 2. Update the chain at this index
      if (_currentChain.length > chainIndex) {
        _currentChain[chainIndex] = newSelection;
      } else {
        _currentChain.add(newSelection);
      }

      // 3. Truncate any existing children (since we changed the parent)
      if (_currentChain.length > chainIndex + 1) {
        _currentChain.removeRange(chainIndex + 1, _currentChain.length);
      }

      // 4. Restore History for the NEW item (if we visited it before)
      if (_selectionHistory.containsKey(newSelection.id)) {
         _currentChain.addAll(_selectionHistory[newSelection.id]!);
      }

      // 5. Re-calculate categoryIds chain
      // Note: We use widget.categoryIds[0] as the Root Base if chainIndex 0 starts from Level 1
      List<String> newIds = [];
      if (widget.categoryIds.isNotEmpty) newIds.add(widget.categoryIds[0]);
      
      // Add current chain IDs
      for (var cat in _currentChain) {
        newIds.add(cat.id.toString());
      }
      // Note: If original widget.categoryIds had more depth, we are replacing it dynamically.
      // But we must assume widget.categoryIds[0] is the only fixed Root Context.
      // Actually, my previous logic `List<String> newIds = [_currentCategoryIds[0]];` 
      // relied on `_currentCategoryIds[0]` being preserved.
      // Here, `widget.categoryIds[0]` is safer/constant.
      
      // Let's stick to using widget.categoryIds[0] as ROOT.
      // But verify if widget.categoryIds is empty (e.g. from Search? Not PropertyFilter).
      // This flow is for PropertyFilter mostly.
      
       if (newIds.isEmpty && _currentChain.isNotEmpty) {
           // Fallback if no root is passed? Should not happen in this flow.
           // Maybe _currentChain[0] is root?
           // No, Rent is Level 1.
           // We'll stick to newIds logic.
       }
       
       // Just to be safe, if we duplicated the Root ID?
       // `widget.categoryIds` might be `[PropertyID, RentID...]`.
       // `_currentChain` starts with Rent. 
       // So `newIds` = `[PropertyID, RentID, ResID...]`. Correct.
       
       // Wait, what if widget.categoryIds comes as `[PropertyID]` only?
       // `newIds` = `[PropertyID, RentID...]`. Correct.
       
       // What if `_currentChain` contains Property (Level 0)?
       // No, `accumulatedModels` logic in PropertyScreen added Tab(Rent) as first item.
       // So Chain starts at Level 1.
       
       _currentCategoryIds = newIds;

      // 6. Trigger API refresh
      // Fetch using the LAST item in the chain (Most specific filter)
      context.read<FetchItemFromCategoryCubit>().fetchItemFromCategory(
          categoryId: _currentChain.last.id!,
          search: searchController.text
      );
    });
  }

  Widget _buildChip({required String label, required bool isActive, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: context.color.primaryColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive
                  ? context.color.borderColor
                  : context.color.borderColor), // Same border for now or customize
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down,
                size: 16, color: context.color.textDefaultColor)
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
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
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
