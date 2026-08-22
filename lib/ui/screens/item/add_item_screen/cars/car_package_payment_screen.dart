import 'dart:developer';
import 'package:Ebozor/data/cubits/item/fetch_my_promoted_items_cubit.dart';
import 'package:Ebozor/ui/screens/advertisement/my_advertisment_screen.dart';
import 'package:Ebozor/ui/screens/item/my_item_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/cars/car_models.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/subscription_pacakage_model.dart';
import 'package:Ebozor/data/repositories/subscription_repository.dart';
import 'package:Ebozor/settings.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/payment/gatways/stripe_service.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class CarPackagePaymentScreen extends StatefulWidget {
  final CarPostingData? postingData;
  final Map<String, dynamic>? genericAdData;
  final ItemModel? model;

  const CarPackagePaymentScreen({
    super.key,
    this.postingData,
    this.genericAdData,
    this.model,
  });

  static Route route(RouteSettings settings) {
    Map<String, dynamic>? arguments =
        settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) => CarPackagePaymentScreen(
        postingData: arguments?['postingData'],
        genericAdData: arguments?['genericAdData'] ?? arguments,
        model: arguments?['model'],
      ),
    );
  }

  @override
  State<CarPackagePaymentScreen> createState() =>
      _CarPackagePaymentScreenState();
}

class _CarPackagePaymentScreenState extends State<CarPackagePaymentScreen> {
  final SubscriptionRepository _subscriptionRepository = SubscriptionRepository();

  // Dynamic pricing state loaded from API
  double _standardAdPrice = 1438.0;
  double _premium7Price = 1098.0;
  double _premium14Price = 1798.0;
  double _featured7Price = 499.0;
  double _featured14Price = 899.0;

  SubscriptionPackageModel? _baseListingPackage;
  SubscriptionPackageModel? _premium7Pkg;
  SubscriptionPackageModel? _premium14Pkg;
  SubscriptionPackageModel? _featured7Pkg;
  SubscriptionPackageModel? _featured14Pkg;
  List<SubscriptionPackageModel> _allAvailablePackages = [];

  bool _isLoadingPackages = true;

  // Selected add-ons
  String? _selectedPremiumAddon; // null, 'premium_7', 'premium_14'
  String? _selectedFeaturedAddon; // null, 'featured_7', 'featured_14'

  final TextEditingController _discountController = TextEditingController();
  double _discountPercent = 0.0;
  String? _appliedPromoCode;
  bool _isProcessingPayment = false;
  String? _selectedGateway = "stripe";

  @override
  void initState() {
    super.initState();
    _fetchPaymentSettings();
    _fetchDynamicPackages();
  }

  Future<void> _fetchPaymentSettings() async {
    try {
      final res = await Api.get(url: Api.getPaymentSettingsApi);
      final data = res['data'];
      if (data != null && data is Map) {
        if (data['Stripe'] != null) {
          final stripeData = data['Stripe'];
          AppSettings.stripePublishableKey =
              stripeData['api_key']?.toString() ?? "";
          AppSettings.stripeStatus =
              int.tryParse(stripeData['status']?.toString() ?? "0") ?? 0;
          AppSettings.stripeCurrency =
              stripeData['currency_code']?.toString() ?? "AED";
          log("💳 [STRIPE SETTINGS] Key: ${AppSettings.stripePublishableKey}, Status: ${AppSettings.stripeStatus}, Currency: ${AppSettings.stripeCurrency}");
        }
      }
    } catch (e) {
      log("⚠️ [PAYMENT SETTINGS WARN] Error fetching payment settings: $e");
    }
  }

  Future<void> _fetchDynamicPackages() async {
    try {
      log("📦 [PACKAGES API] Fetching dynamic ad pricing from get-package...");
      final listingPackagesOutput =
          await _subscriptionRepository.getSubscriptionPacakges(
        type: "item_listing",
      );

      final adPackagesOutput =
          await _subscriptionRepository.getSubscriptionPacakges(
        type: "advertisement",
      );

      log("📦 [PACKAGES RES] Listing packages: ${listingPackagesOutput.modelList.length}, Ad packages: ${adPackagesOutput.modelList.length}");

      if (mounted) {
        setState(() {
          _allAvailablePackages = [
            ...listingPackagesOutput.modelList,
            ...adPackagesOutput.modelList,
          ];

          // If active listing package exists, extract model and price
          if (listingPackagesOutput.modelList.isNotEmpty) {
            _baseListingPackage = listingPackagesOutput.modelList.first;
            log("📦 [BASE PACKAGE] Found base listing package ID: ${_baseListingPackage?.id}, Name: ${_baseListingPackage?.name}");
            if (_baseListingPackage?.finalPrice != null && _baseListingPackage!.finalPrice! > 0) {
              _standardAdPrice = _baseListingPackage!.finalPrice!;
            } else if (_baseListingPackage?.price != null && _baseListingPackage!.price! > 0) {
              _standardAdPrice = _baseListingPackage!.price!;
            }
          }

          // If advertisement packages exist, map them
          for (var pkg in adPackagesOutput.modelList) {
            final pPrice = pkg.finalPrice ?? pkg.price ?? 0.0;
            final pName = (pkg.name ?? "").toLowerCase();
            final pDuration = pkg.duration?.toString() ?? "";

            if (pName.contains("premium") || pkg.type == "premium") {
              if (pDuration.contains("7") || pName.contains("7")) {
                _premium7Pkg = pkg;
                if (pPrice > 0) _premium7Price = pPrice;
              } else if (pDuration.contains("14") || pName.contains("14")) {
                _premium14Pkg = pkg;
                if (pPrice > 0) _premium14Price = pPrice;
              }
            } else if (pName.contains("featured") || pkg.type == "featured") {
              if (pDuration.contains("7") || pName.contains("7")) {
                _featured7Pkg = pkg;
                if (pPrice > 0) _featured7Price = pPrice;
              } else if (pDuration.contains("14") || pName.contains("14")) {
                _featured14Pkg = pkg;
                if (pPrice > 0) _featured14Price = pPrice;
              }
            }
          }

          _isLoadingPackages = false;
        });
      }
    } catch (e) {
      log("⚠️ [PACKAGES API WARN] Using fallback package pricing: $e");
      if (mounted) {
        setState(() => _isLoadingPackages = false);
      }
    }
  }

  double get _premiumAddonPrice {
    if (_selectedPremiumAddon == 'premium_7') return _premium7Price;
    if (_selectedPremiumAddon == 'premium_14') return _premium14Price;
    return 0.0;
  }

  double get _featuredAddonPrice {
    if (_selectedFeaturedAddon == 'featured_7') return _featured7Price;
    if (_selectedFeaturedAddon == 'featured_14') return _featured14Price;
    return 0.0;
  }

  double get _grossSubtotal =>
      _standardAdPrice + _premiumAddonPrice + _featuredAddonPrice;

  double get _discountAmount => _grossSubtotal * _discountPercent;

  double get _netSubtotal => _grossSubtotal - _discountAmount;

  double get _vatAmount => _netSubtotal * 0.05;

  double get _totalAmount => _netSubtotal + _vatAmount;

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  void _applyDiscountCode() {
    final code = _discountController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code == "EBOZOR10" || code == "WELCOME10" || code == "PROMO10") {
      setState(() {
        _discountPercent = 0.10;
        _appliedPromoCode = code;
      });
    if (code == "VIP20" || code == "PROMO20") {
      setState(() {
        _discountPercent = 0.20;
        _appliedPromoCode = code;
      });
      HelperUtils.showSnackBarMessage(
        context,
        "VIP promo code applied! 20% discount",
        type: MessageType.success,
      );
    } else if (code == "EBOZOR10" || code == "WELCOME10" || code == "PROMO10") {
      setState(() {
        _discountPercent = 0.10;
        _appliedPromoCode = code;
      });
      HelperUtils.showSnackBarMessage(
        context,
        "Promo code '$code' applied! 10% discount",
        type: MessageType.success,
      );
    } else {
      HelperUtils.showSnackBarMessage(
        context,
        "Invalid or expired promo code",
        type: MessageType.error,
      );
    }
  }
  }

  Future<String?> _showPaymentGatewayBottomSheet() async {
    String? selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      builder: (BuildContext modalCtx) {
        String localSelectedGateway = "stripe";
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: context.color.textDefaultColor.withValues(alpha: 0.15),
                        ),
                        height: 5,
                        width: 48,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'selectPaymentMethod'.translate(context),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Choose how you would like to pay AED ${_totalAmount.toStringAsFixed(1)}",
                      style: TextStyle(
                        fontSize: 13,
                        color: context.color.textLightColor,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Stripe Only Card Tile
                    Container(
                      decoration: BoxDecoration(
                        color: context.color.territoryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.color.territoryColor,
                          width: 1.5,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.color.secondaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(Icons.credit_card_rounded, color: Color(0xFF635BFF), size: 24),
                          ),
                        ),
                        title: Text(
                          'Credit / Debit Card (Stripe)',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                        subtitle: Text(
                          "Instant & Secure Checkout",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                        trailing: Icon(
                          Icons.check_circle_rounded,
                          color: context.color.territoryColor,
                          size: 22,
                        ),
                        onTap: () {
                          setModalState(() => localSelectedGateway = "stripe");
                        },
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Explicit Proceed Button inside Bottom Sheet
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(modalCtx, localSelectedGateway);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD31027),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Pay with Stripe • AED ${_totalAmount.toStringAsFixed(1)}",
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() => _selectedGateway = selected);
    }
    return selected;
  }

  void _handlePay() async {
    final selectedMethod = await _showPaymentGatewayBottomSheet();
    if (selectedMethod == null) return;

    _executePayment(selectedMethod);
  }

  /// Verify payment status on the server by checking if the item
  /// has been activated (status changed from "pending payment" to "approved").
  /// This handles cases where Android's ActivityResultRegistry drops the
  /// Stripe result even though the payment actually succeeded.
  Future<bool> _verifyPaymentOnServer(int? itemId) async {
    if (itemId == null) return false;
    try {
      // Wait a moment for the Stripe webhook to process
      await Future.delayed(const Duration(seconds: 2));
      final response = await Api.get(
        url: Api.getMyItemApi,
        queryParameters: {"page": 1},
      );
      final items = response['data']?['data'];
      if (items is List) {
        for (final item in items) {
          if (item['id'] == itemId) {
            final status = (item['status'] ?? "").toString().toLowerCase();
            if (status == "approved" || status == "active" || status == "live") {
              log("💳 [PAYMENT VERIFY] Server confirmed payment for item $itemId — status: $status");
              return true;
            }
            break;
          }
        }
      }
    } catch (e) {
      log("💳 [PAYMENT VERIFY] Error verifying payment: $e");
    }
    return false;
  }

  void _executePayment(String paymentMethodType) async {
    setState(() => _isProcessingPayment = true);

    bool paymentSuccess = false;

    try {
      if (AppSettings.stripePublishableKey.isEmpty) {
        await _fetchPaymentSettings();
      }

      if (AppSettings.stripePublishableKey.isEmpty) {
        throw "Stripe is not configured on the server. Please check payment settings.";
      }

      log("💳 [STRIPE] Initializing Stripe with key: ${AppSettings.stripePublishableKey}");
      await StripeService.initStripe(
        AppSettings.stripePublishableKey,
        AppSettings.stripeCurrency.isNotEmpty ? AppSettings.stripeCurrency : "AED",
      );

      // Determine real dynamic package ID and add-on package IDs
      int? activePackageId = _baseListingPackage?.id;
      if (activePackageId == null && _allAvailablePackages.isNotEmpty) {
        activePackageId = _allAvailablePackages.first.id;
      }

      List<int> addonIds = [];
      if (_selectedPremiumAddon == 'premium_7' && _premium7Pkg?.id != null) {
        addonIds.add(_premium7Pkg!.id!);
      } else if (_selectedPremiumAddon == 'premium_14' && _premium14Pkg?.id != null) {
        addonIds.add(_premium14Pkg!.id!);
      }
      if (_selectedFeaturedAddon == 'featured_7' && _featured7Pkg?.id != null) {
        addonIds.add(_featured7Pkg!.id!);
      } else if (_selectedFeaturedAddon == 'featured_14' && _featured14Pkg?.id != null) {
        addonIds.add(_featured14Pkg!.id!);
      }

      if (activePackageId == null && addonIds.isNotEmpty) {
        activePackageId = addonIds.removeAt(0);
      }

      final Map<String, dynamic> requestParams = {
        "payment_method": "Stripe",
        if (activePackageId != null) "package_id": activePackageId,
        if (widget.model?.id != null) "item_id": widget.model!.id,
      };

      log("💳 [PAYMENT INTENT REQ] Sending parameters: $requestParams");

      // Fetch payment intent from backend API
      final response = await Api.post(
        url: Api.getPaymentIntentApi,
        parameter: requestParams,
      );

      log("💳 [PAYMENT INTENT RES] Received response: $response");

      if (response['error'] == true) {
        final errMsg = response['message']?.toString() ?? 'Unable to create payment intent';
        throw errMsg;
      }

      // API returns: { data: { payment_intent: { id, payment_gateway_response: { client_secret } } } }
      final responseData = response['data'];
      final paymentIntentData = (responseData is Map && responseData.containsKey('payment_intent'))
          ? responseData['payment_intent']
          : responseData;

      dynamic gatewayResp;
      if (paymentIntentData is Map) {
        gatewayResp = paymentIntentData['payment_gateway_response'];
      }
      final clientSecret = (gatewayResp is Map)
          ? gatewayResp['client_secret']?.toString()
          : null;
      final paymentIntentId = paymentIntentData is Map
          ? (paymentIntentData['id']?.toString() ?? '')
          : '';

      if (clientSecret == null || clientSecret.isEmpty) {
        throw "Missing client_secret in payment gateway response";
      }

      paymentSuccess = await StripeService.payWithPaymentSheet(
        context: context,
        merchantDisplayName: Constant.appName,
        amount: _totalAmount.toString(),
        currency: AppSettings.stripeCurrency.isNotEmpty ? AppSettings.stripeCurrency : "AED",
        clientSecret: clientSecret,
        paymentIntentId: paymentIntentId,
      );

      // If payWithPaymentSheet returned false, verify server-side
      // (handles Android ActivityResultRegistry dropping the result)
      if (!paymentSuccess && paymentIntentId.isNotEmpty) {
        paymentSuccess = await _verifyPaymentOnServer(widget.model?.id);
      }
    } catch (e) {
      log("💳 [PAYMENT LOG] Error processing payment: $e");
      // Before showing error, check if payment actually succeeded server-side
      if (mounted) {
        final serverConfirmed = await _verifyPaymentOnServer(widget.model?.id);
        if (serverConfirmed) {
          paymentSuccess = true;
        } else {
          HelperUtils.showSnackBarMessage(
            context,
            "Payment could not be completed: $e",
            type: MessageType.error,
          );
          paymentSuccess = false;
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }

    if (!paymentSuccess || !mounted) return;

    final title = widget.model?.name ??
        widget.postingData?.title ??
        widget.genericAdData?['title'] ??
        "Vehicle Advertisement";
    final description = widget.model?.description ??
        widget.postingData?.description ??
        widget.genericAdData?['description'] ??
        "";
    final price = widget.model?.price ??
        widget.postingData?.price ??
        double.tryParse(widget.genericAdData?['price']?.toString() ?? '0') ??
        0.0;
    final city = widget.model?.city ??
        widget.postingData?.specs.emirate ??
        widget.genericAdData?['city'] ??
        "Dubai";
    final imagePath = widget.model?.image ??
        ((widget.postingData != null &&
                widget.postingData!.imageFiles.isNotEmpty)
            ? widget.postingData!.imageFiles.first.path
            : (widget.genericAdData?['image']?.toString()));

    final createdItem = widget.model ??
        ItemModel(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          name: title,
          description: description,
          price: price,
          image: imagePath,
          city: city,
          status: "approved",
        );

    // Refresh MyAds cubits and screens
    try {
      MyAdvertisementScreen.refreshCallback?.call();
      FetchMyPromotedItemsCubit.globalInstance?.addItem(createdItem);
      FetchMyPromotedItemsCubit.globalInstance?.fetchMyPromotedItems();
      myAdsCubitReference[""]?.addItem(createdItem);
      myAdsCubitReference[""]?.fetchMyItems(getItemsWithStatus: "");
      myAdsCubitReference["approved"]?.fetchMyItems(getItemsWithStatus: "approved");
      myAdsCubitReference["inactive"]?.fetchMyItems(getItemsWithStatus: "inactive");
      context.read<FetchMyPromotedItemsCubit>().addItem(createdItem);
      context.read<FetchMyPromotedItemsCubit>().fetchMyPromotedItems();
    } catch (_) {}

    Navigator.pushNamedAndRemoveUntil(
      context,
      Routes.successItemScreen,
      (route) => route.isFirst,
      arguments: {
        'model': createdItem,
        'isEdit': false,
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
            title: "Select Package",
            onBackPress: () => Navigator.pop(context),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header title
                      Center(
                        child: Text(
                          "Select a package that works for you",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.color.textDefaultColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Notice banner: Paid only category
                      _buildPaidNoticeBanner(context),
                      const SizedBox(height: 16),

                      // Base Package Card (Standard Ad)
                      _buildStandardAdCard(context),
                      const SizedBox(height: 16),

                      // Premium Ad Section
                      _buildPremiumAdSection(context),
                      const SizedBox(height: 16),

                      // Featured Ad Section
                      _buildFeaturedAdSection(context),
                      const SizedBox(height: 24),

                      // Order Summary Card
                      _buildOrderSummaryCard(context),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Pay Button Bar
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
                    onPressed: _isProcessingPayment ? null : _handlePay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD31027), // Modern red brand CTA
                      disabledBackgroundColor:
                          const Color(0xFFD31027).withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isProcessingPayment
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            "Pay AED ${_totalAmount.toStringAsFixed(1)}",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
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

  Widget _buildPaidNoticeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD0DCFC),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.diamond_outlined,
              color: Color(0xFF3366FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "You're posting in a paid only category",
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "This will help you get quality buyers for a small fee.",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardAdCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.territoryColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: context.color.territoryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.check,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Standard Ad",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
          const Spacer(),
          Text(
            "1,438 AED",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumAdSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Premium Ad",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "PREMIUM",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Optional add-ons to boost your listing visibility",
            style: TextStyle(
              fontSize: 12.5,
              color: context.color.textLightColor,
            ),
          ),
          const SizedBox(height: 14),

          // Option 1: 7 Days
          _buildAddonOptionRow(
            title: "Premium Ad for 7 days",
            priceStr: "+ 1,098 AED",
            isSelected: _selectedPremiumAddon == 'premium_7',
            onTap: () {
              setState(() {
                if (_selectedPremiumAddon == 'premium_7') {
                  _selectedPremiumAddon = null;
                } else {
                  _selectedPremiumAddon = 'premium_7';
                }
              });
            },
          ),
          const SizedBox(height: 10),

          // Option 2: 14 Days
          _buildAddonOptionRow(
            title: "Premium Ad for 14 days",
            priceStr: "+ 1,798 AED",
            isSelected: _selectedPremiumAddon == 'premium_14',
            onTap: () {
              setState(() {
                if (_selectedPremiumAddon == 'premium_14') {
                  _selectedPremiumAddon = null;
                } else {
                  _selectedPremiumAddon = 'premium_14';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedAdSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Featured Ad",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "FEATURED",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Featured ads appear above the standard ads",
            style: TextStyle(
              fontSize: 12.5,
              color: context.color.textLightColor,
            ),
          ),
          const SizedBox(height: 14),

          // Option 1: 7 Days
          _buildAddonOptionRow(
            title: "Featured Ad for 7 days",
            priceStr: "+ 499 AED",
            isSelected: _selectedFeaturedAddon == 'featured_7',
            onTap: () {
              setState(() {
                if (_selectedFeaturedAddon == 'featured_7') {
                  _selectedFeaturedAddon = null;
                } else {
                  _selectedFeaturedAddon = 'featured_7';
                }
              });
            },
          ),
          const SizedBox(height: 10),

          // Option 2: 14 Days
          _buildAddonOptionRow(
            title: "Featured Ad for 14 days",
            priceStr: "+ 899 AED",
            isSelected: _selectedFeaturedAddon == 'featured_14',
            onTap: () {
              setState(() {
                if (_selectedFeaturedAddon == 'featured_14') {
                  _selectedFeaturedAddon = null;
                } else {
                  _selectedFeaturedAddon = 'featured_14';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddonOptionRow({
    required String title,
    required String priceStr,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? context.color.territoryColor.withValues(alpha: 0.06)
              : context.color.backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? context.color.territoryColor
                : context.color.borderColor.withValues(alpha: 0.7),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.color.territoryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected
                      ? context.color.territoryColor
                      : context.color.textLightColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: context.color.textDefaultColor,
                ),
              ),
            ),
            Text(
              priceStr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? context.color.territoryColor
                    : context.color.textDefaultColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Order Summary",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
          const SizedBox(height: 14),

          // Standard Ad line
          _buildSummaryLine("Standard Ad", "1,438 AED"),

          // Premium add-on line
          if (_selectedPremiumAddon != null) ...[
            const SizedBox(height: 8),
            _buildSummaryLine(
              _selectedPremiumAddon == 'premium_7'
                  ? "Premium Ad (7 days)"
                  : "Premium Ad (14 days)",
              "+ ${_premiumAddonPrice.toStringAsFixed(0)} AED",
              isAddon: true,
            ),
          ],

          // Featured add-on line
          if (_selectedFeaturedAddon != null) ...[
            const SizedBox(height: 8),
            _buildSummaryLine(
              _selectedFeaturedAddon == 'featured_7'
                  ? "Featured Ad (7 days)"
                  : "Featured Ad (14 days)",
              "+ ${_featuredAddonPrice.toStringAsFixed(0)} AED",
              isAddon: true,
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: context.color.borderColor.withValues(alpha: 0.5)),
          const SizedBox(height: 12),

          // Promo code input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.color.textDefaultColor,
                  ),
                  decoration: InputDecoration(
                    hintText: "Discount code",
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: context.color.textLightColor.withValues(alpha: 0.7),
                    ),
                    filled: true,
                    fillColor: context.color.backgroundColor,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: context.color.borderColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: context.color.borderColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _applyDiscountCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.color.secondaryColor,
                  foregroundColor: context.color.textDefaultColor,
                  side: BorderSide(color: context.color.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 13),
                ),
                child: const Text(
                  "Apply",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),

          if (_appliedPromoCode != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Text(
                  "Code $_appliedPromoCode applied (-${(_discountPercent * 100).toInt()}%)",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: context.color.borderColor.withValues(alpha: 0.5)),
          const SizedBox(height: 12),

          // Subtotal
          _buildSummaryLine(
            "Subtotal",
            "${_netSubtotal.toStringAsFixed(1)} AED",
          ),
          const SizedBox(height: 8),

          // VAT 5%
          _buildSummaryLine(
            "VAT 5%",
            "${_vatAmount.toStringAsFixed(1)} AED",
          ),
          const SizedBox(height: 12),
          Divider(
            color: context.color.borderColor,
            thickness: 1.2,
          ),
          const SizedBox(height: 10),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total",
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
              Text(
                "${_totalAmount.toStringAsFixed(1)} AED",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.color.territoryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, {bool isAddon = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: isAddon
                ? context.color.territoryColor
                : context.color.textLightColor,
            fontWeight: isAddon ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: context.color.textDefaultColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader(BuildContext context,
      {required int currentStep, required int totalSteps}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border(
          bottom: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Step $currentStep of $totalSteps: Package & Payment",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.color.territoryColor,
                ),
              ),
              Text(
                "Final Step",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.color.territoryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: currentStep / totalSteps,
              backgroundColor:
                  context.color.borderColor.withValues(alpha: 0.3),
              valueColor:
                  AlwaysStoppedAnimation<Color>(context.color.territoryColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
