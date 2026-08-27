import 'dart:async';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/confirm_location_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationSearchResult {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  LocationSearchResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });
}

class LocationMapScreen extends StatefulWidget {
  const LocationMapScreen({super.key});

  static Route route(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => const LocationMapScreen(),
      settings: settings,
    );
  }

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  GoogleMapController? mapController;
  CameraPosition? _cameraPosition;
  bool _isFetchingLocation = false;
  bool _isSearching = false;
  bool _isGeocoding = false;
  AddressComponent? formatedAddress;
  double? latitude, longitude;
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<LocationSearchResult> _searchResults = [];
  bool _showSuggestions = false;

  bool _initialLocationSet = false;
  String? from;

  bool get _returnsLocationSelection =>
      from == "addItem" || from == "filter";

  @override
  void initState() {
    super.initState();

    // Fast initial setup: Set fallback or cached position immediately so GoogleMap mounts in 0ms
    double initialLat =
        HiveUtils.getLatitude() ?? HiveUtils.getCurrentLatitude() ?? 0.0;
    double initialLng =
        HiveUtils.getLongitude() ?? HiveUtils.getCurrentLongitude() ?? 0.0;

    if (initialLat == 0.0 || initialLng == 0.0) {
      initialLat = double.tryParse(Constant.defaultLatitude) ?? 25.2048;
      initialLng = double.tryParse(Constant.defaultLongitude) ?? 55.2708;
    }

    latitude = initialLat;
    longitude = initialLng;

    _cameraPosition = CameraPosition(
      target: LatLng(initialLat, initialLng),
      zoom: 14.4746,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    _searchDebounce?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLocationSet) {
      Map? arguments = ModalRoute.of(context)?.settings.arguments as Map?;
      if (arguments != null) {
        from = arguments['from'];
        if (arguments.containsKey('latitude') &&
            arguments.containsKey('longitude') &&
            arguments['latitude'] != null &&
            arguments['longitude'] != null) {
          latitude = arguments['latitude'];
          longitude = arguments['longitude'];

          formatedAddress = AddressComponent(
            area: arguments['area'],
            areaId: arguments['area_id'],
            city: arguments['city'],
            country: arguments['country'],
            state: arguments['state'],
          );

          String addressString = _buildFormattedAddressString(formatedAddress);
          searchController.text = addressString;

          _cameraPosition = CameraPosition(
            target: LatLng(latitude!, longitude!),
            zoom: 14.4746,
          );

          if (mapController != null) {
            mapController!.animateCamera(
              CameraUpdate.newCameraPosition(_cameraPosition!),
            );
          }
        } else {
          _getCurrentLocation();
        }
      } else {
        _getCurrentLocation();
      }
      _initialLocationSet = true;
    }
  }

  String _buildFormattedAddressString(AddressComponent? address) {
    if (address == null) return "";
    List<String> parts = [];
    if (address.area != null && address.area!.trim().isNotEmpty) {
      parts.add(address.area!.trim());
    }
    if (address.city != null && address.city!.trim().isNotEmpty) {
      parts.add(address.city!.trim());
    }
    if (address.state != null && address.state!.trim().isNotEmpty) {
      parts.add(address.state!.trim());
    }
    if (address.country != null && address.country!.trim().isNotEmpty) {
      parts.add(address.country!.trim());
    }
    return parts.join(", ");
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 8),
          ),
        );

        latitude = position.latitude;
        longitude = position.longitude;

        _cameraPosition = CameraPosition(
          target: LatLng(latitude!, longitude!),
          zoom: 15.0,
        );

        if (mapController != null && _cameraPosition != null) {
          mapController!.animateCamera(
            CameraUpdate.newCameraPosition(_cameraPosition!),
          );
        }

        await getLocationFromLatitudeLongitude(
          latLng: LatLng(latitude!, longitude!),
        );
      }
    } catch (e) {
      debugPrint("Error fetching current location: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> getLocationFromLatitudeLongitude({LatLng? latLng}) async {
    final targetLat = latLng?.latitude ?? latitude;
    final targetLng = latLng?.longitude ?? longitude;
    if (targetLat == null || targetLng == null) return;

    if (mounted) {
      setState(() {
        _isGeocoding = true;
      });
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        targetLat,
        targetLng,
      );

      if (placemarks.isNotEmpty) {
        Placemark placeMark = placemarks.first;
        formatedAddress = AddressComponent(
          area: placeMark.subLocality?.isNotEmpty == true
              ? placeMark.subLocality
              : placeMark.thoroughfare,
          areaId: null,
          city: placeMark.locality?.isNotEmpty == true
              ? placeMark.locality
              : placeMark.subAdministrativeArea,
          country: placeMark.country,
          state: placeMark.administrativeArea,
        );

        String addressString = _buildFormattedAddressString(formatedAddress);
        if (!searchFocusNode.hasFocus) {
          searchController.text = addressString;
        }
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showSuggestions = false;
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    try {
      List<Location> locations = await locationFromAddress(trimmedQuery);
      List<LocationSearchResult> results = [];

      for (var loc in locations.take(5)) {
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
              title: title.isNotEmpty ? title : trimmedQuery,
              subtitle: subtitle,
              latitude: loc.latitude,
              longitude: loc.longitude,
            ));
          }
        } catch (_) {
          results.add(LocationSearchResult(
            title: trimmedQuery,
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
          _showSuggestions = results.isNotEmpty;
          _isSearching = false;
        });
      }

      // If user pressed enter and we have results, fly to first
      if (results.isNotEmpty && !searchFocusNode.hasFocus) {
        _selectSearchResult(results.first);
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

  void _selectSearchResult(LocationSearchResult result) {
    searchFocusNode.unfocus();
    searchController.text = result.title;

    final targetLatLng = LatLng(result.latitude, result.longitude);
    latitude = result.latitude;
    longitude = result.longitude;
    _cameraPosition = CameraPosition(target: targetLatLng, zoom: 15.0);

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_cameraPosition!),
    );

    setState(() {
      _showSuggestions = false;
    });

    getLocationFromLatitudeLongitude(latLng: targetLatLng);
  }

  void _onMapCreated(GoogleMapController controller) {
    controller.setMapStyle('''
    [
      {
        "featureType": "poi",
        "stylers": [
          { "visibility": "off" }
        ]
      }
    ]
    ''');
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
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
          "Location".translate(context),
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              searchController.clear();
              setState(() {
                _searchResults.clear();
                _showSuggestions = false;
              });
              _getCurrentLocation();
            },
            child: Text(
              "Reset".translate(context),
              style: TextStyle(
                color: context.color.territoryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. Google Map View (Loads instantly with cached/default position)
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    if (_cameraPosition != null)
                      GoogleMap(
                        initialCameraPosition: _cameraPosition!,
                        onMapCreated: _onMapCreated,
                        markers: const {},
                        myLocationButtonEnabled: false,
                        myLocationEnabled: true,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: true,
                        onCameraMove: (position) {
                          _cameraPosition = position;
                        },
                        onCameraIdle: () {
                          if (_cameraPosition != null) {
                            final target = _cameraPosition!.target;
                            latitude = target.latitude;
                            longitude = target.longitude;
                            getLocationFromLatitudeLongitude(latLng: target);
                          }
                        },
                      ),

                    // Center Pin
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 38),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Text(
                                "Move map to choose location"
                                    .translate(context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              Icons.location_on,
                              size: 44,
                              color: context.color.territoryColor,
                              shadows: const [
                                Shadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Status Indicator (Fetching GPS / Geocoding)
                    if (_isFetchingLocation || _isGeocoding)
                      Positioned(
                        top: 75,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.color.secondaryColor
                                  .withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.color.territoryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isFetchingLocation
                                      ? "Locating...".translate(context)
                                      : "Updating address..."
                                          .translate(context),
                                  style: TextStyle(
                                    color: context.color.textDefaultColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Floating GPS My-Location Button
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'map_gps_btn',
                        backgroundColor: context.color.secondaryColor,
                        foregroundColor: context.color.territoryColor,
                        elevation: 4,
                        onPressed: _getCurrentLocation,
                        child: _isFetchingLocation
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.color.territoryColor,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Sheet: Address Info & Action Buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    )
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Address Preview Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.color.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.color.borderColor
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.color.territoryColor
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: context.color.territoryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (formatedAddress?.area?.isNotEmpty == true
                                            ? formatedAddress!.area
                                            : formatedAddress?.city) ??
                                        "Selected Location".translate(context),
                                    style: TextStyle(
                                      color: context.color.textDefaultColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _buildFormattedAddressString(
                                                formatedAddress)
                                            .isEmpty
                                        ? "Pin your desired location on the map"
                                            .translate(context)
                                        : _buildFormattedAddressString(
                                            formatedAddress),
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons Row
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: UiUtils.buildButton(
                              context,
                              onPressed: () async {
                                _getCurrentLocation();
                              },
                              buttonTitle: "Reset".translate(context),
                              textColor: context.color.territoryColor,
                              buttonColor: context.color.secondaryColor,
                              border: BorderSide(
                                color: context.color.territoryColor,
                              ),
                              radius: 10,
                              height: 48,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: UiUtils.buildButton(
                              context,
                              onPressed: () async {
                                if (_returnsLocationSelection) {
                                  if (formatedAddress != null) {
                                    Navigator.pop(context, {
                                      "area_id": formatedAddress!.areaId,
                                      "area": formatedAddress!.area,
                                      "city": formatedAddress!.city,
                                      "state": formatedAddress!.state,
                                      "country": formatedAddress!.country,
                                      "latitude": latitude,
                                      "longitude": longitude,
                                    });
                                  } else {
                                    Navigator.pop(context, {
                                      "area_id": null,
                                      "area": null,
                                      "city": null,
                                      "state": null,
                                      "country": null,
                                      "latitude": latitude,
                                      "longitude": longitude,
                                    });
                                  }
                                } else if (formatedAddress != null) {
                                  await HiveUtils.setLocation(
                                    city: formatedAddress!.city,
                                    state: formatedAddress!.state,
                                    country: formatedAddress!.country,
                                    area: formatedAddress!.area,
                                    latitude: latitude,
                                    longitude: longitude,
                                  );
                                  if (from == "login") {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      Routes.main,
                                      (route) => false,
                                      arguments: {"from": "login"},
                                    );
                                  } else {
                                    Navigator.popUntil(
                                        context, (route) => route.isFirst);
                                  }
                                } else {
                                  await HiveUtils.setLocation(
                                    latitude: latitude,
                                    longitude: longitude,
                                  );
                                  if (from == "login") {
                                    Navigator.pushNamedAndRemoveUntil(
                                      context,
                                      Routes.main,
                                      (route) => false,
                                      arguments: {"from": "login"},
                                    );
                                  } else {
                                    Navigator.popUntil(
                                        context, (route) => route.isFirst);
                                  }
                                }
                              },
                              buttonTitle: "Apply Location".translate(context),
                              textColor: Colors.white,
                              buttonColor: context.color.territoryColor,
                              radius: 10,
                              height: 48,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Top Floating Search Bar with Live Autocomplete
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onChanged: (query) {
                      if (_searchDebounce?.isActive ?? false) {
                        _searchDebounce!.cancel();
                      }
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 400),
                        () => _searchLocation(query),
                      );
                    },
                    textInputAction: TextInputAction.search,
                    onSubmitted: (query) {
                      searchFocusNode.unfocus();
                      _searchLocation(query);
                    },
                    style: TextStyle(
                      color: context.color.textDefaultColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          "Search city, area or landmark...".translate(context),
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
                          if (searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: context.color.textLightColor,
                                size: 20,
                              ),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _showSuggestions = false;
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

                // Live Suggestions Dropdown
                if (_showSuggestions && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: context.color.borderColor.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.location_on_outlined,
                            color: context.color.territoryColor,
                            size: 20,
                          ),
                          title: Text(
                            result.title,
                            style: TextStyle(
                              color: context.color.textDefaultColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: result.subtitle.isNotEmpty
                              ? Text(
                                  result.subtitle,
                                  style: TextStyle(
                                    color: context.color.textLightColor,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
