
import 'dart:async';
import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/data/model/location/statesModel.dart';
import 'package:Ebozor/ui/theme/theme.dart';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import 'package:Ebozor/utils/ApiService/api.dart';

import 'package:Ebozor/data/cubits/location/fetch_states_cubit.dart';

import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';

import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:flutter/material.dart';

import 'package:Ebozor/utils/ui_utils.dart';

class StatesScreen extends StatefulWidget {
  final int countryId;
  final String countryName;
  final String from;

  const StatesScreen({
    super.key,
    required this.countryId,
    required this.countryName,
    required this.from,
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;

    return BlurredRouter(
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => FetchStatesCubit(),
          ),
          /* BlocProvider(
            create: (context) => FetchCitiesCubit(),
          ),*/
        ],
        child: StatesScreen(
          countryId: arguments?['countryId'],
          countryName: arguments?['countryName'],
          from: arguments?['from'],
        ),
      ),
    );
  }

  @override
  StatesScreenState createState() => StatesScreenState();
}

class StatesScreenState extends State<StatesScreen> {
  bool isFocused = false;
  String previousSearchQuery = "";
  TextEditingController searchController = TextEditingController(text: null);
  final ScrollController controller = ScrollController();
  Timer? _searchDelay;

  @override
  void initState() {
    super.initState();
    context.read<FetchStatesCubit>().fetchStates(
        search: searchController.text, countryId: widget.countryId);
    searchController = TextEditingController();

    searchController.addListener(searchItemListener);
    controller.addListener(pageScrollListen);
  }

  void pageScrollListen() {
    if (controller.isEndReached()) {
      if (context.read<FetchStatesCubit>().hasMoreData()) {
        context
            .read<FetchStatesCubit>()
            .fetchStatesMore(countryId: widget.countryId);
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
      context.read<FetchStatesCubit>().fetchStates(
          search: searchController.text, countryId: widget.countryId);
      previousSearchQuery = searchController.text;
      setState(() {});
    }
    // } else {
    // context.read<SearchItemCubit>().clearSearch();
    // }
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
                    "${"search".translate(context)}\t${"state".translate(context)}",
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
        widget.countryName,
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

  StatesModel? selectedState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWidget(),
      body: bodyData(),
      bottomNavigationBar: getBottomButtons(),
      backgroundColor: context.color.backgroundColor,
    );
  }

  Widget bodyData() {
    return searchItemsWidget();
  }

  Widget searchItemsWidget() {
    return BlocBuilder<FetchStatesCubit, FetchStatesState>(
      builder: (context, state) {
        if (state is FetchStatesInProgress) {
          return shimmerEffect();
        }

        if (state is FetchStatesFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage == "no-internet") {
              return SingleChildScrollView(
                child: NoInternet(
                  onRetry: () {
                    context.read<FetchStatesCubit>().fetchStates(
                      search: searchController.text,
                      countryId: widget.countryId,
                    );
                  },
                ),
              );
            }
          }
          return const Center(child: SomethingWentWrong());
        }

        if (state is FetchStatesSuccess) {
          if (state.statesModel.isEmpty) {
            return SingleChildScrollView(
              child: NoDataFound(
                onTap: () {
                  context.read<FetchStatesCubit>().fetchStates(
                    search: searchController.text,
                    countryId: widget.countryId,
                  );
                },
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(top: 17),
            child: Container(
              color: context.color.secondaryColor,
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
                        "${"chooseLbl".translate(context)} ${"state".translate(context)}",
                      )
                          .color(context.color.textDefaultColor)
                          .size(context.font.normal)
                          .bold(weight: FontWeight.w600),
                    )
                        : SizedBox.shrink(),

                    /// ---------- POPULAR SEARCHES TITLE ----------
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
                            "All States".translate(context),
                          )
                              .color(context.color.textDefaultColor)
                              .size(context.font.normal)
                              .bold(weight: FontWeight.w600),
                        ],
                      ),
                    ),

                    /// ---------- STATES CHIP UI ----------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: state.statesModel.map((states) {
                          bool isSelected = selectedState?.id == states.id;
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                selectedState = states;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? context.color.territoryColor : context.color.borderColor,
                                ),
                                color: isSelected ? context.color.territoryColor.withValues(alpha: 0.1) : context.color.secondaryColor,
                              ),
                              child: Text(
                                states.name!,
                              )
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
          );
        }

        return const SizedBox.shrink();
      },
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
          UiUtils.buildButton(
            context,
            onPressed: () {
              if (selectedState != null) {
                Navigator.pushNamed(
                  context,
                  Routes.citiesScreen,
                  arguments: {
                    "stateId": selectedState!.id!,
                    "stateName": selectedState!.name!,
                    "from": widget.from,
                    "countryName": widget.countryName,
                    "countryId": widget.countryId
                  },
                ).then((value) {
                  if (value != null && widget.from == "addItem") {
                    Navigator.pop(context, value);
                  }
                });
              }
            },
            buttonTitle: "continue".translate(context),
            textColor: Colors.white,
            buttonColor: selectedState != null ? context.color.territoryColor : context.color.textLightColor,
            radius: 8,
            disabled: selectedState == null,
          ),
        ],
      ),
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
    //searchController.clear();
    super.dispose();
  }
}