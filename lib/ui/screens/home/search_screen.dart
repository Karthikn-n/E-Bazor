import 'dart:async';
import 'dart:convert';

import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/item/search_item_cubit.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';
import 'package:Ebozor/data/cubits/item/fetch_popular_items_cubit.dart';

import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';

import 'package:Ebozor/utils/ApiService/api.dart';

import 'package:Ebozor/data/helper/designs.dart';
import 'package:Ebozor/data/model/item/item_model.dart';

import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/screens/home/widgets/item_horizontal_card.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:flutter/material.dart';
import 'package:Ebozor/utils/ui_utils.dart';

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
              create: (context) => FetchPopularItemsCubit(),),
          ],
          child: SearchScreen(
            autoFocus: arguments?['autoFocus'],
          )),
    );
  }

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<SearchScreen> {
  @override
  bool get wantKeepAlive => true;
  bool isFocused = false;
  String previousSearchQuery = "";
  static TextEditingController searchController = TextEditingController();
  final ScrollController controller = ScrollController();
  final ScrollController popularController = ScrollController();
  Timer? _searchDelay;
  ItemFilterModel? filter;

  //to store selected filter categories
  List<CategoryModel> categoryList = [];

  @override
  void initState() {
    super.initState();
    Constant.itemFilter = null;
    context.read<FetchPopularItemsCubit>().fetchPopularItems();
    //context.read<ItemCubit>().fetchItem(context, {});
    //context.read<SearchItemCubit>().searchItem(searchController.text, page: 1);
    // context.read<SearchItemCubit>().searchItem(searchController.text,
    //     page: 1, filter: _getLocationFilter());
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   context.read<SearchItemCubit>().searchItem(
    //     searchController.text, // empty text or default query
    //     page: 1,
    //     filter: filter ?? _getLocationFilter(),
    //   );
    // });

    searchController = TextEditingController();

    searchController.addListener(searchItemListener);
    controller.addListener(pageScrollListen);
    popularController.addListener(pagePopularScrollListen);
  }

  void pageScrollListen() {
    if (controller.isEndReached()) {
      if (context.read<SearchItemCubit>().hasMoreData()) {
        context
            .read<SearchItemCubit>()
            .fetchMoreSearchData(searchController.text, Constant.itemFilter);
      }
    }
  }

  void pagePopularScrollListen() {
    if (popularController.isEndReached()) {
      if (context.read<FetchPopularItemsCubit>().hasMoreData()) {
        context.read<FetchPopularItemsCubit>().fetchMyMoreItems();
      }
    }
  }

//this will listen and manage search
  void searchItemListener() {
    _searchDelay?.cancel();
    searchCallAfterDelay();
    setState(() {});
  }

//This will create delay so we don't face rapid api call
  void searchCallAfterDelay() {
    _searchDelay = Timer(const Duration(milliseconds: 500), itemSearch);
  }

  ///This will call api after some delay
  void itemSearch() {
    // if (searchController.text.isNotEmpty) {
    if (previousSearchQuery != searchController.text) {
      context.read<SearchItemCubit>().searchItem(
        searchController.text,
        page: 1,
        filter: filter ?? _getLocationFilter(),
      );
      previousSearchQuery = searchController.text;
      insertSearchQuery(searchController.text);
      setState(() {});
    } else {
      context.read<SearchItemCubit>().clearSearch();
    }
  }

  ItemFilterModel _getLocationFilter() {
    return ItemFilterModel(
      city: HiveUtils.getCityName(),
      areaId: HiveUtils.getAreaId(),
      country: HiveUtils.getCountryName(),
      state: HiveUtils.getStateName(),
    );
  }
  PreferredSizeWidget appBarWidget() {
    return AppBar(
      systemOverlayStyle:
          SystemUiOverlayStyle(statusBarColor: context.color.backgroundColor),
      bottom: PreferredSize(
          preferredSize: Size.fromHeight(64.rh(context)),
          child: LayoutBuilder(builder: (context, c) {
            return SizedBox(
                width: c.maxWidth,
                child: FittedBox(
                  fit: BoxFit.none,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        //seach sotainner
                        Container(
                            width: 270.rw(context),
                            height: 50.rh(context),
                            alignment: AlignmentDirectional.center,
                            decoration: BoxDecoration(
                                border: Border.all(
                                    width: context
                                                .watch<AppThemeCubit>()
                                                .state
                                                .appTheme ==
                                            AppTheme.dark
                                        ? 0
                                        : 1,
                                    color:
                                        context.color.borderColor.darken(30)),
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                                color: context.color.secondaryColor),
                            child: TextFormField(
                                autofocus: widget.autoFocus,
                                controller: searchController,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  //OutlineInputBorder()
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .secondaryColor,
                                  hintText:'searchHintLbl'.translate(context),
                                  prefixIcon: setSearchIcon(),
                                  prefixIconConstraints: const BoxConstraints(
                                      minHeight: 5, minWidth: 5),
                                ),
                                enableSuggestions: true,
                                onEditingComplete: () {
                                  setState(
                                    () {
                                      isFocused = false;
                                    },
                                  );
                                  FocusScope.of(context).unfocus();
                                },
                                onTap: () {
                                  //change prefix icon color to primary
                                  setState(() {
                                    isFocused = true;
                                  });
                                },onChanged: (text){
                                  searchItemListener();
                            },)),
                        const SizedBox(
                          width: 14,
                        ),

                        /////////////////filter icon
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, Routes.filterScreen,
                                arguments: {
                                  "update": getFilterValue,
                                  "from": "search",
                                  "categoryList": categoryList,
                                }).then((value) {
                              if (value == true) {
                                context.read<SearchItemCubit>().searchItem(
                                    searchController.text,
                                    page: 1,
                                    filter: filter);
                              }
                            });
                          },
                          child: Center(
                            child: Container(
                              width: 50.rw(context),
                              height: 50.rh(context),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    width: 1,
                                    color: context.color.borderColor.darken(30)),
                                color: context.color.secondaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: UiUtils.getSvg(
                                    filter != null
                                        ? AppIcons.filterByIcon
                                        : AppIcons.filter,
                                    color: context.color.territoryColor),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ));
          })),
      automaticallyImplyLeading: false,
      leading: Material(
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        type: MaterialType.circle,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: Padding(
              padding: EdgeInsetsDirectional.only(start: 18.0, top: 12),
              child: Directionality(
                  textDirection: Directionality.of(context),
                  child: RotatedBox(
                    quarterTurns:
                        Directionality.of(context) == TextDirection.rtl
                            ? 2
                            : -4,
                    child: UiUtils.getSvg(AppIcons.arrowLeft,
                        fit: BoxFit.none,
                        color: context.color.textDefaultColor),
                  ))),
        ),
      ),
      /*BackButton(
        color: context.color.textDefaultColor,
      ),*/
      elevation: context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark
          ? 0
          : 6,
      shadowColor:
          context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark
              ? null
              : context.color.textDefaultColor.withValues(alpha: 0.2),
      backgroundColor: context.color.backgroundColor,
    );
  }

  getFilterValue(ItemFilterModel model) {
    filter = model;
    setState(() {});
  }

  //simmer loader effect
  ListView shimmerEffect() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        vertical: 10 + defaultPadding,
        horizontal: defaultPadding,
      ),
      itemCount: 5,
      separatorBuilder: (context, index) {
        return const SizedBox(
          height: 12,
        );
      },
      itemBuilder: (context, index) {
        return Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                borderRadius: BorderRadius.all(Radius.circular(15)),
                child: CustomShimmer(height: 90, width: 90),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(
                        height: 10,
                      ),
                      CustomShimmer(
                        height: 10,
                        width: c.maxWidth - 50,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      const CustomShimmer(
                        height: 10,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      CustomShimmer(
                        height: 10,
                        width: c.maxWidth / 1.2,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Align(
                        alignment: AlignmentDirectional.bottomStart,
                        child: CustomShimmer(
                          width: c.maxWidth / 4,
                        ),
                      ),
                    ],
                  );
                }),
              )
            ],
          ),
        );
      },
    );
  }


  // here seach mainbody
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: true,
      onPopInvoked: (isPop) {
        Constant.itemFilter = null;
      },
      child: Scaffold(
        appBar: appBarWidget(),
        body: bodyData(),
        backgroundColor: context.color.backgroundColor,
      ),
    );
  }

/*  Widget bodyData() {
    return SingleChildScrollView(
      controller:
          searchController.text.isNotEmpty ? controller : popularController,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        buildHistoryItemList(),
        searchController.text.isNotEmpty
            ? searchItemsWidget()
            : popularItemsWidget(),
      ]),
    );
  }*/

  /////////////// seach data showsing body
  Widget bodyData() {
    return BlocConsumer<SearchItemCubit, SearchItemState>(
      listener: (context, searchState) {
        // Add any specific listener logic for SearchItemCubit state changes if needed
      },
      builder: (context, searchState) {
        bool hasSearchResults = searchState is SearchItemSuccess &&
            searchState.searchedItems.isNotEmpty;

        ScrollController activeController =
            hasSearchResults ? controller : popularController;

        return SingleChildScrollView(
          controller: activeController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildHistoryItemList(),
              if (searchController.text.isNotEmpty)
                searchItemsWidget()
              //else
              //  popularItemsWidget(),
            ],
          ),
        );
      },
    );
  }


  //////////seachbody ends here
  //////////////////////////////

  void clearBoxData() async {
    var box = Hive.box(HiveKeys.historyBox);
    await box.clear();
    setState(() {});
  }


  // seach history
  Widget buildHistoryItemList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box(HiveKeys.historyBox).listenable(),
      builder: (context, Box box, _) {
        List<ItemModel> items = [];
        for (var item in box.values) {
          if (item is String) {
            try {
              var json = jsonDecode(item);
              if (json['is_query'] == true) {
                 // Reconstruct a dummy item for display
                 items.add(ItemModel(
                   id: -1, 
                   name: json['name'], 
                   category: CategoryModel(name: ""),
                 ));
              } else {
                 items.add(ItemModel.fromJson(json));
              }
            } catch (e) {}
          }
        }
        // Show most recent first
        items = items.reversed.toList();

        if (items.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("recentSearches".translate(context))
                        .color(context.color.textDefaultColor.withValues(alpha: 0.5))
                        .bold(weight: FontWeight.w600),
                    InkWell(
                      child: Text("clear".translate(context))
                          .color(context.color.territoryColor),
                      onTap: () {
                        clearBoxData();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: items.map((item) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        searchController.text = item.name!;
                        searchController.selection = TextSelection.fromPosition(
                            TextPosition(offset: searchController.text.length));
                        setState(() {
                             isFocused = true; // Focus state to show search results if needed
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: context.color.borderColor.darken(30)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history,
                                size: 16,
                                color: context.color.textDefaultColor
                                    .withValues(alpha: 0.6)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(item.name!)
                                  .color(context.color.textDefaultColor)
                                  .size(context.font.normal)
                                  .setMaxLines(lines: 1),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Divider(
                  color: context.color.borderColor.darken(30),
                  thickness: 1.2,
                )
              ],
            ),
          );
        } else {
          return SizedBox.shrink();
        }
      },
    );
  }

/*  void insertNewItem(ItemModel model) {
    var box = Hive.box(HiveKeys.historyBox);

    if (box.length >= 5) {
      box.deleteAt(0);
    }

    box.add(jsonEncode(model.toJson()));

    setState(() {});
  }*/

  void insertNewItem(ItemModel model) {
    var box = Hive.box(HiveKeys.historyBox);
    
    // Create a simplified item or query wrapper if needed, but here we save the item
    // For search queries, we use a different method.
    // If we want to prevent dups:
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
        } catch(e) {}
      }
    }

    if (!exists) {
      if (box.length >= 10) { // Increase limit
        box.deleteAt(0);
      }
      box.add(jsonEncode(model.toJson()));
    }
    setState(() {});
  }

  void insertSearchQuery(String query) {
    if (query.trim().isEmpty) return;
    var box = Hive.box(HiveKeys.historyBox);
    
    // Check if query exists (using a custom format)
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
             } catch(e) {}
        }
    }

    if (!exists) {
       if (box.length >= 10) box.deleteAt(0);
       
       // Create a dummy ItemModel-like JSON for query
       Map<String, dynamic> queryJson = {
         'id': -1, // -1 for query
         'name': query,
         'is_query': true,
         'category': {'name': ''}, // dummy category
         'image': '',
         'price': 0,
         'total_likes': 0,
         'clicks': 0
       };
       box.add(jsonEncode(queryJson));
    }
  }

  Widget searchItemsWidget() {
    return BlocBuilder<SearchItemCubit, SearchItemState>(
      builder: (context, state) {
        if (state is SearchItemFetchProgress) {
          return shimmerEffect();
        }

        if (state is SearchItemFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage == "no-internet") {
              return SingleChildScrollView(
                child: NoInternet(
                  onRetry: () {
                    context.read<SearchItemCubit>().searchItem(
                        searchController.text.toString(),
                        page: 1,
                        filter: filter);
                  },
                ),
              );
            }
          }

          return Center(child: const SomethingWentWrong());
        }

        if (state is SearchItemSuccess) {
          if (state.searchedItems.isEmpty) {
            return SingleChildScrollView(
              child: NoDataFound(
                onTap: () {
                  context.read<SearchItemCubit>().searchItem(
                      searchController.text.toString(),
                      page: 1,
                      filter: filter);
                },
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: sidePadding,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.only(start: 5.0),
                  child: Text("searchedItems".translate(context))
                      .color(context.color.textDefaultColor.withValues(alpha: 0.5))
                      .size(context.font.normal),
                ),
                SizedBox(
                  height: 3,
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  separatorBuilder: (context, index) {
                    return Container(
                      height: 8,
                    );
                  },
                  itemBuilder: (context, index) {
                    ItemModel item = state.searchedItems[index];

                    return InkWell(
                      onTap: () {
                        try {
                          insertNewItem(item);
                        } catch (e) {}
                        Navigator.pushNamed(
                          context,
                          Routes.adDetailsScreen,
                          arguments: {
                            'model': item,
                          },
                        );
                      },
                      /// card design here
                      child: ItemHorizontalCard(
                        item: item,
                        showLikeButton: true,
                        additionalImageWidth: 8,
                      ),
                    );
                  },
                  itemCount: state.searchedItems.length,
                ),
                if (state.isLoadingMore)
                  Center(
                    child: UiUtils.progress(
                      normalProgressColor: context.color.territoryColor,
                    ),
                  )
              ],
            ),
          );
        }
        return Container();
      },
    );
  }

  Widget popularItemsWidget() {
    return BlocBuilder<FetchPopularItemsCubit, FetchPopularItemsState>(
      builder: (context, state) {
        if (state is FetchPopularItemsInProgress) {
          return shimmerEffect();
        }

        if (state is FetchPopularItemsFailed) {
          if (state.error is ApiException) {
            if (state.error.error == "no-internet") {
              return SingleChildScrollView(
                child: NoInternet(
                  onRetry: () {
                    context.read<FetchPopularItemsCubit>().fetchPopularItems();
                  },
                ),
              );
            }
          }

          return const SingleChildScrollView(child: SomethingWentWrong());
        }

        //api success agi item null erutha
        if (state is FetchPopularItemsSuccess) {
          if (state.items.isEmpty) {
            return Container();
          }

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: sidePadding,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ////// here seached automatic showing searching
                Padding(
                  padding: EdgeInsetsDirectional.only(start: 5.0),
                  child: Text("popularAds".translate(context))
                      .color(context.color.textDefaultColor.withValues(alpha: 0.5))
                      .size(context.font.normal),
                ),
                SizedBox(
                  height: 3,
                ),
                ListView.separated(
                  shrinkWrap: true,
                  /*  padding: const EdgeInsets.symmetric(
                    horizontal: sidePadding,
                    vertical: 8,
                  ),*/

                  physics: NeverScrollableScrollPhysics(),
                  separatorBuilder: (context, index) {
                    return Container(
                      height: 8,
                    );
                  },
                  itemBuilder: (context, index) {
                    ItemModel item = state.items[index];

                    return InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          Routes.adDetailsScreen,
                          arguments: {
                            'model': item,
                          },
                        );
                      },
                      child: ItemHorizontalCard(
                        item: item,
                        showLikeButton: true,
                        additionalImageWidth: 8,
                      ),
                    );
                  },
                  itemCount: state.items.length,
                ),
                if (state.isLoadingMore)
                  Center(
                    child: UiUtils.progress(
                      normalProgressColor: context.color.territoryColor,
                    ),
                  )
              ],
            ),
          );
        }
        return Container();
      },
    );
  }

  Widget setSearchIcon() {
    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: UiUtils.getSvg(AppIcons.search,
            color: context.color.territoryColor));
  }

  Widget setSuffixIcon() {
    return GestureDetector(
      onTap: () {
        searchController.clear();
        isFocused = false; //set icon color to black back
        FocusScope.of(context).unfocus(); //dismiss keyboard
        setState(() {});
      },
      child: Icon(
        Icons.close_rounded,
        color: Theme.of(context).colorScheme.blackColor,
        size: 30,
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
