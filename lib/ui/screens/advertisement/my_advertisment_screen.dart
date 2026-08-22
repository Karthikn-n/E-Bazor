import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/delete_advertisment_cubit.dart';
import 'package:Ebozor/data/cubits/item/fetch_my_promoted_items_cubit.dart';
import 'package:Ebozor/data/cubits/utility/item_edit_global.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/advertisement_repository.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/cloudState/cloud_state.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/string_extenstion.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MyAdvertisementScreen extends StatefulWidget {
  final bool fromProfile;
  static VoidCallback? refreshCallback;

  const MyAdvertisementScreen({super.key, this.fromProfile = false});

  static Route route(RouteSettings settings) {
    Map<String, dynamic>? arguments =
        settings.arguments as Map<String, dynamic>?;
    return BlurredRouter(
      builder: (context) {
        return BlocProvider(
          create: (context) => FetchMyPromotedItemsCubit(),
          child: MyAdvertisementScreen(
            fromProfile: arguments?['fromProfile'] ?? false,
          ),
        );
      },
    );
  }

  @override
  CloudState<MyAdvertisementScreen> createState() =>
      _MyAdvertisementScreenState();
}

class _MyAdvertisementScreenState extends CloudState<MyAdvertisementScreen> {
  final ScrollController _pageScrollController = ScrollController();
  int _selectedTab = 0;

  Map<String, int> _itemsCount = {
    "all_ads": 0,
    "live": 0,
    "payment_pending": 0,
    "under_review": 0,
    "drafts": 0,
    "rejected": 0,
    "expired": 0,
  };

  bool _isSelectionMode = false;
  final Set<int> _selectedItemIds = {};
  bool _isDeleting = false;

  final List<Map<String, String>> _tabs = [
    {"label": "All Ads", "key": "all_ads", "status": ""},
    {"label": "Live", "key": "live", "status": "approved"},
    {"label": "Payment Pending", "key": "payment_pending", "status": "inactive"},
    {"label": "Under Review", "key": "under_review", "status": "review"},
    {"label": "Drafts", "key": "drafts", "status": "drafts"},
    {"label": "Rejected", "key": "rejected", "status": "rejected"},
    {"label": "Expired", "key": "expired", "status": "expired"},
  ];

  @override
  void initState() {
    MyAdvertisementScreen.refreshCallback = () {
      if (mounted) {
        _loadData();
      }
    };
    AdHelper.loadInterstitialAd();
    _loadData();
    _pageScrollController.addListener(_pageScroll);
    super.initState();
  }

  void _loadData() {
    _fetchCounts();
    final status = _tabs[_selectedTab]["status"];
    context.read<FetchMyPromotedItemsCubit>().fetchMyPromotedItems(status: status);
  }

  Future<void> _fetchCounts() async {
    try {
      final counts = await ItemRepository().fetchMyItemsCount();
      if (mounted && counts.isNotEmpty) {
        setState(() {
          _itemsCount = counts;
        });
      }
    } catch (_) {}
  }

  void _pageScroll() {
    if (_pageScrollController.isEndReached()) {
      if (context.read<FetchMyPromotedItemsCubit>().hasMoreData()) {
        final status = _tabs[_selectedTab]["status"];
        context
            .read<FetchMyPromotedItemsCubit>()
            .fetchMyPromotedItemsMore(status: status);
      }
    }
  }

  @override
  void dispose() {
     MyAdvertisementScreen.refreshCallback = null;
    _pageScrollController.dispose();
    super.dispose();
  }

  void _openCategoryPickerModal(BuildContext context) {
    Navigator.pushNamed(context, Routes.selectCategoryScreen);
  }

  void _onTabSelected(int index) {
    if (_selectedTab == index) return;
    if (_isSelectionMode) _exitSelectionMode();
    setState(() {
      _selectedTab = index;
    });
    final status = _tabs[index]["status"];
    context.read<FetchMyPromotedItemsCubit>().fetchMyPromotedItems(status: status);
    _fetchCounts();
  }

  void _enterSelectionMode(int itemId) {
    setState(() {
      _isSelectionMode = true;
      _selectedItemIds.add(itemId);
    });
  }

  void _toggleSelection(int itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
        if (_selectedItemIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedItemIds.clear();
    });
  }

  void _toggleSelectAll(List<ItemModel> items) {
    setState(() {
      final validIds = items.where((e) => e.id != null).map((e) => e.id!).toSet();
      if (_selectedItemIds.containsAll(validIds)) {
        _selectedItemIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedItemIds.addAll(validIds);
      }
    });
  }

  void _confirmDeleteSelectedAds(BuildContext context) {
    if (_selectedItemIds.isEmpty) return;
    final count = _selectedItemIds.length;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.color.secondaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              "Delete $count ${count > 1 ? 'Ads' : 'Ad'}",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete $count selected ${count > 1 ? 'ads' : 'ad'}? This action cannot be undone.",
          style: TextStyle(
            fontSize: 13.5,
            color: context.color.textDefaultColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "Cancel",
              style: TextStyle(color: context.color.textLightColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _deleteSelectedAds();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              "Delete ($count)",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedAds() async {
    setState(() => _isDeleting = true);
    final idsToDelete = _selectedItemIds.toList();
    try {
      await Future.wait(
        idsToDelete.map((id) => Api.post(
          url: Api.deleteItemApi,
          parameter: {"id": id},
        )),
      );
      for (var id in idsToDelete) {
        context.read<FetchMyPromotedItemsCubit>().delete(id);
      }
      _fetchCounts();
      HelperUtils.showSnackBarMessage(
        context,
        "${idsToDelete.length} ${idsToDelete.length > 1 ? 'ads' : 'ad'} deleted successfully",
        type: MessageType.success,
      );
      _exitSelectionMode();
    } catch (e) {
      HelperUtils.showSnackBarMessage(
        context,
        "Failed to delete ads: $e",
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _deleteAd(ItemModel item) async {
    try {
      await Api.post(
        url: Api.deleteItemApi,
        parameter: {"id": item.id},
      );
      if (mounted) {
        context.read<FetchMyPromotedItemsCubit>().delete(item.id);
        _fetchCounts();
        HelperUtils.showSnackBarMessage(
          context,
          "Ad deleted successfully",
          type: MessageType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to delete ad: $e",
          type: MessageType.error,
        );
      }
    }
  }

  Future<void> _renewExpiredAd(BuildContext context, ItemModel item) async {
    try {
      HelperUtils.showSnackBarMessage(
        context,
        "Renewing ad...",
        type: MessageType.warning,
      );
      final response = await Api.post(
        url: Api.renewItemApi,
        parameter: {"item_id": item.id},
      );
      if (response['error'] == true) {
        final msg = response['message']?.toString() ?? "Failed to renew ad";
        if (mounted) {
          HelperUtils.showSnackBarMessage(
            context,
            msg,
            type: MessageType.error,
          );
        }
        return;
      }
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Ad renewed successfully!",
          type: MessageType.success,
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to renew ad: $e",
          type: MessageType.error,
        );
      }
    }
  }

  void _confirmDeleteAd(BuildContext context, ItemModel item) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.color.secondaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text(
              "Delete Ad",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete '${item.name ?? 'this ad'}'? This action cannot be undone.",
          style: TextStyle(
            fontSize: 13.5,
            color: context.color.textDefaultColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "Cancel",
              style: TextStyle(color: context.color.textLightColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _deleteAd(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              "Delete",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic rawPrice) {
    if (rawPrice == null) return "AED 0";
    final dPrice = double.tryParse(rawPrice.toString());
    if (dPrice == null) return "AED $rawPrice";
    if (dPrice == dPrice.roundToDouble()) {
      final formatted = dPrice.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
      return "AED $formatted";
    }
    return "AED ${dPrice.toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    AdHelper.showInterstitialAd();
    return BlocBuilder<FetchMyPromotedItemsCubit, FetchMyPromotedItemsState>(
      builder: (context, state) {
        final currentItems = (state is FetchMyPromotedItemsSuccess)
            ? state.itemModel
            : <ItemModel>[];

        return Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: AppBar(
            backgroundColor: context.color.secondaryColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0.5,
            centerTitle: true,
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: context.color.textDefaultColor,
                    onPressed: _exitSelectionMode,
                  )
                : (widget.fromProfile
                    ? IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: context.color.textDefaultColor,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null),
            title: Text(
              _isSelectionMode
                  ? "${_selectedItemIds.length} Selected"
                  : "My Ads",
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: _isSelectionMode
                ? [
                    TextButton(
                      onPressed: () => _toggleSelectAll(currentItems),
                      child: Text(
                        _selectedItemIds.length == currentItems.length &&
                                currentItems.isNotEmpty
                            ? "Deselect All"
                            : "Select All",
                        style: TextStyle(
                          color: context.color.territoryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.red),
                      onPressed: _selectedItemIds.isEmpty
                          ? null
                          : () => _confirmDeleteSelectedAds(context),
                    ),
                    const SizedBox(width: 4),
                  ]
                : [
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, Routes.selectCategoryScreen),
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                        color: context.color.territoryColor,
                      ),
                      label: Text(
                        "Post Ad",
                        style: TextStyle(
                          color: context.color.territoryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              _loadData();
            },
            color: context.color.territoryColor,
            child: _buildBodyContent(state, currentItems),
          ),
        );
      },
    );
  }

  Widget _buildBodyContent(
      FetchMyPromotedItemsState state, List<ItemModel> currentItems) {
    if (state is FetchMyPromotedItemsInProgress && !_isSelectionMode) {
      return shimmerEffect();
    }
    if (state is FetchMyPromotedItemsFailure) {
      if (state.errorMessage is ApiException &&
          state.errorMessage.errorMessage == "no-internet") {
        return NoInternet(
          onRetry: () {
            _loadData();
          },
        );
      }
      return const SomethingWentWrong();
    }

    return SingleChildScrollView(
      controller: _pageScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Status Filter Tabs
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final count = _itemsCount[tab["key"]!] ?? 0;
                final label = "${tab["label"]!} ($count)";
                return _buildTabChip(index, label);
              },
            ),
          ),

          const SizedBox(height: 16),

          if (state is FetchMyPromotedItemsSuccess) ...[
            if (state.itemModel.isEmpty)
              _buildEmptyState()
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.itemModel.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = state.itemModel[index];
                  return _buildAdCard(context, item);
                },
              ),
              if (state.isLoadingMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: UiUtils.progress(
                      normalProgressColor: context.color.territoryColor,
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTabChip(int tabIndex, String label) {
    final isSelected = _selectedTab == tabIndex;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _onTabSelected(tabIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.color.territoryColor.withValues(alpha: 0.12)
              : context.color.secondaryColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? context.color.territoryColor
                : context.color.borderColor.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? context.color.territoryColor
                : context.color.textDefaultColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAdCard(BuildContext context, ItemModel item) {
    final statusStr = (item.status ?? "").toLowerCase();
    final isLive = statusStr == "approved" ||
        statusStr == "live" ||
        statusStr == "1" ||
        statusStr == "active";
    final isPaymentPending = statusStr == "inactive" ||
        statusStr == "pending payment" ||
        statusStr == "payment_pending" ||
        statusStr == "pending";
    final isReview = statusStr == "review" || statusStr == "under_review";
    final isRejected = statusStr == "rejected";
    final isExpired = statusStr == "expired";

    Color badgeBg;
    Color badgeFg;
    String badgeLabel;

    if (isLive) {
      badgeBg = Colors.green.withValues(alpha: 0.12);
      badgeFg = Colors.green;
      badgeLabel = "Live";
    } else if (isPaymentPending) {
      badgeBg = Colors.orange.withValues(alpha: 0.14);
      badgeFg = Colors.orange.shade800;
      badgeLabel = "Payment Pending";
    } else if (isReview) {
      badgeBg = Colors.blue.withValues(alpha: 0.12);
      badgeFg = Colors.blue.shade700;
      badgeLabel = "Under Review";
    } else if (isRejected) {
      badgeBg = Colors.red.withValues(alpha: 0.12);
      badgeFg = Colors.red;
      badgeLabel = "Rejected";
    } else if (isExpired) {
      badgeBg = Colors.amber.withValues(alpha: 0.12);
      badgeFg = Colors.amber.shade800;
      badgeLabel = "Expired";
    } else {
      badgeBg = Colors.grey.withValues(alpha: 0.15);
      badgeFg = Colors.grey.shade700;
      badgeLabel = statusStr.firstUpperCase();
    }

    final isSelected = item.id != null && _selectedItemIds.contains(item.id);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onLongPress: () {
        if (!_isSelectionMode && item.id != null) {
          _enterSelectionMode(item.id!);
        }
      },
      onTap: () {
        if (_isSelectionMode && item.id != null) {
          _toggleSelection(item.id!);
        } else {
          Navigator.pushNamed(
            context,
            Routes.adDetailsScreen,
            arguments: {'model': item},
          );
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? context.color.territoryColor
                    : context.color.borderColor.withValues(alpha: 0.45),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 96,
                        height: 96,
                        color: context.color.backgroundColor,
                        child: UiUtils.getImage(
                          item.image ?? "",
                          fit: BoxFit.cover,
                          width: 96,
                          height: 96,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: SizedBox(
                        height: 96,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Status Badge, Views & Action Menu
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: badgeFg,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (item.views != null && !_isSelectionMode) ...[
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 13,
                                    color: context.color.textLightColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    "${item.views}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                if (!_isSelectionMode)
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      Icons.more_vert_rounded,
                                      size: 18,
                                      color: context.color.textLightColor,
                                    ),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    color: context.color.secondaryColor,
                                    onSelected: (val) {
                                      if (val == "view") {
                                        Navigator.pushNamed(
                                          context,
                                          Routes.adDetailsScreen,
                                          arguments: {'model': item},
                                        );
                                      } else if (val == "pay") {
                                        Navigator.pushNamed(
                                          context,
                                          Routes.carPackagePaymentScreen,
                                          arguments: {'model': item},
                                        );
                                      } else if (val == "renew") {
                                        _renewExpiredAd(context, item);
                                      } else if (val == "delete") {
                                        _confirmDeleteAd(context, item);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem(
                                        value: "view",
                                        height: 36,
                                        child: Row(
                                          children: [
                                            Icon(Icons.visibility_outlined,
                                                size: 16,
                                                color: context
                                                    .color.textDefaultColor),
                                            const SizedBox(width: 8),
                                            Text("View Details",
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: context
                                                        .color.textDefaultColor)),
                                          ],
                                        ),
                                      ),
                                      if (isPaymentPending)
                                        PopupMenuItem(
                                          value: "pay",
                                          height: 36,
                                          child: Row(
                                            children: const [
                                              Icon(Icons.payment_outlined,
                                                  size: 16,
                                                  color: Color(0xFFD31027)),
                                              SizedBox(width: 8),
                                              Text("Pay & Activate",
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFFD31027))),
                                            ],
                                          ),
                                        ),
                                      if (isExpired)
                                        PopupMenuItem(
                                          value: "renew",
                                          height: 36,
                                          child: Row(
                                            children: [
                                              Icon(Icons.refresh_rounded,
                                                  size: 16,
                                                  color: Colors.amber.shade800),
                                              const SizedBox(width: 8),
                                              Text("Renew Ad",
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amber.shade800)),
                                            ],
                                          ),
                                        ),
                                      PopupMenuItem(
                                        value: "delete",
                                        height: 36,
                                        child: Row(
                                          children: const [
                                            Icon(Icons.delete_outline_rounded,
                                                size: 16, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text("Delete Ad",
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            // Title
                            Text(
                              item.name?.firstUpperCase() ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: context.color.textDefaultColor,
                              ),
                            ),

                            // Price & Date
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatPrice(item.price),
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: context.color.territoryColor,
                                  ),
                                ),
                                if (item.created != null)
                                  Text(
                                    item.created.toString().formatDate(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // If ad is in Payment Pending, show Pay Now CTA button
                if (isPaymentPending && !_isSelectionMode) ...[
                  const SizedBox(height: 10),
                  Divider(
                      height: 1,
                      color: context.color.borderColor.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Ad is inactive pending package payment",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            Routes.carPackagePaymentScreen,
                            arguments: {
                              'model': item,
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD31027),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD31027)
                                    .withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            "Pay Now",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // If ad is Expired, show Renew CTA button
                if (isExpired && !_isSelectionMode) ...[
                  const SizedBox(height: 10),
                  Divider(
                      height: 1,
                      color: context.color.borderColor.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "This ad has expired. Renew to make it live again",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _renewExpiredAd(context, item),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.shade700
                                    .withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            "Renew",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Checkmark at Top Right Edge in Selection Mode
          if (_isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? context.color.territoryColor
                      : context.color.secondaryColor,
                  border: Border.all(
                    color: isSelected
                        ? context.color.territoryColor
                        : context.color.textLightColor.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: context.color.territoryColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cactus Illustration container
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: context.color.territoryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF00B0FF), Color(0xFF00C853)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.yard_outlined,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "You haven't placed any ads yet!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.territoryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _openCategoryPickerModal(context),
              child: const Text(
                "Post ad now",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget shimmerEffect() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: CustomShimmer(height: 85, width: 85),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    CustomShimmer(height: 14, width: 140),
                    SizedBox(height: 8),
                    CustomShimmer(height: 12, width: 100),
                    SizedBox(height: 8),
                    CustomShimmer(height: 12, width: 60),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
