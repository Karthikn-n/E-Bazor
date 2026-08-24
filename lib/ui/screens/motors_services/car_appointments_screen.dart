import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:Ebozor/data/model/motors_service_models.dart';
import 'package:Ebozor/data/repositories/motors_service_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class CarAppointmentsScreen extends StatefulWidget {
  const CarAppointmentsScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(
      builder: (_) => const CarAppointmentsScreen(),
    );
  }

  @override
  State<CarAppointmentsScreen> createState() => _CarAppointmentsScreenState();
}

class _CarAppointmentsScreenState extends State<CarAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final MotorsServiceRepository _repository = MotorsServiceRepository();

  String _filter = 'latest_first';
  bool _isLoading = true;
  String? _error;
  List<CarAppointmentModel> _allAppointments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    final userId = HiveUtils.getUserId();
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _allAppointments = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appointments = await _repository.fetchCarAppointments(
        userId,
        filter: _filter,
      );
      if (mounted) {
        setState(() {
          _allAppointments = appointments;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<CarAppointmentModel> get _upcomingAppointments {
    return _allAppointments.where((item) => !item.isPast).toList();
  }

  List<CarAppointmentModel> get _pastAppointments {
    return _allAppointments.where((item) => item.isPast).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            "Car Appointments",
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
                Icons.filter_list_rounded,
                color: context.color.textDefaultColor,
              ),
              initialValue: _filter,
              onSelected: (value) {
                _filter = value;
                _loadAppointments();
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFDC2626), // App Brand Red
                indicatorWeight: 2.5,
                labelColor: const Color(0xFFDC2626),
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelColor: context.color.textLightColor,
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: "Upcoming"),
                  Tab(text: "Past"),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorView()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAppointmentsTab(
                        appointments: _upcomingAppointments,
                        isUpcoming: true,
                      ),
                      _buildAppointmentsTab(
                        appointments: _pastAppointments,
                        isUpcoming: false,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildAppointmentsTab({
    required List<CarAppointmentModel> appointments,
    required bool isUpcoming,
  }) {
    if (appointments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAppointments,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyState(
              subtitle: isUpcoming
                  ? "You do not have any upcoming car appointments"
                  : "You do not have any past car appointments",
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: appointments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final item = appointments[index];
          return _buildAppointmentCard(item);
        },
      ),
    );
  }

  Widget _buildEmptyState({required String subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Soft Circular Calendar Illustration matching user mockup
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _buildCalendarIllustration(),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "No Appointments",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: context.color.textLightColor,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarIllustration() {
    return Container(
      width: 86,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Header Pink Strip
          Container(
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFFFCA5A5), // Soft Pink
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Binder Rings
                Positioned(
                  top: -5,
                  left: 18,
                  child: Container(
                    width: 6,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  top: -5,
                  right: 18,
                  child: Container(
                    width: 6,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Grid Dots/Lines
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                      5,
                      (_) => Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                      5,
                      (_) => Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
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
    );
  }

  Widget _buildAppointmentCard(CarAppointmentModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(item.status);

    return Container(
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Service Type Badge & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.serviceType,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.color.territoryColor,
                  ),
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
                  item.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Car Title
          Text(
            item.carTitle,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
          const SizedBox(height: 8),

          // Date & Time
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: context.color.textLightColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatDate(item.appointmentDate, item.appointmentTime),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: context.color.textLightColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          if (item.location != null && item.location!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: context.color.textLightColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.location!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.color.textLightColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          if (item.appointmentNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Ref: ${item.appointmentNumber}",
                  style: TextStyle(
                    fontSize: 12,
                    color: context.color.textLightColor,
                  ),
                ),
                if (item.amount != null && item.amount! > 0)
                  Text(
                    "AED ${item.amount!.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String rawDate, String? time) {
    if (rawDate.isEmpty) return "Date to be scheduled";
    try {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        final formattedDate = DateFormat('dd MMM yyyy').format(parsed);
        if (time != null && time.isNotEmpty) {
          return "$formattedDate, $time";
        }
        final formattedTime = DateFormat('hh:mm a').format(parsed);
        return "$formattedDate, $formattedTime";
      }
    } catch (_) {}
    return rawDate;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'completed':
      case 'approved':
      case 'success':
        return Colors.green;
      case 'in_progress':
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
      case 'expired':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              "Could not load appointments",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAppointments,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.territoryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}
