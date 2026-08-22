import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/ui/screens/home/widgets/jobs_bottom_sheet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/home/widgets/category_home_card.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';

class CategoryWidgetHome extends StatelessWidget {
  const CategoryWidgetHome({super.key});

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

          return Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) {
                final category = state.categories[index];

                return CategoryHomeCard(
                  title: category.name ?? "",
                  url: category.url ?? "",
                  onTap: () {
                    const filterCategoryIds = [65, 68, 139, 143];

                    /// ✅ FILTER PAGE FOR PROPERTY
                    if (filterCategoryIds.contains(category.id) ||
                        (category.name != null &&
                            (category.name!.toLowerCase().contains("property") ||
                                category.name!.toLowerCase().contains("properties")))) {
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
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.8,
        ),
        itemBuilder: (context, index) {
          return Card(
            elevation: 0.5,
            color: context.color.secondaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomShimmer(
                    width: 52,
                    height: 52,
                    borderRadius: 26,
                  ),
                  const SizedBox(height: 10),
                  CustomShimmer(
                    width: 60,
                    height: 12,
                    borderRadius: 6,
                  ),
                ],
              ),
            ),
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
