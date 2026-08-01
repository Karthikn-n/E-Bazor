// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:developer';

//import 'package:app_links/app_links.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/data/cubits/slider_cubit.dart';
import 'package:Ebozor/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:Ebozor/data/cubits/system/get_api_keys_cubit.dart';
import 'package:Ebozor/ui/screens/home/widgets/grid_list_adapter.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';

import 'package:Ebozor/data/model/home/home_screen_section.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/notification/awsomeNotification.dart';
import 'package:Ebozor/utils/notification/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:uni_links/uni_links.dart';

import 'package:Ebozor/utils/ApiService/api.dart';

import 'package:Ebozor/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:Ebozor/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:Ebozor/data/helper/designs.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/system_settings_model.dart';

import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/ad_banner_screen.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/screens/home/widgets/item_horizontal_card.dart';
import 'package:Ebozor/ui/screens/home/widgets/category_widget_home.dart';
import 'package:Ebozor/ui/screens/home/widgets/home_search.dart';
import 'package:Ebozor/ui/screens/home/widgets/home_sections_adapter.dart';
import 'package:Ebozor/ui/screens/home/widgets/home_shimmers.dart';
import 'package:Ebozor/ui/screens/home/widgets/location_widget.dart';
import 'package:Ebozor/ui/screens/home/slider_widget.dart';
import 'package:Ebozor/ui/screens/home/widgets/verification_banner.dart';

const double sidePadding =12;

class HomeScreen extends StatefulWidget {
  final String? from;

  const HomeScreen({super.key, this.from});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<HomeScreen> {
  //
  @override
  bool get wantKeepAlive => true;

  //
  List<ItemModel> itemLocalList = [];

  //
  bool isCategoryEmpty = false;

  //
  late final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  Future<void> _refreshData() async {
    // context.read<SliderCubit>().fetchSlider(context);
    // context.read<FetchCategoryCubit>().fetchCategories();
    context.read<FetchHomeScreenCubit>().fetch(
        city: HiveUtils.getCityName(),
        areaId: HiveUtils.getAreaId(),
        country: HiveUtils.getCountryName(),
        state: HiveUtils.getStateName());
    context.read<FetchHomeAllItemsCubit>().fetch(
        city: HiveUtils.getCityName(),
        areaId: HiveUtils.getAreaId(),
        radius: HiveUtils.getNearbyRadius(),
        longitude: HiveUtils.getLongitude(),
        latitude: HiveUtils.getLatitude(),
        country: HiveUtils.getCountryName(),
        state: HiveUtils.getStateName());
  }

  @override
  void initState() {
    initializeSettings();
    addPageScrollListener();
    notificationPermissionChecker();
    LocalAwsomeNotification().init(context);
    ///////////////////////////////////////

    NotificationService.init(context);
    context.read<SliderCubit>().fetchSlider(context);
    context.read<FetchCategoryCubit>().fetchCategories();
    _refreshData();

    if (HiveUtils.isUserAuthenticated()) {
      context.read<FavoriteCubit>().getFavorite();
      //fetchApiKeys();
      context.read<GetBuyerChatListCubit>().fetch();
      context.read<BlockedUsersListCubit>().blockedUsersList();
    }

    _scrollController.addListener(() {
      if (_scrollController.isEndReached()) {
        if (context.read<FetchHomeAllItemsCubit>().hasMoreData()) {
          context.read<FetchHomeAllItemsCubit>().fetchMore(
                city: HiveUtils.getCityName(),
                areaId: HiveUtils.getAreaId(),
                radius: HiveUtils.getNearbyRadius(),
                longitude: HiveUtils.getLongitude(),
                latitude: HiveUtils.getLatitude(),
                country: HiveUtils.getCountryName(),
                stateName: HiveUtils.getStateName(),
              );
        }
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void initializeSettings() {
    final settingsCubit = context.read<FetchSystemSettingsCubit>();
    if (!const bool.fromEnvironment("force-disable-demo-mode",
        defaultValue: false)) {
      Constant.isDemoModeOn =
          settingsCubit.getSetting(SystemSetting.demoMode) ?? false;
    }
  }

  void addPageScrollListener() {
    //homeScreenController.addListener(pageScrollListener);
  }

  void fetchApiKeys() {
    context.read<GetApiKeysCubit>().fetch();
  }

 /*void pageScrollListener() {
    ///This will load data on page end
    if (homeScreenController.isEndReached()) {
      if (mounted) {
        if (context.read<FetchHomeItemsCubit>().hasMoreData()) {
          if (context.read<FetchHomeItemsCubit>().hasMoreData()) {
            context.read<FetchHomeItemsCubit>().fetchMoreItem();
          }
        }
      }
    }
  }*/

  @override
  Widget build(BuildContext context) {
    super.build(context);
    print(context.watch<SliderCubit>().state);

    return SafeArea(
      child: Scaffold(
     /*   appBar: AppBar(
          elevation: 0,
          leadingWidth: double.maxFinite,
          leading: Padding(
              padding: EdgeInsetsDirectional.only(
                  start: sidePadding.rw(context), end: sidePadding.rw(context)),
              child: const LocationWidget()),
          /* HiveUtils.getCityName() != null
                    ? const LocationWidget()
                    : const SizedBox.shrink()),*/
          backgroundColor: const Color.fromARGB(0, 0, 0, 0),
        ),*/
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          key: _refreshIndicatorKey,

          color: context.color.territoryColor,
          //triggerMode: RefreshIndicatorTriggerMode.onEdge,
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            child: Column(
              children: [
                BlocBuilder<FetchHomeScreenCubit, FetchHomeScreenState>(
                  builder: (context, state) {

                    if (state is FetchHomeScreenInProgress) {
                      return shimmerEffect();
                    }
                    if (state is FetchHomeScreenSuccess) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
     // seach widget at home scree
                          const HomeSearchField(),
                          const SliderWidget(),
                          const CategoryWidgetHome(),
                          if(HiveUtils.isUserAuthenticated() && HiveUtils.getUserDetails().isVerified != 1)...[
                            const VerificationBanner(),
                          ],
                          ...List.generate(state.sections.length, (index) {
                            HomeScreenSection section = state.sections[index];
                            if (state.sections.isNotEmpty) {
                              return HomeSectionsAdapter(
                                section: section,
                              );
                            } else {
                              return SizedBox.shrink();
                            }
                          }),
                          if (state.sections.isNotEmpty &&
                              Constant.isGoogleBannerAdsEnabled == "1") ...[
                            Container(
                              padding: EdgeInsets.only(top: 5),
                              margin: EdgeInsets.symmetric(vertical: 10),
                              child:
                                  AdBannerWidget(), // Custom widget for banner ad
                            )
                          ] else ...[
                            SizedBox(
                              height: 10,
                            )
                          ],
                        ],
                      );
                    }

                    if(state is FetchHomeScreenFail)
                    {
                      print('hey bro ${state.error}');
                    }
                    return SizedBox.shrink();
                  },
                ),
                // const AllItemsWidget(),
                const SizedBox(
                  height: 30,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget shimmerEffect() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 24,
          horizontal: defaultPadding,
        ),
        child: Column(
          children: [
            ClipRRect(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              borderRadius: BorderRadius.all(Radius.circular(10)),
              child: CustomShimmer(height: 52, width: double.maxFinite),
            ),
            SizedBox(
              height: 12,
            ),
            ClipRRect(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              borderRadius: BorderRadius.all(Radius.circular(10)),
              child: CustomShimmer(height: 170, width: double.maxFinite),
            ),
            SizedBox(
              height: 12,
            ),
            Container(
              height: 100,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: 10,
                physics: NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: index == 0 ? 0 : 8.0),
                    child: const Column(
                      children: [
                        ClipRRect(
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          child: CustomShimmer(
                            height: 70,
                            width: 66,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        CustomShimmer(
                          height: 10,
                          width: 48,
                        ),
                        const SizedBox(
                          height: 2,
                        ),
                        const CustomShimmer(
                          height: 10,
                          width: 60,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomShimmer(
                  height: 20,
                  width: 150,
                ),
                /* CustomShimmer(
                  height: 20,
                  width: 50,
                ),*/
              ],
            ),
            Container(
              height: 214,
              margin: EdgeInsets.only(top: 10),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: 5,
                physics: NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: index == 0 ? 0 : 10.0),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          child: CustomShimmer(
                            height: 147,
                            width: 250,
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        CustomShimmer(
                          height: 15,
                          width: 90,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const CustomShimmer(
                          height: 14,
                          width: 230,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const CustomShimmer(
                          height: 14,
                          width: 200,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.only(top: 20),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: 16,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        child: CustomShimmer(
                          height: 147,
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      CustomShimmer(
                        height: 15,
                        width: 70,
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      const CustomShimmer(
                        height: 14,
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      const CustomShimmer(
                        height: 14,
                        width: 130,
                      ),
                    ],
                  );
                },
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  mainAxisExtent: 215,
                  crossAxisCount: 2, // Single column grid
                  mainAxisSpacing: 15.0,
                  crossAxisSpacing: 15.0,
                  // You may adjust this aspect ratio as needed
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget sliderWidget() {
    return BlocConsumer<SliderCubit, SliderState>(
      listener: (context, state) {

        if (state is SliderFetchSuccess) {
          setState(() {});
        }
      },
      builder: (context, state) {
        log('State is  $state');
        if (state is SliderFetchInProgress) {
          return const SliderShimmer();
        }
        if (state is SliderFetchFailure) {
          return Container();
        }
        if (state is SliderFetchSuccess) {
        
          if (state.sliderlist.isNotEmpty) {
            return const SliderWidget();
          }
        }
        return Container();
      },
    );
  }
}

class AllItemsWidget extends StatelessWidget {
  const AllItemsWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchHomeAllItemsCubit, FetchHomeAllItemsState>(
      builder: (context, state) {
        if (state is FetchHomeAllItemsSuccess) {
          if (state.items.isNotEmpty) {
            return Column(
              children: [
                Text("Recent Ads"),
                GridListAdapter(
                  type: ListUiType.Mixed,
                  mixMode: true,
                  crossAxisCount: 2,
                  height: MediaQuery.of(context).size.height / 3.5.rh(context),
                  builder: (context, int index, bool isGrid) {
                    ItemModel? item = state.items[index];

                    if (isGrid) {
                      // Show ItemCard for grid items
                      return ItemCard(
                        item: item,
                        width: 192,
                      );
                    } else {
                      // Show ItemHorizontalCard for list items
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
                    }
                    // }
                  },
                  total: state.items.length,
                ),
                if (state.isLoadingMore) UiUtils.progress(),
              ],
            );
          } else {
            return SizedBox.shrink();
          }
        }
        if (state is FetchHomeAllItemsFail) {
          if (state.error is ApiException) {
            if (state.error.error == "no-internet") {
              return Center(child: NoInternet());
            }
          }

          return const SomethingWentWrong();
        }
        return SizedBox.shrink();
      },
    );
  }
}



Future<void> notificationPermissionChecker() async {
  if (!(await Permission.notification.isGranted)) {
    await Permission.notification.request();
  }
}
