import 'dart:async';
import 'dart:convert';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/item/fetch_popular_items_cubit.dart';
import 'package:Ebozor/data/cubits/item/search_item_cubit.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';
import 'package:Ebozor/ui/screens/home/widgets/item_horizontal_card.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';

class SearchScreen extends StatefulWidget {
  final bool autoFocus;

  const SearchScreen({
    super.key,
    required this.autoFocus,
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;

    return BlurredRouter(
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => SearchItemCubit(),
          ),
          BlocProvider(
            create: (context) => FetchPopularItemsCubit(),
          ),
        ],
        child: SearchScreen(
          autoFocus: arguments?['autoFocus'] ?? false,
        ),
      ),
    );
  }

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<SearchScreen> {
  @override
  bool get wantKeepAlive => true;

  String previousSearchQuery = "";
  static TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final ScrollController searchScrollController = ScrollController();
  final ScrollController popularScrollController = ScrollController();
  Timer? _searchDelay;
  ItemFilterModel? filter;
  List<CategoryModel> categoryList = [];

  @override
  void initState() {
    super.initState();
    Constant.itemFilter = null;
    searchController = TextEditingController();
    context.read<FetchPopularItemsCubit>().fetchPopularItems();

    searchScrollController.addListener(_pageScrollListen);
    popularScrollController.addListener(_pagePopularScrollListen);
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    searchFocusNode.dispose();
    searchScrollController.dispose();
    popularScrollController.dispose();
    super.dispose();
  }

  void _pageScrollListen() {
    if (searchScrollController.isEndReached()) {
      if (context.read<SearchItemCubit>().hasMoreData()) {
        context.read<SearchItemCubit>().fetchMoreSearchData(
              searchController.text,
              filter ?? Constant.itemFilter,
            );
      }
    }
  }

  void _pagePopularScrollListen() {
    if (popularScrollController.isEndReached()) {
      if (context.read<FetchPopularItemsCubit>().hasMoreData()) {
        context.read<FetchPopularItemsCubit>().fetchMyMoreItems();
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 400), () {
      _executeSearch(value);
    });
    setState(() {});
  }

  void _executeSearch(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      if (previousSearchQuery != trimmedQuery) {
        context.read<SearchItemCubit>().searchItem(
              trimmedQuery,
              page: 1,
              filter: filter ?? _getLocationFilter(),
            );
        previousSearchQuery = trimmedQuery;
        _insertSearchQuery(trimmedQuery);
      }
    } else {
      previousSearchQuery = "";
      context.read<SearchItemCubit>().clearSearch();
    }
    setState(() {});
  }

  ItemFilterModel _getLocationFilter() {
    return ItemFilterModel(
      city: HiveUtils.getCityName(),
      areaId: HiveUtils.getAreaId(),
      country: HiveUtils.getCountryName(),
      state: HiveUtils.getStateName(),
      radius: HiveUtils.getNearbyRadius(),
      latitude: HiveUtils.getLatitude(),
      longitude: HiveUtils.getLongitude(),
    );
  }

  void _clearBoxData() async {
    var box = Hive.box(HiveKeys.historyBox);
    await box.clear();
    setState(() {});
  }

  void _removeHistoryItem(int index) async {
    var box = Hive.box(HiveKeys.historyBox);
    await box.deleteAt(index);
    setState(() {});
  }

  void _insertNewItem(ItemModel model) {
    var box = Hive.box(HiveKeys.historyBox);
    bool exists = false;
    for (int i = 0; i < box.length; i++) {
      var itemString = box.getAt(i);
      if (itemString is String) {
        try {
          var item = jsonDecode(itemString);
          if (item['id'] == model.id) {
            exists = true;
            break;
          }
        } catch (_) {}
      }
    }

    if (!exists) {
      if (box.length >= 10) {
        box.deleteAt(0);
      }
      box.add(jsonEncode(model.toJson()));
    }
    setState(() {});
  }

  void _insertSearchQuery(String query) {
    if (query.trim().isEmpty) return;
    var box = Hive.box(HiveKeys.historyBox);

    bool exists = false;
    for (int i = 0; i < box.length; i++) {
      var itemString = box.getAt(i);
      if (itemString is String) {
        try {
          var json = jsonDecode(itemString);
          if (json['is_query'] == true && json['name'] == query) {
            exists = true;
            break;
          }
        } catch (_) {}
      }
    }

    if (!exists) {
      if (box.length >= 10) box.deleteAt(0);
      Map<String, dynamic> queryJson = {
        'id': -1,
        'name': query,
        'is_query': true,
        'category': {'name': ''},
        'image': '',
        'price': 0,
        'total_likes': 0,
        'clicks': 0
      };
      box.add(jsonEncode(queryJson));
    }
  }

  void _getFilterValue(ItemFilterModel model) {
    setState(() {
      filter = model;
    });
  }

  bool get _hasActiveFilters {
    if (filter == null) return false;
    return (filter?.categoryId != null && filter!.categoryId!.isNotEmpty) ||
        (filter?.minPrice != null && filter!.minPrice!.isNotEmpty) ||
        (filter?.maxPrice != null && filter!.maxPrice!.isNotEmpty) ||
        (filter?.postedSince != null && filter!.postedSince!.isNotEmpty) ||
        (filter?.city != null && filter!.city!.isNotEmpty);
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: context.color.secondaryColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: context.color.textDefaultColor,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: Row(
          children: [
            // Search Input Field
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: context.color.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.color.borderColor.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
                child: TextField(
                  autofocus: widget.autoFocus,
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  textAlignVertical: TextAlignVertical.center,
                  onSubmitted: (value) {
                    searchFocusNode.unfocus();
                    _executeSearch(value);
                  },
                  style: TextStyle(
                    color: context.color.textDefaultColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "searchHintLbl"
                            .translate(context)
                            .replaceAll("%s", "items")
                            .isNotEmpty
                        ? "searchHintLbl"
                            .translate(context)
                            .replaceAll("%s", "items")
                        : "Search items...",
                    hintStyle: TextStyle(
                      color: context.color.textLightColor,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: context.color.textLightColor,
                      size: 20,
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 38, minHeight: 38),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: context.color.textLightColor,
                              size: 18,
                            ),
                            onPressed: () {
                              searchController.clear();
                              _executeSearch("");
                            },
                          )
                        : null,
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Filter Button
            Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        Routes.filterScreen,
                        arguments: {
                          "update": _getFilterValue,
                          "from": "search",
                          "categoryList": categoryList,
                        },
                      ).then((value) {
                        if (value == true) {
                          setState(() {});
                          context.read<SearchItemCubit>().searchItem(
                                searchController.text,
                                page: 1,
                                filter: filter,
                              );
                        }
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _hasActiveFilters
                            ? context.color.territoryColor.withValues(alpha: 0.12)
                            : context.color.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hasActiveFilters
                              ? context.color.territoryColor
                              : context.color.borderColor.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: _hasActiveFilters
                              ? context.color.territoryColor
                              : context.color.textDefaultColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_hasActiveFilters)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: context.color.territoryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.color.secondaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterBar() {
    if (!_hasActiveFilters) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: context.color.secondaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              "Filters:".translate(context),
              style: TextStyle(
                color: context.color.textLightColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (filter?.minPrice != null && filter!.minPrice!.isNotEmpty)
              _buildFilterChip("Min: ${filter!.minPrice}", () {
                setState(() {
                  filter = filter?.copyWith(minPrice: "");
                });
                context.read<SearchItemCubit>().searchItem(
                      searchController.text,
                      page: 1,
                      filter: filter,
                    );
              }),
            if (filter?.maxPrice != null && filter!.maxPrice!.isNotEmpty)
              _buildFilterChip("Max: ${filter!.maxPrice}", () {
                setState(() {
                  filter = filter?.copyWith(maxPrice: "");
                });
                context.read<SearchItemCubit>().searchItem(
                      searchController.text,
                      page: 1,
                      filter: filter,
                    );
              }),
            if (filter?.postedSince != null && filter!.postedSince!.isNotEmpty)
              _buildFilterChip(filter!.postedSince!, () {
                setState(() {
                  filter = filter?.copyWith(postedSince: "");
                });
                context.read<SearchItemCubit>().searchItem(
                      searchController.text,
                      page: 1,
                      filter: filter,
                    );
              }),
            TextButton(
              onPressed: () {
                setState(() {
                  filter = null;
                  Constant.itemFilter = null;
                });
                context.read<SearchItemCubit>().searchItem(
                      searchController.text,
                      page: 1,
                      filter: _getLocationFilter(),
                    );
              },
              child: Text(
                "Clear All".translate(context),
                style: TextStyle(
                  color: context.color.territoryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.color.territoryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.color.territoryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.color.territoryColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: context.color.territoryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItemList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box(HiveKeys.historyBox).listenable(),
      builder: (context, Box box, _) {
        List<ItemModel> items = [];
        for (var item in box.values) {
          if (item is String) {
            try {
              var json = jsonDecode(item);
              if (json['is_query'] == true) {
                items.add(ItemModel(
                  id: -1,
                  name: json['name'],
                  category: CategoryModel(name: ""),
                ));
              } else {
                items.add(ItemModel.fromJson(json));
              }
            } catch (_) {}
          }
        }

        items = items.reversed.toList();

        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: context.color.textLightColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "recentSearches".translate(context),
                        style: TextStyle(
                          color: context.color.textDefaultColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _clearBoxData,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        "clear".translate(context),
                        style: TextStyle(
                          color: context.color.territoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      searchController.text = item.name!;
                      searchController.selection = TextSelection.fromPosition(
                        TextPosition(offset: searchController.text.length),
                      );
                      searchFocusNode.unfocus();
                      _executeSearch(item.name!);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.color.backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.color.borderColor.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.north_west_rounded,
                            size: 13,
                            color: context.color.textLightColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.name!,
                              style: TextStyle(
                                color: context.color.textDefaultColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerEffect() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const CustomShimmer(height: 85, width: 85),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    SizedBox(height: 4),
                    CustomShimmer(height: 14, width: 140),
                    SizedBox(height: 8),
                    CustomShimmer(height: 12, width: 90),
                    SizedBox(height: 12),
                    CustomShimmer(height: 16, width: 70),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsWidget() {
    return BlocBuilder<SearchItemCubit, SearchItemState>(
      builder: (context, state) {
        if (state is SearchItemFetchProgress) {
          return _shimmerEffect();
        }

        if (state is SearchItemFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context.read<SearchItemCubit>().searchItem(
                        searchController.text,
                        page: 1,
                        filter: filter,
                      );
                },
              );
            }
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: SomethingWentWrong(),
            ),
          );
        }

        if (state is SearchItemSuccess) {
          if (state.searchedItems.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: context.color.textLightColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No listings found".translate(context),
                      style: TextStyle(
                        color: context.color.textDefaultColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Try searching with different keywords or check filters"
                          .translate(context),
                      style: TextStyle(
                        color: context.color.textLightColor,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${state.searchedItems.length} ${"searchedItems".translate(context)}",
                        style: TextStyle(
                          color: context.color.textLightColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: state.searchedItems.length,
                  itemBuilder: (context, index) {
                    ItemModel item = state.searchedItems[index];

                    return ItemHorizontalCard(
                      item: item,
                      showLikeButton: true,
                      additionalImageWidth: 8,
                      onTap: () {
                        try {
                          _insertNewItem(item);
                        } catch (_) {}
                        Navigator.pushNamed(
                          context,
                          Routes.adDetailsScreen,
                          arguments: {
                            'model': item,
                          },
                        );
                      },
                    );
                  },
                ),
                if (state.isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: UiUtils.progress(
                        normalProgressColor: context.color.territoryColor,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPopularItemsWidget() {
    return BlocBuilder<FetchPopularItemsCubit, FetchPopularItemsState>(
      builder: (context, state) {
        if (state is FetchPopularItemsInProgress) {
          return _shimmerEffect();
        }

        if (state is FetchPopularItemsFailed) {
          return const SizedBox.shrink();
        }

        if (state is FetchPopularItemsSuccess) {
          if (state.items.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 18,
                        color: context.color.territoryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "popularAds".translate(context),
                        style: TextStyle(
                          color: context.color.textDefaultColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    ItemModel item = state.items[index];

                    return ItemHorizontalCard(
                      item: item,
                      showLikeButton: true,
                      additionalImageWidth: 8,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          Routes.adDetailsScreen,
                          arguments: {
                            'model': item,
                          },
                        );
                      },
                    );
                  },
                ),
                if (state.isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: UiUtils.progress(
                        normalProgressColor: context.color.territoryColor,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        Constant.itemFilter = null;
      },
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildActiveFilterBar(),
            Expanded(
              child: SingleChildScrollView(
                controller: (searchController.text.isNotEmpty || _hasActiveFilters)
                    ? searchScrollController
                    : popularScrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recent Searches (shown when query is empty and no filters are active)
                    if (searchController.text.isEmpty && !_hasActiveFilters)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildHistoryItemList(),
                      ),

                    // Results or Popular listings
                    if (searchController.text.isNotEmpty || _hasActiveFilters)
                      _buildSearchResultsWidget()
                    else
                      _buildPopularItemsWidget(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
