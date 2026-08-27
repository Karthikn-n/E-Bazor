import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:Ebozor/data/model/motors_service_models.dart';
import 'package:Ebozor/data/repositories/motors_service_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:shimmer/shimmer.dart';

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

  String _sortOrder = 'latest'; // local sort
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
        filter: 'latest_first',
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

  List<CarAppointmentModel> _applyLocalSort(List<CarAppointmentModel> list) {
    final sorted = List<CarAppointmentModel>.from(list);
    switch (_sortOrder) {
      case 'latest':
        sorted.sort((a, b) {
          final da = DateTime.tryParse(a.createdAt ?? a.appointmentDate) ??
              DateTime(1970);
          final db = DateTime.tryParse(b.createdAt ?? b.appointmentDate) ??
              DateTime(1970);
          return db.compareTo(da);
        });
        break;
      case 'oldest':
        sorted.sort((a, b) {
          final da = DateTime.tryParse(a.createdAt ?? a.appointmentDate) ??
              DateTime(1970);
          final db = DateTime.tryParse(b.createdAt ?? b.appointmentDate) ??
              DateTime(1970);
          return da.compareTo(db);
        });
        break;
      case 'date_asc':
        sorted.sort((a, b) {
          final da =
              DateTime.tryParse(a.appointmentDate) ?? DateTime(1970);
          final db =
              DateTime.tryParse(b.appointmentDate) ?? DateTime(1970);
          return da.compareTo(db);
        });
        break;
      case 'date_desc':
        sorted.sort((a, b) {
          final da =
              DateTime.tryParse(a.appointmentDate) ?? DateTime(1970);
          final db =
              DateTime.tryParse(b.appointmentDate) ?? DateTime(1970);
          return db.compareTo(da);
        });
        break;
      case 'price_high':
        sorted.sort((a, b) => (b.amount ?? 0).compareTo(a.amount ?? 0));
        break;
      case 'price_low':
        sorted.sort((a, b) => (a.amount ?? 0).compareTo(b.amount ?? 0));
        break;
    }
    return sorted;
  }

  List<CarAppointmentModel> get _upcomingAppointments {
    final list = _allAppointments.where((item) => !item.isPast).toList();
    return _applyLocalSort(list);
  }

  List<CarAppointmentModel> get _pastAppointments {
    final list = _allAppointments.where((item) => item.isPast).toList();
    return _applyLocalSort(list);
  }

  String _getSortLabel(String key) {
    switch (key) {
      case 'latest':
        return 'Latest First';
      case 'oldest':
        return 'Oldest First';
      case 'date_asc':
        return 'Date: Earliest';
      case 'date_desc':
        return 'Date: Latest';
      case 'price_high':
        return 'Price: High to Low';
      case 'price_low':
        return 'Price: Low to High';
      default:
        return 'Sort';
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: SafeArea(
            top: false,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "Sort Appointments",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSortOption(ctx, 'latest', 'Latest Added First'),
                _buildSortOption(ctx, 'oldest', 'Oldest Added First'),
                _buildSortOption(ctx, 'date_asc', 'Appointment Date (Earliest First)'),
                _buildSortOption(ctx, 'date_desc', 'Appointment Date (Latest First)'),
                _buildSortOption(ctx, 'price_high', 'Price: High to Low'),
                _buildSortOption(ctx, 'price_low', 'Price: Low to High'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(BuildContext ctx, String value, String label) {
    final isSelected = _sortOrder == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _sortOrder = value;
        });
        Navigator.pop(ctx);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? context.color.territoryColor
                  : context.color.textLightColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? context.color.territoryColor
                      : context.color.textDefaultColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                indicatorColor: context.color.territoryColor,
                indicatorWeight: 2.5,
                labelColor: context.color.territoryColor,
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _buildSortFab(),
        body: _isLoading
            ? _buildShimmerLoading()
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

  Widget? _buildSortFab() {
    if (_isLoading || _error != null || _allAppointments.isEmpty) return null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(30),
        color: context.color.territoryColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _showSortBottomSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded, color: Colors.white, size: 19),
                const SizedBox(width: 8),
                Text(
                  "Sort: ${_getSortLabel(_sortOrder)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
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
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: appointments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = appointments[index];
          return _buildAppointmentTile(item);
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
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 64,
                  color: context.color.territoryColor.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 24),
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
                fontSize: 13.5,
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

  Widget _buildAppointmentTile(CarAppointmentModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(item.status);
    final hasImage = item.carImage != null && item.carImage!.trim().isNotEmpty;
    final phone = item.phoneNo ?? item.userPhone;
    final inspectionId = item.inspectionId;

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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Car Icon/Image + Car Title & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail / Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 52,
                  color: context.color.territoryColor.withValues(alpha: 0.08),
                  child: hasImage
                      ? UiUtils.getImage(
                          item.carImage!.trim(),
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Icon(
                            Icons.directions_car_rounded,
                            size: 28,
                            color: context.color.territoryColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Car Title & Service Type / Ref
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.carTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      inspectionId != null
                          ? "Inspection #$inspectionId • ${item.serviceType}"
                          : (item.appointmentNumber.isNotEmpty
                              ? item.appointmentNumber
                              : item.serviceType),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.color.textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status.toUpperCase(),
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

          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),

          // Detail 1: Date & Time
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: context.color.textLightColor,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _formatDate(item.appointmentDate, item.appointmentTime),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.color.textDefaultColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          // Detail 2: Location
          if (item.location != null && item.location!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: context.color.textLightColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.location!.trim(),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.color.textLightColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Detail 3: User name / Phone
          if ((item.userName != null && item.userName!.trim().isNotEmpty) ||
              (phone != null && phone.trim().isNotEmpty)) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 15,
                  color: context.color.textLightColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      if (item.userName != null && item.userName!.trim().isNotEmpty)
                        item.userName!.trim(),
                      if (phone != null && phone.trim().isNotEmpty)
                        phone.trim(),
                    ].join(" • "),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.color.textLightColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Bottom Bar: Price & Payment Status
          if (item.amount != null && item.amount! > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.paymentStatus != null &&
                    item.paymentStatus!.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: item.paymentStatus!.toLowerCase() == 'success'
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.paymentStatus!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: item.paymentStatus!.toLowerCase() == 'success'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  "AED ${item.amount!.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.color.territoryColor,
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
