import 'dart:async';

import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/data/cubits/location/fetch_countries_cubit.dart';
import 'package:Ebozor/data/model/location/countriesModel.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:shimmer/shimmer.dart';

import 'package:Ebozor/utils/ApiService/api.dart';

import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_screen_cubit.dart';

import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:flutter/material.dart';

import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/location/location_map_screen.dart';

class CountriesScreen extends StatefulWidget {
  final String from;

  const CountriesScreen({
    super.key,
    required this.from,
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;

    return BlurredRouter(
      builder: (context) => BlocProvider(
          create: (context) => FetchCountriesCubit(),
          child: CountriesScreen(
            from: arguments!['from'] ?? "",
          )),
    );
  }

  @override
  CountriesScreenState createState() => CountriesScreenState();
}

class CountriesScreenState extends State<CountriesScreen> {
  bool isFocused = false;
  String previousSearchQuery = "";
  TextEditingController searchController = TextEditingController(text: null);
  final ScrollController controller = ScrollController();
  Timer? _searchDelay;
  CountriesModel? selectedCountry;
  List<String> recentSearches = [];
  bool isLocationLoading = false;

  @override
  void initState() {
    super.initState();
    context
        .read<FetchCountriesCubit>()
        .fetchCountries(search: searchController.text);

    searchController = TextEditingController();

    searchController.addListener(searchItemListener);
    controller.addListener(pageScrollListen);
    getRecentSearches();
  }

  void getRecentSearches() {
    try {
      if (Hive.isBoxOpen(HiveKeys.historyBox)) {
        recentSearches = List<String>.from(
            Hive.box(HiveKeys.historyBox).get("country_history") ?? []);
      }
    } catch (e) {
      print("Error fetching history: $e");
    }
  }

  void addToRecentSearches(String name) {
    if (!recentSearches.contains(name)) {
      recentSearches.insert(0, name);
      if (recentSearches.length > 5) recentSearches.removeLast();
      if (Hive.isBoxOpen(HiveKeys.historyBox)) {
        Hive.box(HiveKeys.historyBox).put("country_history", recentSearches);
      }
    }
  }

  void clearRecentSearches() {
    setState(() {
      recentSearches.clear();
      if (Hive.isBoxOpen(HiveKeys.historyBox)) {
        Hive.box(HiveKeys.historyBox).put("country_history", recentSearches);
      }
    });
  }

  void pageScrollListen() {
    if (controller.isEndReached()) {
      if (context.read<FetchCountriesCubit>().hasMoreData()) {
        context.read<FetchCountriesCubit>().fetchCountriesMore();
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
      context.read<FetchCountriesCubit>().fetchCountries(
            search: searchController.text,
          );
      previousSearchQuery = searchController.text;
      setState(() {});
    }
    // } else {
    // context.read<SearchItemCubit>().clearSearch();
    // }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLocationLoading = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
           HelperUtils.showSnackBarMessage(
            context, "pleaseEnableLocationServicesManually".translate(context));
            // You can add logic to open app settings here
        }
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          if (mounted) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LocationMapScreen(),
                    settings: RouteSettings(arguments: {
                      'latitude': position.latitude,
                      'longitude': position.longitude,
                      'city': place.locality,
                      'state': place.administrativeArea,
                      'country': place.country,
                      'area': place.subLocality,
                      'area_id': null,
                      'from': widget.from // Passing 'from' parameter
                    }))).then((value) {
                      if (value != null && widget.from == "addItem") {
                        Navigator.pop(context, value);
                      }
                    });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          isLocationLoading = false;
        });
      }
    }
  }

  PreferredSizeWidget appBarWidget(List<CountriesModel> countriesModel) {
    return AppBar(
      systemOverlayStyle:
          SystemUiOverlayStyle(statusBarColor: context.color.backgroundColor),
      bottom: PreferredSize(
          preferredSize: Size.fromHeight(58.rh(context)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Container(
                    width: double.maxFinite,
                    height: 48.rh(context),
                    margin: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    alignment: AlignmentDirectional.center,
                    decoration: BoxDecoration(
                        border: Border.all(
                            width:
                                context.watch<AppThemeCubit>().state.appTheme ==
                                        AppTheme.dark
                                    ? 0
                                    : 1,
                            color: context.color.borderColor.darken(30)),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                        color: context.color.secondaryColor),
                    child: TextFormField(
                        controller: searchController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          //OutlineInputBorder()
                          fillColor:
                              Theme.of(context).colorScheme.secondaryColor,
                          hintText:
                              "${"search".translate(context)}\t${"country".translate(context)}..",
                          prefixIcon: setSearchIcon(),
                          prefixIconConstraints:
                              const BoxConstraints(minHeight: 5, minWidth: 5),
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
                        })),
              ),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, Routes.nearbyLocationScreen,
                      arguments: {"from": widget.from});
                },
                child: Container(
                  width: 50.rw(context),
                  height: 50.rh(context),
                  margin: EdgeInsetsDirectional.only(end: sidePadding),
                  decoration: BoxDecoration(
                    border: Border.all(
                        width: 1, color: context.color.borderColor.darken(30)),
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Image.asset("assets/seachfiltericon.png")
                  ),
                ),
              ),
            ],
          )),
      automaticallyImplyLeading: false,
      title: Text(
        "locationLbl".translate(context),
      )
          .color(context.color.textDefaultColor)
          .bold(weight: FontWeight.w600)
          .size(18),
      leading: Material(
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        type: MaterialType.circle,
        child: InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: 18.0,
                ),
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
                  ),
                ))),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 18.0),
            child: InkWell(
              onTap: clearRecentSearches,
              child: Text("clearAll".translate(context))
                  .color(context.color.textLightColor)
                  .size(context.font.large),
            ),
          ),
        )
      ],
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

  Widget shimmerEffect() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 15,
      separatorBuilder: (context, index) {
        return Container();
      },
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
          highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
          child: Container(
            padding: EdgeInsets.all(5),
            width: double.maxFinite,
            height: 56,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border:
                    Border.all(color: context.color.borderColor.darken(30))),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchCountriesCubit, FetchCountriesState>(
        builder: (context, state) {
      List<CountriesModel> countriesModel = [];
      if (state is FetchCountriesSuccess) {
        countriesModel = state.countriesModel;
      }
      return Scaffold(
        appBar: appBarWidget(countriesModel),
        body: bodyData(),
        bottomNavigationBar: bottomBar(),
        backgroundColor: context.color.backgroundColor,
      );
    });
  }

  Widget bodyData() {
    return searchItemsWidget();
  }

  Widget bottomBar() {
    return Container(
      color: context.color.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLocationLoading
                ? Center(
                    child: UiUtils.progress(
                        normalProgressColor: context.color.territoryColor))
                : UiUtils.buildButton(
                    context,
                    onPressed: () {
                      _getCurrentLocation();
                    },
                    buttonTitle: "useCurrentLocation".translate(context),
                    buttonColor: context.color.backgroundColor,
                    textColor: context.color.territoryColor,
                    border: BorderSide(color: context.color.territoryColor),
                    showElevation: false,
                    radius: 8,
                    height: 48,
                  ),
            const SizedBox(height: 12),
            UiUtils.buildButton(
              context,
              onPressed: () {
                if (selectedCountry != null) {
                  addToRecentSearches(selectedCountry!.name!);
                  Navigator.pushNamed(
                    context,
                    Routes.statesScreen,
                    arguments: {
                      "countryId": selectedCountry!.id!,
                      "countryName": selectedCountry!.name!,
                      "from": widget.from
                    },
                  ).then((value) {
                    if (value != null && widget.from == "addItem") {
                      Navigator.pop(context, value);
                    }
                  });
                }
              },
              buttonTitle: "continue".translate(context),
              radius: 8,
              height: 48,
              disabled: selectedCountry == null,
              disabledColor:
                  context.color.territoryColor.withValues(alpha: 0.5), // Lighter red
              buttonColor: context.color.territoryColor, // Red background
            ),
          ],
        ),
      ),
    );
  }

  Widget searchItemsWidget() {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<FetchCountriesCubit, FetchCountriesState>(
            builder: (context, state) {
              if (state is FetchCountriesInProgress) {
                return shimmerEffect();
              }

              if (state is FetchCountriesFailure) {
                if (state.errorMessage is ApiException) {
                  if (state.errorMessage == "no-internet") {
                    return SingleChildScrollView(
                      child: NoInternet(
                        onRetry: () {
                          context
                              .read<FetchCountriesCubit>()
                              .fetchCountries(search: searchController.text);
                        },
                      ),
                    );
                  }
                }
                return const Center(child: SomethingWentWrong());
              }

              if (state is FetchCountriesSuccess) {
                if (state.countriesModel.isEmpty) {
                  return Center(
                      child: SingleChildScrollView(child: NoDataFound()));
                }

                return Container(
                  width: double.infinity,
                  color: context.color.secondaryColor,
                  child: SingleChildScrollView(
                    controller: controller,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// -------- RECENT SEARCHES ----------
                        if (recentSearches.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.history,
                                    size: 18,
                                    color: context.color.textDefaultColor),
                                const SizedBox(width: 6),
                                Text("Your Last Searches".translate(context))
                                    .color(context.color.textDefaultColor)
                                    .size(context.font.normal)
                                    .bold(weight: FontWeight.bold),
                                const Spacer(),
                                InkWell(
                                  onTap: () {
                                    // See All Logic
                                  },
                                  child: Text("seeAll".translate(context))
                                      .size(context.font.small)
                                      .color(context.color.textLightColor),
                                )
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: recentSearches.map((search) {
                                  return Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        end: 10),
                                    child: Chip(
                                      label: Text(search),
                                      backgroundColor:
                                          context.color.secondaryColor,
                                      side: BorderSide(
                                          color: context.color.borderColor),
                                      labelStyle: TextStyle(
                                          color: context.color.textDefaultColor,
                                          fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],

                        /// -------- POPULAR SEARCHES ----------
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.trending_up,
                                  size: 18,
                                  color: context.color.textDefaultColor),
                              const SizedBox(width: 6),
                              Text(
                                "All Countries".translate(context),
                              )
                                  .color(context.color.textDefaultColor)
                                  .size(context.font.normal)
                                  .bold(weight: FontWeight.bold),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: state.countriesModel.map((country) {
                              bool isSelected =
                                  selectedCountry?.id == country.id;
                              return InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  setState(() {
                                    selectedCountry = country;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? context.color.territoryColor
                                          : context.color.borderColor,
                                    ),
                                    color: isSelected
                                        ? context.color.territoryColor
                                            .withValues(alpha: 0.1)
                                        : context.color.secondaryColor,
                                  ),
                                  child: Text(
                                    country.name!,
                                  )
                                      .color(isSelected
                                          ? context.color.territoryColor
                                          : context.color.textDefaultColor)
                                      .size(context.font.small),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        if (state.isLoadingMore)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: UiUtils.progress(
                                normalProgressColor:
                                    context.color.territoryColor,
                              ),
                            ),
                          ),

                        SizedBox(height: 20), // Bottom padding
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ],
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
  @override
  void dispose() {
    _searchDelay?.cancel(); // cancel timer
    searchController.removeListener(searchItemListener);
    controller.removeListener(pageScrollListen);

    searchController.dispose();
    controller.dispose();

    super.dispose();
  }
}
