import 'dart:async';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/location/fetch_areas_cubit.dart';
import 'package:Ebozor/data/cubits/location/fetch_cities_cubit.dart';
import 'package:Ebozor/data/model/location/cityModel.dart';
import 'package:Ebozor/ui/screens/location/location_map_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/cloudState/cloud_state.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        ],
        child: CitiesScreen(
          stateId: arguments?['stateId'] ?? 0,
          stateName: arguments?['stateName'] ?? "",
          from: arguments?['from'] ?? "",
          countryName: arguments?['countryName'] ?? "",
        ),
      ),
    );
  }

  @override
  CitiesScreenState createState() => CitiesScreenState();
}

class CitiesScreenState extends CloudState<CitiesScreen> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final ScrollController controller = ScrollController();
  Timer? _searchDelay;
  String previousSearchQuery = "";
  CityModel? selectedCity;
  String? manualCityName;

  @override
  void initState() {
    super.initState();
    context.read<FetchCitiesCubit>().fetchCities(
          search: "",
          stateId: widget.stateId,
        );
    controller.addListener(_pageScrollListen);
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    controller.dispose();
    super.dispose();
  }

  void _pageScrollListen() {
    if (controller.isEndReached()) {
      _loadMoreCities();
    }
  }

  void _loadMoreCities() {
    if (context.read<FetchCitiesCubit>().hasMoreData()) {
      context.read<FetchCitiesCubit>().fetchCitiesMore(
            stateId: widget.stateId,
            search: searchController.text.trim(),
          );
    }
  }

  void _onSearchChanged(String query) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final trimmed = query.trim();
      if (previousSearchQuery != trimmed) {
        context.read<FetchCitiesCubit>().fetchCities(
              search: trimmed,
              stateId: widget.stateId,
            );
        previousSearchQuery = trimmed;
        setState(() {});
      }
    });
    setState(() {});
  }

  String get effectiveCityName {
    if (selectedCity != null) return selectedCity!.name ?? "";
    if (manualCityName != null && manualCityName!.trim().isNotEmpty) {
      return manualCityName!.trim();
    }
    if (searchController.text.trim().isNotEmpty) {
      return searchController.text.trim();
    }
    return widget.stateName;
  }

  double? get effectiveLatitude {
    if (selectedCity?.latitude != null) {
      return double.tryParse(selectedCity!.latitude!);
    }
    return null;
  }

  double? get effectiveLongitude {
    if (selectedCity?.longitude != null) {
      return double.tryParse(selectedCity!.longitude!);
    }
    return null;
  }

  void _applyLocationDirectly() {
    final cityName = effectiveCityName;
    final lat = effectiveLatitude;
    final lng = effectiveLongitude;

    if (widget.from == "addItem") {
      Navigator.pop(context, {
        "area_id": null,
        "area": null,
        "city": cityName,
        "state": widget.stateName,
        "country": widget.countryName,
        "latitude": lat,
        "longitude": lng,
      });
    } else {
      HiveUtils.setLocation(
        city: cityName,
        state: widget.stateName,
        country: widget.countryName,
        area: null,
        latitude: lat,
        longitude: lng,
      );

      if (widget.from == "login") {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.main,
          (route) => false,
          arguments: {"from": "login"},
        );
      } else {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  void _openMapForLocation() {
    final cityName = effectiveCityName;
    final lat = effectiveLatitude;
    final lng = effectiveLongitude;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationMapScreen(),
        settings: RouteSettings(
          arguments: {
            'area_id': null,
            'area': null,
            'city': cityName,
            'state': widget.stateName,
            'country': widget.countryName,
            'latitude': lat,
            'longitude': lng,
            'from': widget.from,
          },
        ),
      ),
    ).then((value) {
      if (value != null && widget.from == "addItem") {
        Navigator.pop(context, value);
      }
    });
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
      title: Text(
        widget.stateName.isNotEmpty ? widget.stateName : "Select City".translate(context),
        style: TextStyle(
          color: context.color.textDefaultColor,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            Icons.map_rounded,
            color: context.color.territoryColor,
            size: 22,
          ),
          tooltip: "Pick on Map".translate(context),
          onPressed: _openMapForLocation,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: context.color.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.6),
              ),
            ),
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  setState(() {
                    manualCityName = val.trim();
                    selectedCity = null;
                  });
                }
              },
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: "Search or enter city name...".translate(context),
                hintStyle: TextStyle(
                  color: context.color.textLightColor,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.color.territoryColor,
                  size: 20,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: context.color.textLightColor,
                          size: 18,
                        ),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            manualCityName = null;
                          });
                          _onSearchChanged("");
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: const [
            CustomShimmer(height: 14, width: 130),
            Spacer(),
            CustomShimmer(height: 14, width: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final searchText = searchController.text.trim();

    return BlocBuilder<FetchCitiesCubit, FetchCitiesState>(
      builder: (context, state) {
        if (state is FetchCitiesInProgress) {
          return _buildShimmer();
        }

        if (state is FetchCitiesFailure) {
          if (state.errorMessage.contains("no-internet")) {
            return NoInternet(
              onRetry: () {
                context.read<FetchCitiesCubit>().fetchCities(
                      search: searchController.text,
                      stateId: widget.stateId,
                    );
              },
            );
          }
          return const Center(child: SomethingWentWrong());
        }

        List<CityModel> cities = [];
        bool isLoadingMore = false;

        if (state is FetchCitiesSuccess) {
          cities = state.citiesModel;
          isLoadingMore = state.isLoadingMore;
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 50) {
              _loadMoreCities();
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Quick Select: Entire State / Custom City Pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Apply State as city fallback tile
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            selectedCity = null;
                            manualCityName = widget.stateName;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: (selectedCity == null &&
                                    (manualCityName == widget.stateName ||
                                        (manualCityName == null &&
                                            searchText.isEmpty)))
                                ? context.color.territoryColor.withValues(alpha: 0.12)
                                : context.color.secondaryColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (selectedCity == null &&
                                      (manualCityName == widget.stateName ||
                                          (manualCityName == null &&
                                              searchText.isEmpty)))
                                  ? context.color.territoryColor
                                  : context.color.borderColor.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_city_rounded,
                                size: 18,
                                color: context.color.territoryColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "All of ${widget.stateName}",
                                  style: TextStyle(
                                    color: context.color.textDefaultColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (selectedCity == null &&
                                  (manualCityName == widget.stateName ||
                                      (manualCityName == null &&
                                          searchText.isEmpty)))
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: context.color.territoryColor,
                                ),
                            ],
                          ),
                        ),
                      ),

                      // If user typed a search query, show "Use '[Query]'" chip
                      if (searchText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              selectedCity = null;
                              manualCityName = searchText;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: (manualCityName == searchText)
                                  ? context.color.territoryColor.withValues(alpha: 0.12)
                                  : context.color.secondaryColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (manualCityName == searchText)
                                    ? context.color.territoryColor
                                    : context.color.borderColor.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_location_alt_rounded,
                                  size: 18,
                                  color: context.color.territoryColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Use \"$searchText\" as City",
                                    style: TextStyle(
                                      color: context.color.textDefaultColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (manualCityName == searchText)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: context.color.territoryColor,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 2. City Chips from API
                if (cities.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_city_rounded,
                          size: 16,
                          color: context.color.territoryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Available Cities".translate(context),
                          style: TextStyle(
                            color: context.color.textDefaultColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "(${cities.length})",
                          style: TextStyle(
                            color: context.color.textLightColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: cities.map((city) {
                        final isSelected = selectedCity?.id == city.id;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              selectedCity = city;
                              manualCityName = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.color.territoryColor.withValues(alpha: 0.12)
                                  : context.color.secondaryColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? context.color.territoryColor
                                    : context.color.borderColor.withValues(alpha: 0.6),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  city.name ?? "",
                                  style: TextStyle(
                                    color: isSelected
                                        ? context.color.territoryColor
                                        : context.color.textDefaultColor,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: context.color.territoryColor,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                if (isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: UiUtils.progress(
                        normalProgressColor: context.color.territoryColor,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final cityName = effectiveCityName;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Map Button
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _openMapForLocation,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.color.territoryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    Icons.map_rounded,
                    color: context.color.territoryColor,
                    size: 18,
                  ),
                  label: Text(
                    "Map".translate(context),
                    style: TextStyle(
                      color: context.color.territoryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Apply Button
            Expanded(
              flex: 2,
              child: UiUtils.buildButton(
                context,
                onPressed: _applyLocationDirectly,
                buttonTitle: "Apply $cityName",
                textColor: Colors.white,
                buttonColor: context.color.territoryColor,
                radius: 10,
                height: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}
