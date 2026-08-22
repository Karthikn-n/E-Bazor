import 'package:Ebozor/data/cubits/category/fetch_sub_categories_cubit.dart';
import 'package:Ebozor/ui/screens/propertyscreen.dart';
import 'package:Ebozor/ui/screens/widgets/car_finance_calculator.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';


class SubCategoryScreenOne extends StatefulWidget {
  final List<CategoryModel> categoryList;
  final String catName;
  final int catId;
  final List<String> categoryIds;

  const SubCategoryScreenOne(
      {super.key,
        required this.categoryList,
        required this.catName,
        required this.catId,
        required this.categoryIds});

  @override
  State<SubCategoryScreenOne> createState() => _SubCategoryScreenOneState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => SubCategoryScreenOne(
        categoryList: args?['categoryList'] ?? [],
        catName: args?['catName'] ?? "",
        catId: args?['catId'] ?? 0,
        categoryIds: args?['categoryIds'] ?? [],
      ),
    );
  }
}

class _SubCategoryScreenOneState extends State<SubCategoryScreenOne>
    with TickerProviderStateMixin {
  late final ScrollController controller = ScrollController();

  @override
  void initState() {
    getSubCategories();
    if (widget.categoryList.isEmpty) {
      controller.addListener(pageScrollListen);
    }
    super.initState();
  }

  void getSubCategories() {
    if (widget.categoryList.isEmpty) {
      context
          .read<FetchSubCategoriesCubit>()
          .fetchSubCategories(categoryId: widget.catId);
    }
  }

  void pageScrollListen() {
    if (controller.isEndReached()) {
      if (context.read<FetchSubCategoriesCubit>().hasMoreData()) {
        context
            .read<FetchSubCategoriesCubit>()
            .fetchSubCategories(categoryId: widget.catId);
      }
    }
  }

  bool get _isMotorCategory {
    final name = widget.catName.toLowerCase();
    return name == "motors" ||
        name == "motor" ||
        name.contains("motor") ||
        name.contains("car") ||
        widget.catId == 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.catName.toLowerCase() == "property" ||
        widget.catName.toLowerCase() == "properties") {
      if (widget.categoryList.isNotEmpty) {
        return PropertyFilterScreen(
          categoryList: widget.categoryList,
          catName: widget.catName,
          catId: widget.catId,
          categoryIds: widget.categoryIds,
        );
      }

      return BlocBuilder<FetchSubCategoriesCubit, FetchSubCategoriesState>(
        builder: (context, state) {
          if (state is FetchSubCategoriesSuccess) {
            return PropertyFilterScreen(
              categoryList: state.categories,
              catName: widget.catName,
              catId: widget.catId,
              categoryIds: widget.categoryIds,
            );
          }
          if (state is FetchSubCategoriesFailure) {
            if (state.errorMessage is ApiException) {
              if (state.errorMessage == "no-internet") {
                return Scaffold(
                  body: NoInternet(
                    onRetry: () {
                      context
                          .read<FetchSubCategoriesCubit>()
                          .fetchSubCategories(categoryId: widget.catId);
                    },
                  ),
                );
              }
            }
            return Scaffold(body: const SomethingWentWrong());
          }

          return Scaffold(
              appBar: UiUtils.buildAppBar(
                context,
                showBackButton: true,
                title: widget.catName,
              ),
              body: Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: shimmerEffect()));
        },
      );
    }

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
          context: context, statusBarColor: context.color.secondaryColor),
      child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: UiUtils.buildAppBar(
            context,
            showBackButton: true,
            title: widget.catName,
          ),
          body: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: SingleChildScrollView(
              child: Material(
                color: context.color.secondaryColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 18),

                        ///all categores text here
                        child: Text(
                          "${"lblall".translate(context)}\t${widget.catName}",
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                            .color(context.color.textDefaultColor)
                            .size(context.font.normal)
                            .bold(weight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, Routes.itemsList,
                            arguments: {
                              'catID': widget.catId.toString(),
                              'catName': widget.catName,
                              "categoryIds": [...widget.categoryIds]
                            });
                      },
                    ),
                    const Divider(
                      thickness: 1.2,
                      height: 10,
                    ),
                    widget.categoryList.isNotEmpty
                        ? ListView.separated(
                      itemCount: widget.categoryList.length,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      separatorBuilder: (context, index) {
                        return const Divider(
                          thickness: 1.2,
                          height: 10,
                        );
                      },
                      itemBuilder: (context, index) {
                        CategoryModel category =
                        widget.categoryList[index];
                        return ListTile(
                          onTap: () {
                            final children = category.children ?? [];
                            final subCount = category.subcategoriesCount ?? 0;

                            if (children.isEmpty && subCount == 0) {
                              Navigator.pushNamed(
                                context,
                                Routes.itemsList,
                                arguments: {
                                  'catID': category.id?.toString() ?? "",
                                  'catName': category.name ?? "",
                                  "categoryIds": [
                                    ...widget.categoryIds,
                                    category.id?.toString() ?? ""
                                  ]
                                },
                              );
                            } else {
                              Navigator.pushNamed(
                                context,
                                Routes.subCategoryScreen,
                                arguments: {
                                  "categoryList": children,
                                  "catName": category.name ?? "",
                                  "catId": category.id ?? 0,
                                  "categoryIds": [
                                    ...widget.categoryIds,
                                    category.id?.toString() ?? ""
                                  ]
                                },
                              );
                            }
                          },

                          leading: Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.color.territoryColor.withValues(alpha: 0.1),
                            ),
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
                                    size: 24,
                                    color: context.color.territoryColor,
                                  ),
                          ),

                          title: Text(
                            category.name ?? "No Name", // ✅ FIX
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                              .color(context.color.textDefaultColor)
                              .size(context.font.normal),

                          trailing: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: context.color.borderColor.darken(10),
                            ),
                            child: Icon(
                              Icons.chevron_right_outlined,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                        );
                        //             0) {
                        //       Navigator.pushNamed(
                        //           context, Routes.itemsList,
                        //           arguments: {
                        //             'catID': widget.categoryList[index].id
                        //                 .toString(),
                        //             'catName':
                        //             widget.categoryList[index].name,
                        //             "categoryIds": [
                        //               ...widget.categoryIds,
                        //               widget.categoryList[index].id
                        //                   .toString()
                        //             ]
                        //           });
                        //     } else {
                        //       Navigator.pushNamed(
                        //           context, Routes.subCategoryScreen,
                        //           arguments: {
                        //             "categoryList": widget
                        //                 .categoryList[index].children,
                        //             "catName":
                        //             widget.categoryList[index].name,
                        //             "catId":
                        //             widget.categoryList[index].id,
                        //             "categoryIds": [
                        //               ...widget.categoryIds,
                        //               widget.categoryList[index].id
                        //                   .toString()
                        //             ]
                        //           });
                        //     }
                        //   },
                        //   leading: FittedBox(
                        //     child: Container(
                        //         width: 40,
                        //         height: 40,
                        //         clipBehavior: Clip.antiAlias,
                        //         padding: const EdgeInsets.all(0),
                        //         decoration: BoxDecoration(
                        //             shape: BoxShape.circle,
                        //             color: context.color.territoryColor
                        //                 .withValues(alpha: 0.1)),
                        //         child: ClipRRect(
                        //           child: UiUtils.imageType(
                        //             category.url!,
                        //             color: context.color.territoryColor,
                        //             width: double.infinity,
                        //             height: double.infinity,
                        //             fit: BoxFit.cover,
                        //           ),
                        //         )),
                        //   ),
                        //   title: Text(
                        //     category.name!,
                        //     textAlign: TextAlign.start,
                        //     maxLines: 2,
                        //     overflow: TextOverflow.ellipsis,
                        //   )
                        //       .color(context.color.textDefaultColor)
                        //       .size(context.font.normal),
                        //   trailing: Container(
                        //       width: 32,
                        //       height: 32,
                        //       decoration: BoxDecoration(
                        //           borderRadius: BorderRadius.circular(8),
                        //           color: context.color.borderColor
                        //               .darken(10)),
                        //       child: Icon(
                        //         Icons.chevron_right_outlined,
                        //         color: context.color.textDefaultColor,
                        //       )),
                        // );
                      },
                    )
                        : fetchSubCategoriesData(),

                    if (_isMotorCategory) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: _buildSellMyCarCard(context),
                      ),
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildServicesHeader(context),
                            const SizedBox(height: 14),
                            _buildServicesGrid(context),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ],
                ),
              ),
            ),
          )),
    );
  }

  Widget fetchSubCategoriesData() {
    return BlocBuilder<FetchSubCategoriesCubit, FetchSubCategoriesState>(
      builder: (context, state) {
        if (state is FetchSubCategoriesInProgress) {
          return shimmerEffect();
        }

        if (state is FetchSubCategoriesFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context
                      .read<FetchSubCategoriesCubit>()
                      .fetchSubCategories(categoryId: widget.catId);
                },
              );
            }
          }

          return const SomethingWentWrong();
        }

        if (state is FetchSubCategoriesSuccess) {
          if (state.categories.isEmpty) {
            return NoDataFound(
              onTap: () {
                context
                    .read<FetchSubCategoriesCubit>()
                    .fetchSubCategories(categoryId: widget.catId);
              },
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListView.separated(
                itemCount: state.categories.length,
                padding: EdgeInsets.zero,
                controller: controller,
                physics: NeverScrollableScrollPhysics(),
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
                      final children = category.children ?? [];
                      final subCount = category.subcategoriesCount ?? 0;

                      if (children.isEmpty && subCount == 0) {
                        Navigator.pushNamed(context, Routes.itemsList,
                            arguments: {
                              'catID': category.id?.toString() ?? "",
                              'catName': category.name ?? "",
                              "categoryIds": [
                                ...widget.categoryIds,
                                category.id?.toString() ?? ""
                              ]
                            });
                      } else {
                        Navigator.pushNamed(context, Routes.subCategoryScreen,
                            arguments: {
                              "categoryList": children,
                              "catName": category.name ?? "",
                              "catId": category.id ?? 0,
                              "categoryIds": [
                                ...widget.categoryIds,
                                category.id?.toString() ?? ""
                              ]
                            });
                      }
                    },
                    leading: Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.color.territoryColor.withValues(alpha: 0.1),
                      ),
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
                              size: 24,
                              color: context.color.territoryColor,
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
                    trailing: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: context.color.borderColor.darken(10)),
                        child: Icon(
                          Icons.chevron_right_outlined,
                          color: context.color.textDefaultColor,
                        )),
                  );
                },
              ),
              if (state.isLoadingMore) UiUtils.progress()
            ],
          );
        }

        return Container();
      },
    );
  }

  Widget shimmerEffect() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 15,
      separatorBuilder: (context, index) {
        return const Divider(
          thickness: 1.2,
          height: 10,
        );
      },
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
          highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
          child: Container(
            padding: EdgeInsets.all(5),
            width: double.maxFinite,
            height: 56,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
          ),
        );
      },
    );
  }

  Widget _buildSellMyCarCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2433) : const Color(0xFFE8EEFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.blue.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.pushNamed(context, Routes.carSpecsFormScreen);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Sell My Car",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  height: 52,
                  child: Image.asset(
                    "assets/icons/sell_car_banner.png",
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.directions_car_filled_rounded,
                        size: 40,
                        color: context.color.territoryColor,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesHeader(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: "Services by ",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.color.textDefaultColor,
        ),
        children: [
          TextSpan(
            text: "Ebazzor",
            style: TextStyle(
              color: context.color.territoryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          const TextSpan(
            text: " cars",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        // 1. Car Inspection
        _buildServiceCard(
          context: context,
          title: "Car\nInspection",
          backgroundColor:
              isDark ? const Color(0xFF2C1E1E) : const Color(0xFFFDECEB),
          iconWidget: Icon(
            Icons.car_repair_rounded,
            size: 32,
            color: Colors.redAccent.shade200,
          ),
          onTap: () => _showServiceBottomSheet(
            context: context,
            title: "Car Inspection",
            description:
                "Get a comprehensive 150+ point vehicle inspection conducted by certified automotive technicians before buying or selling.",
            actionText: "Request Inspection",
            icon: Icons.car_repair_rounded,
            accentColor: Colors.redAccent,
          ),
        ),

        // 2. Car Finance
        _buildServiceCard(
          context: context,
          title: "Car Finance",
          backgroundColor:
              isDark ? const Color(0xFF192837) : const Color(0xFFE8F4FD),
          iconWidget: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.shade600,
            ),
            child: const Center(
              child: Icon(
                Icons.percent_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          onTap: () => _openCarFinanceModal(context),
        ),

        // 3. Car Evaluation
        _buildServiceCard(
          context: context,
          title: "Car\nEvaluation",
          backgroundColor:
              isDark ? const Color(0xFF2E2718) : const Color(0xFFFFF4E5),
          iconWidget: Icon(
            Icons.assignment_turned_in_rounded,
            size: 30,
            color: Colors.amber.shade700,
          ),
          onTap: () => _showServiceBottomSheet(
            context: context,
            title: "Car Evaluation",
            description:
                "Find out the accurate market value of your vehicle based on real-time UAE market trends and valuation insights.",
            actionText: "Evaluate Now",
            icon: Icons.assignment_turned_in_rounded,
            accentColor: Colors.amber.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required Color backgroundColor,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.color.textDefaultColor,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                iconWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCarFinanceModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const CarFinanceCalculator(
                    initialPrice: 100000,
                    carName: "Motors Finance Calculator",
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showServiceBottomSheet({
    required BuildContext context,
    required String title,
    required String description,
    required String actionText,
    required IconData icon,
    required Color accentColor,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: accentColor, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.color.textLightColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.color.territoryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
