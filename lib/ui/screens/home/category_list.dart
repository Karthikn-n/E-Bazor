import 'package:Ebozor/ui/screens/home/widgets/jobs_bottom_sheet.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/utils/sliver_grid_delegate_with_fixed_cross_axis_count_and_fixed_height.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/property_filter_category_resolver.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/category.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';

class CategoryList extends StatefulWidget {
  final String? from;

  const CategoryList({super.key, this.from});

  @override
  State<CategoryList> createState() => _CategoryListState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => CategoryList(from: args?['from']),
    );
  }
}

class _CategoryListState extends State<CategoryList> {
  final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    _pageScrollController.addListener(pageScrollListen);
    super.initState();
  }

  void pageScrollListen() {
    if (_pageScrollController.isEndReached()) {
      if (context.read<FetchCategoryCubit>().hasMoreData()) {
        context.read<FetchCategoryCubit>().fetchCategoriesMore();
      }
    }
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
          context: context, statusBarColor: context.color.secondaryColor),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "categoriesLbl".translate(context),
        ),
        body: BlocConsumer<FetchCategoryCubit, FetchCategoryState>(
          listener: ((context, state) {
            // if (state is FetchCategorySuccess) {}
          }),
          builder: (context, state) {
            if (state is FetchCategoryInProgress) {
              return UiUtils.progress();
            }
            if (state is FetchCategorySuccess) {
              return Column(
                children: [
                  Expanded(
                      child: GridView.builder(
                    shrinkWrap: true,
                    controller: _pageScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCountAndFixedHeight(
                      crossAxisCount: 3,
                      height: MediaQuery.of(context).size.height * 0.18,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemBuilder: (context, index) {
                      CategoryModel category = state.categories[index];
                      return CategoryCard(
                        onTap: () {
                          if (widget.from == Routes.filterScreen) {
                            Navigator.pop(context, category);
                          } else {
                            if (PropertyFilterCategoryResolver
                                .isPropertyCategory(category)) {
                              Navigator.pushNamed(
                                context,
                                Routes.filterpage,
                                arguments: category,
                              );
                            } else if (category.id == 4 ||
                                (category.name != null &&
                                    category.name!.toLowerCase() == 'jobs') ||
                                (category.slug != null &&
                                    category.slug!.toLowerCase() == 'jobs')) {
                              JobsBottomSheet.show(context,
                                  jobsCategory: category);
                            } else {
                              Navigator.pushNamed(
                                context,
                                Routes.subCategoryScreen,
                                arguments: {
                                  "categoryList": category.children ?? [],
                                  "catName": category.name ?? "",
                                  "categorySlug": category.slug,
                                  "catId": category.id ?? 0,
                                  "categoryIds": [
                                    category.id.toString(),
                                  ],
                                },
                              );
                            }
                          }
                        },
                        title: category.name!,
                        url: category.url!,
                      );
                    },
                    itemCount: state.categories.length,
                  )),
                  if (state.isLoadingMore) UiUtils.progress()
                ],
              );
            }

            return Container();
          },
        ),
      ),
    );
    //   body:
    //       BlocBuilder<CategoryCubit, CategoryState>(builder: (context, state) {
    //     if (state is CategoryFetchProgress) {
    //       return const Center(
    //         child: CircularProgressIndicator(),
    //       );
    //     } else if (state is CategoryFetchSuccess) {
    //       initCategoryAnimations(state.categorylist);
    //       categorieslist.clear();
    //       categorieslist.addAll(state.categorylist);

    //       return gridWidget();
    //     } else if (state is ChangeSelectedCategory) {
    //       return gridWidget();
    //     } else {
    //       return const SizedBox.shrink();
    //     }
    //   }),
    // );
  }
}
