import 'dart:async';
import 'dart:io';

import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/app/routes.dart';

class LocationMapScreen extends StatefulWidget {
  const LocationMapScreen({super.key});

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  GoogleMapController? mapController;
  CameraPosition? _cameraPosition;
  final Set<Marker> _markers = {};
  bool _isFetchingLocation = true;
  AddressComponent? formatedAddress;
  double? latitude, longitude;
  TextEditingController searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  bool _initialLocationSet = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  String? from;

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
            state: arguments['state']);

         String addressString = "";
         if (formatedAddress!.area != null && formatedAddress!.area!.isNotEmpty) {
           addressString += "${formatedAddress!.area}, ";
         }
         if (formatedAddress!.city != null) {
           addressString += "${formatedAddress!.city}, ";
         }
         if (formatedAddress!.state != null) {
           addressString += "${formatedAddress!.state}, ";
         }
         if (formatedAddress!.country != null) {
           addressString += "${formatedAddress!.country}";
         }
         searchController.text = addressString;

        _cameraPosition = CameraPosition(
          target: LatLng(latitude!, longitude!),
          zoom: 14.4746,
        );

        _markers.clear();
        _markers.add(Marker(
          markerId: const MarkerId('currentLocation'),
          position: LatLng(latitude!, longitude!),
        ));

        setState(() {
          _isFetchingLocation = false;
        });
      } else {
        _getCurrentLocation();
      }
      } else {
        _getCurrentLocation();
      }
      _initialLocationSet = true;
    }
  }

  Future<void> _getCurrentLocation() async {
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
            desiredAccuracy: LocationAccuracy.high);

        latitude = position.latitude;
        longitude = position.longitude;

        _cameraPosition = CameraPosition(
          target: LatLng(latitude!, longitude!),
          zoom: 14.4746,
        );

        _markers.clear();
        _markers.add(Marker(
          markerId: const MarkerId('currentLocation'),
          position: LatLng(latitude!, longitude!),
        ));

        getLocationFromLatitudeLongitude(
            latLng: LatLng(latitude!, longitude!));

        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newCameraPosition(_cameraPosition!),
          );
        }

      }
    } catch (e) {
      // Handle error
    }

    setState(() {
      _isFetchingLocation = false;
    });
  }

  getLocationFromLatitudeLongitude({LatLng? latLng}) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          latLng?.latitude ?? latitude!,
          latLng?.longitude ?? longitude!);

      if (placemarks.isNotEmpty) {
        Placemark placeMark = placemarks.first;
        formatedAddress = AddressComponent(
            area: placeMark.subLocality,
            areaId: null,
            city: placeMark.locality,
            country: placeMark.country,
            state: placeMark.administrativeArea);
            
         String addressString = "";
         if (formatedAddress!.area != null && formatedAddress!.area!.isNotEmpty) {
           addressString += "${formatedAddress!.area}, ";
         }
         if (formatedAddress!.city != null) {
           addressString += "${formatedAddress!.city}, ";
         }
         if (formatedAddress!.state != null) {
           addressString += "${formatedAddress!.state}, ";
         }
         if (formatedAddress!.country != null) {
           addressString += "${formatedAddress!.country}";
         }
         if (formatedAddress!.country != null) {
           addressString += "${formatedAddress!.country}";
         }
         if (!searchFocusNode.hasFocus) {
           searchController.text = addressString;
         }
      }
      setState(() {});
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        LatLng newLatLng = LatLng(loc.latitude, loc.longitude);

        mapController?.animateCamera(CameraUpdate.newLatLng(newLatLng));

        setState(() {
          latitude = loc.latitude;
          longitude = loc.longitude;
          _markers.clear();
          _markers.add(Marker(
            markerId: const MarkerId('searchedLocation'),
            position: newLatLng,
          ));
        });

        getLocationFromLatitudeLongitude(latLng: newLatLng);
      }
    } catch (e) {
      // Handle invalid address
    }
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
        leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.arrow_back_ios, color: context.color.textDefaultColor),
            )
        ),
        title: Text("Location", style: TextStyle(color: context.color.textDefaultColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: InkWell(
              onTap: () {
                searchController.clear();
                _getCurrentLocation();
              },
              child: Center(child: Text("Clear All", style: TextStyle(color: context.color.textLightColor))),
            ),
          )
        ],
        backgroundColor: context.color.backgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _cameraPosition == null
                    ? Center(child: UiUtils.progress())
                      :GoogleMap(
                    initialCameraPosition: _cameraPosition!,
                    onMapCreated: _onMapCreated,
                    // markers: _markers, // No markers for center pin mode
                    markers: {},
                    myLocationButtonEnabled: false,
                    myLocationEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                    onCameraMove: (position) {
                      _cameraPosition = position;
                    },
                    onCameraIdle: () {
                      getLocationFromLatitudeLongitude(
                        latLng: _cameraPosition!.target
                      );
                      latitude = _cameraPosition!.target.latitude;
                      longitude = _cameraPosition!.target.longitude;
                    },
                    onTap: (latLng) {
                      // Optional: Tap logic if needed, but center pin is primary
                    },
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Icon(
                        Icons.location_on,
                        size: 45,
                        color: Colors.red,
                      ),
                    ),
                  ),
                Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                                color: context.color.borderColor.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5)
                            )
                          ]
                      ),
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: (query) {
                          if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
                          _searchDebounce = Timer(const Duration(milliseconds: 1000), () {
                            _searchLocation(query);
                          });
                        },
                        textInputAction: TextInputAction.search,
                        onSubmitted: _searchLocation,
                        decoration: InputDecoration(
                            hintText: "Search",
                            hintStyle: TextStyle(color: context.color.textLightColor),
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.location_on_outlined, color: Colors.red),
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14)
                        ),
                      ),
                    )
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
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
                    // Reset Logic - basically current location
                    _getCurrentLocation();
                  },
                  buttonTitle: "Reset",
                  textColor: Colors.red,
                  buttonColor: context.color.secondaryColor,
                  border: BorderSide(color: Colors.red),
                  radius: 8,
                ),
                const SizedBox(height: 12),
                UiUtils.buildButton(
                  context,
                  onPressed: () {
                    if (from == "addItem") {
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
                       }
                    } else if (formatedAddress != null) {
                      HiveUtils.setLocation(
                          city: formatedAddress!.city,
                          state: formatedAddress!.state,
                          country: formatedAddress!.country,
                          area: formatedAddress!.area,
                          latitude: latitude,
                          longitude: longitude);
                      Navigator.pushNamedAndRemoveUntil(
                          context, Routes.main, (route) => false,
                          arguments: {"from": "login"});
                    } else {
                      HiveUtils.setLocation(
                          latitude: latitude, longitude: longitude);
                      Navigator.pushNamedAndRemoveUntil(
                          context, Routes.main, (route) => false,
                          arguments: {"from": "login"});
                    }
                  },
                  buttonTitle: "Apply",
                  textColor: Colors.white,
                  buttonColor: Colors.red, // Matching image red color
                  radius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddressComponent {
  final String? area;
  final int? areaId;
  final String? city;
  final String? state;
  final String? country;

  AddressComponent({this.area, this.areaId, this.city, this.state, this.country});
}
