import 'dart:async';

import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' as f;
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/settings.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({
    super.key,
    required this.item,
    required CameraPosition kInitialPlace,
    required Completer<GoogleMapController> controller,
  })  : _kInitialPlace = kInitialPlace,
        _controller = controller;

  final ItemModel? item;
  final CameraPosition _kInitialPlace;
  final Completer<GoogleMapController> _controller;

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  bool isGoogleMapVisible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(
      const Duration(milliseconds: 200),
      () {
        if (mounted) {
          setState(() {
            isGoogleMapVisible = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Stack(
          children: [
            // Google Map Widget
            Builder(builder: (context) {
              if (!isGoogleMapVisible) {
                return Center(child: UiUtils.progress());
              }
              return GoogleMap(
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                gestureRecognizers: <f.Factory<OneSequenceGestureRecognizer>>{
                  f.Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
                markers: {
                  Marker(
                    markerId: const MarkerId("1"),
                    position: LatLng(
                      widget.item!.latitude ?? 0,
                      widget.item!.longitude ?? 0,
                    ),
                  )
                },
                mapType: AppSettings.googleMapType,
                initialCameraPosition: widget._kInitialPlace,
                onMapCreated: (GoogleMapController controller) {
                  if (!widget._controller.isCompleted) {
                    widget._controller.complete(controller);
                  }
                },
              );
            }),

            // Custom Back Button on top of the Map
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 18,
              child: Material(
                clipBehavior: Clip.antiAlias,
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Directionality(
                      textDirection: Directionality.of(context),
                      child: RotatedBox(
                        quarterTurns:
                            Directionality.of(context) == TextDirection.rtl
                                ? 2
                                : 0,
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
