import 'dart:developer';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/motors_service_models.dart';
import 'package:Ebozor/data/repositories/motors_service_repository.dart';
import 'package:Ebozor/settings.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/payment/gatways/stripe_service.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/utils/validator.dart';
import 'package:flutter/material.dart';

class MotorsInspectionCheckoutScreen extends StatefulWidget {
  final MotorsServicePaymentDraft draft;

  const MotorsInspectionCheckoutScreen({
    super.key,
    required this.draft,
  });

  static Route route(RouteSettings settings) {
    final draft = settings.arguments as MotorsServicePaymentDraft;
    return MaterialPageRoute(
      builder: (_) => MotorsInspectionCheckoutScreen(draft: draft),
    );
  }

  @override
  State<MotorsInspectionCheckoutScreen> createState() =>
      _MotorsInspectionCheckoutScreenState();
}

class _MotorsInspectionCheckoutScreenState
    extends State<MotorsInspectionCheckoutScreen> {
  final _repository = MotorsServiceRepository();
  final _emailController = TextEditingController();
  late final Future<List<InspectionPackageModel>> _packagesFuture;

  InspectionPackageModel? _selectedPackage;
  String _paymentMethod = 'Stripe';
  bool _processing = false;
  bool _paymentCompleted = false;
  bool _showSummary = false;

  bool get _isInspection => widget.draft.type == MotorsServiceType.inspection;

  String get _screenTitle => switch (widget.draft.type) {
        MotorsServiceType.inspection => 'Book Car Inspection',
        MotorsServiceType.finance => 'Car Finance Payment',
        MotorsServiceType.evaluation => 'Car Evaluation Payment',
      };

  String get _packageSubtitle => switch (widget.draft.type) {
        MotorsServiceType.inspection =>
          'Choose the inspection coverage that suits you',
        MotorsServiceType.finance =>
          'Choose your preferred service package to continue',
        MotorsServiceType.evaluation =>
          'Choose your preferred service package to continue',
      };

  double get _subtotal => _selectedPackage?.price ?? 0;
  double get _vat => _subtotal * .05;
  double get _total => _subtotal + _vat;

  bool get _hasValidEmail =>
      RegExp(Validator.emailPattern).hasMatch(_emailController.text.trim());

  bool get _canPay =>
      _selectedPackage?.id != null && _hasValidEmail && !_processing;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.draft.email;
    _selectedPackage = widget.draft.initialPackage;
    _packagesFuture = _loadPackages();
  }

  Future<List<InspectionPackageModel>> _loadPackages() async {
    final packages = await _repository.fetchInspectionPackages();
    if (!mounted) return packages;
    final requested = _selectedPackage;
    InspectionPackageModel? selected;
    for (final package in packages) {
      final sameId = requested?.id != null && package.id == requested?.id;
      final samePlan = requested != null &&
          package.name == requested.name &&
          package.price == requested.price;
      if (sameId || samePlan) {
        selected = package;
        break;
      }
    }
    selected ??= packages.firstOrNull;
    setState(() => _selectedPackage = selected);
    return packages;
  }

  Future<void> _loadStripeSettings() async {
    final response = await Api.get(url: Api.getPaymentSettingsApi);
    final data = response['data'];
    if (data is! Map || data['Stripe'] is! Map) return;
    final stripe = data['Stripe'] as Map;
    AppSettings.stripePublishableKey =
        stripe['api_key']?.toString() ?? AppSettings.stripePublishableKey;
    AppSettings.stripeStatus =
        int.tryParse(stripe['status']?.toString() ?? '') ??
            AppSettings.stripeStatus;
    AppSettings.stripeCurrency = stripe['currency_code']?.toString() ?? 'AED';
  }

  Future<bool> _payWithStripe(InspectionPackageModel package) async {
    if (AppSettings.stripePublishableKey.isEmpty) {
      await _loadStripeSettings();
    }
    if (AppSettings.stripePublishableKey.isEmpty) {
      throw Exception('Stripe is currently unavailable');
    }

    await StripeService.initStripe(
      AppSettings.stripePublishableKey,
      AppSettings.stripeCurrency.isEmpty ? 'AED' : AppSettings.stripeCurrency,
    );
    final requestParams = <String, dynamic>{
      'payment_method': 'Stripe',
      'package_id': package.id,
    };
    log('[MOTORS PAYMENT] intent request: $requestParams');
    final response = await Api.post(
      url: Api.getPaymentIntentApi,
      parameter: requestParams,
    );
    log('[MOTORS PAYMENT] intent response: $response');
    final responseData = response['data'];
    final paymentIntent =
        responseData is Map && responseData.containsKey('payment_intent')
            ? responseData['payment_intent']
            : responseData;
    if (paymentIntent is! Map) {
      throw Exception('Invalid payment intent response');
    }
    final gatewayResponse = paymentIntent['payment_gateway_response'];
    final clientSecret = gatewayResponse is Map
        ? gatewayResponse['client_secret']?.toString()
        : paymentIntent['client_secret']?.toString();
    if (clientSecret == null || clientSecret.isEmpty) {
      throw Exception('Missing Stripe client secret');
    }

    return StripeService.payWithPaymentSheet(
      context: context,
      merchantDisplayName: Constant.appName,
      amount: _total.toStringAsFixed(2),
      currency: AppSettings.stripeCurrency.isEmpty
          ? 'AED'
          : AppSettings.stripeCurrency,
      clientSecret: clientSecret,
      paymentIntentId: paymentIntent['id']?.toString() ?? '',
    );
  }

  Future<void> _pay() async {
    final package = _selectedPackage;
    if (package?.id == null || !_hasValidEmail) return;
    if (_paymentMethod == 'Tabby') {
      HelperUtils.showSnackBarMessage(
        context,
        'Tabby checkout is not configured by the server yet',
        type: MessageType.warning,
      );
      return;
    }

    setState(() => _processing = true);
    try {
      if (!_paymentCompleted) {
        final paid = await _payWithStripe(package!);
        if (!paid || !mounted) return;
        _paymentCompleted = true;
      }
      final payload = <String, dynamic>{...widget.draft.servicePayload};
      late final Map<String, dynamic> response;
      switch (widget.draft.type) {
        case MotorsServiceType.inspection:
          payload.addAll({
            'email': _emailController.text.trim(),
            'package_id': package!.id,
            'price': package.price == package.price.truncate()
                ? package.price.toInt()
                : package.price,
            'payment_type': 'Stripe',
            'payment_status': 'success',
          });
          response = await _repository.bookInspection(payload);
        case MotorsServiceType.finance:
          payload['user_email'] = _emailController.text.trim();
          response = await _repository.submitFinance(payload);
        case MotorsServiceType.evaluation:
          payload['user_email'] = _emailController.text.trim();
          response = await _repository.submitEvaluation(payload);
      }
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(
        context,
        response['message']?.toString() ??
            'Car inspection details added successfully',
        type: MessageType.success,
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        _isInspection
            ? Routes.carInspectionHistoryScreen
            : Routes.motorsServiceScreen,
        (route) => route.isFirst,
      );
    } catch (error) {
      if (!mounted) return;
      final retryNote = _paymentCompleted
          ? ' Payment is complete; tap Pay again to retry the booking without another charge.'
          : '';
      HelperUtils.showSnackBarMessage(
        context,
        '${error.toString().replaceFirst('Exception: ', '')}$retryNote',
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
        title: Text(_screenTitle),
        backgroundColor: context.color.secondaryColor,
        foregroundColor: context.color.textDefaultColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
              children: [
                const Text(
                  'Select a Package',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  _packageSubtitle,
                  style: TextStyle(color: context.color.textLightColor),
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<InspectionPackageModel>>(
                  future: _packagesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final packages = snapshot.data ?? const [];
                    if (packages.isEmpty) {
                      return _messageCard(
                        'Service packages are unavailable. Please try again.',
                      );
                    }
                    final highestPrice = packages.fold<double>(
                      0,
                      (highest, item) =>
                          item.price > highest ? item.price : highest,
                    );
                    return Column(
                      children: packages
                          .map(
                            (package) => _packageCard(
                              package,
                              recommended: package.price == highestPrice,
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  _isInspection
                      ? 'Email for your inspection report'
                      : 'Email for your payment receipt',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) =>
                      Validator.validateEmail(email: value, context: context),
                  decoration: _inputDecoration('Email address'),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Select a Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _paymentTile(
                  method: 'Stripe',
                  title: 'Credit Card',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UiUtils.getSvg(
                        'assets/svg/payment/ic_stripe.svg',
                        width: 34,
                        height: 26,
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.credit_card_rounded, size: 28),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _paymentTile(
                  method: 'Tabby',
                  title:
                      '4 payments of AED ${(_total / 4).toStringAsFixed(2)} each',
                  trailing: SizedBox(
                    width: 54,
                    height: 22,
                    child: UiUtils.getSvgImage(
                      _staticAssetUrl(
                        '_next/static/media/tabby.239b310d.svg',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _packageCard(
    InspectionPackageModel package, {
    required bool recommended,
  }) {
    final selected = package.id != null && package.id == _selectedPackage?.id;
    final foreground = selected ? Colors.white : context.color.textDefaultColor;
    final muted = selected
        ? Colors.white.withValues(alpha: .72)
        : context.color.textLightColor;
    final points = package.points.trim();
    final pointsLabel = points.isEmpty
        ? ''
        : points.toLowerCase().contains('point')
            ? points
            : '$points-point inspection';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        elevation: selected ? 10 : 1,
        shadowColor: selected
            ? const Color(0xFFFFC857).withValues(alpha: .22)
            : Colors.black.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _paymentCompleted
              ? null
              : () => setState(() => _selectedPackage = package),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selected ? null : context.color.secondaryColor,
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF17171F), Color(0xFF302829)],
                    )
                  : null,
              border: Border.all(
                color: selected
                    ? const Color(0xFFFFC857)
                    : recommended
                        ? const Color(0xFFFFC857).withValues(alpha: .55)
                        : context.color.borderColor,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommended) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC857),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'MOST POPULAR',
                      style: TextStyle(
                        color: Color(0xFF242018),
                        fontSize: 9,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package.name,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.3,
                            ),
                          ),
                          if (pointsLabel.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                pointsLabel,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        selected
                            ? Icons.verified_rounded
                            : Icons.circle_outlined,
                        key: ValueKey(selected),
                        color: selected
                            ? const Color(0xFFFFC857)
                            : context.color.textLightColor,
                        size: 29,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: foreground),
                          children: [
                            const TextSpan(
                              text: 'AED ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: package.price.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF57D39B),
                      size: 20,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '100% Refund Policy',
                        style: const TextStyle(
                          color: Color(0xFF57D39B),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pay in 4 payments of AED ${(package.price * 1.05 / 4).toStringAsFixed(2)} with',
                        style: TextStyle(
                          color: muted,
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      height: 20,
                      child: UiUtils.getSvgImage(
                        _staticAssetUrl(
                          '_next/static/media/tabby.239b310d.svg',
                        ),
                      ),
                    ),
                  ],
                ),
                if (package.features.isNotEmpty) ...[
                  Divider(
                    height: 28,
                    color: selected
                        ? Colors.white.withValues(alpha: .16)
                        : context.color.borderColor,
                  ),
                  ...package.features.take(4).map(
                        (feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF56B96B),
                                size: 17,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (package.features.length > 4)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => _showPackageDetails(package),
                        style: TextButton.styleFrom(
                          foregroundColor: selected
                              ? const Color(0xFFFFC857)
                              : context.color.territoryColor,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 17),
                        label: Text(
                          'View ${package.features.length - 4} more benefits',
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFC857)
                        : context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    selected ? 'Selected plan' : 'Tap to select',
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF242018)
                          : context.color.textDefaultColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPackageDetails(InspectionPackageModel package) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .78,
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: BoxDecoration(
            color: sheetContext.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetContext.color.borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${package.name} benefits',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: package.features.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF56B96B),
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(package.features[index])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentTile({
    required String method,
    required String title,
    required Widget trailing,
  }) {
    final selected = _paymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = method),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.red : context.color.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? Colors.red : context.color.textLightColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showSummary) ...[
              _summaryRow('Package', _subtotal),
              const SizedBox(height: 5),
              _summaryRow('VAT (5%)', _vat),
              const Divider(height: 16),
              _summaryRow('Total', _total, bold: true),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showSummary = !_showSummary),
                    icon: Icon(
                      _showSummary
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                    ),
                    label: const Text('Show Summary'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _canPay ? _pay : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.red,
                    ),
                    child: _processing
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Pay - AED ${_total.toStringAsFixed(2)}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          'AED ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _messageCard(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.color.borderColor),
      ),
      child: Text(message),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: context.color.secondaryColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.color.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.color.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.color.territoryColor, width: 1.5),
      ),
    );
  }

  String _staticAssetUrl(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return '${AppSettings.hostUrl}:8003/$normalized';
  }
}
