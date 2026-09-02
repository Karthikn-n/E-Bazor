import 'dart:io';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  LocationPermissionScreenState createState() =>
      LocationPermissionScreenState();

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(builder: (_) => const LocationPermissionScreen());
  }
}

class LocationPermissionScreenState extends State<LocationPermissionScreen>
    with WidgetsBindingObserver {
  bool _openedAppSettings = false;

  @override
  void initState() {
    // _checkLocationPermission();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _openedAppSettings) {
      _openedAppSettings = false;

      // Reset the flag
      _getCurrentLocation();
      setState(() {}); // Call the method to fetch the current location
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
        // Handle permission not granted for while in use or always
        setDefaultLocationAndNavigate();
      } else {
        _getCurrentLocation();
      }
    } else {
      _getCurrentLocationAndNavigate();
    }
  }

  Future<void> setDefaultLocationAndNavigate() async {
    try {
      double latitude = double.parse(Constant.defaultLatitude);
      double longitude = double.parse(Constant.defaultLongitude);

      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        if (Constant.isDemoModeOn) {
          UiUtils.setDefaultLocationValue(
              isCurrent: false, isHomeUpdate: false, context: context);
        } else {
          await HiveUtils.setLocation(
            area: placemark.subLocality,
            city: placemark.locality!,
            state: placemark.administrativeArea!,
            country: placemark.country!,
            latitude: latitude,
            longitude: longitude,
          );
        }

        if (mounted) {
          HelperUtils.killPreviousPages(
              context, Routes.main, {"from": "login"});
        }
      }
    } catch (e) {
      print("Error getting current location: $e");
    }
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
            setState(() {
              _openedAppSettings = true;
            });

            // Optionally handle action button press
          },
        ),
      ),
    );
  }

  Future<void> _getCurrentLocationAndNavigate() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
      ));

      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        if (Constant.isDemoModeOn) {
          UiUtils.setDefaultLocationValue(
              isCurrent: false, isHomeUpdate: false, context: context);
        } else {
          await HiveUtils.setLocation(
            area: placemark.subLocality,
            city: placemark.locality!,
            state: placemark.administrativeArea!,
            country: placemark.country!,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }

        if (mounted) {
          HelperUtils.killPreviousPages(
              context, Routes.main, {"from": "login"});
        }
      }
    } catch (e) {
      print("Error getting current location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      height: 300,
                      child: UiUtils.getSvg(AppIcons.locationAccessIcon)),
                  const SizedBox(height: 19),
                  Text(
                    "whatsYourLocation".translate(context),
                  ).size(context.font.extraLarge).bold(weight: FontWeight.w600),
                  const SizedBox(height: 14),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'enjoyPersonalizedSellingAndBuyingLocationLbl'
                          .translate(context),
                    )
                        .size(context.font.larger)
                        .color(context.color.textDefaultColor
                            .withValues(alpha: 0.65))
                        .centerAlign(),
                  ),
                  const SizedBox(height: 58),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 12),
                    child: UiUtils.buildButton(context,
                        showElevation: false,
                        buttonColor: context.color.territoryColor,
                        textColor: context.color.secondaryColor, onPressed: () {
                      // Check location permission when the button is pressed
                      _getCurrentLocation();
                    },
                        radius: 8,
                        height: 46,
                        buttonTitle: "findMyLocation".translate(context)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 12),
                    child: UiUtils.buildButton(context,
                        showElevation: false,
                        buttonColor: context.color.backgroundColor,
                        border: BorderSide(color: context.color.territoryColor),
                        textColor: context.color.territoryColor, onPressed: () {
                      Navigator.pushNamed(context, Routes.countriesScreen,
                          arguments: {"from": "login"});
                    },
                        radius: 8,
                        height: 46,
                        buttonTitle: "otherLocation".translate(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
