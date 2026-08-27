import 'package:Ebozor/data/model/motors_service_models.dart';
import 'package:Ebozor/data/repositories/motors_service_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class CarInspectionHistoryScreen extends StatefulWidget {
  const CarInspectionHistoryScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(
      builder: (_) => const CarInspectionHistoryScreen(),
    );
  }

  @override
  State<CarInspectionHistoryScreen> createState() =>
      _CarInspectionHistoryScreenState();
}

class _CarInspectionHistoryScreenState
    extends State<CarInspectionHistoryScreen> {
  final _repository = MotorsServiceRepository();
  String _filter = 'latest_first';
  bool _loading = true;
  String? _error;
  List<CarInspectionRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = HiveUtils.getUserId();
    if (userId == null) {
      setState(() {
        _loading = false;
        _records = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchInspections(
        userId,
        filter: _filter,
      );
      if (mounted) setState(() => _records = records);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
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
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            'Car Inspections',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.color.textDefaultColor,
            ),
          ),
          centerTitle: true,
          actions: [
            PopupMenuButton<String>(
              icon: Icon(
                Icons.sort_rounded,
                color: context.color.textDefaultColor,
              ),
              initialValue: _filter,
              onSelected: (value) {
                _filter = value;
                _load();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'latest_first',
                  child: Text('Latest first'),
                ),
                PopupMenuItem(
                  value: 'oldest_first',
                  child: Text('Oldest first'),
                ),
              ],
            ),
          ],
        ),
        body: _loading
            ? _buildShimmerLoading()
            : _error != null
                ? _message(
                    Icons.error_outline_rounded,
                    'Could not load car inspections',
                    action: true,
                  )
                : _records.isEmpty
                    ? _message(
                        Icons.car_repair_outlined,
                        'No car inspections found',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          itemCount: _records.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) =>
                              _buildInspectionTile(_records[index]),
                        ),
                      ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, _) => Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.shimmerBaseColor,
        highlightColor: Theme.of(context).colorScheme.shimmerHighlightColor,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildInspectionTile(CarInspectionRecord record) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(record.status);

    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.car_repair_rounded,
                    color: context.color.territoryColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.id == null
                          ? 'Car Inspection'
                          : 'Inspection #${record.id}',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.packageName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: context.color.textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  record.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          if (record.appointmentDate.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: context.color.textLightColor,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(record.appointmentDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.color.textLightColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),

          // Details grid / list
          if (record.userNumber.isNotEmpty)
            _detailRow(
              Icons.person_outline_rounded,
              'Customer Mobile',
              record.userNumber,
            ),
          if (record.sellerNumber.isNotEmpty)
            _detailRow(
              Icons.phone_outlined,
              'Seller Mobile',
              record.sellerNumber,
            ),
          if (record.email.isNotEmpty)
            _detailRow(
              Icons.email_outlined,
              'Email Address',
              record.email,
            ),
          if (record.paymentType.isNotEmpty || record.paymentStatus.isNotEmpty)
            _detailRow(
              Icons.credit_card_outlined,
              'Payment Details',
              [
                record.paymentType,
                record.paymentStatus,
              ].where((value) => value.isNotEmpty).join(' • '),
            ),

          // Price & Action Footer
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (record.price != null && record.price! > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.color.textLightColor,
                      ),
                    ),
                    Text(
                      'AED ${record.price!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.color.territoryColor,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
              if (record.hasInspectionReport)
                ElevatedButton.icon(
                  onPressed: () => _openReport(record.inspectionReport),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.color.territoryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.description_outlined,
                    size: 16,
                  ),
                  label: const Text(
                    'Report',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: context.color.textLightColor),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 12,
              color: context.color.textLightColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.color.textDefaultColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status.trim().toLowerCase()) {
      'success' || 'completed' || 'approved' => Colors.green,
      'failed' || 'cancelled' || 'rejected' => Colors.red,
      _ => Colors.orange,
    };
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());
  }

  Future<void> _openReport(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open inspection report')),
      );
    }
  }

  Widget _message(IconData icon, String text, {bool action = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: context.color.textLightColor),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.color.textDefaultColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (action) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
