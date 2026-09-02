import 'dart:async';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/location/fetch_countries_cubit.dart';
import 'package:Ebozor/data/model/location/countriesModel.dart';
import 'package:Ebozor/ui/screens/location/location_map_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

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
          from: arguments?['from'] ?? "",
        ),
      ),
    );
  }

  @override
  CountriesScreenState createState() => CountriesScreenState();
}

class CountriesScreenState extends State<CountriesScreen> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final ScrollController controller = ScrollController();
  Timer? _searchDelay;
  String previousSearchQuery = "";
  CountriesModel? selectedCountry;
  List<String> recentSearches = [];
  bool isLocationLoading = false;

  bool get _returnsLocationSelection =>
      widget.from == "addItem" || widget.from == "filter";

  bool get _isAuthFlow =>
      widget.from == "login" ||
      widget.from == "signup" ||
      widget.from == "signin" ||
      widget.from == "locationPermission" ||
      widget.from == "auth";

  @override
  void initState() {
    super.initState();
    context.read<FetchCountriesCubit>().fetchCountries(search: "");
    controller.addListener(_pageScrollListen);
    _getRecentSearches();
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    controller.dispose();
    super.dispose();
  }

  void _getRecentSearches() {
    try {
      if (Hive.isBoxOpen(HiveKeys.historyBox)) {
        recentSearches = List<String>.from(
          Hive.box(HiveKeys.historyBox).get("country_history") ?? [],
        );
      }
    } catch (_) {}
  }

  void _addToRecentSearches(String name) {
    if (!recentSearches.contains(name)) {
      recentSearches.insert(0, name);
      if (recentSearches.length > 8) recentSearches.removeLast();
      if (Hive.isBoxOpen(HiveKeys.historyBox)) {
        Hive.box(HiveKeys.historyBox).put("country_history", recentSearches);
      }
    }
  }

  void _clearRecentSearches() {
    setState(() {
      recentSearches.clear();
      if (Hive.isBoxOpen(HiveKeys.historyBox)) {
        Hive.box(HiveKeys.historyBox).put("country_history", recentSearches);
      }
    });
  }

  void _pageScrollListen() {
    if (controller.isEndReached()) {
      if (context.read<FetchCountriesCubit>().hasMoreData()) {
        context.read<FetchCountriesCubit>().fetchCountriesMore(
              search: searchController.text,
            );
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 350), () {
      final trimmed = query.trim();
      if (previousSearchQuery != trimmed) {
        context.read<FetchCountriesCubit>().fetchCountries(search: trimmed);
        previousSearchQuery = trimmed;
        setState(() {});
      }
    });
    setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    if (isLocationLoading) return;
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
            context,
            "pleaseEnableLocationServicesManually".translate(context),
          );
        }
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 8),
          ),
        );

        List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty && mounted) {
          Placemark place = placemarks.first;
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
                'from': widget.from,
              }),
            ),
          ).then((value) {
            if (value != null && _returnsLocationSelection) {
              Navigator.pop(context, value);
            }
          });
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
        "Select Country".translate(context),
        style: TextStyle(
          color: context.color.textDefaultColor,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        if (recentSearches.isNotEmpty)
          TextButton(
            onPressed: _clearRecentSearches,
            child: Text(
              "Clear".translate(context),
              style: TextStyle(
                color: context.color.territoryColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
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
                    style: TextStyle(
                      color: context.color.textDefaultColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search country...".translate(context),
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
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    Routes.nearbyLocationScreen,
                    arguments: {"from": widget.from},
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.radar_rounded,
                      color: context.color.territoryColor,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
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
        height: 52,
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
            CustomShimmer(height: 20, width: 20, borderRadius: 10),
            SizedBox(width: 12),
            CustomShimmer(height: 14, width: 140),
            Spacer(),
            CustomShimmer(height: 14, width: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearchesSection() {
    if (recentSearches.isEmpty || searchController.text.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 16,
                color: context.color.textLightColor,
              ),
              const SizedBox(width: 6),
              Text(
                "Recent Searches".translate(context),
                style: TextStyle(
                  color: context.color.textLightColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: recentSearches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final countryName = recentSearches[index];
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  searchController.text = countryName;
                  _onSearchChanged(countryName);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        countryName,
                        style: TextStyle(
                          color: context.color.textDefaultColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBody() {
    return BlocBuilder<FetchCountriesCubit, FetchCountriesState>(
      builder: (context, state) {
        if (state is FetchCountriesInProgress) {
          return _buildShimmer();
        }

        if (state is FetchCountriesFailure) {
          if (state.errorMessage.contains("no-internet")) {
            return NoInternet(
              onRetry: () {
                context.read<FetchCountriesCubit>().fetchCountries(
                      search: searchController.text,
                    );
              },
            );
          }
          return const Center(child: SomethingWentWrong());
        }

        if (state is FetchCountriesSuccess) {
          if (state.countriesModel.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.public_off_rounded,
                      size: 54,
                      color: context.color.textLightColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "No countries found".translate(context),
                      style: TextStyle(
                        color: context.color.textDefaultColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 50) {
                if (context.read<FetchCountriesCubit>().hasMoreData()) {
                  context.read<FetchCountriesCubit>().fetchCountriesMore(
                        search: searchController.text.trim(),
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
                  _buildRecentSearchesSection(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.public_rounded,
                        size: 16,
                        color: context.color.territoryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "All Countries".translate(context),
                        style: TextStyle(
                          color: context.color.textDefaultColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "(${state.countriesModel.length})",
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
                    children: state.countriesModel.map((country) {
                      final isSelected = selectedCountry?.id == country.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            selectedCountry = country;
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
                                country.name ?? "",
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
                if (state.isLoadingMore)
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
      }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBottomBar() {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Use Current Location Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _getCurrentLocation,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.color.territoryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: isLocationLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.color.territoryColor,
                        ),
                      )
                    : Icon(
                        Icons.my_location_rounded,
                        color: context.color.territoryColor,
                        size: 18,
                      ),
                label: Text(
                  "Use Current Location".translate(context),
                  style: TextStyle(
                    color: context.color.territoryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Actions Button Row
            if (selectedCountry != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _applyCountryDirectly,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.color.territoryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        "Apply ${selectedCountry!.name}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.color.territoryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: UiUtils.buildButton(
                      context,
                      onPressed: _navigateToStates,
                      buttonTitle: "States".translate(context),
                      textColor: Colors.white,
                      buttonColor: context.color.territoryColor,
                      radius: 10,
                      height: 48,
                    ),
                  ),
                ],
              )
            else
              UiUtils.buildButton(
                context,
                onPressed: () {},
                buttonTitle: "Select a Country".translate(context),
                textColor: Colors.white,
                buttonColor:
                    context.color.territoryColor.withValues(alpha: 0.4),
                radius: 10,
                height: 48,
                disabled: true,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyCountryDirectly() async {
    if (selectedCountry == null) return;
    _addToRecentSearches(selectedCountry!.name!);

    if (_returnsLocationSelection) {
      Navigator.pop(context, {
        "area_id": null,
        "area": null,
        "city": null,
        "state": null,
        "country": selectedCountry!.name,
        "latitude": null,
        "longitude": null,
      });
    } else {
      await HiveUtils.setLocation(
        city: null,
        state: null,
        country: selectedCountry!.name,
        area: null,
        areaId: null,
        latitude: null,
        longitude: null,
      );

      if (!mounted) return;
      if (_isAuthFlow) {
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

  void _navigateToStates() {
    if (selectedCountry != null) {
      _addToRecentSearches(selectedCountry!.name!);
      Navigator.pushNamed(
        context,
        Routes.statesScreen,
        arguments: {
          "countryId": selectedCountry!.id!,
          "countryName": selectedCountry!.name!,
          "from": widget.from,
        },
      ).then((value) {
        if (value != null && _returnsLocationSelection) {
          Navigator.pop(context, value);
        }
      });
    }
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
