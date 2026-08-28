import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:Ebozor/data/cubits/location/fetch_cities_cubit.dart';
import 'package:Ebozor/data/model/location/cityModel.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ─── Flat City Tile ───────────────────────────────────────────────────────────
class _CityTile extends StatelessWidget {
  final CityModel city;
  final bool selected;
  final VoidCallback onTap;

  const _CityTile({
    required this.city,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final territoryColor = context.color.territoryColor;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 18,
              color: selected ? territoryColor : context.color.textLightColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                city.name ?? '',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? territoryColor : context.color.textColorDark,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: territoryColor),
          ],
        ),
      ),
    );
  }
}

class CitySelectionScreen extends StatefulWidget {
  final String from;
  final String? title;

  const CitySelectionScreen({
    super.key,
    this.from = '',
    this.title,
  });

  static Route route(RouteSettings settings) {
    final arguments = settings.arguments is Map
        ? settings.arguments as Map
        : const <String, dynamic>{};
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => BlocProvider(
        create: (_) => FetchCitiesCubit(),
        child: CitySelectionScreen(
          from: arguments['from']?.toString() ?? '',
          title: arguments['title']?.toString(),
        ),
      ),
    );
  }

  @override
  State<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends State<CitySelectionScreen> {
  CityModel? _pendingFilterCity;
  bool _clearFilterLocation = false;

  bool get _returnsSelection =>
      widget.from == 'filter' || widget.from == 'addItem';

  bool get _isAuthFlow => const {
        'auth',
        'login',
        'signup',
        'signin',
        'locationPermission',
      }.contains(widget.from);

  bool get _isAdPosting => widget.from == 'addItem';
  bool get _isFilterFlow => widget.from == 'filter';

  String get _title {
    if (widget.title?.trim().isNotEmpty == true) return widget.title!.trim();
    if (widget.from == 'filter') return 'Filter by city';
    return 'Select a City';
  }

  @override
  void initState() {
    super.initState();
    context.read<FetchCitiesCubit>().fetchCities();
  }

  Map<String, dynamic> _locationFor(CityModel city) {
    return <String, dynamic>{
      'area_id': null,
      'area': null,
      'city': city.name,
      'city_id': city.id,
      'state': '',
      'state_id': city.stateId,
      'state_code': city.stateCode,
      'country': '',
      'country_id': city.countryId,
      'country_code': city.countryCode,
      'latitude': double.tryParse(city.latitude ?? ''),
      'longitude': double.tryParse(city.longitude ?? ''),
    };
  }

  Future<void> _selectCity(CityModel city) async {
    final location = _locationFor(city);
    if (_isFilterFlow) {
      setState(() {
        _pendingFilterCity = city;
        _clearFilterLocation = false;
      });
      return;
    }
    if (_returnsSelection) {
      Navigator.pop(context, location);
      return;
    }

    final selectedCity = city.name?.trim() ?? '';
    if (selectedCity.isEmpty) return;
    await HiveUtils.setSelectedCity(
      selectedCity,
      latitude: location['latitude'] as double?,
      longitude: location['longitude'] as double?,
      countryCode: location['country_code'] as String?,
    );
    if (!mounted) return;

    // Refresh home with city as the only location constraint. This produces
    // `get-item?city=<selected city>` without stale nearby/map parameters.
    context.read<FetchHomeAllItemsCubit>().fetch(city: selectedCity);
    context.read<FetchHomeScreenCubit>().fetch(city: selectedCity);

    if (_isAuthFlow) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.main,
        (route) => false,
        arguments: const {'from': 'login'},
      );
    } else {
      Navigator.pop(context, location);
    }
  }

  void _resetFilterLocation() {
    setState(() {
      _pendingFilterCity = null;
      _clearFilterLocation = true;
    });
  }

  void _applyFilterLocation() {
    if (_pendingFilterCity != null) {
      Navigator.pop(context, _locationFor(_pendingFilterCity!));
    } else if (_clearFilterLocation) {
      Navigator.pop(context, const <String, dynamic>{
        'clear': true,
        'area_id': null,
        'area': null,
        'city': '',
        'state': '',
        'country': '',
        'latitude': null,
        'longitude': null,
      });
    }
  }

  Future<void> _openPostingMap() async {
    final result = await Navigator.pushNamed(
      context,
      Routes.locationMapScreen,
      arguments: const {'from': 'addItem'},
    );
    if (!mounted || result == null) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.color.secondaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: _isFilterFlow,
        leading: _isFilterFlow
            ? null
            : IconButton(
                tooltip: 'Close'.translate(context),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close_rounded, size: 26),
              ),
        toolbarHeight: _isFilterFlow ? kToolbarHeight : 96,
        title: _isFilterFlow
            ? const Text('Location')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Where would you like to shop?'.translate(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.color.textLightColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
        centerTitle: true,
        actions: _isFilterFlow
            ? [
                TextButton(
                  onPressed: _resetFilterLocation,
                  child: Text(
                    'Clear All',
                    style: TextStyle(color: context.color.territoryColor),
                  ),
                ),
              ]
            : _isAdPosting
                ? [
                    IconButton(
                      tooltip: 'Pick on Map'.translate(context),
                      onPressed: _openPostingMap,
                      icon: const Icon(Icons.map_rounded),
                    ),
                  ]
                : null,
      ),
      body: BlocBuilder<FetchCitiesCubit, FetchCitiesState>(
        builder: (context, state) {
          if (state is FetchCitiesInProgress || state is FetchCitiesInitial) {
            return Center(
              child: CircularProgressIndicator(
                color: context.color.territoryColor,
                strokeWidth: 2.5,
              ),
            );
          }
          if (state is FetchCitiesFailure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: context.color.textLightColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load cities'.translate(context),
                    style: TextStyle(
                      color: context.color.textLightColor,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () =>
                        context.read<FetchCitiesCubit>().fetchCities(),
                    child: Text('retry'.translate(context)),
                  ),
                ],
              ),
            );
          }

          final success = state as FetchCitiesSuccess;
          final cities = success.citiesModel;

          return RefreshIndicator(
            color: context.color.territoryColor,
            onRefresh: () => context.read<FetchCitiesCubit>().fetchCities(),
            child: cities.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 160),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.location_off_rounded,
                              size: 48,
                              color: context.color.textLightColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No cities found'.translate(context),
                              style: TextStyle(
                                color: context.color.textLightColor,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount:
                        cities.length + (success.loadingMoreError ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: context.color.borderColor.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (context, index) {
                      if (index == cities.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          child: Text(
                            'Showing saved cities. Pull down to refresh.'
                                .translate(context),
                            style: TextStyle(
                              color: context.color.textLightColor,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }
                      final city = cities[index];
                      final selected = _isFilterFlow
                          ? _pendingFilterCity?.id == city.id
                          : HiveUtils.getCityName()?.toString() == city.name;
                      return _CityTile(
                        city: city,
                        selected: selected,
                        onTap: () => _selectCity(city),
                      );
                    },
                  ),
          );
        },
      ),
      bottomNavigationBar: !_isFilterFlow
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  border: Border(
                    top: BorderSide(
                      color: context.color.borderColor.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetFilterLocation,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _pendingFilterCity != null || _clearFilterLocation
                                ? _applyFilterLocation
                                : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
