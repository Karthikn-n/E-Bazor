import 'dart:io';

import 'package:Ebozor/data/cubits/subscription/fetch_ads_listing_subscription_packages_cubit.dart';
import 'package:Ebozor/data/cubits/system/get_api_keys_cubit.dart';
import 'package:Ebozor/settings.dart';
import 'package:Ebozor/ui/screens/subscription/widget/featured_ads_subscription_plan_item.dart';
import 'package:Ebozor/ui/screens/subscription/widget/item_listing_subscription_plans_item.dart';
import 'package:Ebozor/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/payment/gatways/inAppPurchaseManager.dart';
import 'package:Ebozor/utils/payment/gatways/stripe_service.dart';
import 'package:Ebozor/data/cubits/subscription/assign_free_package_cubit.dart';
import 'package:Ebozor/data/cubits/subscription/fetch_featured_subscription_packages_cubit.dart';
import 'package:Ebozor/data/model/subscription_pacakage_model.dart';
import 'package:flutter/material.dart';

import 'package:Ebozor/utils/ApiService/api.dart';

import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SubscriptionPackageListScreen extends StatefulWidget {
  const SubscriptionPackageListScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(builder: (context) {
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AssignFreePackageCubit(),
          ),
          //BlocProvider<InAppPurchaseCubit>(create: (_) => InAppPurchaseCubit()),
        ],
        child: const SubscriptionPackageListScreen(),
      );
    });
  }

  @override
  State<SubscriptionPackageListScreen> createState() => _SubscriptionPackageListScreenState();
}

class _SubscriptionPackageListScreenState
    extends State<SubscriptionPackageListScreen> {
  //List mySubscriptions = [];
  bool isLifeTimeSubscription = false;
  bool hasAlreadyPackage = false;
  bool isInterstitialAdShown = false;

  PageController adsPageController =
      PageController(initialPage: 0, viewportFraction: 0.8);
  PageController featuredPageController =
      PageController(initialPage: 0, viewportFraction: 0.8);

  int currentIndex = 0;
  TabController? _tabController;

  List<SubscriptionPackageModel> iapListingAdsProducts = [];
  List<String> listingAdsProducts = [];
  List<SubscriptionPackageModel> iapFeaturedAdsProducts = [];
  List<String> featuredAdsProducts = [];
  final InAppPurchaseManager _inAppPurchaseManager = InAppPurchaseManager();

  //bool isCurrentPlan = false;

  @override
  void initState() {
    AdHelper.loadInterstitialAd();
    if (HiveUtils.isUserAuthenticated()) {
      context.read<GetApiKeysCubit>().fetch();
    }
    context.read<FetchAdsListingSubscriptionPackagesCubit>().fetchPackages();
    context.read<FetchFeaturedSubscriptionPackagesCubit>().fetchPackages();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _tabController = DefaultTabController.of(context);
    //   _tabController!.addListener(_handleTabSelection);
    // });
    if (Platform.isIOS) {
      InAppPurchaseManager.getPendings();
      _inAppPurchaseManager.listenIAP(context);
    }
    //_initializeInAppPurchase();
    super.initState();
    //inAppPurchase.listenIAP(context);
  }

  /* Future<void> _initializeInAppPurchase() async {
    List<String> productIds = []; // Populate this with your product IDs
    await _inAppPurchaseManager.initialize(productIds);
  }*/

/*  void adsListingInitPurchase() {
    Future.delayed(Duration.zero, () async {
      context.read<FetchAdsListingSubscriptionPackagesCubit>().fetchPackages();
      iapProducts = await InAppPurchaseRepo.fetchInAppProducts();
      if (context.read<UserDetailsCubit>().removeAds()) {
        iapProducts.removeWhere((e) => e.isRemoveAds);
      }
      productIds = iapProducts.map((e) => e.productId).toSet().toList();
      initPurchase();
    });
    context.read<InAppPurchaseCubit>().initializePurchase(productIds: []);
  }

  void featuredAdsInitPurchase() {
    context.read<InAppPurchaseCubit>().initializePurchase(productIds: []);
  }*/

  @override
  void dispose() {
    if (_tabController != null) {
      _tabController!.removeListener(_handleTabSelection);
    }
    if (Platform.isIOS) {
      _inAppPurchaseManager.dispose();
    }
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController!.indexIsChanging) {
      setState(() {
        currentIndex = 0;
      });
    }
  }

  void onPageChanged(int index) {
    setState(() {
      currentIndex = index; //update current index for Next button
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Number of tabs
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "subsctiptionPlane".translate(context),
          // bottomHeight: 49,
          bottomHeight: 49,

          bottom: [
            Container(
              decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  // Set background color here
                  boxShadow: [
                    BoxShadow(
                      color: context.color.borderColor.withValues(alpha: 0.8),
                      // Shadow color
                      spreadRadius: 3,
                      // Spread radius
                      blurRadius: 2,
                      // Blur radius
                      offset: Offset(0, 1), // Shadow offset
                    ),
                  ]),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: "adsListing".translate(context)),
                  Tab(text: "featuredAdsLbl".translate(context)),
                ],

                indicatorColor: context.color.territoryColor,
                // Line color
                indicatorWeight: 3,

                // Line thickness
                labelColor: context.color.territoryColor,
                // Selected tab text color
                unselectedLabelColor:
                    context.color.textDefaultColor.withValues(alpha: 0.5),
                // Unselected tab text color
                labelStyle: TextStyle(
                  fontSize: 16,
                ),
                // Selected tab text style
                labelPadding: EdgeInsets.symmetric(horizontal: 16),
                // Padding around the tab text
                indicatorSize: TabBarIndicatorSize.tab,
              ),
            ),
          ],
        ),
        body: BlocListener<GetApiKeysCubit, GetApiKeysState>(
          listener: (context, state) {
            if (state is GetApiKeysSuccess) {
              AppSettings.stripeCurrency = state.stripeCurrency ?? "";
              AppSettings.stripePublishableKey =
                  state.stripePublishableKey ?? "";
              AppSettings.stripeStatus = state.stripeStatus ?? 0;
              AppSettings.payStackCurrency = state.payStackCurrency ?? "";
              AppSettings.payStackKey = state.payStackApiKey ?? "";
              AppSettings.payStackStatus = state.payStackStatus ?? 0;
              AppSettings.razorpayKey = state.razorPayApiKey ?? "";
              AppSettings.razorpayStatus = state.razorPayStatus ?? 0;
              AppSettings.phonePeCurrency = state.phonePeCurrency ?? "";
              AppSettings.phonePeKey = state.phonePeKey ?? "";
              AppSettings.phonePeStatus = state.phonePeStatus ?? 0;

              AppSettings.updatePaymentGateways();
              if (AppSettings.stripePublishableKey.isNotEmpty) {
                StripeService.initStripe(AppSettings.stripePublishableKey, "test");
              }
            }
          },
          child: TabBarView(
            controller: _tabController,
            children: [
              adsListing(),
              featuredAds(),
            ],
          ),
        ),
      ),
    );
  }

  Builder adsListing() {
    return Builder(builder: (context) {
      if (!isInterstitialAdShown) {
        AdHelper.showInterstitialAd();
        isInterstitialAdShown = true; // Update the flag
      }
      return BlocConsumer<FetchAdsListingSubscriptionPackagesCubit,
              FetchAdsListingSubscriptionPackagesState>(
          listener: (context, FetchAdsListingSubscriptionPackagesState state) {
        /*if (state is FetchAdsListingSubscriptionPackagesSuccess) {
              Future.delayed(Duration.zero, () async {
                iapListingAdsProducts = state.subscriptionPackages;
                listingAdsProducts = iapListingAdsProducts
                    .map((e) => e.iosProductId!)
                    .toSet()
                    .toList();
                context
                    .read<InAppPurchaseCubit>()
                    .initializePurchase(listingAdsProducts);
              });
            }*/
      }, builder: (context, state) {
        if (state is FetchAdsListingSubscriptionPackagesInProgress) {
          return Center(
            child: UiUtils.progress(),
          );
        }
        if (state is FetchAdsListingSubscriptionPackagesFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context
                      .read<FetchAdsListingSubscriptionPackagesCubit>()
                      .fetchPackages();
                },
              );
            }
          }

          return const SomethingWentWrong();
        }
        if (state is FetchAdsListingSubscriptionPackagesSuccess) {
          if (state.subscriptionPackages.isEmpty) {
            return NoDataFound(
              onTap: () {
                context
                    .read<FetchAdsListingSubscriptionPackagesCubit>()
                    .fetchPackages();
              },
            );
          }

          return PageView.builder(
              onPageChanged: onPageChanged,
              //update index and fetch nex index details
              controller: adsPageController,
              itemBuilder: (context, index) {
                return ItemListingSubscriptionPlansItem(
                  itemIndex: currentIndex,
                  index: index,
                  model: state.subscriptionPackages[index],
                  inAppPurchaseManager: _inAppPurchaseManager,
                );
              },
              itemCount: state.subscriptionPackages.length);
        }

        return Container();
      });
    });
  }

  Builder featuredAds() {
    return Builder(builder: (context) {
      if (!isInterstitialAdShown) {
        AdHelper.showInterstitialAd();
        isInterstitialAdShown = true; // Update the flag
      }
      return BlocConsumer<FetchFeaturedSubscriptionPackagesCubit,
              FetchFeaturedSubscriptionPackagesState>(
          listener: (context, FetchFeaturedSubscriptionPackagesState state) {
        /* if (state is FetchFeaturedSubscriptionPackagesSuccess) {
              Future.delayed(Duration.zero, () async {
                iapFeaturedAdsProducts = state.subscriptionPackages;
                featuredAdsProducts = iapFeaturedAdsProducts
                    .map((e) => e.iosProductId!)
                    .toSet()
                    .toList();
                context
                    .read<InAppPurchaseCubit>()
                    .initializePurchase(featuredAdsProducts);
              });
            }*/
      }, builder: (context, state) {
        if (state is FetchFeaturedSubscriptionPackagesInProgress) {
          return Center(
            child: UiUtils.progress(),
          );
        }
        if (state is FetchFeaturedSubscriptionPackagesFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context
                      .read<FetchFeaturedSubscriptionPackagesCubit>()
                      .fetchPackages();
                },
              );
            }
          }

          return const SomethingWentWrong();
        }
        if (state is FetchFeaturedSubscriptionPackagesSuccess) {
          if (state.subscriptionPackages.isEmpty) {
            return NoDataFound(
              onTap: () {
                context
                    .read<FetchFeaturedSubscriptionPackagesCubit>()
                    .fetchPackages();
              },
            );
          }

          return FeaturedAdsSubscriptionPlansItem(
            modelList: state.subscriptionPackages,
            inAppPurchaseManager: _inAppPurchaseManager,
          );
        }

        return Container();
      });
    });
  }
}
