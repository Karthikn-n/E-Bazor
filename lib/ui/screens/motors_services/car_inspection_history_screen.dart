import 'package:Ebozor/data/model/motors_service_models.dart';
import 'package:Ebozor/data/repositories/motors_service_repository.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CarInspectionHistoryScreen extends StatefulWidget {
  const CarInspectionHistoryScreen({super.key});

  static Route route(RouteSettings settings) {
    return MaterialPageRoute(
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
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
        title: const Text('Car Inspections'),
        backgroundColor: context.color.secondaryColor,
        foregroundColor: context.color.textDefaultColor,
        actions: [
          PopupMenuButton<String>(
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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _message(
                  Icons.error_outline,
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
                        padding: const EdgeInsets.all(16),
                        itemCount: _records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) => _recordCard(_records[index]),
                      ),
                    ),
    );
  }

  Widget _recordCard(CarInspectionRecord record) {
    final statusColor = _statusColor(record.status);
    return Card(
      color: context.color.secondaryColor,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.color.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: context.color.territoryColor.withValues(
                    alpha: .12,
                  ),
                  child: Icon(
                    Icons.car_repair_outlined,
                    color: context.color.territoryColor,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        record.packageName,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.color.textLightColor,
                        ),
                      ),
                      if (record.appointmentDate.isNotEmpty)
                        Text(
                          _formatDate(record.appointmentDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.color.textLightColor,
                          ),
                        ),
                    ],
                  ),
                ),
                Chip(
                  side: BorderSide.none,
                  backgroundColor: statusColor.withValues(alpha: .12),
                  label: Text(
                    record.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (record.price != null)
              _detailRow(
                Icons.payments_outlined,
                'Inspection price',
                'AED ${record.price!.toStringAsFixed(0)}',
              ),
            if (record.userNumber.isNotEmpty)
              _detailRow(
                Icons.person_outline_rounded,
                'Customer number',
                record.userNumber,
              ),
            if (record.sellerNumber.isNotEmpty)
              _detailRow(
                Icons.phone_outlined,
                'Seller number',
                record.sellerNumber,
              ),
            if (record.email.isNotEmpty)
              _detailRow(Icons.email_outlined, 'Email', record.email),
            if (record.paymentType.isNotEmpty ||
                record.paymentStatus.isNotEmpty)
              _detailRow(
                Icons.credit_card_outlined,
                'Payment',
                [
                  record.paymentType,
                  record.paymentStatus,
                ].where((value) => value.isNotEmpty).join(' • '),
              ),
            if (record.hasInspectionReport) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _openReport(record.inspectionReport),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: context.color.territoryColor,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('View Inspection Report'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.color.textLightColor),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.color.textLightColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
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
            Text(text, textAlign: TextAlign.center),
            if (action) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
