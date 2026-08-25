import 'dart:async';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/location/location_map_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class SelectLocationScreen extends StatefulWidget {
  final String from;

  const SelectLocationScreen({
    super.key,
    this.from = "home",
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;
    return MaterialPageRoute(
      builder: (context) => SelectLocationScreen(
        from: arguments?['from'] ?? "home",
      ),
      settings: settings,
    );
  }

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  bool _isLocatingCurrent = false;
  bool _isSearching = false;
  List<LocationSearchResult> _searchResults = [];
  String _currentGpsAddress = '';

  @override
  void initState() {
    super.initState();
    _loadCachedAddress();
  }

  void _loadCachedAddress() {
    final parts = [
      HiveUtils.getCurrentAreaName(),
      HiveUtils.getCurrentCityName(),
      HiveUtils.getCurrentStateName(),
      HiveUtils.getCurrentCountryName(),
    ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();

    if (parts.isNotEmpty) {
      _currentGpsAddress = parts.join(", ");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_isLocatingCurrent) return;

    setState(() {
      _isLocatingCurrent = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Location services are disabled.'.translate(context)),
              action: SnackBarAction(
                label: 'Enable'.translate(context),
                textColor: context.color.secondaryColor,
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Location permissions are denied'.translate(context)),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location permissions are permanently denied.'
                    .translate(context),
              ),
              action: SnackBarAction(
                label: 'Settings'.translate(context),
                textColor: context.color.secondaryColor,
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        final area = place.subLocality?.isNotEmpty == true
            ? place.subLocality
            : place.thoroughfare;
        final city = place.locality?.isNotEmpty == true
            ? place.locality
            : place.subAdministrativeArea;
        final state = place.administrativeArea;
        final country = place.country;

        final addressStr = [
          area,
          city,
          state,
          country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        setState(() {
          _currentGpsAddress = addressStr;
        });

        // Save current location into Hive
        HiveUtils.setCurrentLocation(
          city: city ?? "",
          state: state ?? "",
          country: country ?? "",
          area: area,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (widget.from == "addItem") {
          if (mounted) {
            Navigator.pop(context, {
              "area_id": null,
              "area": area,
              "city": city,
              "state": state,
              "country": country,
              "latitude": position.latitude,
              "longitude": position.longitude,
            });
          }
        } else {
          await HiveUtils.setLocation(
            city: city,
            state: state,
            country: country,
            area: area,
            latitude: position.latitude,
            longitude: position.longitude,
          );

          if (mounted) {
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
      }
    } catch (e) {
      debugPrint("Error fetching GPS location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocatingCurrent = false;
        });
      }
    }
  }

  Future<void> _searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<Location> locations = await locationFromAddress(trimmed);
      List<LocationSearchResult> results = [];

      for (var loc in locations.take(6)) {
        try {
          List<Placemark> marks = await placemarkFromCoordinates(
            loc.latitude,
            loc.longitude,
          );
          if (marks.isNotEmpty) {
            final mark = marks.first;
            final title = [
              mark.name,
              mark.subLocality,
              mark.locality,
            ].where((e) => e != null && e.isNotEmpty).toSet().join(", ");

            final subtitle = [
              mark.administrativeArea,
              mark.country,
            ].where((e) => e != null && e.isNotEmpty).join(", ");

            results.add(LocationSearchResult(
              title: title.isNotEmpty ? title : trimmed,
              subtitle: subtitle,
              latitude: loc.latitude,
              longitude: loc.longitude,
            ));
          }
        } catch (_) {
          results.add(LocationSearchResult(
            title: trimmed,
            subtitle:
                "${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}",
            latitude: loc.latitude,
            longitude: loc.longitude,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _onSelectPlaceResult(LocationSearchResult result) async {
    _searchFocusNode.unfocus();

    try {
      List<Placemark> marks = await placemarkFromCoordinates(
        result.latitude,
        result.longitude,
      );

      String? area;
      String? city;
      String? state;
      String? country;

      if (marks.isNotEmpty) {
        final mark = marks.first;
        area = mark.subLocality?.isNotEmpty == true
            ? mark.subLocality
            : mark.thoroughfare;
        city = mark.locality?.isNotEmpty == true
            ? mark.locality
            : mark.subAdministrativeArea;
        state = mark.administrativeArea;
        country = mark.country;
      }

      if (widget.from == "addItem") {
        if (mounted) {
          Navigator.pop(context, {
            "area_id": null,
            "area": area,
            "city": city,
            "state": state,
            "country": country,
            "latitude": result.latitude,
            "longitude": result.longitude,
          });
        }
      } else {
        await HiveUtils.setLocation(
          city: city,
          state: state,
          country: country,
          area: area,
          latitude: result.latitude,
          longitude: result.longitude,
        );

        if (mounted) {
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
    } catch (e) {
      debugPrint("Select location error: $e");
    }
  }

  void _navigateToMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationMapScreen(),
        settings: RouteSettings(arguments: {
          'from': widget.from,
          'latitude': HiveUtils.getLatitude() ?? HiveUtils.getCurrentLatitude(),
          'longitude':
              HiveUtils.getLongitude() ?? HiveUtils.getCurrentLongitude(),
          'city': HiveUtils.getCityName(),
          'state': HiveUtils.getStateName(),
          'country': HiveUtils.getCountryName(),
          'area': HiveUtils.getAreaName(),
          'area_id': HiveUtils.getAreaId(),
        }),
      ),
    ).then((value) {
      if (value != null && widget.from == "addItem") {
        Navigator.pop(context, value);
      }
    });
  }

  void _navigateToNearbyRadius() {
    Navigator.pushNamed(
      context,
      Routes.nearbyLocationScreen,
      arguments: {"from": widget.from},
    ).then((value) {
      if (value != null && widget.from == "addItem") {
        Navigator.pop(context, value);
      }
      setState(() {});
    });
  }

  void _navigateToCountries() {
    Navigator.pushNamed(
      context,
      Routes.countriesScreen,
      arguments: {"from": widget.from},
    ).then((value) {
      if (value != null && widget.from == "addItem") {
        Navigator.pop(context, value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeRadius = HiveUtils.getNearbyRadius();
    final savedLocationString = [
      HiveUtils.getAreaName(),
      HiveUtils.getCityName(),
      HiveUtils.getStateName(),
      HiveUtils.getCountryName(),
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(", ");

    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
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
          "Select Location".translate(context),
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Search Bar with Instant Suggestions
            Container(
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.color.borderColor.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (query) {
                  if (_searchDebounce?.isActive ?? false) {
                    _searchDebounce!.cancel();
                  }
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 350),
                    () => _searchPlaces(query),
                  );
                },
                style: TextStyle(
                  color: context.color.textDefaultColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText:
                      "Search city, area, or address...".translate(context),
                  hintStyle: TextStyle(
                    color: context.color.textLightColor,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: context.color.territoryColor,
                    size: 22,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSearching)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.color.territoryColor,
                            ),
                          ),
                        ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.color.textLightColor,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults.clear();
                            });
                          },
                        ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),

            // Search Results Dropdown List
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.color.borderColor.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: context.color.borderColor.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: context.color.territoryColor,
                        size: 20,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          color: context.color.textDefaultColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: item.subtitle.isNotEmpty
                          ? Text(
                              item.subtitle,
                              style: TextStyle(
                                color: context.color.textLightColor,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => _onSelectPlaceResult(item),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 2. Active Selected Location Banner
            if (savedLocationString.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.color.territoryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.color.territoryColor
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: context.color.territoryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Active Location".translate(context),
                                style: TextStyle(
                                  color: context.color.territoryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              if (activeRadius != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.color.territoryColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${activeRadius}km",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            savedLocationString,
                            style: TextStyle(
                              color: context.color.textDefaultColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        HiveUtils.clearLocation();
                        HiveUtils.clearNearbyRadius();
                        setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          "Clear".translate(context),
                          style: TextStyle(
                            color: context.color.textLightColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Section Label
            Text(
              "Choose Location Method".translate(context),
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),

            // 3. Action Option Tiles
            _buildOptionCard(
              icon: Icons.my_location_rounded,
              iconColor: Colors.blueAccent,
              title: "Use Current Location".translate(context),
              subtitle: _isLocatingCurrent
                  ? "Detecting your precise GPS location...".translate(context)
                  : (_currentGpsAddress.isNotEmpty
                      ? _currentGpsAddress
                      : "Tap to fetch accurate location via GPS"
                          .translate(context)),
              trailing: _isLocatingCurrent
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.color.territoryColor,
                      ),
                    )
                  : Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: context.color.textLightColor,
                    ),
              onTap: _getCurrentLocation,
            ),

            const SizedBox(height: 12),

            _buildOptionCard(
              icon: Icons.map_rounded,
              iconColor: Colors.teal,
              title: "Pick on Interactive Map".translate(context),
              subtitle:
                  "Drag and pin exact location on full map".translate(context),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: context.color.textLightColor,
              ),
              onTap: _navigateToMap,
            ),

            const SizedBox(height: 12),

            _buildOptionCard(
              icon: Icons.radar_rounded,
              iconColor: Colors.deepPurpleAccent,
              title: "Nearby Listings Radius".translate(context),
              subtitle: activeRadius != null
                  ? "Active radius: ${activeRadius} km".translate(context)
                  : "Filter items within custom radius (1km - 100km)"
                      .translate(context),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (activeRadius != null)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.color.territoryColor
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${activeRadius}km",
                        style: TextStyle(
                          color: context.color.territoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: context.color.textLightColor,
                  ),
                ],
              ),
              onTap: _navigateToNearbyRadius,
            ),

            const SizedBox(height: 12),

            _buildOptionCard(
              icon: Icons.public_rounded,
              iconColor: Colors.orangeAccent,
              title: "Browse Countries & Cities".translate(context),
              subtitle: "Select from structured regional categories"
                  .translate(context),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: context.color.textLightColor,
              ),
              onTap: _navigateToCountries,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: context.color.territoryColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.color.textDefaultColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.color.textLightColor,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
