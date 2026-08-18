

import 'dart:async';
import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/location/fetch_areas_cubit.dart';
import 'package:Ebozor/data/cubits/location/fetch_cities_cubit.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/data/model/location/cityModel.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/cloudState/cloud_state.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_screen_cubit.dart';

import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:flutter/material.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/location/location_map_screen.dart';

class CitiesScreen extends StatefulWidget {
  final int stateId;
  final String stateName;
  final String countryName;
  final String from;

  const CitiesScreen({
    super.key,
    required this.stateId,
    required this.stateName,
    required this.from,
    required this.countryName,
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;

    return BlurredRouter(
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => FetchCitiesCubit(),
          ),
          BlocProvider(
            create: (context) => FetchAreasCubit(),
          ),

          /* BlocProvider(
            create: (context) => FetchHomeAllItemsCubit(),
          ),
          BlocProvider(
            create: (context) => FetchHomeScreenCubit(),
          ),*/
        ],
        child: CitiesScreen(
          stateId: arguments?['stateId'],
          stateName: arguments?['stateName'],
          from: arguments?['from'],
          countryName: arguments?['countryName'],
        ),
      ),
    );
  }

  @override
  CitiesScreenState createState() => CitiesScreenState();
}

class CitiesScreenState extends CloudState<CitiesScreen> {
  bool isFocused = false;
  String previousSearchQuery = "";
  TextEditingController searchController = TextEditingController(text: null);
  final ScrollController controller = ScrollController();
  Timer? _searchDelay;
  CityModel? selectedCity;

  @override
  void initState() {
    super.initState();
    context
        .read<FetchCitiesCubit>()
        .fetchCities(search: searchController.text, stateId: widget.stateId);
    searchController = TextEditingController();

    searchController.addListener(searchItemListener);
    controller.addListener(pageScrollListen);
  }

  void pageScrollListen() {
    if (controller.isEndReached()) {
      if (context.read<FetchCitiesCubit>().hasMoreData()) {
        context.read<FetchCitiesCubit>().fetchCitiesMore(
              stateId: widget.stateId,
              search: searchController.text,
            );
      }
    }
  }

//this will listen and manage search
  void searchItemListener() {
    if (!mounted) return; // ✅ important
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
    if (!mounted) return; // ✅ VERY IMPORTANT

    if (previousSearchQuery != searchController.text) {
      context
          .read<FetchCitiesCubit>()
          .fetchCities(search: searchController.text, stateId: widget.stateId);

      previousSearchQuery = searchController.text;
      setState(() {});
    }
  }


  PreferredSizeWidget appBarWidget() {
    return AppBar(
      systemOverlayStyle:
      SystemUiOverlayStyle(statusBarColor: context.color.backgroundColor),
      bottom: PreferredSize(
          preferredSize: Size.fromHeight(58.rh(context)),
          child: Container(
              width: double.maxFinite,
              height: 48.rh(context),
              margin: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              alignment: AlignmentDirectional.center,
              decoration: BoxDecoration(
                  border: Border.all(
                      width: context.watch<AppThemeCubit>().state.appTheme ==
                          AppTheme.dark
                          ? 0
                          : 1,
                      color: context.color.borderColor.darken(30)),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  color: context.color.secondaryColor),
              child: TextFormField(
                  controller: searchController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    //OutlineInputBorder()
                    fillColor: Theme.of(context).colorScheme.secondaryColor,
                    hintText:
                    "${"search".translate(context)}\t${"city".translate(context)}",
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
                  }))),
      automaticallyImplyLeading: false,
      title: Text(
        widget.stateName,
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

  Widget shimmerEffect() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      /*   padding: const EdgeInsets.symmetric(
        vertical: 10 + defaultPadding,
        //horizontal: defaultPadding,
      ),*/
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
    return BlocListener<FetchAreasCubit, FetchAreasState>(
      listener: (context, state) {
        if (state is FetchAreasSuccess) {
          if (state.areasModel.isNotEmpty) {
            Navigator.pushNamed(
              context,
              Routes.areasScreen,
              arguments: {
                "cityId": selectedCity!.id!,
                "cityName": selectedCity!.name!,
                "from": widget.from,
                "stateName": widget.stateName,
                "countryName": widget.countryName,
                "latitude": double.parse(selectedCity!.latitude!),
                "longitude": double.parse(selectedCity!.longitude!),
              },
            ).then((value) {
              if (value != null && widget.from == "addItem") {
                Navigator.pop(context, value);
              }
            });
          } else {
            // Navigate to LocationMapScreen directly with City arguments
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LocationMapScreen(),
                settings: RouteSettings(
                  arguments: {
                    'area_id': null,
                    'area': null,
                    'city': selectedCity!.name!,
                    'state': widget.stateName,
                    'country': widget.countryName,
                    'latitude': double.parse(selectedCity!.latitude!),
                    'longitude': double.parse(selectedCity!.longitude!),
                    'from': widget.from,
                  }
                )
              ),
            ).then((value) {
              if (value != null && widget.from == "addItem") {
                Navigator.pop(context, value);
              }
            });
          }
        }
      },
      child: Scaffold(
        appBar: appBarWidget(),
        body: bodyData(),
        bottomNavigationBar: getBottomButtons(),
        backgroundColor: context.color.backgroundColor,
      ),
    );
  }

  Widget bodyData() {
    return searchItemsWidget();
  }

  Widget searchItemsWidget() {
    return BlocBuilder<FetchCitiesCubit, FetchCitiesState>(
      builder: (context, state) {
        if (state is FetchCitiesInProgress) {
          return shimmerEffect();
        }

        if (state is FetchCitiesFailure) {
          if (state.errorMessage is ApiException &&
              state.errorMessage == "no-internet") {
            return SingleChildScrollView(
              child: NoInternet(
                onRetry: () {
                  context.read<FetchCitiesCubit>().fetchCities(
                    search: searchController.text,
                    stateId: widget.stateId,
                  );
                },
              ),
            );
          }
          return const Center(child: SomethingWentWrong());
        }

        if (state is FetchCitiesSuccess) {
          if (state.citiesModel.isEmpty) {
            return SingleChildScrollView(
              child: NoDataFound(
                onTap: () {
                  context.read<FetchCitiesCubit>().fetchCities(
                    search: searchController.text,
                    stateId: widget.stateId,
                  );
                },
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(top: 17),
            child: Container(
              color: context.color.secondaryColor,
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (scrollInfo.metrics.pixels >=
                      scrollInfo.metrics.maxScrollExtent - 50) {
                    if (context.read<FetchCitiesCubit>().hasMoreData()) {
                      context.read<FetchCitiesCubit>().fetchCitiesMore(
                            stateId: widget.stateId,
                            search: searchController.text,
                          );
                    }
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// ---------- HEADER (UNCHANGED) ----------
                      widget.from == "addItem"
                          ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 18),
                        child: Text(
                          "${"chooseLbl".translate(context)} ${"city".translate(context)}",
                        )
                            .color(context.color.textDefaultColor)
                            .size(context.font.normal)
                            .bold(weight: FontWeight.w600),
                      )
                          : SizedBox.shrink(),

                      /// ---------- POPULAR SEARCHES ----------
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.trending_up,
                                size: 18,
                                color: context.color.textDefaultColor),
                            const SizedBox(width: 6),
                            Text(" All Cities".translate(context))
                                .color(context.color.textDefaultColor)
                                .size(context.font.normal)
                                .bold(weight: FontWeight.w600),
                          ],
                        ),
                      ),

                      /// ---------- CITY CHIP UI ----------
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: state.citiesModel.map((city) {
                            bool isSelected = selectedCity?.id == city.id;
                            return InkWell(
                              borderRadius:
                              BorderRadius.circular(8),
                              onTap: () {
                                setState(() {
                                  selectedCity = city;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius:
                                  BorderRadius.circular(8),
                                  border: Border.all(
                                      color: isSelected ? context.color.territoryColor :
                                      context.color.borderColor),
                                  color: isSelected ? context.color.territoryColor.withValues(alpha: 0.1) :
                                  context.color.secondaryColor,
                                ),
                                child: Text(city.name!)
                                    .color(isSelected ? context.color.territoryColor : context.color.textDefaultColor)
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
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
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

  Widget getBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        boxShadow: [
          BoxShadow(
            color: context.color.borderColor.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocBuilder<FetchAreasCubit, FetchAreasState>(
            builder: (context, state) {
              return state is FetchAreasInProgress
                  ? UiUtils.progress()
                  : UiUtils.buildButton(
                context,
                onPressed: () {
                  if (selectedCity != null) {
                    context.read<FetchAreasCubit>().fetchAreas(
                        search: "", cityId: selectedCity!.id!);
                  }
                },
                buttonTitle: "continue".translate(context),
                textColor: Colors.white,
                buttonColor: selectedCity != null ? context.color.territoryColor : context.color.textLightColor,
                radius: 8,
                disabled: selectedCity == null,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDelay?.cancel();          // timer cancel (good practice)
    searchController.removeListener(searchItemListener);
    controller.removeListener(pageScrollListen);

    searchController.dispose();
    controller.dispose();

    super.dispose();
  }

}
