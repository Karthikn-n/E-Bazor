import 'dart:developer';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CarFinanceCalculation {
  final double downPayment;
  final double financedAmount;
  final double totalInterest;
  final double totalLoanAmount;
  final double monthlyPayment;

  const CarFinanceCalculation({
    required this.downPayment,
    required this.financedAmount,
    required this.totalInterest,
    required this.totalLoanAmount,
    required this.monthlyPayment,
  });

  factory CarFinanceCalculation.calculate({
    required double carPrice,
    required double downPaymentPercent,
    required double annualInterestRate,
    required int loanPeriodYears,
  }) {
    final downPayment = carPrice * downPaymentPercent / 100;
    final financedAmount =
        (carPrice - downPayment).clamp(0, double.infinity).toDouble();
    final totalInterest =
        financedAmount * annualInterestRate / 100 * loanPeriodYears;
    final totalLoanAmount = financedAmount + totalInterest;
    final months = loanPeriodYears * 12;

    return CarFinanceCalculation(
      downPayment: downPayment,
      financedAmount: financedAmount,
      totalInterest: totalInterest,
      totalLoanAmount: totalLoanAmount,
      monthlyPayment: months > 0 ? totalLoanAmount / months : 0,
    );
  }
}

class CarFinanceCalculator extends StatefulWidget {
  final double initialPrice;
  final String? carName;
  final String? carYear;
  final int? carMakeId;
  final int? carModelId;
  final int? carTrimId;
  final bool showApplyButton;

  const CarFinanceCalculator({
    super.key,
    required this.initialPrice,
    this.carName,
    this.carYear,
    this.carMakeId,
    this.carModelId,
    this.carTrimId,
    this.showApplyButton = true,
  });

  @override
  State<CarFinanceCalculator> createState() => _CarFinanceCalculatorState();
}

class _CarFinanceCalculatorState extends State<CarFinanceCalculator> {
  static const double _minCarPrice = 15000;
  static const double _maxCarPrice = 1000000;
  late double _carPrice;
  double _downPaymentPercent = 10;
  double _interestRate = 1;
  int _loanPeriodYears = 1;
  bool _isSubmittingFinance = false;
  late final TextEditingController _priceController;
  late final TextEditingController _downPaymentController;
  late final TextEditingController _interestController;

  late final NumberFormat _formatter = NumberFormat("#,##0", "en_US");

  @override
  void initState() {
    super.initState();
    _carPrice = widget.initialPrice.clamp(_minCarPrice, _maxCarPrice);
    _priceController =
        TextEditingController(text: _carPrice.round().toString());
    _downPaymentController = TextEditingController(
      text: _downPaymentPercent.round().toString(),
    );
    _interestController = TextEditingController(
      text: _interestRate.toStringAsFixed(1),
    );
  }

  @override
  void didUpdateWidget(covariant CarFinanceCalculator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPrice != widget.initialPrice &&
        widget.initialPrice > 0) {
      _carPrice = widget.initialPrice.clamp(_minCarPrice, _maxCarPrice);
      _priceController.text = _carPrice.round().toString();
    }
  }

  CarFinanceCalculation get _calculation => CarFinanceCalculation.calculate(
        carPrice: _carPrice,
        downPaymentPercent: _downPaymentPercent,
        annualInterestRate: _interestRate,
        loanPeriodYears: _loanPeriodYears,
      );

  double get _downPaymentAmount => _calculation.downPayment;
  double get _totalInterest => _calculation.totalInterest;
  double get _totalLoanAmount => _calculation.totalLoanAmount;
  double get _monthlyPayment => _calculation.monthlyPayment;

  void _updatePrice(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed >= _minCarPrice && parsed <= _maxCarPrice) {
      setState(() => _carPrice = parsed);
    }
  }

  void _commitPrice() {
    final parsed = double.tryParse(_priceController.text) ?? _carPrice;
    setState(() {
      _carPrice = parsed.clamp(_minCarPrice, _maxCarPrice);
      _priceController.text = _carPrice.round().toString();
    });
  }

  void _updateDownPayment(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed >= 0 && parsed <= 80) {
      setState(() => _downPaymentPercent = parsed.roundToDouble());
    }
  }

  void _commitDownPayment() {
    final parsed =
        double.tryParse(_downPaymentController.text) ?? _downPaymentPercent;
    setState(() {
      _downPaymentPercent = parsed.clamp(0, 80).roundToDouble();
      _downPaymentController.text = _downPaymentPercent.round().toString();
    });
  }

  void _updateInterest(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed >= 1 && parsed <= 10) {
      setState(() => _interestRate = (parsed * 10).round() / 10);
    }
  }

  void _commitInterest() {
    final parsed = double.tryParse(_interestController.text) ?? _interestRate;
    setState(() {
      _interestRate = (parsed.clamp(1, 10) * 10).round() / 10;
      _interestController.text = _interestRate.toStringAsFixed(1);
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _downPaymentController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _applyForCarFinance() async {
    if (!HiveUtils.isUserAuthenticated()) {
      UiUtils.checkUser(onNotGuest: () {}, context: context);
      return;
    }

    final user = HiveUtils.getUserDetails();
    final userId = HiveUtils.getUserId();

    if (userId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        "Please login to apply for car finance",
        type: MessageType.warning,
      );
      return;
    }

    setState(() => _isSubmittingFinance = true);

    try {
      final payload = {
        "user_id": userId,
        if (user.name != null && user.name!.isNotEmpty) "user_name": user.name,
        if (user.mobile != null && user.mobile!.isNotEmpty)
          "user_number": user.mobile,
        if (user.email != null && user.email!.isNotEmpty)
          "user_email": user.email,
        if (widget.carName != null && widget.carName!.isNotEmpty)
          "car_name": widget.carName,
        if (widget.carYear != null && widget.carYear!.isNotEmpty)
          "car_year": widget.carYear,
        if (widget.carMakeId != null) "car_make_id": widget.carMakeId,
        if (widget.carModelId != null) "car_model_id": widget.carModelId,
        if (widget.carTrimId != null) "car_trim_id": widget.carTrimId,
        "car_price": _carPrice.round(),
        "down_payment": _downPaymentAmount.round(),
        "down_payment_percentage": _downPaymentPercent.round(),
        "interest_rate": _interestRate,
        "loan_period_years": _loanPeriodYears,
        "monthly_payment": _monthlyPayment.round(),
        "total_loan_amount": _totalLoanAmount.round(),
      };

      log("🚗 [CAR FINANCE API] Sending POST /api/car-finance with payload: $payload");

      final response = await Api.post(
        url: Api.carFinanceApi,
        parameter: payload,
      );

      log("🚗 [CAR FINANCE API] Response: $response");

      if (mounted) {
        if (response['error'] == true) {
          final msg = response['message']?.toString() ??
              "Failed to submit finance request";
          HelperUtils.showSnackBarMessage(context, msg,
              type: MessageType.error);
        } else {
          final msg = response['message']?.toString() ??
              "Car finance inquiry submitted! A representative will contact you.";
          showDialog(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              backgroundColor: context.color.secondaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    "Inquiry Submitted",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.color.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Monthly Payment",
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: context.color.textLightColor)),
                            Text(
                                "AED ${_formatter.format(_monthlyPayment.round())}",
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Loan Tenure",
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: context.color.textLightColor)),
                            Text("$_loanPeriodYears Years",
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text("Done",
                      style: TextStyle(
                          color: context.color.territoryColor,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      log("🚗 [CAR FINANCE API] Error: $e");
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to submit finance request: $e",
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingFinance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            "Car Finance Calculator",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Estimate your monthly payments using Ebazzor's car loan calculator.",
            style: TextStyle(
              fontSize: 13,
              color: context.color.textLightColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // Monthly Payment Summary Card
          _buildResultCard(),
          const SizedBox(height: 20),

          // Control 1: Car Price
          _buildCarPriceControl(),
          const SizedBox(height: 16),

          // Control 2: Down Payment
          _buildDownPaymentControl(),
          const SizedBox(height: 16),

          // Control 3: Interest Rate
          _buildInterestRateControl(),
          const SizedBox(height: 16),

          // Control 4: Loan Period (Years)
          _buildLoanPeriodControl(),
          if (widget.showApplyButton) ...[
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isSubmittingFinance ? null : _applyForCarFinance,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.red,
              ),
              child: _isSubmittingFinance
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Apply for Car Finance'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.color.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Text(
            "Monthly Payment",
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: context.color.textDefaultColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "AED ${_formatter.format(_monthlyPayment.round())}",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: context.color.textDefaultColor,
            ),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: context.color.borderColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Loan Amount",
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.color.textLightColor,
                ),
              ),
              Text(
                "AED ${_formatter.format(_totalLoanAmount.round())}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Interest",
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.color.textLightColor,
                ),
              ),
              Text(
                "AED ${_formatter.format(_totalInterest.round())}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editableNumberField({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required VoidCallback onCommit,
    String? prefix,
    String? suffix,
    bool allowDecimal = false,
    double width = 132,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.end,
        keyboardType: TextInputType.numberWithOptions(
          decimal: allowDecimal,
        ),
        inputFormatters: [
          if (allowDecimal)
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d?)?$'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: onChanged,
        onFieldSubmitted: (_) => onCommit(),
        onTapOutside: (_) {
          onCommit();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.color.textDefaultColor,
        ),
        decoration: InputDecoration(
          prefixText: prefix,
          suffixText: suffix,
          isDense: true,
          filled: true,
          fillColor: context.color.backgroundColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
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
            borderSide: BorderSide(
              color: context.color.territoryColor,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarPriceControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Car Price",
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            _editableNumberField(
              controller: _priceController,
              prefix: 'AED ',
              onChanged: _updatePrice,
              onCommit: _commitPrice,
              width: 150,
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: context.color.territoryColor,
            inactiveTrackColor: context.color.borderColor,
            thumbColor: context.color.territoryColor,
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: _carPrice,
            min: _minCarPrice,
            max: _maxCarPrice,
            divisions: 985,
            onChanged: (val) {
              setState(() {
                _carPrice = val;
                _priceController.text = _carPrice.round().toString();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDownPaymentControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Down Payment Percentage',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            _editableNumberField(
              controller: _downPaymentController,
              suffix: String.fromCharCode(37),
              onChanged: _updateDownPayment,
              onCommit: _commitDownPayment,
              width: 82,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Amount",
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            Text(
              "AED ${_formatter.format(_downPaymentAmount.round())}",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.color.textDefaultColor,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: context.color.territoryColor,
            inactiveTrackColor: context.color.borderColor,
            thumbColor: context.color.territoryColor,
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: _downPaymentPercent.clamp(0.0, 80.0),
            min: 0.0,
            max: 80.0,
            divisions: 80,
            onChanged: (val) {
              setState(() {
                _downPaymentPercent = val;
                _downPaymentController.text = val.round().toString();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInterestRateControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Interest Rate',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            _editableNumberField(
              controller: _interestController,
              suffix: String.fromCharCode(37),
              allowDecimal: true,
              onChanged: _updateInterest,
              onCommit: _commitInterest,
              width: 82,
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: context.color.territoryColor,
            inactiveTrackColor: context.color.borderColor,
            thumbColor: context.color.territoryColor,
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: _interestRate,
            min: 1.0,
            max: 10.0,
            divisions: 90,
            onChanged: (val) {
              setState(() {
                _interestRate = (val * 10).round() / 10.0;
                _interestController.text = _interestRate.toStringAsFixed(1);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoanPeriodControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Loan Period",
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: context.color.textDefaultColor,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final year = index + 1;
            final isSelected = _loanPeriodYears == year;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 4,
                  right: index == 4 ? 0 : 4,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _loanPeriodYears = year;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.color.backgroundColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? context.color.territoryColor
                            : context.color.borderColor.withValues(alpha: 0.6),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Text(
                      "$year",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? context.color.textDefaultColor
                            : context.color.textLightColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
