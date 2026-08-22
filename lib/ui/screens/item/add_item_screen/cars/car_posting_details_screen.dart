import 'dart:io';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/cars/car_models.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class CarPostingDetailsScreen extends StatefulWidget {
  final CarSpecsData specsData;

  const CarPostingDetailsScreen({super.key, required this.specsData});

  static Route route(RouteSettings settings) {
    Map<String, dynamic>? arguments =
        settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) => CarPostingDetailsScreen(
        specsData: arguments!['specsData'],
      ),
    );
  }

  @override
  State<CarPostingDetailsScreen> createState() =>
      _CarPostingDetailsScreenState();
}

class _CarPostingDetailsScreenState extends State<CarPostingDetailsScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Selections
  String _interiorColor = "Beige";
  String _exteriorColor = "White";
  String _warranty = "Yes";
  String _fuelType = "Petrol";
  String _doors = "4 Doors";
  String _cylinders = "4 Cylinders";
  String _transmission = "Automatic";
  String _seatingCapacity = "5 Seater";
  String _horsepower = "200 - 300 HP";
  String _steeringSide = "Left Hand";
  String _engineCapacity = "2000 - 2500 cc";

  // Multi-select Feature Categories
  List<String> _selectedDriverAssistance = [];
  List<String> _selectedEntertainmentTech = [];
  List<String> _selectedComfortConvenience = [];
  List<String> _selectedExteriorFeatures = [];

  // Location Data
  String _locationNeighbourhood = "Downtown Dubai";
  String _locationBuildingStreet = "";
  String _locationApartmentVilla = "";
  String _locationLabel = "Home";
  String _locationAddress = "Downtown Dubai, Dubai, United Arab Emirates";
  LatLng _currentLocationLatLng = const LatLng(25.2048, 55.2708); // Dubai

  int _descriptionCharCount = 0;

  // Options
  final List<String> _interiorColors = [
    "Beige",
    "Black",
    "Brown",
    "Tan",
    "Grey",
    "Red",
    "White",
    "Other"
  ];

  final List<String> _exteriorColors = [
    "White",
    "Black",
    "Silver",
    "Grey",
    "Blue",
    "Red",
    "Brown",
    "Green",
    "Gold / Yellow",
    "Orange",
    "Custom / Other"
  ];

  final List<String> _warranties = [
    "Yes",
    "No",
    "Does not apply"
  ];

  final List<String> _doorsOptions = [
    "2 Doors",
    "3 Doors",
    "4 Doors",
    "5+ Doors"
  ];

  final List<String> _cylindersOptions = [
    "3 Cylinders",
    "4 Cylinders",
    "5 Cylinders",
    "6 Cylinders",
    "8 Cylinders",
    "10 Cylinders",
    "12 Cylinders",
    "Electric / Rotary"
  ];

  final List<String> _seatingCapacities = [
    "2 Seater",
    "4 Seater",
    "5 Seater",
    "7 Seater",
    "8+ Seater"
  ];

  final List<String> _horsepowers = [
    "Less than 150 HP",
    "150 - 200 HP",
    "200 - 300 HP",
    "300 - 400 HP",
    "400 - 500 HP",
    "500+ HP"
  ];

  final List<String> _engineCapacities = [
    "1000 - 1500 cc",
    "1600 - 2000 cc",
    "2000 - 2500 cc",
    "2500 - 3000 cc",
    "3000 - 4000 cc",
    "4000+ cc",
    "Electric"
  ];

  final List<String> _driverAssistanceList = [
    "Anti-Lock Braking System (ABS)",
    "Blind Spot Monitor",
    "Lane Departure Warning",
    "Lane Keeping Assist",
    "Forward Collision Warning",
    "Automatic Emergency Braking",
    "Adaptive Cruise Control",
    "Parking Sensors (Front & Rear)",
    "Reversing Camera",
    "360 Degree Camera System",
    "Tire Pressure Monitoring (TPMS)",
    "Traction & Stability Control"
  ];

  final List<String> _entertainmentTechList = [
    "Apple CarPlay",
    "Android Auto",
    "Bluetooth Audio & Handsfree",
    "Touchscreen Infotainment",
    "Satellite Navigation (GPS)",
    "Premium Sound System (Bose/Harman)",
    "Wireless Phone Charger",
    "Head-Up Display (HUD)",
    "USB Ports / Fast Charging",
    "Rear Seat Entertainment Screens"
  ];

  final List<String> _comfortConvenienceList = [
    "Leather Seats",
    "Sunroof / Moonroof",
    "Panoramic Glass Roof",
    "Keyless Entry & Start",
    "Push Button Engine Start",
    "Heated Front Seats",
    "Ventilated / Cooled Seats",
    "Dual-Zone Automatic Climate Control",
    "Power Adjustable Seats with Memory",
    "Power Tailgate / Trunk",
    "Paddle Shifters",
    "Ambient Interior Lighting"
  ];

  final List<String> _exteriorFeaturesList = [
    "Alloy Wheels",
    "LED Headlights & DRLs",
    "Fog Lights",
    "Roof Rails",
    "Rear Spoiler",
    "Tinted Windows",
    "Power Folding Mirrors",
    "Tow Hitch / Towing Package",
    "Body Kit / Sport Package"
  ];

  final List<String> _neighbourhoods = [
    "Downtown Dubai",
    "Dubai Marina",
    "Business Bay",
    "Jumeirah Beach Residence (JBR)",
    "Jumeirah Lake Towers (JLT)",
    "Palm Jumeirah",
    "Al Barsha",
    "Deira",
    "Bur Dubai",
    "Al Nahda",
    "Mirdif",
    "Jumeirah",
    "Dubai Silicon Oasis",
    "Al Quoz",
    "Arabian Ranches",
    "Dubai Hills Estate",
    "Al Reem Island (Abu Dhabi)",
    "Al Khalidiyah (Abu Dhabi)",
    "Al Majaz (Sharjah)",
    "Al Nahda (Sharjah)"
  ];

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.specsData.displayName;
    _descriptionController.text =
        "Excellent condition ${widget.specsData.displayName} for sale. Carefully driven, well-maintained, and ${widget.specsData.regionalSpecs}.";
    _descriptionCharCount = _descriptionController.text.length;

    _setInitialCoordinates();

    _descriptionController.addListener(() {
      setState(() {
        _descriptionCharCount = _descriptionController.text.length;
      });
    });
  }

  void _setInitialCoordinates() {
    final emirate = widget.specsData.emirate.toLowerCase();
    if (emirate.contains("abu dhabi")) {
      _currentLocationLatLng = const LatLng(24.4539, 54.3773);
    } else if (emirate.contains("sharjah")) {
      _currentLocationLatLng = const LatLng(25.3463, 55.4209);
    } else if (emirate.contains("ajman")) {
      _currentLocationLatLng = const LatLng(25.4052, 55.5136);
    } else if (emirate.contains("ras al khaimah")) {
      _currentLocationLatLng = const LatLng(25.7895, 55.9432);
    } else if (emirate.contains("fujairah")) {
      _currentLocationLatLng = const LatLng(25.1288, 56.3265);
    } else if (emirate.contains("al ain")) {
      _currentLocationLatLng = const LatLng(24.2075, 55.7447);
    } else {
      _currentLocationLatLng = const LatLng(25.2048, 55.2708);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(picked.map((p) => File(p.path)));
        });
      }
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Failed to pick images: $e",
        type: MessageType.error,
      );
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  String _getBreadcrumbText() {
    if (widget.specsData.breadcrumbs != null &&
        widget.specsData.breadcrumbs!.isNotEmpty) {
      return widget.specsData.breadcrumbs!.map((e) => e.name ?? '').join('  ›  ');
    }
    final catName = widget.specsData.category?.name ?? 'Cars';
    return "Motors  ›  $catName";
  }

  Future<void> _validateAndProceed() async {
    if (_titleController.text.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter an ad Title",
        type: MessageType.warning,
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please provide a description of your car",
        type: MessageType.warning,
      );
      return;
    }

    final postingData = CarPostingData(
      specs: widget.specsData,
      imageFiles: _selectedImages,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      interiorColor: _interiorColor,
      exteriorColor: _exteriorColor,
      warranty: _warranty,
      fuelType: _fuelType,
      doors: _doors,
      cylinders: _cylinders,
      transmission: _transmission,
      seatingCapacity: _seatingCapacity,
      horsepower: _horsepower,
      steeringSide: _steeringSide,
      engineCapacity: _engineCapacity,
      driverAssistance: _selectedDriverAssistance,
      entertainmentTech: _selectedEntertainmentTech,
      comfortConvenience: _selectedComfortConvenience,
      exteriorFeatures: _selectedExteriorFeatures,
      locationNeighbourhood: _locationNeighbourhood,
      locationBuildingStreet: _locationBuildingStreet,
      locationApartmentVilla: _locationApartmentVilla,
      locationLabel: _locationLabel,
      locationAddress: _locationAddress,
    );

    final categoryId = widget.specsData.category?.id ?? 1;
    final allCategoryIds = widget.specsData.breadcrumbs != null &&
            widget.specsData.breadcrumbs!.isNotEmpty
        ? widget.specsData.breadcrumbs!
            .map((b) => b.id)
            .where((id) => id != null)
            .join(',')
        : "$categoryId";

    final itemDetails = <String, dynamic>{
      'name': _titleController.text.trim(),
      'slug': _titleController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      'category_id': categoryId,
      'all_category_ids': allCategoryIds,
      'price': widget.specsData.price,
      'description': _descriptionController.text.trim(),
      'contact': widget.specsData.phoneNumber,
      'show_only_to_premium': 0,
      'country': 'United Arab Emirates',
      'state': widget.specsData.emirate,
      'city': widget.specsData.emirate,
      'latitude': _currentLocationLatLng.latitude,
      'longitude': _currentLocationLatLng.longitude,
      'address': _locationAddress,
      'status': 'inactive',
    };

    Widgets.showLoader(context);
    ItemModel? createdItemModel;
    try {
      if (_selectedImages.isNotEmpty) {
        final mainImg = _selectedImages.first;
        final otherImgs = _selectedImages.length > 1
            ? _selectedImages.sublist(1)
            : <File>[];
        createdItemModel = await ItemRepository()
            .createItem(itemDetails, mainImg, otherImgs);
      }
    } catch (e) {
      debugPrint("Car item create API log: $e");
    } finally {
      Widgets.hideLoder(context);
    }

    final finalModel = createdItemModel ??
        ItemModel(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          name: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: widget.specsData.price,
          image: _selectedImages.isNotEmpty ? _selectedImages.first.path : null,
          city: widget.specsData.emirate,
          status: 'inactive',
        );

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      Routes.carPackagePaymentScreen,
      arguments: {
        'postingData': postingData,
        'model': finalModel,
      },
    );
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
          appBar: UiUtils.buildAppBar(
            context,
            showBackButton: true,
            title: "Post Your Ad",
            onBackPress: () => Navigator.pop(context),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Title
                      Center(
                        child: Text(
                          "You're almost there!",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          "Include as much details and pictures as possible, and set the right price!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Breadcrumbs
                      Row(
                        children: [
                          Icon(
                            Icons.directions_car_outlined,
                            size: 15,
                            color: const Color(0xFF3366FF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getBreadcrumbText(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3366FF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Theme-based Listing Summary Card (with Edit button)
                      _buildListingSummaryCard(context),
                      const SizedBox(height: 20),

                      // 1. Add Pictures
                      _buildAddPicturesSection(context),
                      const SizedBox(height: 20),

                      // 2. Title
                      _buildFieldLabel("Title *"),
                      _buildTextField(
                        controller: _titleController,
                        hint: "Title *",
                        maxLength: 100,
                      ),
                      const SizedBox(height: 16),

                      // 3. Describe your item
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFieldLabel("Describe your item *"),
                          Text(
                            "$_descriptionCharCount/76000",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ],
                      ),
                      _buildTextField(
                        controller: _descriptionController,
                        hint: "Describe your item *",
                        maxLines: 5,
                      ),
                      const SizedBox(height: 20),

                      // 4. Interior Color
                      _buildFieldLabel("Interior Color *"),
                      _buildDropdownTile(
                        title: _interiorColor,
                        onTap: () => _showPickerModal(
                          title: "Select Interior Color",
                          items: _interiorColors,
                          selected: _interiorColor,
                          onSelect: (val) => setState(() => _interiorColor = val),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 5. Exterior Color
                      _buildFieldLabel("Exterior Color *"),
                      _buildDropdownTile(
                        title: _exteriorColor,
                        onTap: () => _showPickerModal(
                          title: "Select Exterior Color",
                          items: _exteriorColors,
                          selected: _exteriorColor,
                          onSelect: (val) => setState(() => _exteriorColor = val),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 6. Warranty
                      _buildFieldLabel("Warranty *"),
                      _buildDropdownTile(
                        title: _warranty,
                        onTap: () => _showPickerModal(
                          title: "Select Warranty Status",
                          items: _warranties,
                          selected: _warranty,
                          onSelect: (val) => setState(() => _warranty = val),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 7. Fuel Type (Filter Buttons)
                      _buildFieldLabel("Fuel Type *"),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildToggleButton(
                            title: "Petrol",
                            isSelected: _fuelType == "Petrol",
                            onTap: () => setState(() => _fuelType = "Petrol"),
                          ),
                          _buildToggleButton(
                            title: "Diesel",
                            isSelected: _fuelType == "Diesel",
                            onTap: () => setState(() => _fuelType = "Diesel"),
                          ),
                          _buildToggleButton(
                            title: "Hybrid",
                            isSelected: _fuelType == "Hybrid",
                            onTap: () => setState(() => _fuelType = "Hybrid"),
                          ),
                          _buildToggleButton(
                            title: "Electric",
                            isSelected: _fuelType == "Electric",
                            onTap: () => setState(() => _fuelType = "Electric"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 8. Doors
                      _buildFieldLabel("Doors *"),
                      _buildDropdownTile(
                        title: _doors,
                        onTap: () => _showPickerModal(
                          title: "Select Number of Doors",
                          items: _doorsOptions,
                          selected: _doors,
                          onSelect: (val) => setState(() => _doors = val),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 9. No. of Cylinders
                      _buildFieldLabel("No. of Cylinders *"),
                      _buildDropdownTile(
                        title: _cylinders,
                        onTap: () => _showPickerModal(
                          title: "Select Cylinders",
                          items: _cylindersOptions,
                          selected: _cylinders,
                          onSelect: (val) => setState(() => _cylinders = val),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 10. Transmission Type (Filter Buttons)
                      _buildFieldLabel("Transmission Type *"),
                      Row(
                        children: [
                          _buildToggleButton(
                            title: "Manual",
                            isSelected: _transmission == "Manual",
                            onTap: () => setState(() => _transmission = "Manual"),
                          ),
                          const SizedBox(width: 12),
                          _buildToggleButton(
                            title: "Automatic",
                            isSelected: _transmission == "Automatic",
                            onTap: () => setState(() => _transmission = "Automatic"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 11. Seating Capacity
                      _buildFieldLabel("Seating Capacity"),
                      _buildDropdownTile(
                        title: _seatingCapacity,
                        onTap: () => _showPickerModal(
                          title: "Select Seating Capacity",
                          items: _seatingCapacities,
                          selected: _seatingCapacity,
                          onSelect: (val) => setState(() => _seatingCapacity = val),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 12. Horsepower
                      _buildFieldLabel("Horsepower"),
                      _buildDropdownTile(
                        title: _horsepower,
                        onTap: () => _showPickerModal(
                          title: "Select Horsepower",
                          items: _horsepowers,
                          selected: _horsepower,
                          onSelect: (val) => setState(() => _horsepower = val),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 13. Steering Side (Filter Buttons)
                      _buildFieldLabel("Steering Side *"),
                      Row(
                        children: [
                          _buildToggleButton(
                            title: "Left Hand",
                            isSelected: _steeringSide == "Left Hand",
                            onTap: () => setState(() => _steeringSide = "Left Hand"),
                          ),
                          const SizedBox(width: 12),
                          _buildToggleButton(
                            title: "Right Hand",
                            isSelected: _steeringSide == "Right Hand",
                            onTap: () => setState(() => _steeringSide = "Right Hand"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 14. Engine Capacity (cc)
                      _buildFieldLabel("Engine Capacity (cc)"),
                      _buildDropdownTile(
                        title: _engineCapacity,
                        onTap: () => _showPickerModal(
                          title: "Select Engine Capacity",
                          items: _engineCapacities,
                          selected: _engineCapacity,
                          onSelect: (val) => setState(() => _engineCapacity = val),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // MULTI-SELECT FEATURE CHECKLISTS WITH HORIZONTAL SCROLL CHIPS (UX REQUIREMENT 1)
                      // 15. Driver Assistance & Safety
                      _buildFeatureCategorySection(
                        title: "Driver Assistance & Safety",
                        selectedItems: _selectedDriverAssistance,
                        onTap: () => _showMultiSelectChecklistModal(
                          title: "Driver Assistance & Safety",
                          allItems: _driverAssistanceList,
                          selectedItems: _selectedDriverAssistance,
                          onDone: (selected) =>
                              setState(() => _selectedDriverAssistance = selected),
                        ),
                        onRemoveItem: (item) {
                          setState(() => _selectedDriverAssistance.remove(item));
                        },
                      ),
                      const SizedBox(height: 16),

                      // 16. Entertainment & Technology
                      _buildFeatureCategorySection(
                        title: "Entertainment & Technology",
                        selectedItems: _selectedEntertainmentTech,
                        onTap: () => _showMultiSelectChecklistModal(
                          title: "Entertainment & Technology",
                          allItems: _entertainmentTechList,
                          selectedItems: _selectedEntertainmentTech,
                          onDone: (selected) =>
                              setState(() => _selectedEntertainmentTech = selected),
                        ),
                        onRemoveItem: (item) {
                          setState(() => _selectedEntertainmentTech.remove(item));
                        },
                      ),
                      const SizedBox(height: 16),

                      // 17. Comfort & Convenience
                      _buildFeatureCategorySection(
                        title: "Comfort & Convenience",
                        selectedItems: _selectedComfortConvenience,
                        onTap: () => _showMultiSelectChecklistModal(
                          title: "Comfort & Convenience",
                          allItems: _comfortConvenienceList,
                          selectedItems: _selectedComfortConvenience,
                          onDone: (selected) =>
                              setState(() => _selectedComfortConvenience = selected),
                        ),
                        onRemoveItem: (item) {
                          setState(() => _selectedComfortConvenience.remove(item));
                        },
                      ),
                      const SizedBox(height: 16),

                      // 18. Exterior
                      _buildFeatureCategorySection(
                        title: "Exterior",
                        selectedItems: _selectedExteriorFeatures,
                        onTap: () => _showMultiSelectChecklistModal(
                          title: "Exterior Features",
                          allItems: _exteriorFeaturesList,
                          selectedItems: _selectedExteriorFeatures,
                          onDone: (selected) =>
                              setState(() => _selectedExteriorFeatures = selected),
                        ),
                        onRemoveItem: (item) {
                          setState(() => _selectedExteriorFeatures.remove(item));
                        },
                      ),
                      const SizedBox(height: 24),

                      // 19. Integrated Live Google Map Section (UX REQUIREMENT 2)
                      _buildLocationMapSection(context),
                      const SizedBox(height: 20),

                      // 20. Disclaimer Box
                      _buildDisclaimerBox(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // 21. Bottom Next Button
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _validateAndProceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD31027), // Red CTA matching web screenshot
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Post & Continue to Payment",
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

  /// Theme-based Listing Summary Card (UX REQUIREMENT 3)
  Widget _buildListingSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Listing Summary",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "Edit",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD31027),
                  ),
                ),
              ),
            ],
          ),
          Divider(
            height: 20,
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),
          _buildSummaryRow("Make", widget.specsData.make?.name ?? "-"),
          _buildSummaryRow("Model", widget.specsData.model?.name ?? "-"),
          _buildSummaryRow("Trim", widget.specsData.effectiveTrim),
          _buildSummaryRow("Regional Specs", widget.specsData.regionalSpecs),
          _buildSummaryRow("Year", widget.specsData.year.toString()),
          _buildSummaryRow("Kilometers", "${widget.specsData.kilometers} km"),
          _buildSummaryRow("Body type", widget.specsData.bodyType),
          _buildSummaryRow(
              "Price", "${widget.specsData.price.toStringAsFixed(0)} AED"),
          _buildSummaryRow("Phone number", widget.specsData.phoneNumber),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.color.textLightColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.color.textDefaultColor,
        ),
      ),
    );
  }

  Widget _buildAddPicturesSection(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: _pickImages,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD31027),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFFD31027),
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  "Add Pictures",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD31027),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = _selectedImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        image,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Main",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToggleButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? context.color.territoryColor.withValues(alpha: 0.1)
              : context.color.secondaryColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? context.color.territoryColor
                : context.color.borderColor.withValues(alpha: 0.8),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? context.color.territoryColor
                : context.color.textDefaultColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: context.color.textDefaultColor,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: context.color.textLightColor.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: context.color.secondaryColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.8),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.color.territoryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.color.textDefaultColor,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: context.color.textLightColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Multi-select feature section with horizontal scrollable chips (UX REQUIREMENT 1)
  Widget _buildFeatureCategorySection({
    required String title,
    required List<String> selectedItems,
    required VoidCallback onTap,
    required ValueChanged<String> onRemoveItem,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureCategoryTile(
          title: title,
          selectedCount: selectedItems.length,
          onTap: onTap,
        ),
        if (selectedItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: selectedItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = selectedItems[index];
                return Container(
                  padding: const EdgeInsets.only(left: 12, right: 6),
                  decoration: BoxDecoration(
                    color: context.color.territoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          context.color.territoryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: context.color.territoryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => onRemoveItem(item),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: context.color.territoryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeatureCategoryTile({
    required String title,
    required int selectedCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.color.textDefaultColor,
                ),
              ),
            ),
            if (selectedCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$selectedCount selected",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: context.color.territoryColor,
                  ),
                ),
              ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: context.color.textLightColor,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getLabelIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('home') || lower.contains('villa') || lower.contains('apt')) {
      return Icons.home_rounded;
    }
    if (lower.contains('office') || lower.contains('work') || lower.contains('business')) {
      return Icons.business_rounded;
    }
    if (lower.contains('showroom') || lower.contains('shop') || lower.contains('store')) {
      return Icons.storefront_rounded;
    }
    return Icons.location_on_rounded;
  }

  Future<void> _openFullMapPicker() async {
    final result = await Navigator.pushNamed(
      context,
      Routes.locationMapScreen,
      arguments: {
        "from": "addItem",
        "latitude": _currentLocationLatLng.latitude,
        "longitude": _currentLocationLatLng.longitude,
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
        setState(() {
          _currentLocationLatLng = LatLng(lat, lng);
          _locationNeighbourhood = area?.isNotEmpty == true
              ? area!
              : (city?.isNotEmpty == true ? city! : "Selected Area");
          final parts = [area, city, state, country]
              .where((s) => s != null && s.isNotEmpty)
              .toList();
          _locationAddress = parts.isNotEmpty
              ? parts.join(", ")
              : "$_locationNeighbourhood, ${widget.specsData.emirate}, UAE";
        });
      }
    }
  }

  /// Integrated Live Google Map Section (UX REQUIREMENT 2)
  Widget _buildLocationMapSection(BuildContext context) {
    return Container(
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
                    _getLabelIcon(_locationLabel),
                    size: 18,
                    color: context.color.territoryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _locationLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _openFullMapPicker,
                child: Row(
                  children: [
                    Icon(Icons.edit_location_alt_outlined,
                        size: 16, color: context.color.territoryColor),
                    const SizedBox(width: 4),
                    Text(
                      "Change Pin",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.color.territoryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _locationAddress,
            style: TextStyle(
              fontSize: 12.5,
              color: context.color.textLightColor,
            ),
          ),
          const SizedBox(height: 14),

          // Live Interactive Google Map widget with full map picker
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                children: [
                  GoogleMap(
                    key: ValueKey(
                        "${_currentLocationLatLng.latitude}_${_currentLocationLatLng.longitude}"),
                    initialCameraPosition: CameraPosition(
                      target: _currentLocationLatLng,
                      zoom: 14,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId("current_loc"),
                        position: _currentLocationLatLng,
                        infoWindow: InfoWindow(
                          title: _locationLabel,
                          snippet: _locationAddress,
                        ),
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    onTap: (_) => _openFullMapPicker(),
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
          const SizedBox(height: 14),

          // Location chips / buttons with Wrap to prevent overflow
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showLocationEditModal(context),
                icon: const Icon(Icons.add,
                    size: 16, color: Color(0xFFD31027)),
                label: const Text(
                  "Add Label",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD31027),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD31027)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              InkWell(
                onTap: () => _showLocationEditModal(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.color.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getLabelIcon(_locationLabel),
                        size: 14,
                        color: context.color.territoryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _locationLabel,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit,
                        size: 12,
                        color: context.color.textLightColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLocationEditModal(BuildContext context) {
    String tempNeighbourhood = _locationNeighbourhood;
    final buildingCtrl = TextEditingController(text: _locationBuildingStreet);
    final aptCtrl = TextEditingController(text: _locationApartmentVilla);
    final labelCtrl = TextEditingController(text: _locationLabel);
    final quickLabels = ["Home", "Office", "Showroom", "Workshop", "Warehouse", "Villa", "Apartment"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Material(
                color: context.color.backgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: context.color.borderColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Location Details & Label",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(modalContext),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Neighbourhood dropdown
                        _buildFieldLabel("Neighbourhood / Area *"),
                        InkWell(
                          onTap: () {
                            _showPickerModal(
                              title: "Select Neighbourhood",
                              items: _neighbourhoods,
                              selected: tempNeighbourhood,
                              onSelect: (val) {
                                setModalState(() => tempNeighbourhood = val);
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: context.color.secondaryColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.color.borderColor
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tempNeighbourhood,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: context.color.textLightColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Building / Street name
                        _buildFieldLabel("Building or Street name (Optional)"),
                        _buildTextField(
                          controller: buildingCtrl,
                          hint: "e.g. Burj Crown, Sheikh Zayed Road",
                        ),
                        const SizedBox(height: 14),

                        // Apartment / Villa
                        _buildFieldLabel("Apartment or Villa number (Optional)"),
                        _buildTextField(
                          controller: aptCtrl,
                          hint: "e.g. Apt 1402 / Villa 12",
                        ),
                        const SizedBox(height: 14),

                        // Quick Label Chips
                        _buildFieldLabel("Select Location Label"),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: quickLabels.map((lbl) {
                            final isSel = labelCtrl.text.trim().toLowerCase() == lbl.toLowerCase();
                            return ChoiceChip(
                              label: Text(lbl),
                              selected: isSel,
                              selectedColor: const Color(0xFFD31027).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? const Color(0xFFD31027) : context.color.textDefaultColor,
                              ),
                              onSelected: (_) {
                                setModalState(() {
                                  labelCtrl.text = lbl;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),

                        // Custom Location Label
                        _buildFieldLabel("Custom Label"),
                        _buildTextField(
                          controller: labelCtrl,
                          hint: "e.g. Home, Office, Showroom",
                        ),
                        const SizedBox(height: 20),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _locationNeighbourhood = tempNeighbourhood;
                                _locationBuildingStreet =
                                    buildingCtrl.text.trim();
                                _locationApartmentVilla = aptCtrl.text.trim();
                                _locationLabel = labelCtrl.text.trim().isNotEmpty
                                    ? labelCtrl.text.trim()
                                    : "Home";
                                _locationAddress =
                                    "$tempNeighbourhood, ${widget.specsData.emirate}, UAE";
                              });
                              Navigator.pop(modalContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD31027),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Save Location",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDisclaimerBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: context.color.textLightColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Make sure the car information you have entered is correct. You will only be able to edit specific fields after publishing.",
              style: TextStyle(
                fontSize: 12,
                color: context.color.textLightColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPickerModal({
    required String title,
    required List<String> items,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Material(
          color: context.color.backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.55,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.color.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: context.color.borderColor.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = selected == item;
                      return ListTile(
                        onTap: () {
                          onSelect(item);
                          Navigator.pop(modalContext);
                        },
                        title: Text(
                          item,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? context.color.territoryColor
                                : context.color.textDefaultColor,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: context.color.territoryColor,
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMultiSelectChecklistModal({
    required String title,
    required List<String> allItems,
    required List<String> selectedItems,
    required ValueChanged<List<String>> onDone,
  }) {
    List<String> tempSelected = List.from(selectedItems);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Material(
              color: context.color.backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.70,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.color.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: allItems.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: context.color.borderColor
                              .withValues(alpha: 0.3),
                        ),
                        itemBuilder: (context, index) {
                          final item = allItems[index];
                          final isChecked = tempSelected.contains(item);
                          return CheckboxListTile(
                            value: isChecked,
                            activeColor: const Color(0xFFD31027),
                            title: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight:
                                    isChecked ? FontWeight.bold : FontWeight.w500,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  tempSelected.add(item);
                                } else {
                                  tempSelected.remove(item);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          onDone(tempSelected);
                          Navigator.pop(modalContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD31027),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Done (${tempSelected.length} Selected)",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
