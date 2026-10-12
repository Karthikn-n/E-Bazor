import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/data/model/property_filter_category_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/ui/screens/home/widgets/jobs_bottom_sheet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/home/widgets/category_home_card.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';

class CategoryWidgetHome extends StatelessWidget {
  const CategoryWidgetHome({super.key});

  static Map<String, dynamic> _getCategoryStyle(String name, String slug, int index) {
    final lowerName = name.toLowerCase();
    final lowerSlug = slug.toLowerCase();

    if (lowerName.contains('motor') || lowerName.contains('car') || lowerName.contains('auto') || lowerSlug.contains('motor') || lowerSlug.contains('car')) {
      return {
        'bg': const Color(0xFFEBF3FF),
        'iconColor': const Color(0xFF007AFF),
        'icon': Icons.directions_car_rounded,
      };
    } else if (lowerName.contains('propert') || lowerName.contains('real estate') || (lowerName.contains('home') && lowerName.contains('rent')) || lowerSlug.contains('propert')) {
      return {
        'bg': const Color(0xFFFFF3EB),
        'iconColor': const Color(0xFFFF7A1A),
        'icon': Icons.home_rounded,
      };
    } else if (lowerName.contains('electr') || lowerName.contains('phone') || lowerName.contains('computer') || lowerSlug.contains('electr')) {
      return {
        'bg': const Color(0xFFE8F5FE),
        'iconColor': const Color(0xFF0284C7),
        'icon': Icons.devices_rounded,
      };
    } else if (lowerName.contains('job') || lowerName.contains('career') || lowerSlug.contains('job')) {
      return {
        'bg': const Color(0xFFF3EDFD),
        'iconColor': const Color(0xFF8B5CF6),
        'icon': Icons.work_rounded,
      };
    } else if (lowerName.contains('home') || lowerName.contains('furnitur') || lowerName.contains('garden') || lowerSlug.contains('home') || lowerSlug.contains('garden')) {
      return {
        'bg': const Color(0xFFFDE8EF),
        'iconColor': const Color(0xFFEC4899),
        'icon': Icons.weekend_rounded,
      };
    } else if (lowerName.contains('fashion') || lowerName.contains('cloth') || lowerName.contains('wear') || lowerSlug.contains('fashion')) {
      return {
        'bg': const Color(0xFFFEF6E4),
        'iconColor': const Color(0xFFF59E0B),
        'icon': Icons.checkroom_rounded,
      };
    } else if (lowerName.contains('servic') || lowerSlug.contains('servic')) {
      return {
        'bg': const Color(0xFFEBF5FF),
        'iconColor': const Color(0xFF2563EB),
        'icon': Icons.build_rounded,
      };
    }

    const defaultStyles = [
      {'bg': Color(0xFFEBF3FF), 'iconColor': Color(0xFF007AFF), 'icon': Icons.directions_car_rounded},
      {'bg': Color(0xFFFFF3EB), 'iconColor': Color(0xFFFF7A1A), 'icon': Icons.home_rounded},
      {'bg': Color(0xFFE8F5FE), 'iconColor': Color(0xFF0284C7), 'icon': Icons.devices_rounded},
      {'bg': Color(0xFFF3EDFD), 'iconColor': Color(0xFF8B5CF6), 'icon': Icons.work_rounded},
      {'bg': Color(0xFFFDE8EF), 'iconColor': Color(0xFFEC4899), 'icon': Icons.weekend_rounded},
      {'bg': Color(0xFFFEF6E4), 'iconColor': Color(0xFFF59E0B), 'icon': Icons.checkroom_rounded},
      {'bg': Color(0xFFEBF5FF), 'iconColor': Color(0xFF2563EB), 'icon': Icons.build_rounded},
    ];
    return defaultStyles[index % defaultStyles.length];
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
      builder: (context, state) {
        if (state is FetchCategoryInProgress) {
          return _buildShimmerGrid(context);
        }

        if (state is FetchCategorySuccess) {
          if (state.categories.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(50),
              child: NoDataFound(onTap: null),
            );
          }

          final bool hasMore = state.categories.length > 7;
          final int displayCount = hasMore ? 8 : (state.categories.length + 1);
          final categoriesToShow = state.categories.take(7).toList();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 6,
                mainAxisExtent: 88,
              ),
              itemBuilder: (context, index) {
                // The 8th slot (index 7 or last) is "More"
                if (index == displayCount - 1) {
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
                      Navigator.pushNamed(
                        context,
                        Routes.categories,
                        arguments: {
                          "from": Routes.home,
                          "categories": state.categories,
                        },
                      );
                    },
                  );
                }

                final category = categoriesToShow[index];
                final style = _getCategoryStyle(
                  category.name ?? '',
                  category.slug ?? '',
                  index,
                );

                return CategoryHomeCard(
                  title: category.name ?? "",
                  url: category.url ?? "",
                  bgColor: style['bg'] as Color,
                  iconColor: style['iconColor'] as Color,
                  fallbackIcon: style['icon'] as IconData,
                  onTap: () {
                    /// ✅ FILTER PAGE FOR PROPERTY
                    if (PropertyFilterCategoryResolver.isPropertyCategory(
                        category)) {
                      Navigator.pushNamed(
                        context,
                        Routes.filterpage,
                        arguments: category,
                      );
                    }

                    /// ✅ JOBS BOTTOM SHEET
                    else if (category.id == 4 ||
                        (category.name != null &&
                            category.name!.toLowerCase() == 'jobs') ||
                        (category.slug != null &&
                            category.slug!.toLowerCase() == 'jobs')) {
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
                  },
                );
              },
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
          mainAxisSpacing: 10,
          crossAxisSpacing: 6,
          mainAxisExtent: 88,
        ),
        itemBuilder: (context, index) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomShimmer(
                width: 56,
                height: 56,
                borderRadius: 16,
              ),
              const SizedBox(height: 6),
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

// ---------------- MORE CATEGORY CARD ----------------
// ❌ NOT USED – COMMENTED
/*
  Widget moreCategory(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          Routes.categories,
          arguments: {"from": Routes.home},
        ).then((value) {
          if (value != null) {
            selectedCategory = value;
          }
        });
      },
      child: Column(
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: context.color.borderColor.darken(60),
              ),
              color: context.color.secondaryColor,
            ),
            child: Center(
              child: RotatedBox(
                quarterTurns: 1,
                child: UiUtils.getSvg(
                  AppIcons.more,
                  color: context.color.territoryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text("more".translate(context))
              .centerAlign()
              .setMaxLines(lines: 2)
              .size(context.font.smaller)
              .color(context.color.textDefaultColor),
        ],
      ),
    );
  }
  */
}
