import 'dart:developer';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/repositories/category_repository.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/data/model/category_model.dart';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:Ebozor/utils/cloudState/cloud_state.dart';
import 'package:Ebozor/utils/touch_manager.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/repositories/custom_fields_repository.dart';
import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';

int screenStack = 0;

class SelectCategoryScreen extends StatefulWidget {
  const SelectCategoryScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(
      builder: (context) {
        return const SelectCategoryScreen();
      },
    );
  }

  @override
  CloudState<SelectCategoryScreen> createState() =>
      _SelectCategoryScreenState();
}

class _SelectCategoryScreenState extends CloudState<SelectCategoryScreen> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  late Future<List<CategoryModel>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _categoryRepository.fetchCategoryChildrenByParent();
  }

  void _handleCategoryTap(BuildContext context, CategoryModel cat) {
    final catName = cat.name ?? "";
    final catSlug = cat.slug ?? "";

    // Special check for Jobs category
    if (catSlug.toLowerCase() == 'jobs' ||
        catName.toLowerCase().contains('job')) {
      _showJobsSelectionBottomSheet(context, cat);
      return;
    }

    log("📌 [CATEGORY TAP] Navigating: $catName (ID: ${cat.id}, Slug: $catSlug)");

    addCloudData("breadCrumb", [cat]);
    Navigator.pushNamed(
      context,
      Routes.selectNestedCategoryScreen,
      arguments: {
        "current": cat,
        "breadcrumbs": [cat],
      },
    );
  }

  void _showJobsSelectionBottomSheet(
      BuildContext context, CategoryModel jobsCategory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.backgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.color.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Jobs in Ebozor",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Choose your goal",
                        style: TextStyle(
                          fontSize: 13.5,
                          color: context.color.textLightColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.color.textDefaultColor,
                    ),
                    onPressed: () => Navigator.pop(bottomSheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Two split cards side-by-side
              Row(
                children: [
                  // Option 1: I'm hiring
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        _openJobsBranch(
                          context,
                          jobsCategory,
                          categoryId: 356,
                          displayName: "I'm hiring",
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 20),
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.color.territoryColor
                                .withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: context.color.territoryColor
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.business_center_rounded,
                                color: context.color.territoryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "I'm hiring",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Recruiter / Company",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.color.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Option 2: I want a job
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        _openJobsBranch(
                          context,
                          jobsCategory,
                          categoryId: 357,
                          displayName: "I want a job",
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 20),
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.color.territoryColor
                                .withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: context.color.territoryColor
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_search_rounded,
                                color: context.color.territoryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "I want a job",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Job Seeker / Candidate",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.color.textLightColor,
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
        );
      },
    );
  }

  void _openJobsBranch(
    BuildContext context,
    CategoryModel jobsCategory, {
    required int categoryId,
    required String displayName,
  }) {
    CategoryModel? apiCategory;
    for (final child in jobsCategory.children ?? const <CategoryModel>[]) {
      if (child.id == categoryId) {
        apiCategory = child;
        break;
      }
    }
    final selectedCategory = CategoryModel(
      id: categoryId,
      name: displayName,
      url: apiCategory?.url,
      slug: apiCategory?.slug,
      description: apiCategory?.description,
      children: apiCategory?.children,
      subcategoriesCount: apiCategory?.subcategoriesCount,
      parentCategoryId: jobsCategory.id,
    );
    final breadcrumbs = [jobsCategory, selectedCategory];
    addCloudData("breadCrumb", breadcrumbs);
    Navigator.pushNamed(
      context,
      Routes.selectNestedCategoryScreen,
      arguments: {
        "current": selectedCategory,
        "breadcrumbs": breadcrumbs,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
          context: context, statusBarColor: context.color.secondaryColor),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: UiUtils.buildAppBar(
            context,
            showBackButton: true,
            title: "adListing".translate(context),
            onBackPress: () {
              Navigator.of(context).pop();
            },
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, what are you\nlisting today?",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Select the area that best suits your ad",
                  style: TextStyle(
                    fontSize: 14,
                    color: context.color.textLightColor,
                  ),
                ),
                const SizedBox(height: 24),
                FutureBuilder<List<CategoryModel>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildCategoryGridShimmer(context);
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                "Failed to load categories",
                                style: TextStyle(
                                    color: context.color.textDefaultColor),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _categoriesFuture = _categoryRepository
                                        .fetchCategoryChildrenByParent();
                                  });
                                },
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    List<CategoryModel> categories = snapshot.data ?? [];
                    if (categories.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                          child: Text(
                            "No categories found",
                            style:
                                TextStyle(color: context.color.textLightColor),
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _handleCategoryTap(context, cat),
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.color.secondaryColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: context.color.borderColor
                                    .withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: (cat.url != null &&
                                          cat.url!.isNotEmpty)
                                      ? UiUtils.imageType(
                                          cat.url!,
                                          fit: BoxFit.contain,
                                          // color: cat.url!.endsWith('.svg')
                                          //     ? context.color.territoryColor
                                          //     : null,
                                        )
                                      : Icon(
                                          Icons.category_outlined,
                                          size: 38,
                                          color: context.color.territoryColor,
                                        ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  cat.name ?? "",
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGridShimmer(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.15,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
          highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 80,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
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

class SelectNestedCategory extends StatefulWidget {
  const SelectNestedCategory({
    super.key,
    required this.current,
    this.breadcrumbs,
  });

  final CategoryModel current;
  final List<CategoryModel>? breadcrumbs;

  static Route route(RouteSettings settings) {
    Map<String, dynamic> arguments = settings.arguments as Map<String, dynamic>;
    return BlurredRouter(
      builder: (context) {
        return SelectNestedCategory(
          current: arguments['current'],
          breadcrumbs: arguments['breadcrumbs'] ?? arguments['breadCrumbItems'],
        );
      },
    );
  }

  @override
  CloudState<SelectNestedCategory> createState() =>
      _SelectNestedCategoryState();
}

class _SelectNestedCategoryState extends CloudState<SelectNestedCategory> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  final CustomFieldRepository _customFieldsRepository = CustomFieldRepository();
  late Future<List<CategoryModel>> _subCategoriesFuture;
  List<CategoryModel> breadCrumbData = [];

  @override
  void initState() {
    super.initState();
    if (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty) {
      breadCrumbData = List<CategoryModel>.from(widget.breadcrumbs!);
    } else {
      final dynamic rawBreadcrumb = getCloudData('breadCrumb');
      if (rawBreadcrumb is List && rawBreadcrumb.isNotEmpty) {
        breadCrumbData = rawBreadcrumb.whereType<CategoryModel>().toList();
      } else {
        breadCrumbData = [widget.current];
      }
    }

    if (widget.current.children != null &&
        widget.current.children!.isNotEmpty) {
      _subCategoriesFuture = Future.value(widget.current.children!);
    } else {
      _subCategoriesFuture = _categoryRepository.fetchCategoryChildrenByParent(
        parentId: widget.current.id,
      );
    }
  }

  void _onBreadCrumbItemTap(
    List<CategoryModel> dataList,
    int index,
  ) {
    int popTimes = (dataList.length - 1) - index;
    for (int i = 0; i < popTimes; i++) {
      Navigator.pop(context);
    }
  }

  Future<void> _onCategorySelected(CategoryModel category) async {
    if (!TouchManager.canProcessTouch()) return;

    // 1. Fetch children directly from the API using parent_category_id: category.id
    List<CategoryModel> children = [];
    try {
      Widgets.showLoader(context);
      children = await _categoryRepository.fetchCategoryChildrenByParent(
        parentId: category.id,
      );
    } catch (e) {
      log("❌ [CATEGORY CHILDREN FETCH ERROR] $e");
    } finally {
      if (mounted) {
        Widgets.hideLoader(context);
      }
    }

    // 2. If the API returned children -> navigate to the next subcategory level
    if (children.isNotEmpty) {
      final updatedCat = category.copyWith(children: children);
      screenStack++;
      Navigator.pushNamed(
        context,
        Routes.selectNestedCategoryScreen,
        arguments: {
          "current": updatedCat,
          "breadcrumbs": [
            ...breadCrumbData,
            updatedCat,
          ],
        },
      ).then((value) {
        screenStack--;
      });
      Future.delayed(const Duration(seconds: 1), () {
        TouchManager.touchProcessed();
      });
    } else {
      // 3. If no children returned from the API -> this is a leaf node!
      // Call get-customfields-by-category-id and navigate based on the category and custom fields
      final isCar = _isCarCategory(category, breadCrumbData);
      List<CustomFieldModel> customFields = [];
      if (!isCar) {
        try {
          Widgets.showLoader(context);
          customFields = await _customFieldsRepository
              .getCustomFieldsByCategoryId(category.id);
        } catch (e) {
          log("❌ [CUSTOM FIELDS BY CATEGORY FETCH ERROR] $e");
        } finally {
          if (mounted) {
            Widgets.hideLoader(context);
          }
        }
      }

      _navigateToPostingScreen(category, customFields: customFields);
    }
  }

  void _navigateToPostingScreen(CategoryModel category,
      {List<CustomFieldModel>? customFields}) {
    screenStack++;
    final isCar = _isCarCategory(category, breadCrumbData);
    final isMotor = breadCrumbData.any((b) =>
        b.slug?.toLowerCase().contains('motor') == true ||
        b.name?.toLowerCase().contains('motor') == true);
    final isProperty = breadCrumbData.any((b) =>
        b.slug?.toLowerCase().contains('property') == true ||
        b.name?.toLowerCase().contains('property') == true ||
        b.slug?.toLowerCase().contains('rent') == true ||
        b.slug?.toLowerCase().contains('sale') == true);

    if (isCar) {
      Navigator.pushNamed(
        context,
        Routes.carSpecsFormScreen,
        arguments: <String, dynamic>{
          "category": category,
          "current": category,
          "breadcrumbs": [
            ...breadCrumbData,
            category,
          ],
          "customFields": customFields,
        },
      ).then((value) {
        screenStack--;
      });
      Future.delayed(const Duration(seconds: 1), () {
        TouchManager.touchProcessed();
      });
      return;
    }

    if (isProperty) {
      Navigator.pushNamed(
        context,
        Routes.propertyPostingFormScreen,
        arguments: <String, dynamic>{
          "category": category,
          "breadcrumbs": [
            ...breadCrumbData,
            category,
          ],
          "initialTitle": getCloudData("prefilled_listing_title"),
          "customFields": customFields,
        },
      ).then((value) {
        screenStack--;
      });
    } else if (isMotor) {
      Navigator.pushNamed(
        context,
        Routes.motorPostingFormScreen,
        arguments: <String, dynamic>{
          "category": category,
          "breadcrumbs": [
            ...breadCrumbData,
            category,
          ],
          "customFields": customFields,
        },
      ).then((value) {
        screenStack--;
      });
    } else {
      Navigator.pushNamed(
        context,
        Routes.classifiedsPostingFormScreen,
        arguments: <String, dynamic>{
          "category": category,
          "breadcrumbs": [
            ...breadCrumbData,
            category,
          ],
          "initialTitle": getCloudData("prefilled_listing_title"),
          "customFields": customFields,
        },
      ).then((value) {
        screenStack--;
      });
    }

    Future.delayed(const Duration(seconds: 1), () {
      TouchManager.touchProcessed();
    });
  }

  bool _isCarCategory(CategoryModel category, List<CategoryModel> breadcrumbs) {
    final allSlugs = [
      category.slug?.toLowerCase() ?? '',
      ...breadcrumbs.map((b) => b.slug?.toLowerCase() ?? '')
    ];
    final allNames = [
      category.name?.toLowerCase() ?? '',
      ...breadcrumbs.map((b) => b.name?.toLowerCase() ?? '')
    ];

    // If under Motorcycles, Heavy Vehicles, Boats, Auto Accessories, or Number Plates -> not a car!
    if (allSlugs.any((s) =>
        s == 'motorcycles' ||
        s == 'heavy-vehicles' ||
        s == 'boats' ||
        s == 'auto-accessories-parts' ||
        s == 'number-plates')) {
      return false;
    }

    return allSlugs.contains('cars') ||
        allSlugs.contains('used-cars') ||
        allSlugs.contains('new-cars') ||
        allSlugs.contains('export-cars') ||
        allSlugs.contains('rental-cars') ||
        allNames.any((n) => n.contains('car'));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty) {
      breadCrumbData = List<CategoryModel>.from(widget.breadcrumbs!);
    }
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
          context: context, statusBarColor: context.color.secondaryColor),
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) async {
          return;
        },
        child: SafeArea(
          child: Scaffold(
            appBar: UiUtils.buildAppBar(context,
                showBackButton: true, title: "adListing".translate(context)),
            body: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("selectTheCategory".translate(context))
                      .size(context.font.large)
                      .bold(weight: FontWeight.w600)
                      .color(context.color.textColorDark),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 26,
                    width: context.screenWidth,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await Future.delayed(
                                const Duration(milliseconds: 5),
                                () {
                                  for (int i = 0;
                                      i < breadCrumbData.length;
                                      i++) {
                                    Navigator.pop(context);
                                  }
                                },
                              );
                            },
                            child: UiUtils.getSvg(
                              AppIcons.homeDark,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                          const Text(" > ").color(context.color.territoryColor),
                          ...breadCrumbData.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final isNotLast =
                                (breadCrumbData.length - 1) != index;

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    _onBreadCrumbItemTap(breadCrumbData, index);
                                  },
                                  child: Text(item.name ?? "")
                                      .firstUpperCaseWidget()
                                      .color(
                                        isNotLast
                                            ? context.color.territoryColor
                                            : context.color.textColorDark,
                                      ),
                                ),
                                if (isNotLast)
                                  const Text(" > ")
                                      .color(context.color.territoryColor)
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: FutureBuilder<List<CategoryModel>>(
                      future: _subCategoriesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return shimmerEffect();
                        }
                        if (snapshot.hasError) {
                          return const SomethingWentWrong();
                        }
                        final categories = snapshot.data ?? [];
                        if (categories.isEmpty) {
                          return NoDataFound(
                            onTap: () {
                              setState(() {
                                _subCategoriesFuture = _categoryRepository
                                    .fetchCategoryChildrenByParent(
                                  parentId: widget.current.id,
                                );
                              });
                            },
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            CategoryModel category = categories[index];
                            return GestureDetector(
                              onTap: () => _onCategorySelected(category),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    width: Constant.borderWidth,
                                    color: context.color.borderColor,
                                  ),
                                  color: context.color.secondaryColor,
                                ),
                                height: 56,
                                alignment: AlignmentDirectional.centerStart,
                                width: double.infinity,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(category.name ?? "")
                                            .color(context.color.textColorDark)
                                            .firstUpperCaseWidget()
                                            .bold(weight: FontWeight.w600),
                                      ),
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: context.color.primaryColor,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_ios_sharp,
                                          color: context.color.textColorDark,
                                          size: 12,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget shimmerEffect() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 15,
      separatorBuilder: (context, index) => Container(),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
          highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
          child: Container(
            padding: const EdgeInsets.all(5),
            width: double.maxFinite,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: context.color.borderColor.darken(30)),
            ),
          ),
        );
      },
    );
  }
}
