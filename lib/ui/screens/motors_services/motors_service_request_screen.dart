import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/cars/car_models.dart';
import 'package:Ebozor/data/model/motors_service_models.dart';
import 'package:Ebozor/data/repositories/cars_repository.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/utils/validator.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

class MotorsServiceRequestScreen extends StatefulWidget {
  final MotorsServiceType type;
  final InspectionPackageModel? initialPackage;

  const MotorsServiceRequestScreen({
    super.key,
    required this.type,
    this.initialPackage,
  });

  static Route route(RouteSettings settings) {
    final args = settings.arguments;
    final map = args is Map ? args : const {};
    return MaterialPageRoute(
      builder: (_) => MotorsServiceRequestScreen(
        type: map['type'] is MotorsServiceType
            ? map['type'] as MotorsServiceType
            : MotorsServiceType.inspection,
        initialPackage: map['package'] is InspectionPackageModel
            ? map['package'] as InspectionPackageModel
            : null,
      ),
    );
  }

  @override
  State<MotorsServiceRequestScreen> createState() =>
      _MotorsServiceRequestScreenState();
}

class _MotorsServiceRequestScreenState
    extends State<MotorsServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _carsRepository = CarsRepository();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _sellerPhoneController = TextEditingController();

  InspectionPackageModel? _selectedPackage;
  List<CarMake> _makes = const [];
  CarMake? _make;
  CarModelItem? _model;
  String? _selectedYear;
  bool _agree = false;
  bool _loading = false;
  bool _loadingMakes = false;
  String _phoneCountryCode = '971';
  String _phoneCountryFlag = '\u{1F1E6}\u{1F1EA}';
  String _sellerCountryCode = '971';
  String _sellerCountryFlag = '\u{1F1E6}\u{1F1EA}';

  bool get _isInspection => widget.type == MotorsServiceType.inspection;
  bool get _isFinance => widget.type == MotorsServiceType.finance;
  bool get _isEvaluation => widget.type == MotorsServiceType.evaluation;

  String get _title => switch (widget.type) {
        MotorsServiceType.inspection => 'Inspection',
        MotorsServiceType.finance => 'Get Car Finance',
        MotorsServiceType.evaluation => 'Get Car Evaluation Certificate',
      };

  String get _carDisplayName =>
      [_make?.name, _model?.name].whereType<String>().join(' ');

  String get _fullPhoneNumber =>
      '+$_phoneCountryCode${_phoneController.text.trim()}';
  String get _fullSellerPhoneNumber =>
      '+$_sellerCountryCode${_sellerPhoneController.text.trim()}';

  bool get _hasValidContact =>
      _nameController.text.trim().isNotEmpty &&
      Validator.isValidPhoneNumber(
        _phoneController.text,
        _phoneCountryCode,
      );

  bool get _canSubmit {
    if (!_hasValidContact || !_agree) return false;
    if (_isInspection) {
      return _emailController.text.trim().isNotEmpty &&
          Validator.isValidPhoneNumber(
            _sellerPhoneController.text,
            _sellerCountryCode,
          );
    }
    if (_make == null || _model == null || _selectedYear == null) return false;
    if (_isEvaluation) {
      return RegExp(Validator.emailPattern)
          .hasMatch(_emailController.text.trim());
    }
    return true;
  }

  List<String> get _years {
    final currentYear = DateTime.now().year;
    return List.generate(60, (index) => '${currentYear + 1 - index}');
  }

  @override
  void initState() {
    super.initState();
    final user = HiveUtils.getUserDetails();
    _nameController.text = user.name ?? '';
    _emailController.text = user.email ?? '';
    final savedCode =
        (HiveUtils.getCountryCode() ?? '971').replaceAll(RegExp(r'\D'), '');
    if (savedCode.isNotEmpty) {
      _phoneCountryCode = savedCode;
      _phoneCountryFlag =
          savedCode == '971' ? '\u{1F1E6}\u{1F1EA}' : '\u{1F310}';
    }
    _phoneController.text = _localPhoneNumber(
      user.mobile ?? '',
      _phoneCountryCode,
    );
    if (_isInspection) {
      _selectedPackage = widget.initialPackage;
    } else {
      _loadMakes();
    }
  }

  String _localPhoneNumber(String value, String countryCode) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith(countryCode)) {
      digits = digits.substring(countryCode.length);
    }
    if (countryCode == '971' && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  void _showCountryCodePicker({bool seller = false}) {
    showCountryPicker(
      context: context,
      showWorldWide: false,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: context.color.secondaryColor,
        textStyle: TextStyle(color: context.color.textDefaultColor),
        inputDecoration: _inputDecoration(hint: 'Search country'),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      onSelect: (country) {
        setState(() {
          if (seller) {
            _sellerCountryCode = country.phoneCode;
            _sellerCountryFlag = country.flagEmoji;
          } else {
            _phoneCountryCode = country.phoneCode;
            _phoneCountryFlag = country.flagEmoji;
          }
        });
      },
    );
  }

  Future<void> _loadMakes() async {
    setState(() => _loadingMakes = true);
    final makes = await _carsRepository.fetchCarMakes();
    if (!mounted) return;
    setState(() {
      _makes = makes;
      _loadingMakes = false;
    });
  }

  Future<void> _showCarPicker() async {
    if (_loadingMakes) return;
    if (_makes.isEmpty) {
      await _loadMakes();
      if (!mounted || _makes.isEmpty) {
        if (mounted) {
          HelperUtils.showSnackBarMessage(
            context,
            'Car makes are unavailable. Please try again.',
            type: MessageType.warning,
          );
        }
        return;
      }
    }

    final searchController = TextEditingController();
    CarMake? pendingMake = _make;
    CarModelItem? pendingModel = _model;
    List<CarModelItem> models = const [];
    var loadingModels = pendingMake != null;
    if (pendingMake != null) {
      models = await _carsRepository.fetchCarModels(
        pendingMake.id,
        makeName: pendingMake.name,
      );
      loadingModels = false;
      if (!mounted) {
        searchController.dispose();
        return;
      }
    }

    final result = await showModalBottomSheet<(CarMake, CarModelItem)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (modalContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final normalizedQuery = query.trim().toLowerCase();
            final List<Object> options = pendingMake == null
                ? _makes
                    .where(
                      (item) =>
                          item.name.toLowerCase().contains(normalizedQuery),
                    )
                    .toList(growable: false)
                : models
                    .where(
                      (item) =>
                          item.name.toLowerCase().contains(normalizedQuery),
                    )
                    .toList(growable: false);
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .82,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.color.borderColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          if (pendingMake != null)
                            IconButton(
                              onPressed: () => setModalState(() {
                                pendingMake = null;
                                pendingModel = null;
                                models = const [];
                                query = '';
                                searchController.clear();
                              }),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          Expanded(
                            child: Text(
                              pendingMake == null
                                  ? 'Car Make and Model'
                                  : '${pendingMake!.name} Models',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(modalContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: searchController,
                        onChanged: (value) =>
                            setModalState(() => query = value),
                        decoration: InputDecoration(
                          hintText: pendingMake == null
                              ? 'Search car make'
                              : 'Search car model',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        normalizedQuery.isEmpty
                            ? 'Popular searches'
                            : 'Search results',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: loadingModels
                            ? const Center(child: CircularProgressIndicator())
                            : options.isEmpty
                                ? const Center(child: Text('No results found'))
                                : ListView.separated(
                                    itemCount: options.length,
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: context.color.borderColor,
                                    ),
                                    itemBuilder: (_, index) {
                                      final option = options[index];
                                      final optionName = switch (option) {
                                        CarMake value => value.name,
                                        CarModelItem value => value.name,
                                        _ => '',
                                      };
                                      final selected = option is CarModelItem &&
                                          option == pendingModel;
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(optionName),
                                        trailing: selected
                                            ? Icon(
                                                Icons.check_circle_rounded,
                                                color: context
                                                    .color.territoryColor,
                                              )
                                            : const Icon(
                                                Icons.chevron_right_rounded,
                                              ),
                                        onTap: () async {
                                          if (option is CarMake) {
                                            setModalState(() {
                                              pendingMake = option;
                                              pendingModel = null;
                                              loadingModels = true;
                                              query = '';
                                              searchController.clear();
                                            });
                                            final loaded = await _carsRepository
                                                .fetchCarModels(
                                              option.id,
                                              makeName: option.name,
                                            );
                                            if (!modalContext.mounted) return;
                                            setModalState(() {
                                              models = loaded;
                                              loadingModels = false;
                                            });
                                          } else if (option is CarModelItem) {
                                            setModalState(
                                              () => pendingModel = option,
                                            );
                                          }
                                        },
                                      );
                                    },
                                  ),
                      ),
                      if (pendingMake != null) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: pendingModel == null
                              ? null
                              : () => Navigator.pop(
                                    modalContext,
                                    (pendingMake!, pendingModel!),
                                  ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: context.color.territoryColor,
                          ),
                          child: const Text('Confirm Car'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
    if (result != null && mounted) {
      setState(() {
        _make = result.$1;
        _model = result.$2;
      });
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  Future<void> _submit() async {
    if (!HiveUtils.isUserAuthenticated()) {
      UiUtils.checkUser(onNotGuest: () {}, context: context);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isInspection && _emailController.text.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please add an email address to your profile first',
        type: MessageType.warning,
      );
      return;
    }
    if (!_isInspection &&
        (_make == null || _model == null || _selectedYear == null)) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please select the car make, model and year',
        type: MessageType.warning,
      );
      return;
    }
    final userId = HiveUtils.getUserId();
    if (userId == null) return;
    final payload = _isInspection
        ? <String, dynamic>{
            'user_id': userId,
            'email': _emailController.text.trim(),
            'user_number': _fullPhoneNumber,
            'seller_number': _fullSellerPhoneNumber,
          }
        : <String, dynamic>{
            'user_id': userId,
            'user_name': _nameController.text.trim(),
            'user_number': _fullPhoneNumber,
            if (_emailController.text.trim().isNotEmpty)
              'user_email': _emailController.text.trim(),
            'car_name': _carDisplayName,
            'car_year': _selectedYear,
            'car_make_id': _make!.id,
            'car_model_id': _model!.id,
          };
    await Navigator.pushNamed(
      context,
      Routes.motorsInspectionCheckoutScreen,
      arguments: MotorsServicePaymentDraft(
        type: widget.type,
        servicePayload: payload,
        email: _emailController.text.trim(),
        initialPackage: _selectedPackage,
      ),
    );
  }

  Future<void> _requestCallback() async {
    final name = _nameController.text.trim();
    final phone = _fullPhoneNumber;
    final email = _emailController.text.trim();
    if (name.isEmpty ||
        !Validator.isValidPhoneNumber(
          _phoneController.text,
          _phoneCountryCode,
        )) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please enter your name and phone number',
        type: MessageType.warning,
      );
      return;
    }
    if (email.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please add an email address to your profile first',
        type: MessageType.warning,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await Api.post(
        url: Api.postContactUsApi,
        parameter: {
          'name': name,
          'email': email,
          'subject': '$_title callback',
          'message': 'Please call $name at $phone regarding $_title.',
        },
      );
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(
        context,
        response['message']?.toString() ?? 'Callback request submitted',
        type: MessageType.success,
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          error.toString(),
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _sellerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.secondaryColor,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: context.color.secondaryColor,
        foregroundColor: context.color.textDefaultColor,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _isInspection
                  ? 'Fill out this form and secure your inspection slot.'
                  : _isFinance
                      ? 'Tell us about yourself and the car you want to finance.'
                      : 'Tell us about your car to request its evaluation certificate.',
              style: TextStyle(color: context.color.textLightColor),
            ),
            const SizedBox(height: 20),
            _sectionLabel('Your Details'),
            const SizedBox(height: 14),
            _textField(_nameController, hint: 'Enter your name'),
            const SizedBox(height: 16),
            _phoneField(_phoneController),
            if (_isEvaluation) ...[
              const SizedBox(height: 16),
              _fieldLabel('Your Email'),
              _textField(
                _emailController,
                keyboardType: TextInputType.emailAddress,
                hint: 'Enter your email',
                validator: (value) =>
                    Validator.validateEmail(email: value, context: context),
              ),
            ],
            const SizedBox(height: 16),
            if (_isInspection) ...[
              _fieldLabel('Seller Phone Number'),
              _phoneField(_sellerPhoneController, seller: true),
              const SizedBox(height: 8),
              _agreementField(),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.amber.withValues(alpha: .12)
                      : const Color(0xFFFFF8D9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1 in 5 buyers change their mind after inspection.',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'View Sample Report  →',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              _sectionLabel('Car Details'),
              const SizedBox(height: 14),
              _fieldLabel('Car Make and Model'),
              TextFormField(
                readOnly: true,
                onTap: _showCarPicker,
                validator: (_) =>
                    _make == null || _model == null ? 'Select your car' : null,
                decoration: _inputDecoration(
                  hint: _carDisplayName.isEmpty
                      ? _loadingMakes
                          ? 'Loading car makes...'
                          : 'Select car make and model'
                      : _carDisplayName,
                  suffixIcon: _loadingMakes
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
              if (_isFinance)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: _showCarPicker,
                    icon: const Icon(Icons.link_rounded, size: 17),
                    label: const Text('Autofill with Ad Link'),
                  ),
                ),
              const SizedBox(height: 16),
              _fieldLabel('Year'),
              DropdownButtonFormField<String>(
                initialValue: _selectedYear,
                isExpanded: true,
                validator: _required,
                hint: const Text('Select year'),
                items: _years
                    .map(
                      (year) => DropdownMenuItem(
                        value: year,
                        child: Text(year),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _selectedYear = value),
                decoration: _inputDecoration(),
                borderRadius: BorderRadius.circular(12),
              ),
              _agreementField(),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading || !_canSubmit ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: context.color.territoryColor,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Continue to Payment',
                    ),
            ),
            TextButton(
              onPressed:
                  _loading || !_hasValidContact ? null : _requestCallback,
              child: const Text('Request Call Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String value) => Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      );

  Widget _fieldLabel(String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );

  Widget _phoneField(
    TextEditingController controller, {
    bool seller = false,
  }) {
    final countryCode = seller ? _sellerCountryCode : _phoneCountryCode;
    final countryFlag = seller ? _sellerCountryFlag : _phoneCountryFlag;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => Validator.validatePhoneNumber(
        value: value,
        countryCode: countryCode,
        context: context,
        isRequired: true,
      ),
      decoration: _inputDecoration(
        hint: '50 123 4567',
        prefixIcon: InkWell(
          onTap: () => _showCountryCodePicker(seller: seller),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(countryFlag),
                const SizedBox(width: 6),
                Text(
                  '+$countryCode',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _agreementField() {
    return FormField<bool>(
      initialValue: _agree,
      validator: (value) =>
          value == true ? null : 'Please agree to the terms of service',
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _agree,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I agree to Ebazzor\'s terms of service',
              style: TextStyle(fontSize: 13),
            ),
            onChanged: (value) {
              final checked = value == true;
              setState(() => _agree = checked);
              field.didChange(checked);
            },
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                field.errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller, {
    TextInputType? keyboardType,
    String? hint,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator ?? _required,
      decoration: _inputDecoration(hint: hint, prefixText: prefixText),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    String? prefixText,
    Widget? suffixIcon,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14,
        color: context.color.textLightColor.withValues(alpha: 0.5),
        fontWeight: FontWeight.normal,
      ),
      prefixText: prefixText,
      prefixIcon: prefixIcon,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 48),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: context.color.backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.color.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.color.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: context.color.territoryColor,
          width: 1.4,
        ),
      ),
    );
  }
}
