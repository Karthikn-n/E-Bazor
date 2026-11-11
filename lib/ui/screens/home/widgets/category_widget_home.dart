import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/property_filter_category_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:Ebozor/ui/screens/home/widgets/jobs_bottom_sheet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/home/widgets/category_home_card.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';

class _CoreCategoryItem {
  final String title;
  final List<String> keywords;
  final Color bg;
  final Color iconColor;
  final WidgetBuilder iconBuilder;
  final IconData icon;
  final int defaultId;
  final String defaultSlug;

  const _CoreCategoryItem({
    required this.title,
    required this.keywords,
    required this.bg,
    required this.iconColor,
    required this.iconBuilder,
    required this.icon,
    required this.defaultId,
    required this.defaultSlug,
  });
}

class CategoryWidgetHome extends StatefulWidget {
  const CategoryWidgetHome({super.key});

  @override
  State<CategoryWidgetHome> createState() => _CategoryWidgetHomeState();
}

class _CategoryWidgetHomeState extends State<CategoryWidgetHome> {
  bool _isExpanded = false;

  /// The 7 core categories fixed to the mockup layout in home.jpeg:
  /// Row 1: Motors, Property, Electronics, Jobs
  /// Row 2: Home, Fashion, Services, More
  static final List<_CoreCategoryItem> _coreCategories = [
    _CoreCategoryItem(
      title: 'Motors',
      keywords: ['motor', 'car', 'auto'],
      bg: const Color(0xFFE8F1FE),
      iconColor: const Color(0xFF007AFF),
      iconBuilder: (context) => const Icon(
        Icons.directions_car_rounded,
        size: 30,
        color: Color(0xFF007AFF),
      ),
      icon: Icons.directions_car_rounded,
      defaultId: 1,
      defaultSlug: 'motors',
    ),
    _CoreCategoryItem(
      title: 'Property',
      keywords: ['propert', 'estate'],
      bg: const Color(0xFFFFEFE7),
      iconColor: const Color(0xFFFF7A1A),
      iconBuilder: (context) => const Icon(
        Icons.home_rounded,
        size: 30,
        color: Color(0xFFFF7A1A),
      ),
      icon: Icons.home_rounded,
      defaultId: 65,
      defaultSlug: 'property-for-rent',
    ),
    _CoreCategoryItem(
      title: 'Electronics',
      keywords: ['electr', 'phone', 'tablet', 'mobile', 'computer'],
      bg: const Color(0xFFE6F4FE),
      iconColor: const Color(0xFF0284C7),
      iconBuilder: (context) => const Icon(
        Icons.desktop_windows_rounded,
        size: 28,
        color: Color(0xFF0284C7),
      ),
      icon: Icons.desktop_windows_rounded,
      defaultId: 220,
      defaultSlug: 'classified-mobile-phones-tablets',
    ),
    _CoreCategoryItem(
      title: 'Jobs',
      keywords: ['job', 'career'],
      bg: const Color(0xFFF3E8FF),
      iconColor: const Color(0xFF8B5CF6),
      iconBuilder: (context) => const Icon(
        Icons.work_rounded,
        size: 28,
        color: Color(0xFF8B5CF6),
      ),
      icon: Icons.work_rounded,
      defaultId: 4,
      defaultSlug: 'jobs',
    ),
    _CoreCategoryItem(
      title: 'Home',
      keywords: ['home', 'furnitur', 'garden', 'decor'],
      bg: const Color(0xFFFCE7F3),
      iconColor: const Color(0xFFEC4899),
      iconBuilder: (context) => const Icon(
        Icons.home_rounded,
        size: 30,
        color: Color(0xFFEC4899),
      ),
      icon: Icons.home_rounded,
      defaultId: 219,
      defaultSlug: 'classified-furniture-home-garden',
    ),
    _CoreCategoryItem(
      title: 'Fashion',
      keywords: ['fashion', 'cloth', 'apparel', 'wear'],
      bg: const Color(0xFFFEF3C7),
      iconColor: const Color(0xFFF59E0B),
      iconBuilder: (context) => SvgPicture.string(
        '''<svg viewBox="0 0 24 24" width="28" height="28" fill="#F59E0B">
          <path d="M12 4a3 3 0 0 1 3 2.5h3.2a1 1 0 0 1 .9.6l2 4a1 1 0 0 1-.3 1.2l-2.2 1.5a1 1 0 0 1-1.3-.2l-.8-.9V20a1 1 0 0 1-1 1H7.5a1 1 0 0 1-1-1v-7.3l-.8.9a1 1 0 0 1-1.3.2l-2.2-1.5a1 1 0 0 1-.3-1.2l2-4a1 1 0 0 1 .9-.6H9A3 3 0 0 1 12 4z"/>
        </svg>''',
        width: 28,
        height: 28,
      ),
      icon: Icons.checkroom_rounded,
      defaultId: 204,
      defaultSlug: 'classified-clothing-accessories',
    ),
    _CoreCategoryItem(
      title: 'Services',
      keywords: ['servic', 'community'],
      bg: const Color(0xFFEBF4FF),
      iconColor: const Color(0xFF2563EB),
      iconBuilder: (context) => const Icon(
        Icons.build_rounded,
        size: 26,
        color: Color(0xFF2563EB),
      ),
      icon: Icons.build_rounded,
      defaultId: 444,
      defaultSlug: 'community',
    ),
  ];

  void _handleCategoryTap(BuildContext context, CategoryModel category) {
    /// ✅ MOTORS CATEGORY LANDING SCREEN
    final catName = (category.name ?? '').toLowerCase();
    final catSlug = (category.slug ?? '').toLowerCase();
    if (category.id == 1 ||
        catName == 'motors' ||
        catName == 'motor' ||
        catName == 'cars' ||
        catSlug == 'motors' ||
        catSlug == 'motor' ||
        catSlug == 'cars') {
      Navigator.pushNamed(
        context,
        Routes.motorsHomeScreen,
        arguments: {
          'category': category,
        },
      );
    }

    /// ✅ FILTER PAGE FOR PROPERTY
    else if (PropertyFilterCategoryResolver.isPropertyCategory(category)) {
      Navigator.pushNamed(
        context,
        Routes.filterpage,
        arguments: category,
      );
    }

    /// ✅ JOBS BOTTOM SHEET
    else if (category.id == 4 ||
        (category.name != null && category.name!.toLowerCase() == 'jobs') ||
        (category.slug != null && category.slug!.toLowerCase() == 'jobs')) {
      JobsBottomSheet.show(context, jobsCategory: category);
    }

    /// ✅ SUB CATEGORY (Inner categories flow via get-category-children-by-parent)
    else {
      Navigator.pushNamed(
        context,
        Routes.subCategoryScreen,
        arguments: {
          "categoryList": category.children ?? [],
          "catName": category.name ?? "",
          "categorySlug": category.slug,
          "catId": category.id ?? 0,
          "categoryIds": [category.id.toString()],
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
      builder: (context, state) {
        if (state is FetchCategoryInProgress) {
          return _buildShimmerGrid(context);
        }

        if (state is FetchCategorySuccess) {
          final List<CategoryModel> backendCategories = state.categories;

          // Map each of the 7 core categories to a backend model if available
          final Set<int> usedBackendIds = {};
          final List<Map<String, dynamic>> primaryItems = [];

          for (final core in _coreCategories) {
            CategoryModel? matchedModel;
            for (final cat in backendCategories) {
              if (usedBackendIds.contains(cat.id)) continue;
              final text = '${cat.name ?? ''} ${cat.slug ?? ''}'.toLowerCase();
              if (core.keywords.any((k) => text.contains(k))) {
                matchedModel = cat;
                if (cat.id != null) usedBackendIds.add(cat.id!);
                break;
              }
            }

            final effectiveModel = matchedModel ??
                CategoryModel(
                  id: core.defaultId,
                  name: core.title,
                  slug: core.defaultSlug,
                );

            primaryItems.add({
              'title': core.title,
              'bg': core.bg,
              'iconColor': core.iconColor,
              'customIcon': core.iconBuilder(context),
              'icon': core.icon,
              'model': effectiveModel,
            });
          }

          // Gather any other extra backend categories that weren't in the top 7
          final List<Map<String, dynamic>> extraItems = [];
          for (final cat in backendCategories) {
            if (usedBackendIds.contains(cat.id)) continue;
            extraItems.add({
              'title': cat.name ?? '',
              'bg': const Color(0xFFF1F5F9),
              'iconColor': const Color(0xFF007AFF),
              'icon': Icons.category_rounded,
              'model': cat,
            });
          }

          // If not expanded: 7 core categories + 1 "More" button = 8 tiles
          // If expanded: 7 core categories + extra categories + 1 "Less" button
          final int totalItems = _isExpanded
              ? (primaryItems.length + extraItems.length + 1)
              : (primaryItems.length + 1);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalItems,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 92,
                ),
                itemBuilder: (context, index) {
                  // Last slot is More / Less toggle
                  if (index == totalItems - 1) {
                    if (!_isExpanded) {
                      // MORE BUTTON -> Expands categories in-place!
                      return CategoryHomeCard(
                        title: "more".translate(context).isNotEmpty
                            ? "more".translate(context)
                            : "More",
                        bgColor: const Color(0xFFF1F5F9),
                        iconColor: const Color(0xFF334155),
                        customIcon: const Icon(
                          Icons.more_horiz_rounded,
                          size: 26,
                          color: Color(0xFF334155),
                        ),
                        onTap: () {
                          setState(() {
                            _isExpanded = true;
                          });
                        },
                      );
                    } else {
                      // LESS BUTTON -> Collapses categories back to 8 items!
                      return CategoryHomeCard(
                        title: "less".translate(context).isNotEmpty
                            ? "less".translate(context)
                            : "Less",
                        bgColor: const Color(0xFFF1F5F9),
                        iconColor: const Color(0xFF007AFF),
                        customIcon: const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 28,
                          color: Color(0xFF007AFF),
                        ),
                        onTap: () {
                          setState(() {
                            _isExpanded = false;
                          });
                        },
                      );
                    }
                  }

                  // Core 7 categories
                  if (index < primaryItems.length) {
                    final item = primaryItems[index];
                    final catModel = item['model'] as CategoryModel;
                    return CategoryHomeCard(
                      title: item['title'] as String,
                      customIcon: item['customIcon'] as Widget?,
                      bgColor: item['bg'] as Color,
                      iconColor: item['iconColor'] as Color,
                      fallbackIcon: item['icon'] as IconData,
                      onTap: () => _handleCategoryTap(
                        context,
                        catModel,
                      ),
                    );
                  }

                  // Extra categories when expanded
                  final extraIndex = index - primaryItems.length;
                  final extra = extraItems[extraIndex];
                  final extraModel = extra['model'] as CategoryModel;
                  return CategoryHomeCard(
                    title: extra['title'] as String,
                    url: extraModel.url,
                    bgColor: extra['bg'] as Color,
                    iconColor: extra['iconColor'] as Color,
                    fallbackIcon: extra['icon'] as IconData,
                    onTap: () => _handleCategoryTap(
                      context,
                      extraModel,
                    ),
                  );
                },
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildShimmerGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 8,
          mainAxisExtent: 92,
        ),
        itemBuilder: (context, index) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: const [
              CustomShimmer(
                width: 60,
                height: 60,
                borderRadius: 18,
              ),
              SizedBox(height: 6),
              CustomShimmer(
                width: 48,
                height: 8,
                borderRadius: 4,
              ),
            ],
          );
        },
      ),
    );
  }
}
