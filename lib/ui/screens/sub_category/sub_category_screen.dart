import 'package:Ebozor/data/cubits/category/fetch_sub_categories_cubit.dart';
import 'package:Ebozor/data/model/motors_service_models.dart';
import 'package:Ebozor/settings.dart';
import 'package:Ebozor/ui/screens/home/widgets/jobs_bottom_sheet.dart';
import 'package:Ebozor/ui/screens/sub_category/sub_category_filter_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';

class SubCategoryScreenOne extends StatefulWidget {
  final List<CategoryModel> categoryList;
  final String catName;
  final String? catSlug;
  final int catId;
  final List<String> categoryIds;

  const SubCategoryScreenOne(
      {super.key,
      required this.categoryList,
      required this.catName,
      this.catSlug,
      required this.catId,
      required this.categoryIds});

  @override
  State<SubCategoryScreenOne> createState() => _SubCategoryScreenOneState();

  static Route route(RouteSettings routeSettings) {
    Map? args = routeSettings.arguments as Map?;
    return BlurredRouter(
      builder: (_) => BlocProvider(
        create: (context) => FetchSubCategoriesCubit(),
        child: SubCategoryScreenOne(
          categoryList: args?['categoryList'] ?? [],
          catName: args?['catName'] ?? "",
          catSlug:
              args?['categorySlug']?.toString() ?? args?['catSlug']?.toString(),
          catId: args?['catId'] ?? 0,
          categoryIds: args?['categoryIds'] ?? [],
        ),
      ),
    );
  }
}

class _SubCategoryScreenOneState extends State<SubCategoryScreenOne>
    with TickerProviderStateMixin {
  late final ScrollController controller = ScrollController();

  @override
  void initState() {
    super.initState();
    getSubCategories();
    controller.addListener(pageScrollListen);
  }

  void getSubCategories() {
    context
        .read<FetchSubCategoriesCubit>()
        .fetchSubCategories(categoryId: widget.catId);
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

  bool get _isMainMotorsCategory {
    if (widget.categoryIds.length > 1) return false;
    final name = widget.catName.trim().toLowerCase();
    final slug = (widget.catSlug ?? '').trim().toLowerCase();
    return name == "motors" ||
        name == "motor" ||
        slug == "motors" ||
        slug == "motor" ||
        widget.catId == 1;
  }

  @override
  Widget build(BuildContext context) {
    const filterCategoryIds = [65, 68, 139, 143];
    if (widget.catName.toLowerCase() == "property" ||
        widget.catName.toLowerCase() == "properties" ||
        filterCategoryIds.contains(widget.catId)) {
      return FiltersPage(
        category: CategoryModel(
          id: widget.catId,
          name: widget.catName,
          slug: widget.catSlug,
          children: widget.categoryList,
        ),
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
                              'categorySlug': widget.catSlug,
                              "categoryIds": [...widget.categoryIds]
                            });
                      },
                    ),
                    const Divider(
                      thickness: 1.2,
                      height: 10,
                    ),
                    fetchSubCategoriesData(),
                    if (_isMainMotorsCategory) ...[
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushReplacementNamed(
                  context,
                  Routes.itemsList,
                  arguments: {
                    'catID': widget.catId.toString(),
                    'catName': widget.catName,
                    'categorySlug': widget.catSlug,
                    "categoryIds": [...widget.categoryIds],
                  },
                );
              }
            });
            return shimmerEffect();
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListView.separated(
                itemCount: state.categories.length,
                padding: EdgeInsets.zero,
                controller: controller,
                physics: const NeverScrollableScrollPhysics(),
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
                      const filterCategoryIds = [65, 68, 139, 143];
                      if (filterCategoryIds.contains(category.id) ||
                          (category.name != null &&
                              (category.name!
                                      .toLowerCase()
                                      .contains("property") ||
                                  category.name!
                                      .toLowerCase()
                                      .contains("properties")))) {
                        Navigator.pushNamed(
                          context,
                          Routes.filterpage,
                          arguments: category,
                        );
                        return;
                      }

                      if (category.id == 4 ||
                          (category.name != null &&
                              category.name!.toLowerCase() == 'jobs') ||
                          (category.slug != null &&
                              category.slug!.toLowerCase() == 'jobs')) {
                        JobsBottomSheet.show(context, jobsCategory: category);
                        return;
                      }

                      Navigator.pushNamed(
                        context,
                        Routes.subCategoryScreen,
                        arguments: {
                          "categoryList": category.children ?? [],
                          "catName": category.name ?? "",
                          "categorySlug": category.slug,
                          "catId": category.id ?? 0,
                          "categoryIds": [
                            ...widget.categoryIds,
                            category.id?.toString() ?? ""
                          ]
                        },
                      );
                    },
                    leading: Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            context.color.territoryColor.withValues(alpha: 0.1),
                      ),
                      child: (category.url != null &&
                              category.url!.trim().isNotEmpty)
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
                      category.name ?? "No Name",
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
            final defaultCategory = CategoryModel(
              id: 6,
              name: widget.catName.isNotEmpty ? widget.catName : "Motors",
              slug: widget.catSlug ?? "motors",
              children: [],
              subcategoriesCount: 0,
            );
            Navigator.pushNamed(
              context,
              Routes.carSpecsFormScreen,
              arguments: <String, dynamic>{
                "category": defaultCategory,
                "current": defaultCategory,
                "breadcrumbs": [defaultCategory],
              },
            );
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
                  child: CachedNetworkImage(
                    imageUrl:
                        "${AppSettings.hostUrl}:8003/_next/static/media/sellcar.eb9a34b8.png",
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const SizedBox.shrink(),
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
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
      childAspectRatio: 2.5,
      children: [
        // 1. Car Inspection
        _buildServiceCard(
          context: context,
          title: "Car Inspection",
          backgroundColor:
              isDark ? const Color(0xFF2C1E1E) : const Color(0xFFFDECEB),
          onTap: () => Navigator.pushNamed(
            context,
            Routes.motorsServiceScreen,
            arguments: MotorsServiceType.inspection,
          ),
        ),

        // 2. Car Finance
        _buildServiceCard(
          context: context,
          title: "Car Finance",
          backgroundColor:
              isDark ? const Color(0xFF192837) : const Color(0xFFE8F4FD),
          onTap: () => Navigator.pushNamed(
            context,
            Routes.motorsServiceScreen,
            arguments: MotorsServiceType.finance,
          ),
        ),

        // 3. Car Evaluation
        _buildServiceCard(
          context: context,
          title: "Car Evaluation",
          backgroundColor:
              isDark ? const Color(0xFF2E2718) : const Color(0xFFFFF4E5),
          onTap: () => Navigator.pushNamed(
            context,
            Routes.motorsServiceScreen,
            arguments: MotorsServiceType.evaluation,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required Color backgroundColor,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.color.textDefaultColor,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
