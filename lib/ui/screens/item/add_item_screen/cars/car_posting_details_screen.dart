import 'dart:convert';
import 'dart:io';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/ui/screens/advertisement/my_advertisment_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/cars/car_models.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/posting_form_shared.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/dynamic_custom_fields_form.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/ad_creation_stepper.dart';

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
  final List<String> _existingNetworkImages = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final DynamicCustomFieldsController _detailsFieldsController =
      DynamicCustomFieldsController();

  int _currentStep = 2; // 2: Photos & Price, 4: Review & Publish
  bool _isNegotiable = true;
  bool _showPhoneNumber = true;
  String _phoneNumber = "";
  PostingLocationData _location = PostingLocationData.saved();

  @override
  void initState() {
    super.initState();
    _showPhoneNumber = widget.specsData.showPhoneNumber;
    _phoneNumber = widget.specsData.phoneNumber;
    _isNegotiable = widget.specsData.isNegotiable;

    final initialPrice = widget.specsData.price;
    if (initialPrice > 0) {
      _priceController.text = (initialPrice % 1 == 0)
          ? initialPrice.toInt().toString()
          : initialPrice.toString();
    } else {
      _priceController.text = "185000";
    }

    final makeName = widget.specsData.make.name;
    final modelName = widget.specsData.model.name;
    final year = widget.specsData.year ?? '2022';
    _titleController.text = "$makeName $modelName • $year";
    _descriptionController.text =
        "Excellent condition $makeName $modelName. Full service history. Single owner. Well maintained and ready for a new owner.";

    final item = widget.specsData.item;
    if (item != null) {
      if (item.name != null && item.name!.isNotEmpty) {
        _titleController.text = item.name!;
      }
      if (item.description != null && item.description!.isNotEmpty) {
        _descriptionController.text = item.description!;
      }
      if (item.price != null && item.price! > 0) {
        _priceController.text = (item.price! % 1 == 0)
            ? item.price!.toInt().toString()
            : item.price.toString();
      }
      if (item.latitude != null && item.longitude != null) {
        _location = PostingLocationData(
          coordinates: LatLng(item.latitude!, item.longitude!),
          city: item.city ?? _location.city,
          state: item.state ?? item.city ?? _location.state,
          country: item.country ?? _location.country,
          address: item.address ?? item.city ?? _location.address,
          area: item.area ?? item.address ?? item.city ?? _location.area,
        );
      }
      if (item.image != null && item.image!.trim().isNotEmpty) {
        _existingNetworkImages.add(item.image!.trim());
      }
      if (item.galleryImages != null) {
        for (final g in item.galleryImages!) {
          final gUrl = g.image?.trim();
          if (gUrl != null &&
              gUrl.isNotEmpty &&
              !_existingNetworkImages.contains(gUrl)) {
            _existingNetworkImages.add(gUrl);
          }
        }
      }
    }

    _detailsFieldsController
        .replaceFields(widget.specsData.remainingCustomFields);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _detailsFieldsController.dispose();
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

  void _generateAiTitleAndDescription() {
    final make = widget.specsData.make.name;
    final model = widget.specsData.model.name;
    final year = widget.specsData.year ?? '2022';
    final mileage = widget.specsData.mileage ?? '48,000 km';
    final bodyType = widget.specsData.bodyType ?? 'SUV';
    final fuel = widget.specsData.fuelType ?? 'Petrol';
    final trans = widget.specsData.transmission ?? 'Automatic';
    final drive = widget.specsData.driveType ?? '4WD';
    final condition = widget.specsData.condition ?? 'Used';

    final generatedTitle = "$make $model • $year";
    final generatedDesc =
        "Excellent condition $make $model $year ($bodyType). "
        "Single owner, well maintained and ready for a new owner. "
        "Mileage: $mileage. Transmission: $trans. Fuel: $fuel. Drive: $drive. "
        "Condition: $condition. Full service history available.";

    setState(() {
      _titleController.text = generatedTitle;
      _descriptionController.text = generatedDesc;
    });

    HelperUtils.showSnackBarMessage(
      context,
      "AI title & description generated!",
      type: MessageType.success,
    );
  }

  void _showEditTitleDialog() {
    final controller = TextEditingController(text: _titleController.text);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Edit Title", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter listing title",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF)),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _titleController.text = controller.text.trim());
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _saveDraftAndExit() {
    HelperUtils.showSnackBarMessage(
      context,
      "Draft saved successfully",
      type: MessageType.success,
    );
    Navigator.pop(context);
  }

  void _goToReviewStep() {
    final priceVal = double.tryParse(_priceController.text.replaceAll(',', '').trim());
    if (priceVal == null || priceVal <= 0) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please enter a valid price",
        type: MessageType.warning,
      );
      return;
    }
    setState(() => _currentStep = 4);
  }

  Future<void> _publishAd() async {
    final price = double.tryParse(_priceController.text.replaceAll(',', '').trim()) ?? widget.specsData.price;
    final isEditMode = widget.specsData.isEdit || widget.specsData.item != null;

    final customFieldError = _detailsFieldsController.validate();
    if (customFieldError != null) {
      HelperUtils.showSnackBarMessage(
        context,
        customFieldError,
        type: MessageType.warning,
      );
      return;
    }

    final postingData = CarPostingData(
      specs: widget.specsData,
      imageFiles: _selectedImages,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    final categoryId =
        widget.specsData.category?.id ?? widget.specsData.item?.categoryId ?? 1;
    final allCategoryIds = isEditMode &&
            (widget.specsData.item?.allCategoryIds?.trim().isNotEmpty ?? false)
        ? widget.specsData.item!.allCategoryIds!
        : widget.specsData.breadcrumbs != null &&
                widget.specsData.breadcrumbs!.isNotEmpty
            ? widget.specsData.breadcrumbs!
                .map((b) => b.id)
                .where((id) => id != null)
                .join(',')
            : (widget.specsData.item?.allCategoryIds ?? "$categoryId");

    final customFields = {
      ...widget.specsData.customFields,
      ..._detailsFieldsController.toSubmissionMap(),
    };

    final itemDetails = <String, dynamic>{
      if (isEditMode && widget.specsData.item?.id != null)
        'id': widget.specsData.item!.id,
      if (isEditMode &&
          (widget.specsData.item?.status?.trim().isNotEmpty ?? false))
        'status': widget.specsData.item!.status,
      'name': _titleController.text.trim(),
      'slug': _titleController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      'category_id': categoryId,
      'all_category_ids': allCategoryIds,
      'price': (price % 1 == 0) ? price.toInt() : price,
      'description': _descriptionController.text.trim(),
      'contact': _phoneNumber.isNotEmpty ? _phoneNumber : widget.specsData.phoneNumber,
      'hide_phone_number': _showPhoneNumber ? 0 : 1,
      'car_make': widget.specsData.make.id,
      'car_model': widget.specsData.model.id,
      if (widget.specsData.trim != null) 'car_trim': widget.specsData.trim!.id,
      'car_make_id': widget.specsData.make.id,
      'car_model_id': widget.specsData.model.id,
      if (widget.specsData.trim != null)
        'car_trim_id': widget.specsData.trim!.id,
      ..._location.toItemDetails(),
      if (customFields.isNotEmpty) 'custom_fields': jsonEncode(customFields),
    };

    Widgets.showLoader(context);

    if (isEditMode) {
      late final ItemModel updatedItem;
      try {
        itemDetails.addAll(
          await _detailsFieldsController.toFileSubmissionMap(),
        );
        final mainImg =
            _selectedImages.isNotEmpty ? _selectedImages.first : null;
        final otherImgs =
            _selectedImages.length > 1 ? _selectedImages.sublist(1) : null;
        updatedItem =
            await ItemRepository().editItem(itemDetails, mainImg, otherImgs);
      } catch (e) {
        Widgets.hideLoder(context);
        if (mounted) {
          HelperUtils.showSnackBarMessage(
            context,
            "Failed to update ad: $e",
            type: MessageType.error,
          );
        }
        return;
      }
      Widgets.hideLoder(context);
      if (!mounted) return;

      HelperUtils.showSnackBarMessage(
        context,
        "Ad updated successfully!",
        type: MessageType.success,
      );
      try {
        MyAdvertisementScreen.refreshCallback?.call();
      } catch (_) {}
      Navigator.of(context).pop(updatedItem);
      return;
    }

    late final ItemModel createdItemModel;
    try {
      itemDetails.addAll(
        await _detailsFieldsController.toFileSubmissionMap(),
      );
      final mainImg = _selectedImages.isNotEmpty ? _selectedImages.first : null;
      final otherImgs =
          _selectedImages.length > 1 ? _selectedImages.sublist(1) : <File>[];
      createdItemModel =
          await ItemRepository().createItem(itemDetails, mainImg, otherImgs);
    } catch (e) {
      Widgets.hideLoder(context);
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to create ad: $e",
          type: MessageType.error,
        );
      }
      return;
    }
    Widgets.hideLoder(context);
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      Routes.successItemScreen,
      arguments: {
        'isEdit': false,
        'model': createdItemModel,
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
          appBar: AppBar(
            backgroundColor: context.color.secondaryColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: context.color.textDefaultColor,
              onPressed: () {
                if (_currentStep == 4) {
                  setState(() => _currentStep = 2);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              "Post a vehicle",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.color.textDefaultColor,
              ),
            ),
            actions: [
              TextButton(
                onPressed: _saveDraftAndExit,
                child: const Text(
                  "Save & exit",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _currentStep == 4 ? _buildReviewScreen() : _buildPhotosAndPriceScreen(),
        ),
      ),
    );
  }

  // SCREEN 3: Step 2 & 3 - Photos & Price
  Widget _buildPhotosAndPriceScreen() {
    final photoCount = _selectedImages.length + _existingNetworkImages.length;

    return Column(
      children: [
        AdCreationStepper(currentStep: 2, onStepTapped: (step) { if (step == 4) _goToReviewStep(); }),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Headline
                Text(
                  "Make your listing stand out",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Great photos get more views and faster sales.",
                  style: TextStyle(
                    fontSize: 13,
                    color: context.color.textLightColor,
                  ),
                ),
                const SizedBox(height: 20),

                // Add photos header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Add photos",
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    Text(
                      "$photoCount/20",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.color.textLightColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Big Dropzone
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickImages,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF007AFF),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/icons/camera_upload.png',
                              width: 26,
                              height: 26,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Add up to 20 photos",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Tap to upload or choose from your gallery",
                          style: TextStyle(
                            fontSize: 12,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Photo Thumbnails
                if (_selectedImages.isNotEmpty || _existingNetworkImages.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _existingNetworkImages.length + _selectedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final isNetwork = index < _existingNetworkImages.length;
                        final isCover = index == 0;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 80,
                                height: 80,
                                child: isNetwork
                                    ? Image.network(
                                        _existingNetworkImages[index],
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        _selectedImages[index - _existingNetworkImages.length],
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            if (isCover)
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007AFF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "Cover ★",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: InkWell(
                                onTap: () {
                                  if (isNetwork) {
                                    setState(() => _existingNetworkImages.removeAt(index));
                                  } else {
                                    _removeImage(index - _existingNetworkImages.length);
                                  }
                                },
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 13,
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

                const SizedBox(height: 14),

                // Photo Views Tip Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFDE68A),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/lightbulb_tip.png',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Bright, clear photos get up to 3× more views",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: Color(0xFFB45309),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Set your price
                Text(
                  "Set your price",
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.color.textDefaultColor,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "185,000",
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            Text(
                              Constant.currencySymbol,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: context.color.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Negotiable",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _isNegotiable,
                      activeTrackColor: const Color(0xFF007AFF),
                      activeThumbColor: Colors.white,
                      onChanged: (val) => setState(() => _isNegotiable = val),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Create title & description (AI) Card
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _generateAiTitleAndDescription,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/icons/ai_sparkles.png',
                              width: 20,
                              height: 20,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF007AFF),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Create title & description (AI)",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Let AI suggest a great title and description",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Color(0xFF007AFF),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox.shrink(),

                // Preview title (you can edit later)
                Text(
                  "Preview title (you can edit later)",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: context.color.textLightColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _titleController.text.isNotEmpty
                              ? _titleController.text
                              : "${widget.specsData.make.name} ${widget.specsData.model.name} • 2022",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _showEditTitleDialog,
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Sticky Bottom CTA: Review listing >
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            border: Border(
              top: BorderSide(
                color: context.color.borderColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _goToReviewStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Review listing",
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // SCREEN 4: Step 4 - Review & Publish
  Widget _buildReviewScreen() {
    final makeName = widget.specsData.make.name;
    final modelName = widget.specsData.model.name;
    final year = widget.specsData.year ?? '2022';
    final mileage = widget.specsData.mileage ?? '48,000 km';
    final city = widget.specsData.emirate.isNotEmpty ? widget.specsData.emirate : 'Dushanbe';
    final priceVal = double.tryParse(_priceController.text.replaceAll(',', '').trim()) ?? widget.specsData.price;
    final priceFormatted = priceVal.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    final totalPhotos = _selectedImages.length + _existingNetworkImages.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ready to publish",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Review your listing before it goes live.",
                style: TextStyle(
                  fontSize: 13,
                  color: context.color.textLightColor,
                ),
              ),
            ],
          ),
        ),
        AdCreationStepper(currentStep: 4, onStepTapped: (step) { if (step == 2) setState(() => _currentStep = 2); }),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Headline
                Text(
                  "",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "",
                  style: TextStyle(
                    fontSize: 13,
                    color: context.color.textLightColor,
                  ),
                ),
                const SizedBox.shrink(),

                // Live Preview Card
                Container(
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Car Photo
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: _selectedImages.isNotEmpty
                                  ? Image.file(
                                      _selectedImages.first,
                                      fit: BoxFit.cover,
                                    )
                                  : _existingNetworkImages.isNotEmpty
                                      ? Image.network(
                                          _existingNetworkImages.first,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: const Color(0xFF1E293B),
                                          child: const Center(
                                            child: Icon(
                                              Icons.directions_car_filled_rounded,
                                              size: 64,
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                            ),
                            // Top Right: Edit button
                            Positioned(
                              top: 10,
                              right: 10,
                              child: InkWell(
                                onTap: () => setState(() => _currentStep = 2),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Edit ",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 13,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Bottom Right: Photo counter badge
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "1/${totalPhotos > 0 ? totalPhotos : 5}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Details inside card
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$makeName $modelName",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$priceFormatted ${Constant.currencySymbol}",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(year, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                const SizedBox(width: 14),
                                const Icon(Icons.speed_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(mileage.contains('km') ? mileage : "$mileage km", style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                const SizedBox(width: 14),
                                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(city, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox.shrink(),

                // Review Checklist Section
                Container(
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Row 1: Photos
                      _buildChecklistRow(
                        icon: Icons.camera_alt_outlined,
                        title: "Photos",
                        subtitle: "$totalPhotos photos added",
                        onEdit: () => setState(() => _currentStep = 2),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Row 2: Vehicle details
                      _buildChecklistRow(
                        icon: Icons.directions_car_outlined,
                        title: "Vehicle details",
                        subtitle: "$makeName $modelName • $year",
                        onEdit: () => Navigator.pop(context),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Row 3: Price
                      _buildChecklistRow(
                        icon: Icons.local_offer_outlined,
                        title: "Price",
                        subtitle: "$priceFormatted ${Constant.currencySymbol} • ${_isNegotiable ? 'Negotiable' : 'Fixed'}",
                        onEdit: () => setState(() => _currentStep = 2),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),

                      // Row 4: Contact
                      _buildChecklistRow(
                        icon: Icons.phone_outlined,
                        title: "Contact",
                        subtitle: "Your phone number is ready",
                        onEdit: () {
                          HelperUtils.showSnackBarMessage(
                            context,
                            "Contact phone is verified",
                            type: MessageType.success,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Privacy Guarantee Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/privacy_shield.png',
                        width: 22,
                        height: 22,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF007AFF),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Your phone number stays private",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Buyers contact you through eBozor. Stay safe and in control.",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Sticky Bottom Bar: Save draft & Publish now
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            border: Border(
              top: BorderSide(
                color: context.color.borderColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Save draft button
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _saveDraftAndExit,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icons/draft_folder.png',
                            width: 18,
                            height: 18,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.bookmark_border_rounded,
                              size: 17,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Save draft",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Publish now button
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _publishAd,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: const Color(0xFF007AFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icons/publish_airplane.png',
                            width: 18,
                            height: 18,
                            color: Colors.white,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Publish now",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onEdit,
            child: const Text(
              "Edit >",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
