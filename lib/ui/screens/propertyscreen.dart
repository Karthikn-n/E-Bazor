import 'package:Ebozor/data/cubits/category/fetch_sub_categories_cubit.dart';
import 'package:Ebozor/ui/screens/home/widgets/location_widget.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Ebozor/app/routes.dart';

class PropertyFilterScreen extends StatefulWidget {
  final List<CategoryModel> categoryList; // Expecting [Rent, Sale]
  final String catName;
  final int catId;
  final List<String> categoryIds;
  final String? from;

  const PropertyFilterScreen({
    super.key,
    required this.categoryList,
    required this.catName,
    required this.catId,
    required this.categoryIds,
    this.from,
  });

  @override
  State<PropertyFilterScreen> createState() => _PropertyFilterScreenState();
}

class _PropertyFilterScreenState extends State<PropertyFilterScreen> {
  int _selectedTabIndex = 0; // 0 for Rent, 1 for Sale (assuming order)
  CategoryModel? _selectedPropertyType; // e.g. Residential
  CategoryModel? _selectedSubCategory; // e.g. Apartment

  // We need a separate cubit to fetch children of the selected property type (e.g. Residential -> Apartments)
  late final FetchSubCategoriesCubit _subCategoryCubit;

  // We need another cubit to fetch Property Types (Residential/Commercial) if the Tab doesn't have them (e.g. Sale)
  late final FetchSubCategoriesCubit _propertyTypesCubit;

  @override
  void initState() {
    super.initState();
    _subCategoryCubit = FetchSubCategoriesCubit();
    _propertyTypesCubit = FetchSubCategoriesCubit();
    // Default selection logic
    _initializeDefaultSelection();
  }

  @override
  void dispose() {
    _subCategoryCubit.close();
    _propertyTypesCubit.close();
    super.dispose();
  }

  void _initializeDefaultSelection() {
    if (widget.categoryList.isNotEmpty) {
      // By default select the first sub-category of the first tab (e.g. Residential in Rent)
      var firstTabCategory = widget.categoryList.first;
      if (firstTabCategory.children != null &&
          firstTabCategory.children!.isNotEmpty) {
        _onPropertyTypeSelected(firstTabCategory.children!.first);
      } else {
        // If even the first tab is empty, fetch it
        _propertyTypesCubit.fetchSubCategories(
            categoryId: firstTabCategory.id!);
      }
    }
  }

  void _onPropertyTypeSelected(CategoryModel propertyType) {
    setState(() {
      _selectedPropertyType = propertyType;
      _selectedSubCategory = null; // Reset sub-sub category
    });

    // If this property type has children already loaded, we don't need to fetch.
    if (propertyType.children != null && propertyType.children!.isNotEmpty) {
      // Children already available
    } else {
      // Check if it's supposed to have children?
      // Many times subcategoriesCount is reliable.
      // Or just fetch anyway if it's a leaf node candidate.
      if ((propertyType.subcategoriesCount ?? 0) > 0) {
        _subCategoryCubit.fetchSubCategories(categoryId: propertyType.id!);
      }
    }
  }

  /*
   * Helper to get the currently active "Tab" category (Rent or Sale)
   */
  CategoryModel? get _currentTabCategory {
    if (widget.categoryList.length > _selectedTabIndex) {
      return widget.categoryList[_selectedTabIndex];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
          context: context, statusBarColor: context.color.backgroundColor),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: widget.catName,
          actions: [
            TextButton(
              onPressed: () {
                // Reset logic
                setState(() {
                  _selectedTabIndex = 0;
                  _initializeDefaultSelection();
                });
              },
              child: Text(
                "Reset".translate(context),
                style: TextStyle(
                    color:
                        context.color.textDefaultColor.withValues(alpha: 0.5)),
              ),
            )
          ],
        ),
        body: Container(
          color: context.color.secondaryColor,
          child: Column(
            children: [
              _buildTabs(),
              const Divider(thickness: 1, height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLocationSection(),
                      const SizedBox(height: 24),
                      _buildPropertyTypes(),
                      if (_selectedPropertyType != null) ...[
                        const SizedBox(height: 24),
                        _buildSubCategories(),
                      ],
                    ],
                  ),
                ),
              ),
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: context.color.secondaryColor,
      child: Row(
        children: widget.categoryList.asMap().entries.map((entry) {
          int index = entry.key;
          CategoryModel category = entry.value;
          bool isSelected = _selectedTabIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                  // Reset lower selections when switching tabs
                  if (category.children != null &&
                      category.children!.isNotEmpty) {
                    _onPropertyTypeSelected(category.children!.first);
                  } else {
                    _selectedPropertyType = null;
                    _selectedSubCategory = null;
                    // Fetch if empty
                    _propertyTypesCubit.fetchSubCategories(
                        categoryId: category.id!);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border(
                          bottom: BorderSide(
                              color: context.color.territoryColor, width: 2))
                      : null,
                ),
                child: Text(
                  category.name ?? "",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? context.color.territoryColor
                        : context.color.textDefaultColor,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Location",
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.color.backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.color.borderColor),
          ),
          child: const LocationWidget(),
        ),
        const SizedBox(height: 8),
        Text(
          "Select the cities neighbourhoods or building that you want to search property in .",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPropertyTypes() {
    CategoryModel? activeTab = _currentTabCategory;
    if (activeTab == null) return const SizedBox.shrink();

    // Case 1: Children are pre-loaded
    if (activeTab.children != null && activeTab.children!.isNotEmpty) {
      return _buildPropertyTypesList(activeTab.children!);
    }

    // Case 2: Children need fetching
    return BlocProvider.value(
      value: _propertyTypesCubit,
      child: BlocBuilder<FetchSubCategoriesCubit, FetchSubCategoriesState>(
        builder: (context, state) {
          if (state is FetchSubCategoriesInProgress) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: UiUtils.progress(),
            ));
          }
          if (state is FetchSubCategoriesSuccess) {
            if (state.categories.isEmpty) return const SizedBox.shrink();

            return _buildPropertyTypesList(state.categories);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPropertyTypesList(List<CategoryModel> propertyTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Property Type",
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: propertyTypes.map((subCat) {
              bool isSelected = _selectedPropertyType?.id == subCat.id;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    _onPropertyTypeSelected(subCat);
                  },
                  child: Container(
                    width: 100,
                    height: 100, // 🔥 FIXED HEIGHT (important)
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.color.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? context.color.blackColor
                            : context.color.borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        /// ICON
                        SizedBox(
                          height: 30,
                          width: 30,
                          child: UiUtils.imageType(
                            subCat.url ?? "",
                            color: isSelected
                                ? context.color.blackColor
                                : context.color.textDefaultColor,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 8),

                        /// TEXT (height controlled)
                        SizedBox(
                          height: 32, // 🔥 text area fixed
                          child: Text(
                            subCat.name ?? "",
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? context.color.blackColor
                                  : context.color.textDefaultColor,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              height: 1.2, // 🔥 line height control
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubCategories() {
    // Check if we have children locally first
    if (_selectedPropertyType?.children != null &&
        _selectedPropertyType!.children!.isNotEmpty) {
      return _buildSubCategoryChips(_selectedPropertyType!.children!);
    }

    // Otherwise use BlocBuilder to listen to fetched children
    return BlocProvider.value(
      value: _subCategoryCubit,
      child: BlocBuilder<FetchSubCategoriesCubit, FetchSubCategoriesState>(
        builder: (context, state) {
          if (state is FetchSubCategoriesInProgress) {
            return Center(child: UiUtils.progress());
          }
          if (state is FetchSubCategoriesSuccess) {
            if (state.categories.isEmpty) return const SizedBox.shrink();
            return _buildSubCategoryChips(state.categories);
          }
          if (state is FetchSubCategoriesFailure) {
            // Can show retry here or fail silently
            return const SizedBox.shrink();
          }
          // Initial or other states
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSubCategoryChips(List<CategoryModel> subCats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${_selectedPropertyType?.name} Categories",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.color.textDefaultColor,
          ),
        ),
        const SizedBox(height: 12),

        /// 🔥 Horizontal scroll – single row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: subCats.map((child) {
              bool isSelected = _selectedSubCategory?.id == child.id;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(child.name ?? ""),
                  backgroundColor: isSelected
                      ? context.color.backgroundColor
                      : context.color.backgroundColor,
                  side: BorderSide(
                    color: isSelected
                        ? context.color.blackColor
                        : context.color.borderColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5), // 👈 change value
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? context.color.blackColor
                        : context.color.textDefaultColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedSubCategory = child;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: MaterialButton(
        onPressed: () {
          _onShowResults();
        },
        height: 50,
        minWidth: double.infinity,
        color: context.color.territoryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Text(
          "Show Results",
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _onShowResults() {
    // 1. Root Category (Property)
    // 2. Tab (Property for Rent / Sale)
    // 3. Type (Residential / Commercial)
    // 4. SubType (Apartment / Villa)

    List<String> accumulatedIds = [...widget.categoryIds];
    List<CategoryModel> accumulatedModels = []; // We need this for the chips!

    // We don't have the parent models of widget.categoryList here easily without fetching or passing them.
    // However, we have the current selections.

    if (_currentTabCategory != null) {
      accumulatedIds.add(_currentTabCategory!.id.toString());
      accumulatedModels.add(_currentTabCategory!);
    }
    if (_selectedPropertyType != null) {
      accumulatedIds.add(_selectedPropertyType!.id.toString());
      accumulatedModels.add(_selectedPropertyType!);
    }
    if (_selectedSubCategory != null) {
      accumulatedIds.add(_selectedSubCategory!.id.toString());
      accumulatedModels.add(_selectedSubCategory!);
    }

    // Determine the "final" category to show in the header or as main context
    // Usually the most specific one.
    CategoryModel targetCat = _selectedSubCategory ??
        _selectedPropertyType ??
        _currentTabCategory ??
        widget.categoryList[0];

    if (widget.from == "itemsList") {
      Navigator.pop(context, {
        'catID': targetCat.id.toString(),
        'catName': targetCat.name,
        'categorySlug': targetCat.slug,
        "categoryIds": accumulatedIds,
        "selectedCategoryChain": accumulatedModels,
      });
      return;
    }

    Navigator.pushNamed(context, Routes.itemsList, arguments: {
      'catID': targetCat.id.toString(),
      'catName': targetCat.name,
      'categorySlug': targetCat.slug,
      "categoryIds": accumulatedIds, // Passing the full chain IDs
      "selectedCategoryChain":
          accumulatedModels // Passing the full chain Models
    });
  }
}
