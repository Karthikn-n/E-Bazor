import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/location_search_helper.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:Ebozor/utils/ui_utils.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/confirm_location_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';

class NearbyLocationScreen extends StatefulWidget {
  final String from;

  const NearbyLocationScreen({
    super.key,
    required this.from,
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;

    return BlurredRouter(
        builder: (context) => NearbyLocationScreen(
              from: arguments?['from'],
            ));
  }

  @override
  NearbyLocationScreenState createState() => NearbyLocationScreenState();
}

class NearbyLocationScreenState extends State<NearbyLocationScreen>
    with WidgetsBindingObserver {
  double radius = 1.0;
  late GoogleMapController mapController;
  CameraPosition? _cameraPosition;
  Set<Circle> circles = Set.from([]);
  String currentLocation = '';
  double? latitude, longitude;
  AddressComponent? formatedAddress;
  bool isMapLoading = true;

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _isSearching = false;
  List<LocationSearchResult> _searchResults = [];
  bool _showSuggestions = false;

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    _searchDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 1. Load persistent radius if set previously
    final savedRadius = HiveUtils.getNearbyRadius();
    if (savedRadius != null) {
      if (savedRadius is int) {
        radius = savedRadius.toDouble();
      } else if (savedRadius is double) {
        radius = savedRadius;
      }
    }

    // 2. Set fast initial coordinates immediately so map loads instantly
    latitude = HiveUtils.getLatitude() ?? HiveUtils.getCurrentLatitude();
    longitude = HiveUtils.getLongitude() ?? HiveUtils.getCurrentLongitude();
    if (latitude == null ||
        longitude == null ||
        latitude == 0 ||
        longitude == 0) {
      latitude = double.tryParse(Constant.defaultLatitude) ?? 25.2048;
      longitude = double.tryParse(Constant.defaultLongitude) ?? 55.2708;
    }

    _cameraPosition = CameraPosition(
      target: LatLng(latitude!, longitude!),
      zoom: 14.4746,
      bearing: 0,
    );

    _getCurrentLocation();

    WidgetsBinding.instance.addObserver(this);
  }

  bool _initialCircleSet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialCircleSet && latitude != null && longitude != null) {
      _addCircle(LatLng(latitude!, longitude!), radius);
      _initialCircleSet = true;
    }
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission;

    // Check location permission status
    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      if (Platform.isAndroid) {
        await Geolocator.openLocationSettings();
        _getCurrentLocation();
      }
      _showLocationServiceInstructions();
    } else if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        setDefaultLocation();
      } else {
        _getCurrentLocation();
      }
    } else {
      // Permission is granted, proceed to get the current location
      preFillLocationWhileEdit();
    }
  }

  void setDefaultLocation() {
    latitude = double.tryParse(Constant.defaultLatitude) ?? 25.2048;
    longitude = double.tryParse(Constant.defaultLongitude) ?? 55.2708;
    getLocationFromLatitudeLongitude(latLng: LatLng(latitude!, longitude!));
    _cameraPosition = CameraPosition(
      target: LatLng(latitude!, longitude!),
      zoom: 14.4746,
      bearing: 0,
    );
    _addCircle(LatLng(latitude!, longitude!), radius);
    if (mounted)
      setState(() {
        isMapLoading = false;
      });
  }

  Future<void> preFillLocationWhileEdit() async {
    latitude = HiveUtils.getLatitude();
    longitude = HiveUtils.getLongitude();
    if (latitude != "" &&
        latitude != null &&
        longitude != "" &&
        longitude != null) {
      getLocationFromLatitudeLongitude(latLng: LatLng(latitude!, longitude!));
      _cameraPosition = CameraPosition(
        target: LatLng(latitude!, longitude!),
        zoom: 14.4746,
        bearing: 0,
      );
      _addCircle(LatLng(latitude!, longitude!), radius);
      setState(() {});
    } else {
      currentLocation = [
        HiveUtils.getCurrentAreaName(),
        HiveUtils.getCurrentCityName(),
        HiveUtils.getCurrentStateName(),
        HiveUtils.getCurrentCountryName()
      ].where((part) => part != null && part.isNotEmpty).join(', ');
      if (currentLocation == "") {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        _cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14.4746,
          bearing: 0,
        );
        getLocationFromLatitudeLongitude(
            latLng: LatLng(position.latitude, position.longitude));
        latitude = position.latitude;
        longitude = position.longitude;
        _addCircle(LatLng(position.latitude, position.longitude), radius);
      } else {
        formatedAddress = AddressComponent(
            area: HiveUtils.getCurrentAreaName(),
            areaId: null,
            city: HiveUtils.getCurrentCityName(),
            country: HiveUtils.getCurrentCountryName(),
            state: HiveUtils.getCurrentStateName());
        latitude = HiveUtils.getCurrentLatitude();
        longitude = HiveUtils.getCurrentLongitude();
        _cameraPosition = CameraPosition(
          target: LatLng(latitude!, longitude!),
          zoom: 14.4746,
          bearing: 0,
        );
        _addCircle(LatLng(latitude!, longitude!), radius);
        getLocationFromLatitudeLongitude(latLng: LatLng(latitude!, longitude!));
      }
    }

    setState(() {});
  }

  Future<void> getLocationFromLatitudeLongitude({LatLng? latLng}) async {
    try {
      Placemark? placeMark = (await Geocoding().placemarkFromCoordinates(
              latLng?.latitude ?? _cameraPosition!.target.latitude,
              latLng?.longitude ?? _cameraPosition!.target.longitude))
          .first;

      formatedAddress = AddressComponent(
          area: placeMark.subLocality,
          areaId: null,
          city: placeMark.locality,
          country: placeMark.country,
          state: placeMark.administrativeArea);

      final addrStr = [
        formatedAddress?.area,
        formatedAddress?.city,
        formatedAddress?.state,
        formatedAddress?.country,
      ].where((e) => e != null && e.isNotEmpty).join(", ");

      if (!searchFocusNode.hasFocus && addrStr.isNotEmpty) {
        searchController.text = addrStr;
      }

      setState(() {});
    } catch (e) {
      log(e.toString());
      formatedAddress = null;
      setState(() {});
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
      final results = await LocationSearchHelper.search(
        trimmedQuery,
        defaultCountry: HiveUtils.getCountryName() ?? 'United Arab Emirates',
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _showSuggestions = results.isNotEmpty;
          _isSearching = false;
        });
      }
    } catch (e) {
      log("[NearbySearch] Error: $e");
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showSuggestions = false;
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
    _cameraPosition = CameraPosition(target: targetLatLng, zoom: 14.4746);

    mapController.animateCamera(
      CameraUpdate.newCameraPosition(_cameraPosition!),
    );

    _addCircle(targetLatLng, radius);

    setState(() {
      _showSuggestions = false;
      if (result.area != null || result.city != null) {
        formatedAddress = AddressComponent(
          area: result.area,
          areaId: null,
          city: result.city,
          country: result.country,
          state: result.state,
        );
      }
    });

    getLocationFromLatitudeLongitude(latLng: targetLatLng);
  }

  void _showLocationServiceInstructions() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('pleaseEnableLocationServicesManually'.translate(context)),
        action: SnackBarAction(
          label: 'ok'.translate(context),
          textColor: context.color.secondaryColor,
          onPressed: () {
            openAppSettings();
          },
        ),
      ),
    );
  }

/*  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }*/

  void _addCircle(LatLng position, double radiusInKm) {
    final double radiusInMeters = radiusInKm * 1000; // Convert km to meters
    final color = context.color.territoryColor;

    circles = {
      Circle(
        circleId: const CircleId("radius_circle"),
        center: position,
        radius: radiusInMeters,
        fillColor: color.withValues(alpha: 0.15),
        strokeColor: color,
        strokeWidth: 2,
      ),
    };

    if (mounted) {
      setState(() {});
    }
  }

  Widget bottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          color: context.color.backgroundColor,
          thickness: 1.5,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: sidePadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                  child: UiUtils.buildButton(context, radius: 8, fontSize: 16,
                      onPressed: () {
                setState(() {
                  radius = 1;
                  _addCircle(LatLng(latitude!, longitude!), radius);
                });
                HiveUtils.clearNearbyRadius();
              },
                      buttonTitle: "reset".translate(context),
                      height: 43,
                      border: BorderSide(color: context.color.territoryColor),
                      textColor: context.color.territoryColor,
                      buttonColor: context.color.secondaryColor)),
              const SizedBox(width: 16),
              Expanded(
                  child: UiUtils.buildButton(context, radius: 8, fontSize: 16,
                      onPressed: () {
                HiveUtils.setNearbyRadius(radius.toInt());
                applyOnPressed();
              },
                      buttonTitle: "apply".translate(context),
                      height: 43,
                      textColor: context.color.secondaryColor,
                      buttonColor: context.color.territoryColor)),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<void> applyOnPressed() async {
    if (widget.from == "home") {
      await HiveUtils.setLocation(
          city: formatedAddress!.city,
          state: formatedAddress!.state,
          area: formatedAddress!.area,
          country: formatedAddress!.country,
          latitude: latitude,
          longitude: longitude);

      Future.delayed(
        Duration.zero,
        () {
          context.read<FetchHomeScreenCubit>().fetch(
              country: formatedAddress!.country,
              state: formatedAddress!.state,
              city: formatedAddress!.city);
          context.read<FetchHomeAllItemsCubit>().fetch(
              country: formatedAddress!.country,
              state: formatedAddress!.state,
              city: formatedAddress!.city,
              radius: radius.toInt(),
              latitude: latitude,
              longitude: longitude);
        },
      );

      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (widget.from == "location" ||
        widget.from == "login" ||
        widget.from == "signup" ||
        widget.from == "signin" ||
        widget.from == "locationPermission" ||
        widget.from == "auth") {
      await HiveUtils.setLocation(
          city: formatedAddress!.city,
          state: formatedAddress!.state,
          area: formatedAddress!.area,
          country: formatedAddress!.country,
          latitude: latitude,
          longitude: longitude);
      HelperUtils.killPreviousPages(context, Routes.main, {"from": "login"});
    } else {
      Map<String, dynamic> result = {
        'area_id': null,
        'area': formatedAddress!.area,
        'state': formatedAddress!.state,
        'country': formatedAddress!.country,
        'city': formatedAddress!.city,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius.toInt()
      };
      Navigator.pop(context);
      Navigator.pop(context, result);
    }
  }

  Set<Factory<OneSequenceGestureRecognizer>> getMapGestureRecognizers() {
    return <Factory<OneSequenceGestureRecognizer>>{
      Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        bottomNavigationBar: bottomBar(),
        backgroundColor: context.color.secondaryColor,
        appBar: UiUtils.buildAppBar(context,
            showBackButton: true, title: "nearbyListings".translate(context)),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: context.color.backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      _cameraPosition != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            color:
                                                context.color.backgroundColor),
                                        height: context.screenHeight * 0.6,
                                        child: GoogleMap(
                                            onCameraMove: (position) {
                                              _cameraPosition = position;
                                            },
                                            onCameraIdle: () async {
                                              final target =
                                                  _cameraPosition!.target;
                                              if (latitude == target.latitude &&
                                                  longitude ==
                                                      target.longitude) {
                                                return;
                                              }
                                              latitude = target.latitude;
                                              longitude = target.longitude;
                                              _addCircle(target, radius);
                                              await getLocationFromLatitudeLongitude(
                                                  latLng: target);
                                            },
                                            initialCameraPosition:
                                                _cameraPosition!,
                                            //onMapCreated: _onMapCreated,
                                            circles: circles,
                                            zoomControlsEnabled: false,
                                            minMaxZoomPreference:
                                                const MinMaxZoomPreference(
                                                    2, 20),
                                            scrollGesturesEnabled: true,
                                            zoomGesturesEnabled: true,
                                            rotateGesturesEnabled: true,
                                            tiltGesturesEnabled: true,
                                            compassEnabled: true,
                                            indoorViewEnabled: true,
                                            mapToolbarEnabled: true,
                                            myLocationButtonEnabled: false,
                                            mapType: MapType.normal,
                                            gestureRecognizers:
                                                getMapGestureRecognizers(),
                                            onMapCreated: (GoogleMapController
                                                controller) {
                                              Future.delayed(const Duration(
                                                      milliseconds: 500))
                                                  .then((value) {
                                                mapController = (controller);
                                                mapController.animateCamera(
                                                  CameraUpdate
                                                      .newCameraPosition(
                                                    _cameraPosition!,
                                                  ),
                                                );
                                                //preFillLocationWhileEdit();
                                              });
                                            },
                                            onTap: (latLng) {
                                              mapController.animateCamera(
                                                CameraUpdate.newLatLng(latLng),
                                              );
                                            }))),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Transform.translate(
                                        offset: const Offset(0, -22),
                                        child: Icon(
                                          Icons.location_pin,
                                          size: 48,
                                          color: context.color.territoryColor,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black38,
                                              blurRadius: 5,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                 PositionedDirectional(
                                   start: 12,
                                   top: 12,
                                   end: 12,
                                   child: Material(
                                     color: context.color.secondaryColor,
                                     borderRadius: BorderRadius.circular(14),
                                     clipBehavior: Clip.antiAlias,
                                     elevation: 4,
                                     shadowColor: Colors.black
                                         .withValues(alpha: 0.15),
                                     child: AnimatedSize(
                                       duration:
                                           const Duration(milliseconds: 250),
                                       curve: Curves.easeInOut,
                                       alignment: Alignment.topCenter,
                                       child: Column(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           // 1. Search Field
                                           TextField(
                                             controller: searchController,
                                             focusNode: searchFocusNode,
                                             onChanged: (query) {
                                               if (_searchDebounce?.isActive ??
                                                   false) {
                                                 _searchDebounce!.cancel();
                                               }
                                               _searchDebounce = Timer(
                                                 const Duration(
                                                     milliseconds: 350),
                                                 () => _searchLocation(query),
                                               );
                                             },
                                             textInputAction:
                                                 TextInputAction.search,
                                             onSubmitted: (query) {
                                               searchFocusNode.unfocus();
                                               _searchLocation(query);
                                             },
                                             style: TextStyle(
                                               color: context
                                                   .color.textDefaultColor,
                                               fontSize: 13,
                                               fontWeight: FontWeight.w500,
                                             ),
                                             decoration: InputDecoration(
                                               hintText:
                                                   "Search city, area or address..."
                                                       .translate(context),
                                               hintStyle: TextStyle(
                                                 color: context
                                                     .color.textLightColor,
                                                 fontSize: 13,
                                               ),
                                               border: InputBorder.none,
                                               prefixIcon: Icon(
                                                 Icons.search_rounded,
                                                 color: context
                                                     .color.territoryColor,
                                                 size: 20,
                                               ),
                                               suffixIcon: Row(
                                                 mainAxisSize: MainAxisSize.min,
                                                 children: [
                                                   if (_isSearching)
                                                     Padding(
                                                       padding:
                                                           const EdgeInsets.all(
                                                               10),
                                                       child: SizedBox(
                                                         width: 14,
                                                         height: 14,
                                                         child:
                                                             CircularProgressIndicator(
                                                           strokeWidth: 2,
                                                           color: context.color
                                                               .territoryColor,
                                                         ),
                                                       ),
                                                     ),
                                                   if (searchController
                                                       .text.isNotEmpty)
                                                     IconButton(
                                                       icon: Icon(
                                                         Icons.close_rounded,
                                                         color: context.color
                                                             .textLightColor,
                                                         size: 18,
                                                       ),
                                                       onPressed: () {
                                                         searchController
                                                             .clear();
                                                         setState(() {
                                                           _searchResults = [];
                                                           _showSuggestions =
                                                               false;
                                                         });
                                                       },
                                                     ),
                                                 ],
                                               ),
                                               contentPadding:
                                                   const EdgeInsets.symmetric(
                                                 horizontal: 14,
                                                 vertical: 12,
                                               ),
                                             ),
                                           ),

                                           // 2. Seamlessly Extended Live Suggestions Dropdown
                                           if (_showSuggestions &&
                                               _searchResults.isNotEmpty) ...[
                                             Divider(
                                               height: 1,
                                               thickness: 0.8,
                                               color: context.color.borderColor
                                                   .withValues(alpha: 0.6),
                                             ),
                                             ConstrainedBox(
                                               constraints:
                                                   const BoxConstraints(
                                                       maxHeight: 220),
                                               child: ListView.separated(
                                                 padding:
                                                     const EdgeInsets.symmetric(
                                                         vertical: 4),
                                                 shrinkWrap: true,
                                                 itemCount:
                                                     _searchResults.length,
                                                 separatorBuilder: (_, __) =>
                                                     Divider(
                                                   height: 1,
                                                   thickness: 0.5,
                                                   color: context
                                                       .color.borderColor
                                                       .withValues(alpha: 0.4),
                                                 ),
                                                 itemBuilder: (context, index) {
                                                   final result =
                                                       _searchResults[index];
                                                   return ListTile(
                                                     dense: true,
                                                     leading: Container(
                                                       padding:
                                                           const EdgeInsets.all(
                                                               6),
                                                       decoration:
                                                           BoxDecoration(
                                                         color: context
                                                             .color
                                                             .territoryColor
                                                             .withValues(
                                                                 alpha: 0.1),
                                                         shape: BoxShape.circle,
                                                       ),
                                                       child: Icon(
                                                         Icons
                                                             .location_on_outlined,
                                                         color: context.color
                                                             .territoryColor,
                                                         size: 16,
                                                       ),
                                                     ),
                                                     title: Text(
                                                       result.title,
                                                       style: TextStyle(
                                                         color: context.color
                                                             .textDefaultColor,
                                                         fontSize: 12,
                                                         fontWeight:
                                                             FontWeight.w600,
                                                       ),
                                                       maxLines: 1,
                                                       overflow: TextOverflow
                                                           .ellipsis,
                                                     ),
                                                     subtitle: result.subtitle
                                                             .isNotEmpty
                                                         ? Text(
                                                             result.subtitle,
                                                             style: TextStyle(
                                                               color: context
                                                                   .color
                                                                   .textLightColor,
                                                               fontSize: 10,
                                                             ),
                                                             maxLines: 1,
                                                             overflow:
                                                                 TextOverflow
                                                                     .ellipsis,
                                                           )
                                                         : null,
                                                     onTap: () =>
                                                         _selectSearchResult(
                                                             result),
                                                   );
                                                 },
                                               ),
                                             ),
                                           ],
                                         ],
                                       ),
                                     ),
                                   ),
                                 ),
                                PositionedDirectional(
                                  end: 30,
                                  bottom: 15,
                                  child: InkWell(
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: context.color.borderColor,
                                          width: Constant.borderWidth,
                                        ),
                                        color: context.color.secondaryColor,
                                        // Adjust the opacity as needed
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.my_location_sharp,
                                        // Change the icon color if needed
                                      ),
                                    ),
                                    onTap: () async {
                                      Position position =
                                          await Geolocator.getCurrentPosition(
                                        locationSettings:
                                            const LocationSettings(
                                          accuracy: LocationAccuracy.high,
                                        ),
                                      );

                                      _cameraPosition = CameraPosition(
                                        target: LatLng(position.latitude,
                                            position.longitude),
                                        zoom: 14.4746,
                                        bearing: 0,
                                      );
                                      mapController.animateCamera(
                                        CameraUpdate.newCameraPosition(
                                            _cameraPosition!),
                                      );
                                      setState(() {});
                                    },
                                  ),
                                )
                              ],
                            )
                          : Container(),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                child: Text(
                  'selectAreaRange'.translate(context),
                )
                    .color(context.color.textDefaultColor)
                    .bold(weight: FontWeight.w600),
              ),
              SizedBox(
                height: 15,
              ),
              Slider(
                value: radius,
                min: 1,
                activeColor: context.color.textDefaultColor,
                inactiveColor: context.color.backgroundColor.darken(20),
                max: 100,
                divisions: 99,
                label: '${radius.toInt()}\t${"km".translate(context)}',
                onChanged: (value) {
                  setState(() {
                    radius = value;
                    _addCircle(LatLng(latitude!, longitude!), radius);
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1\t${"km".translate(context)}')
                        .color(context.color.textDefaultColor)
                        .bold(weight: FontWeight.w500),
                    Text('100\t${"km".translate(context)}')
                        .color(context.color.textDefaultColor)
                        .bold(weight: FontWeight.w500),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
