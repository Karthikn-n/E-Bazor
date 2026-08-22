import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';

import 'package:Ebozor/data/model/category_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


class CategoryFilterScreen extends StatefulWidget {
  final List<CategoryModel> categoryList;

  const CategoryFilterScreen({super.key, required this.categoryList});

  @override
  State<CategoryFilterScreen> createState() => _CategoryFilterScreenState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => CategoryFilterScreen(
        categoryList: args!["categoryList"],
      ),
    );
  }
}

class _CategoryFilterScreenState extends State<CategoryFilterScreen>
    with TickerProviderStateMixin {
  final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    _pageScrollController.addListener(() {
      if (_pageScrollController.isEndReached()) {
        if (context.read<FetchCategoryCubit>().hasMoreData()) {
          context.read<FetchCategoryCubit>().fetchCategoriesMore();
        }
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        onBackPress: () {
          Navigator.of(context).pop();
        },
        title: "classifieds".translate(context),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: context.screenWidth,
          child: BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
            builder: (context, state) {
              if (state is FetchCategoryInProgress) {
                return UiUtils.progress();
              }
              if (state is FetchCategorySuccess) {
                return Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: Container(
                    color: context.color.secondaryColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 18),
                          child: Text(
                            "allInClassified".translate(context),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                              .color(context.color.textDefaultColor)
                              .size(context.font.normal)
                              .bold(weight: FontWeight.w600),
                        ),
                        const Divider(
                          thickness: 1.2,
                          height: 10,
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: state.categories.length,
                            padding: EdgeInsets.zero,
                            controller: _pageScrollController,
                            shrinkWrap: true,
                            separatorBuilder: (context, index) {
                              return const Divider(
                                thickness: 1.2,
                                height: 10,
                              );
                            },
                            itemBuilder: (context, index) {
                              CategoryModel category = state.categories[index];

                              return ListTile(
                                onTap: () {
                                  widget.categoryList
                                      .add(state.categories[index]);

                                  const filterCategoryIds = [65, 68, 139, 143];
                                  final cat = state.categories[index];

                                  if (filterCategoryIds.contains(cat.id) ||
                                      (cat.name != null &&
                                          (cat.name!.toLowerCase().contains("property") ||
                                              cat.name!.toLowerCase().contains("properties")))) {
                                    Navigator.pushNamed(
                                      context,
                                      Routes.filterpage,
                                      arguments: cat,
                                    );
                                  } else if (cat.children?.isNotEmpty ?? false) {
                                    Navigator.pushNamed(
                                      context,
                                      Routes.subCategoryScreen,
                                      arguments: {
                                        "categoryList": cat.children,
                                        "catName": cat.name,
                                        "catId": cat.id,
                                        "categoryIds": [cat.id.toString()],
                                      },
                                    );
                                  } else {
                                    Navigator.pop(context, cat);
                                  }
                                },
                                leading: Container(
                                    width: 40,
                                    height: 40,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: context.color.territoryColor
                                            .withValues(alpha: 0.1)),
                                    child: (category.url != null && category.url!.trim().isNotEmpty)
                                        ? UiUtils.imageType(
                                            category.url!,
                                            color: category.url!.endsWith('.svg')
                                                ? context.color.territoryColor
                                                : null,
                                            fit: BoxFit.contain,
                                          )
                                        : Icon(
                                            Icons.category_outlined,
                                            color: context.color.territoryColor,
                                            size: 20,
                                          ),
                                ),
                                title: Text(
                                  category.name!,
                                  textAlign: TextAlign.start,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                                    .color(context.color.textDefaultColor)
                                    .size(context.font.normal),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: context.color.textLightColor,
                                  size: 22,
                                ),
                              );
                            },
                          ),
                        ),
                        if (state.isLoadingMore) Center(child: UiUtils.progress())
                      ],
                    ),
                  ),
                );
              }
              return Container();
            },
          ),
        ),
      ),
    );
  }
}
