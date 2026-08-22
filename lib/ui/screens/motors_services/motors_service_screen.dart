import 'dart:async';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/motors_service_models.dart';
import 'package:Ebozor/data/repositories/motors_service_repository.dart';
import 'package:Ebozor/settings.dart';
import 'package:Ebozor/ui/screens/motors_services/data/motors_service_faqs.dart';
import 'package:Ebozor/ui/screens/motors_services/data/motors_finance_faqs.dart';
import 'package:Ebozor/ui/screens/motors_services/data/motors_evaluation_faqs.dart';
import 'package:Ebozor/ui/screens/widgets/car_finance_calculator.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';

class MotorsServiceScreen extends StatefulWidget {
  final MotorsServiceType initialType;

  const MotorsServiceScreen({
    super.key,
    this.initialType = MotorsServiceType.inspection,
  });

  static Route route(RouteSettings settings) {
    final arguments = settings.arguments;
    MotorsServiceType type = MotorsServiceType.inspection;
    if (arguments is MotorsServiceType) {
      type = arguments;
    } else if (arguments is Map && arguments['type'] is MotorsServiceType) {
      type = arguments['type'] as MotorsServiceType;
    }
    return MaterialPageRoute(
      builder: (_) => MotorsServiceScreen(initialType: type),
    );
  }

  @override
  State<MotorsServiceScreen> createState() => _MotorsServiceScreenState();
}

class _MotorsServiceScreenState extends State<MotorsServiceScreen> {
  final MotorsServiceRepository _repository = MotorsServiceRepository();
  late MotorsServiceType _selectedType = widget.initialType;
  late final Future<List<InspectionPackageModel>> _packages =
      _repository.fetchInspectionPackages();
  final TextEditingController _callbackNameController = TextEditingController();
  final TextEditingController _callbackPhoneController =
      TextEditingController();
  InspectionPackageModel? _selectedInspectionPackage;
  bool _submittingCallback = false;
  static const int _bankLoopStart = 7000;
  final PageController _bankPageController = PageController(
    viewportFraction: .34,
    initialPage: _bankLoopStart,
  );
  Timer? _bankTimer;
  int _bankPage = _bankLoopStart;

  static const _reviews = [
    MotorsServiceReview(
      name: 'Faisal Shafeeq',
      title: 'Thanks a lot',
      review:
          'The inspection team was professional, thorough and very helpful. The report explained the car clearly and helped me buy with confidence.',
    ),
    MotorsServiceReview(
      name: 'Mohammed Ali',
      title: 'Very satisfied',
      review:
          'Great inspection experience. The detailed report highlighted the important points and made the final decision much easier.',
    ),
    MotorsServiceReview(
      name: 'Amir F.',
      title: 'Quick and reliable',
      review:
          'Booking was simple, the inspector arrived on time, and the digital report was delivered quickly.',
    ),
    MotorsServiceReview(
      name: 'Sarah K.',
      title: 'Excellent service',
      review:
          'A convenient service with clear communication and a useful report. I would recommend Ebazzor inspection.',
    ),
  ];

  static const _faqs = motorsServiceFaqs;

  @override
  void initState() {
    super.initState();
    final user = HiveUtils.getUserDetails();
    _callbackNameController.text = user.name ?? '';
    _callbackPhoneController.text = user.mobile ?? '';
    _bankTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_bankPageController.hasClients) return;
      _bankPage++;
      _bankPageController.animateToPage(
        _bankPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  String get _title => switch (_selectedType) {
        MotorsServiceType.inspection => 'Car Inspection',
        MotorsServiceType.finance => 'Car Finance',
        MotorsServiceType.evaluation => 'Car Evaluation',
      };

  String get _action => switch (_selectedType) {
        MotorsServiceType.inspection => 'Book Inspection',
        MotorsServiceType.finance => 'Apply for Finance',
        MotorsServiceType.evaluation => 'Evaluate My Car',
      };

  String get _subtitle => switch (_selectedType) {
        MotorsServiceType.inspection =>
          'Book a pre-purchase car inspection anywhere in the UAE.',
        MotorsServiceType.finance =>
          'Estimate your monthly payment and submit a finance request.',
        MotorsServiceType.evaluation =>
          'Request a market evaluation for your car in a few simple steps.',
      };

  void _openForm({InspectionPackageModel? inspectionPackage}) {
    final package = inspectionPackage ??
        (_selectedType == MotorsServiceType.inspection
            ? _selectedInspectionPackage
            : null);
    Navigator.pushNamed(
      context,
      Routes.motorsServiceRequestScreen,
      arguments: {
        'type': _selectedType,
        'package': package,
      },
    );
  }

  Future<void> _submitCallback() async {
    final name = _callbackNameController.text.trim();
    final phone = _callbackPhoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please enter your name and phone number',
        type: MessageType.warning,
      );
      return;
    }
    final email = HiveUtils.getUserDetails().email?.trim() ?? '';
    if (email.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please add an email address to your profile first',
        type: MessageType.warning,
      );
      return;
    }
    setState(() => _submittingCallback = true);
    try {
      final response = await Api.post(
        url: Api.postContactUsApi,
        parameter: {
          'name': name,
          'email': email,
          'subject': 'Motors service callback',
          'message': 'Please call $name at $phone regarding $_title.',
        },
      );
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(
        context,
        response['message']?.toString() ?? 'Callback request submitted',
        type: MessageType.success,
      );
    } catch (error) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          error.toString(),
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submittingCallback = false);
    }
  }

  @override
  void dispose() {
    _callbackNameController.dispose();
    _callbackPhoneController.dispose();
    _bankTimer?.cancel();
    _bankPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.color.secondaryColor,
        foregroundColor: context.color.textDefaultColor,
        elevation: 0,
        title: Text(_title),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          color: context.color.secondaryColor,
          child: FilledButton(
            onPressed: _openForm,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(_action),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _serviceTabs()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _hero(),
                const SizedBox(height: 28),
                if (_selectedType == MotorsServiceType.inspection) ...[
                  _sectionTitle('Why you need an inspection'),
                  const SizedBox(height: 14),
                  _benefits(),
                  const SizedBox(height: 28),
                  _sectionTitle('How Ebazzor Car Inspection Works'),
                  const SizedBox(height: 14),
                  _steps(),
                  const SizedBox(height: 28),
                  _sectionTitle('Why choose Ebazzor Car Inspection'),
                  const SizedBox(height: 14),
                  _trustMetrics(),
                  const SizedBox(height: 28),
                  _sectionTitle('Inspection Packages for Your Needs'),
                  const SizedBox(height: 14),
                  _packageList(),
                  const SizedBox(height: 30),
                  _sectionTitle('What our Customers Say'),
                  const SizedBox(height: 14),
                  _reviewsList(),
                  const SizedBox(height: 28),
                  _contactCard(),
                  const SizedBox(height: 28),
                  _sectionTitle('Frequently Asked Questions'),
                  const SizedBox(height: 6),
                  Text(
                    'Find quick answers to common questions about our service, process and support.',
                    style: TextStyle(color: context.color.textLightColor),
                  ),
                  const SizedBox(height: 10),
                  _faqList(_faqs),
                ] else if (_selectedType == MotorsServiceType.finance) ...[
                  ..._financeContent(),
                ] else ...[
                  ..._evaluationContent(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceTabs() {
    return Container(
      color: context.color.secondaryColor,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: MotorsServiceType.values.map((type) {
          final selected = type == _selectedType;
          final label = switch (type) {
            MotorsServiceType.inspection => 'Inspection',
            MotorsServiceType.finance => 'Finance',
            MotorsServiceType.evaluation => 'Evaluation',
          };
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: OutlinedButton(
                onPressed: () => setState(() => _selectedType = type),
                style: OutlinedButton.styleFrom(
                  backgroundColor: selected
                      ? context.color.territoryColor.withValues(alpha: .12)
                      : Colors.transparent,
                  foregroundColor: context.color.textDefaultColor,
                  side: BorderSide(
                    color: selected
                        ? Colors.red.shade200
                        : context.color.borderColor,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(label, style: const TextStyle(fontSize: 12)),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _hero() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = switch (_selectedType) {
      MotorsServiceType.inspection =>
        '_next/static/media/carbanner.bea38160.png',
      MotorsServiceType.finance =>
        '_next/static/media/carfinancebanner.4e521e93.png',
      MotorsServiceType.evaluation =>
        '_next/static/media/carevaluation.feda5d85.png',
    };
    final background = isDark
        ? context.color.secondaryColor
        : switch (_selectedType) {
            MotorsServiceType.inspection => const Color(0xFFFFF6F7),
            MotorsServiceType.finance => const Color(0xFFF2FAFF),
            MotorsServiceType.evaluation => const Color(0xFFFFFBF0),
          };
    return Container(
      constraints: const BoxConstraints(minHeight: 235),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ebazzor',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            _title,
            style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(_subtitle, style: const TextStyle(height: 1.35)),
          if (_selectedType == MotorsServiceType.inspection)
            const Text(
              'Packages start from AED 369.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: _remoteImage(
              asset,
              Icons.directions_car_filled_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefits() {
    const items = [
      (
        'Avoid Surprises',
        'Save thousands on costly repairs',
        'dollar.19a1e613.png',
        Icons.savings_outlined
      ),
      (
        'Hidden Issues',
        '70% of cars have hidden defects',
        'speed.be945e0b.png',
        Icons.speed_rounded
      ),
      (
        'Trusted Reports',
        '120 or 240-point detailed report',
        'report.0961b2fa.png',
        Icons.description_outlined
      ),
      (
        'Convenient',
        'Quick inspection anywhere, anytime',
        'clock.a8dc819f.png',
        Icons.schedule_rounded
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.15,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return _infoCard(
          item.$1,
          item.$2,
          '_next/static/media/${item.$3}',
          item.$4,
        );
      },
    );
  }

  Widget _steps() {
    const steps = [
      (
        'Book Car Inspection',
        'Sign up and pay online. We handle the rest.',
        Icons.calendar_month_outlined
      ),
      (
        'Car Gets Inspected',
        'Our certified mechanics inspect your car.',
        Icons.car_repair_outlined
      ),
      (
        'Receive Your Report',
        'Your report is sent instantly to your email.',
        Icons.menu_book_outlined
      ),
    ];
    return Column(
      children: List.generate(
        steps.length,
        (index) => ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 5),
          leading: CircleAvatar(
            backgroundColor:
                context.color.territoryColor.withValues(alpha: .12),
            child: Icon(
              steps[index].$3,
              color: context.color.territoryColor,
            ),
          ),
          title: Text(
            steps[index].$1,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(steps[index].$2),
          trailing: CircleAvatar(
            radius: 12,
            backgroundColor:
                context.color.territoryColor.withValues(alpha: .12),
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trustMetrics() {
    const items = [
      ('100,000+', 'Car Inspections', 'car.214ca2a5.png', Icons.directions_car),
      ('Instant', 'Online Reports', 'report.0961b2fa.png', Icons.description),
      (
        'Certified Mechanics',
        '20+ Years Experience',
        'certified.f0b2feb0.png',
        Icons.verified
      ),
      ('4.7/5 Average', 'Customer Rating', 'rating.c470cf32.png', Icons.star),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, index) => _infoCard(
        items[index].$1,
        items[index].$2,
        '_next/static/media/${items[index].$3}',
        items[index].$4,
      ),
    );
  }

  Widget _packageList() {
    return FutureBuilder<List<InspectionPackageModel>>(
      future: _packages,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final packages =
            snapshot.data ?? MotorsServiceRepository.fallbackPackages;
        return Column(
          children: packages
              .map((inspectionPackage) => _packageCard(inspectionPackage))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _packageCard(InspectionPackageModel inspectionPackage) {
    final selected =
        _selectedInspectionPackage?.id != null && inspectionPackage.id != null
            ? _selectedInspectionPackage!.id == inspectionPackage.id
            : _selectedInspectionPackage?.name == inspectionPackage.name &&
                _selectedInspectionPackage?.price == inspectionPackage.price;
    final installment = inspectionPackage.price * 1.05 / 4;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: selected
            ? context.color.territoryColor.withValues(alpha: .1)
            : context.color.secondaryColor,
        elevation: selected ? 4 : 1,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _selectedInspectionPackage = inspectionPackage);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.red : context.color.borderColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AED ${inspectionPackage.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            '(exclusive of 5% tax)',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        key: ValueKey(selected),
                        color: selected
                            ? Colors.red
                            : context.color.textLightColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Pay in 4 payments of AED ${installment.toStringAsFixed(2)} with',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    SizedBox(
                      width: 48,
                      height: 19,
                      child: UiUtils.getSvgImage(
                        _staticAssetUrl(
                          '_next/static/media/tabby.239b310d.svg',
                        ),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  inspectionPackage.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (inspectionPackage.points.isNotEmpty)
                  Text(inspectionPackage.points),
                const Divider(height: 24),
                ...inspectionPackage.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(feature)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(
                        () => _selectedInspectionPackage = inspectionPackage,
                      );
                    },
                    icon: Icon(
                      selected ? Icons.check_rounded : Icons.touch_app_outlined,
                    ),
                    label: Text(selected ? 'Selected' : 'Select Package'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewsList() {
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 4),
        itemCount: _reviews.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final review = _reviews[index];
          return Container(
            width: MediaQuery.sizeOf(context).width * .82,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.color.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor:
                          context.color.territoryColor.withValues(alpha: .12),
                      child: Text(
                        review.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            review.title,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.format_quote_rounded,
                      color: Color(0xFFFFC1CB),
                      size: 32,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: List.generate(
                    5,
                    (_) => const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    review.review,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _contactCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? context.color.secondaryColor
            : const Color(0xFFEEF5FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Have Questions?\nWe’ve got answers!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Request a call back or reach out to the Ebazzor team.'),
          const SizedBox(height: 14),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.phone_outlined),
            title: Text('04 446 6830'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.email_outlined),
            title: Text('support@ebozor.com'),
          ),
          TextField(
            controller: _callbackNameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Your name',
              prefixIcon: Icon(Icons.person_outline_rounded),
              filled: true,
              fillColor: context.color.backgroundColor,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _callbackPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
              filled: true,
              fillColor: context.color.backgroundColor,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submittingCallback ? null : _submitCallback,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor: context.color.territoryColor,
            ),
            child: _submittingCallback
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Call Me Back'),
          ),
        ],
      ),
    );
  }

  Widget _faqList(List<MotorsServiceFaq> faqs) {
    return Column(
      children: faqs
          .map(
            (faq) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .035),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 15),
                  childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
                  title: Text(
                    faq.question,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: faq.answer.isEmpty
                      ? const <Widget>[]
                      : [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              faq.answer,
                              style: const TextStyle(height: 1.45),
                            ),
                          ),
                        ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  List<Widget> _financeContent() {
    return [
      Center(
        child: Column(
          children: [
            _sectionTitle('Trusted by the UAE’s Leading Banks'),
            const SizedBox(height: 6),
            Text(
              'We work directly with leading banks to provide quick and trusted service.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.color.textLightColor),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _bankCarousel(),
      const SizedBox(height: 28),
      const CarFinanceCalculator(
        initialPrice: 15000,
        carName: 'Car Finance',
        showApplyButton: false,
      ),
      const SizedBox(height: 28),
      _sectionTitle('How Ebazzor Car Finance Works'),
      const SizedBox(height: 6),
      Text(
        'Get your car finance in five simple steps.',
        style: TextStyle(color: context.color.textLightColor),
      ),
      const SizedBox(height: 14),
      _processCards(const [
        (
          'Submit a Request for Free',
          'Share your details and our team will contact you to start the process.',
          Icons.description_outlined
        ),
        (
          'Choose the Best Finance Option',
          'Compare finance options offered by leading banks.',
          Icons.account_balance_outlined
        ),
        (
          'Get Fast Approval',
          'Receive assistance through the bank approval process.',
          Icons.verified_outlined
        ),
        (
          'Submit Details and Documents',
          'Provide the required vehicle and customer information.',
          Icons.upload_file_outlined
        ),
        (
          'Drive Away in Your New Car',
          'Complete the process and enjoy your car.',
          Icons.directions_car_outlined
        ),
      ]),
      const SizedBox(height: 28),
      _contactCard(),
      const SizedBox(height: 28),
      _sectionTitle('Frequently Asked Questions'),
      const SizedBox(height: 6),
      Text(
        'Find quick answers to common questions about car finance.',
        style: TextStyle(color: context.color.textLightColor),
      ),
      const SizedBox(height: 10),
      _faqList(motorsFinanceFaqs),
    ];
  }

  List<Widget> _evaluationContent() {
    return [
      Center(
        child: Column(
          children: [
            _sectionTitle('Why You Need a Car Evaluation Certificate'),
            const SizedBox(height: 8),
            Text(
              'Banks require an official car evaluation certificate to approve your loan. Ebazzor’s certificate is recognized by leading UAE banks, helping make the financing process smooth and quick.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.color.textLightColor,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ACCEPTED AT LEADING UAE BANKS',
              style: TextStyle(
                color: context.color.textLightColor,
                fontSize: 11,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(width: 115, child: _bankAsset(0)),
                  SizedBox(width: 115, child: _bankAsset(1)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 30),
      _sectionTitle('How the Ebazzor Evaluation Works'),
      const SizedBox(height: 6),
      Text(
        'Get your evaluation certificate in three simple steps.',
        style: TextStyle(color: context.color.textLightColor),
      ),
      const SizedBox(height: 14),
      _processCards(const [
        (
          'Submit Your Request',
          'Complete the form and confirm your appointment.',
          Icons.description_outlined
        ),
        (
          'Ebazzor Checks the Car',
          'Our expert team checks the vehicle and prepares its evaluation.',
          Icons.fact_check_outlined
        ),
        (
          'Receive Your Evaluation Certificate',
          'Get the completed certificate for use with leading banks.',
          Icons.workspace_premium_outlined
        ),
      ]),
      const SizedBox(height: 28),
      _contactCard(),
      const SizedBox(height: 28),
      _sectionTitle('Frequently Asked Questions'),
      const SizedBox(height: 6),
      Text(
        'Find quick answers to common questions about car evaluation.',
        style: TextStyle(color: context.color.textLightColor),
      ),
      const SizedBox(height: 10),
      _faqList(motorsEvaluationFaqs),
    ];
  }

  Widget _bankCarousel() {
    return SizedBox(
      height: 72,
      child: PageView.builder(
        controller: _bankPageController,
        padEnds: false,
        onPageChanged: (page) => _bankPage = page,
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.color.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _bankAsset(index % 7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bankAsset(int index) {
    const paths = [
      '1.3dd12541.svg',
      '2.ecbbcd81.png',
      '3.9f1abe17.svg',
      '4.55230058.png',
      '5.0c02f95e.svg',
      '6.d73076b1.svg',
      '7.57e65ace.svg',
    ];
    final url = _staticAssetUrl('_next/static/media/${paths[index]}');
    if (paths[index].endsWith('.svg')) {
      return UiUtils.getSvgImage(
        url,
        fit: BoxFit.contain,
      );
    }
    return UiUtils.getImage(
      url,
      fit: BoxFit.contain,
    );
  }

  Widget _processCards(
    List<(String, String, IconData)> steps,
  ) {
    return Column(
      children: List.generate(
        steps.length,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.color.borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor:
                        context.color.territoryColor.withValues(alpha: .12),
                    child: Icon(
                      steps[index].$3,
                      color: context.color.territoryColor,
                    ),
                  ),
                  Positioned(
                    right: -5,
                    top: -7,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor:
                          context.color.territoryColor.withValues(alpha: .12),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[index].$1,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index].$2,
                      style: TextStyle(
                        color: context.color.textLightColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(
    String title,
    String subtitle,
    String assetPath,
    IconData fallback,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.color.borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 42, child: _remoteImage(assetPath, fallback)),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: context.color.textLightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _remoteImage(String path, IconData _fallback) {
    return UiUtils.getImage(
      _staticAssetUrl(path),
      fit: BoxFit.contain,
    );
  }

  String _staticAssetUrl(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return '${AppSettings.hostUrl}:8003/$normalized';
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
    );
  }
}
