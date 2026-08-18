import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/ui/screens/main_activity.dart';
import 'package:Ebozor/ui/screens/sub_category/sub_category_filter_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/home/widgets/category_home_card.dart';

class CategoryWidgetHome extends StatelessWidget {
  const CategoryWidgetHome({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
      builder: (context, state) {
        if (state is FetchCategoryInProgress) {
          return const Center(child: CircularProgressIndicator());
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

              /// ❌ +1 REMOVED (NO MORE CARD)
              itemCount: state.categories.length,

              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) {

                // ❌ MORE CATEGORY REMOVED
                // if (index == state.categories.length) {
                //   return moreCategory(context);
                // }

                final category = state.categories[index];
                // print("BUILDING CATEGORY 👉 ${category.name} | ${category.url}");
                // print("IMAGE URL 👉 ${category.url}");

                return CategoryHomeCard(

                 title: category.name ?? "",
                 url: category.url ?? "",
                 // title: "Test",
                 // url: "https://upload.wikimedia.org/wikipedia/commons/6/6b/Bitmap_VS_SVG.svg",
                 //   print("CARD IMAGE 👉 $url");
                 //  onTap: () {
                 //
                 //    if (category.children!.isNotEmpty) {
                 //
                 //      Navigator.pushNamed(
                 //        context,
                 //
                 //        ///////// categories egga send aguthu
                 //        Routes.subCategoryScreen,
                 //        arguments: {
                 //          "categoryList": category.children,
                 //          "catName": category.name,
                 //          "catId": category.id,
                 //          "categoryIds": [category.id.toString()],
                 //        },
                 //      );
                 //    } else {
                 //      Navigator.pushNamed(
                 //        context,
                 //        Routes.itemsList,
                 //        arguments: {
                 //          "catID": category.id.toString(),
                 //          "catName": category.name,
                 //          "categoryIds": [category.id.toString()],
                 //        },
                 //      );
                 //
                 //    }
                 //  },

                    onTap: () {

                      const filterCategoryIds = [65, 68, 139, 143];

                      /// ✅ FILTER PAGE
                      if (filterCategoryIds.contains(category.id)) {

                        Navigator.pushNamed(
                          context,
                          Routes.filterpage,
                          arguments: category,
                          // arguments: {
                          //   "categoryList": category.children,
                          //   "catName": category.name,
                          //   "catId": category.id,
                          // },
                        );
                      }

                      /// ✅ SUB CATEGORY
                      else if (category.children != null &&
                          category.children!.isNotEmpty) {

                        Navigator.pushNamed(
                          context,
                          Routes.subCategoryScreen,
                          arguments: {
                            "categoryList": category.children,
                            "catName": category.name,
                            "catId": category.id,
                            "categoryIds": [category.id.toString()],
                          },
                        );
                      }

                      /// ✅ ITEM LIST
                      else {

                        Navigator.pushNamed(
                          context,
                          Routes.itemsList,
                          arguments: {
                            "catID": category.id.toString(),
                            "catName": category.name,
                            "categoryIds": [category.id.toString()],
                          },
                        );
                      }
                    }
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
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
