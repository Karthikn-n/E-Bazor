import 'dart:developer';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/repositories/category_repository.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/utils/category_fallback_helper.dart';

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
import 'package:Ebozor/ui/screens/widgets/app_logo_widget.dart';

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

  Map<String, dynamic> _getCategoryStyle(String name, String slug) {
    final lower = '${name.toLowerCase()} ${slug.toLowerCase()}';
    if (lower.contains('motor') ||
        lower.contains('car') ||
        lower.contains('auto') ||
        lower.contains('vehicle')) {
      return {
        'color': const Color(0xFF007AFF),
        'sublabel': 'Cars, bikes, trucks',
        'icon': Icons.directions_car_rounded,
      };
    } else if (lower.contains('prop') ||
        lower.contains('real') ||
        lower.contains('estate') ||
        lower.contains('house') ||
        lower.contains('rent')) {
      return {
        'color': const Color(0xFF007AFF),
        'sublabel': 'Homes, apartments',
        'icon': Icons.home_work_rounded,
      };
    } else if (lower.contains('elect') ||
        lower.contains('phone') ||
        lower.contains('mobile') ||
        lower.contains('gadget') ||
        lower.contains('tech')) {
      return {
        'color': const Color(0xFF007AFF),
        'sublabel': 'Phones, computers',
        'icon': Icons.devices_other_rounded,
      };
    } else if (lower.contains('job') ||
        lower.contains('career') ||
        lower.contains('hire')) {
      return {
        'color': const Color(0xFF007AFF),
        'sublabel': 'Find or offer work',
        'icon': Icons.work_outline_rounded,
      };
    } else if (lower.contains('home') ||
        lower.contains('garden') ||
        lower.contains('furnit')) {
      return {
        'color': const Color(0xFF007AFF),
        'sublabel': 'Furniture, appliances',
        'icon': Icons.chair_outlined,
      };
    } else if (lower.contains('serv') || lower.contains('repair')) {
      return {
        'color': const Color(0xFF007AFF),
        'sublabel': 'Skills and local services',
        'icon': Icons.handyman_outlined,
      };
    }
    return {
      'color': const Color(0xFF007AFF),
      'sublabel': 'Browse listings',
      'icon': Icons.category_rounded,
    };
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
          appBar: AppBar(
            backgroundColor: context.color.secondaryColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: context.color.textDefaultColor,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: const AppLogoWidget(height: 28),
            centerTitle: !Navigator.canPop(context),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 24),
                color: context.color.textDefaultColor,
                onPressed: () {
                  Navigator.pushNamed(context, Routes.notificationPage);
                },
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    "What are you selling?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    "Choose a category to get started",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.color.textLightColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: Color(0xFF007AFF)),
                        SizedBox(width: 5),
                        Text(
                          "Usually takes about 2 minutes",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
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
                        childAspectRatio: 1.05,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final style = _getCategoryStyle(
                          cat.name ?? '',
                          cat.slug ?? '',
                        );

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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007AFF)
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: CategoryFallbackHelper
                                        .buildCategoryIconWidget(
                                      url: cat.url,
                                      title: cat.name ?? '',
                                      slug: cat.slug,
                                      fallbackIcon: style['icon'] as IconData?,
                                      iconColor: const Color(0xFF007AFF),
                                      size: 26,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  cat.name ?? "",
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  style['sublabel'] as String,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.color.textLightColor,
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
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFF007AFF),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Usually takes about 2 minutes",
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: context.color.textColorDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "A few simple steps and you're live!",
                              style: TextStyle(
                                fontSize: 12,
                                color: context.color.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
