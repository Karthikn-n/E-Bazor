import 'dart:developer';
import 'package:Ebozor/app/routes.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:Ebozor/data/model/user_address_model.dart';
import 'package:Ebozor/data/repositories/user_address_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class LocationDetailsFormScreen extends StatefulWidget {
  final UserAddressModel? addressToEdit;

  const LocationDetailsFormScreen({
    super.key,
    this.addressToEdit,
  });

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;
    return BlurredRouter(
      builder: (context) => LocationDetailsFormScreen(
        addressToEdit: arguments?['address'],
      ),
    );
  }

  @override
  State<LocationDetailsFormScreen> createState() =>
      _LocationDetailsFormScreenState();
}

class _LocationDetailsFormScreenState extends State<LocationDetailsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserAddressRepository _addressRepo = UserAddressRepository();

  late final TextEditingController _neighborhoodController;
  late final TextEditingController _streetNameController;
  late final TextEditingController _apartmentNumberController;
  late final TextEditingController _customLabelController;

  String _selectedLabelType = "Home"; // 'Add Custom Label', 'Home', 'Work'
  bool _isDefault = false;
  bool _isSaving = false;
  bool _isLocating = false;

  LatLng _selectedLatLng = const LatLng(25.2048, 55.2708); // Dubai default
  String _selectedLocationName = "Pinned Location";
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    final edit = widget.addressToEdit;
    _neighborhoodController =
        TextEditingController(text: edit?.neighbourhood ?? "");
    _streetNameController = TextEditingController(text: edit?.streetName ?? "");
    _apartmentNumberController =
        TextEditingController(text: edit?.apartmentNumber ?? "");

    final existingLabel = edit?.label ?? "Home";
    if (existingLabel == "Home" || existingLabel == "Work") {
      _selectedLabelType = existingLabel;
      _customLabelController = TextEditingController();
    } else if (existingLabel.isNotEmpty) {
      _selectedLabelType = "Add Custom Label";
      _customLabelController = TextEditingController(text: existingLabel);
    } else {
      _selectedLabelType = "Home";
      _customLabelController = TextEditingController();
    }

    _isDefault = edit?.isDefault ?? false;

    if (edit?.lat != null && edit?.lan != null) {
      _selectedLatLng = LatLng(edit!.lat!, edit.lan!);
      _selectedLocationName = edit.neighbourhood?.isNotEmpty == true
          ? edit.neighbourhood!
          : "Pinned Location";
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _neighborhoodController.dispose();
    _streetNameController.dispose();
    _apartmentNumberController.dispose();
    _customLabelController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _openFullMapPicker() async {
    final result = await Navigator.pushNamed(
      context,
      Routes.locationMapScreen,
      arguments: {
        "from": "addItem",
        "latitude": _selectedLatLng.latitude,
        "longitude": _selectedLatLng.longitude,
      },
    );

    if (result is Map) {
      final lat = result['latitude'] as double?;
      final lng = result['longitude'] as double?;
      final area = result['area'] as String?;
      final city = result['city'] as String?;
      final state = result['state'] as String?;
      final country = result['country'] as String?;

      if (lat != null && lng != null) {
        final newTarget = LatLng(lat, lng);
        setState(() {
          _selectedLatLng = newTarget;
          final locTitle = area?.isNotEmpty == true
              ? area!
              : (city?.isNotEmpty == true ? city! : "Selected Location");
          _selectedLocationName = locTitle;
          if (area?.isNotEmpty == true) {
            _neighborhoodController.text = area!;
          }
          final fullAddr = [city, state, country]
              .where((s) => s != null && s.isNotEmpty)
              .join(", ");
          if (fullAddr.isNotEmpty) {
            _streetNameController.text = fullAddr;
          }
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newTarget, 15));
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
                accuracy: LocationAccuracy.high,));

        final target = LatLng(position.latitude, position.longitude);
        _updateLocation(target);
      }
    } catch (e) {
      log("Location error: $e");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _updateLocation(LatLng target) async {
    setState(() {
      _selectedLatLng = target;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));

    try {
      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
        target.latitude,
        target.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        final neigh = place.subLocality ?? place.locality ?? place.name ?? "";
        if (neigh.isNotEmpty) {
          _neighborhoodController.text = neigh;
          _selectedLocationName = neigh;
        }
        final streetParts = [
          place.name,
          place.street,
          place.thoroughfare,
          place.locality,
        ].where((s) => s != null && s.isNotEmpty && s != neigh).toSet().toList();

        if (streetParts.isNotEmpty) {
          _streetNameController.text = streetParts.join(", ");
        }
        setState(() {});
      }
    } catch (e) {
      log("Reverse geocode error: $e");
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please fill all required fields",
        type: MessageType.warning,
      );
      return;
    }

    final userId = int.tryParse(HiveUtils.getUserId() ?? "0") ?? 0;
    if (userId == 0) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please log in to save addresses",
        type: MessageType.warning,
      );
      return;
    }

    final String finalLabel = _selectedLabelType == "Add Custom Label"
        ? (_customLabelController.text.trim().isNotEmpty
            ? _customLabelController.text.trim()
            : "Other")
        : _selectedLabelType;

    setState(() => _isSaving = true);

    try {
      await _addressRepo.saveAddress(
        userId: userId,
        addressId: widget.addressToEdit?.id,
        neighbourhood: _neighborhoodController.text.trim(),
        streetName: _streetNameController.text.trim(),
        apartmentNumber: _apartmentNumberController.text.trim(),
        label: finalLabel,
        isDefault: _isDefault,
        lat: _selectedLatLng.latitude,
        lan: _selectedLatLng.longitude,
      );

      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          widget.addressToEdit != null
              ? "Address updated successfully"
              : "Address saved successfully",
          type: MessageType.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to save address: $e",
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: AppBar(
            backgroundColor: context.color.secondaryColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: context.color.textDefaultColor,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Text(
              "Location Details",
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Pinned Location Card (Matching Motor Posting Style)
                  Container(
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.color.borderColor.withValues(alpha: 0.8),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 18,
                                  color: context.color.territoryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedLocationName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: _getCurrentLocation,
                              child: Row(
                                children: [
                                  if (_isLocating)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  else
                                    Icon(Icons.my_location_rounded,
                                        size: 15, color: context.color.territoryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Locate Me",
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: context.color.territoryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _neighborhoodController.text.isNotEmpty
                              ? "${_neighborhoodController.text}, ${_streetNameController.text.isNotEmpty ? _streetNameController.text : 'United Arab Emirates'}"
                              : "Click on map or change pin to update address",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 170,
                            width: double.infinity,
                            child: Stack(
                              children: [
                                GoogleMap(
                                  key: ValueKey(
                                      "${_selectedLatLng.latitude}_${_selectedLatLng.longitude}"),
                                  initialCameraPosition: CameraPosition(
                                    target: _selectedLatLng,
                                    zoom: 15,
                                  ),
                                  onMapCreated: (ctrl) => _mapController = ctrl,
                                  onTap: (latLng) => _updateLocation(latLng),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId("address_loc"),
                                      position: _selectedLatLng,
                                      draggable: true,
                                      onDragEnd: (newPos) => _updateLocation(newPos),
                                      infoWindow: InfoWindow(
                                        title: _selectedLocationName,
                                        snippet: _neighborhoodController.text,
                                      ),
                                    ),
                                  },
                                  zoomControlsEnabled: false,
                                  myLocationButtonEnabled: false,
                                  mapToolbarEnabled: false,
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: InkWell(
                                    onTap: _openFullMapPicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: context.color.secondaryColor,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.fullscreen_rounded,
                                            size: 16,
                                            color: context.color.textDefaultColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Full Map",
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: context.color.textDefaultColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Neighborhood Field (Required*)
                  _buildFormInput(
                    controller: _neighborhoodController,
                    hint: "Neighborhood",
                    isRequired: true,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? "Neighborhood is required" : null,
                  ),
                  const SizedBox(height: 16),

                  // 3. Building or Street Name Field
                  _buildFormInput(
                    controller: _streetNameController,
                    hint: "Building or Street name",
                  ),
                  const SizedBox(height: 16),

                  // 4. Apartment or Villa Number Field
                  _buildFormInput(
                    controller: _apartmentNumberController,
                    hint: "Apartment or Villa number",
                  ),
                  const SizedBox(height: 24),

                  // 5. Choose how you want to label your location (Required*)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Choose how you want to label your\nlocation",
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                          height: 1.25,
                        ),
                      ),
                      Text(
                        "Required*",
                        style: TextStyle(
                          fontSize: 12,
                          color: context.color.textLightColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Label Choice Chips
                  Row(
                    children: [
                      _buildLabelChip("Add Custom Label"),
                      const SizedBox(width: 8),
                      _buildLabelChip("Home"),
                      const SizedBox(width: 8),
                      _buildLabelChip("Work"),
                    ],
                  ),
                  if (_selectedLabelType == "Add Custom Label") ...[
                    const SizedBox(height: 12),
                    _buildFormInput(
                      controller: _customLabelController,
                      hint: "Enter custom label (e.g. Parents' House, Office)",
                      validator: (val) =>
                          _selectedLabelType == "Add Custom Label" &&
                                  (val == null || val.trim().isEmpty)
                              ? "Custom label is required"
                              : null,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // 6. Set as Default Switch
                  Row(
                    children: [
                      Switch(
                        value: _isDefault,
                        activeThumbColor: const Color(0xFFD31027),
                        onChanged: (val) => setState(() => _isDefault = val),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Set as Default",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 7. Save Address CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD31027),
                        disabledBackgroundColor:
                            const Color(0xFFD31027).withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Save Address",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormInput({
    required TextEditingController controller,
    required String hint,
    bool isRequired = false,
    FormFieldValidator<String>? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.7),
        ),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: TextStyle(
          fontSize: 14.5,
          color: context.color.textDefaultColor,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 14,
            color: context.color.textLightColor.withValues(alpha: 0.7),
          ),
          suffixText: isRequired ? "Required*" : null,
          suffixStyle: TextStyle(
            fontSize: 12,
            color: context.color.textLightColor,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildLabelChip(String label) {
    final isSelected = _selectedLabelType == label;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedLabelType = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? context.color.territoryColor.withValues(alpha: 0.1)
                : context.color.secondaryColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? context.color.territoryColor
                  : context.color.borderColor.withValues(alpha: 0.7),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? context.color.territoryColor
                  : context.color.textDefaultColor,
            ),
          ),
        ),
      ),
    );
  }
}
