import 'dart:developer';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/item/fetch_my_promoted_items_cubit.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/screens/home/widgets/verification_banner.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:Ebozor/utils/cloudState/cloud_state.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
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
    "inactive": 0,
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
    {
      "label": "Payment Pending",
      "key": "payment_pending",
      "status": "pending payment"
    },
    {"label": "Under Review", "key": "under_review", "status": "review"},
    {"label": "Inactive", "key": "inactive", "status": "inactive"},
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
    context
        .read<FetchMyPromotedItemsCubit>()
        .fetchMyPromotedItems(status: status);
  }

  Future<void> _fetchCounts() async {
    try {
      final counts = await ItemRepository().fetchMyItemsCount();
      final allItems = <ItemModel>[];
      var page = 1;
      var fetchedCount = 0;
      var serverTotal = 0;
      do {
        final result = await ItemRepository().fetchMyItems(page: page);
        serverTotal = result.total;
        fetchedCount += result.modelList.length;
        allItems.addAll(result.modelList);
        page++;
        if (result.modelList.isEmpty) break;
      } while (fetchedCount < serverTotal);

      bool hasStatus(ItemModel item, Set<String> statuses) => statuses.contains(
          (item.status ?? '').trim().toLowerCase().replaceAll('_', ' '));

      if (allItems.isNotEmpty) {
        counts['all_ads'] = allItems.length;
        counts['live'] = allItems
            .where(
                (item) => hasStatus(item, {'active', 'approved', 'live', '1'}))
            .length;
        counts['payment_pending'] = allItems
            .where((item) => hasStatus(item, {'pending payment', 'pending'}))
            .length;
      }

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
    context
        .read<FetchMyPromotedItemsCubit>()
        .fetchMyPromotedItems(status: status);
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
      final validIds =
          items.where((e) => e.id != null).map((e) => e.id!).toSet();
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
            const Icon(Icons.delete_sweep_outlined,
                color: Colors.red, size: 24),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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

  Future<void> _updateItemStatus(
      BuildContext context, ItemModel item, String newStatus) async {
    if (item.id == null) return;
    try {
      HelperUtils.showSnackBarMessage(
        context,
        "Updating ad status...",
        type: MessageType.warning,
      );
      final response = await ItemRepository().changeMyItemStatus(
        itemId: item.id!,
        status: newStatus,
      );
      if (response['error'] == true) {
        final msg =
            response['message']?.toString() ?? "Failed to update status";
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
        // Silently update item in cubit without full shimmer reload
        context
            .read<FetchMyPromotedItemsCubit>()
            .updateItemStatus(item.id!, newStatus);
        _fetchCounts();
        HelperUtils.showSnackBarMessage(
          context,
          "Ad status updated to '${newStatus.firstUpperCase()}'",
          type: MessageType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          "Failed to update status: $e",
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
            const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 22),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
                      onPressed: () => Navigator.pushNamed(
                          context, Routes.selectCategoryScreen),
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

          const SizedBox(height: 12),

          const _MyAdsBannerCarousel(),

          const SizedBox(height: 12),

          if (state is FetchMyPromotedItemsSuccess) ...[
            if (state.itemModel.isEmpty)
              _buildEmptyState()
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 4),
                itemCount: state.itemModel.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.8,
                  indent: 118,
                  endIndent: 16,
                  color: context.color.borderColor.withValues(alpha: 0.35),
                ),
                itemBuilder: (context, index) {
                  final item = state.itemModel[index];
                  return _buildAdTile(context, item);
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

  bool _isPaymentPendingStatus(String status) {
    final normalized = status.trim().toLowerCase().replaceAll('_', ' ');
    return normalized == 'pending payment' || normalized == 'pending';
  }

  String _editStatusFor(ItemModel item) {
    final itemStatus = item.status?.trim() ?? '';
    if (itemStatus.isNotEmpty) return itemStatus;

    final tabStatus = _tabs[_selectedTab]['status']?.trim() ?? '';
    if (tabStatus.isNotEmpty) return tabStatus;

    // The API represents some unpaid items with a blank status even though
    // my-items-count includes them under payment_pending.
    return 'pending payment';
  }

  Future<void> _navigateToEditAd(BuildContext context, ItemModel item) async {
    final editStatus = _editStatusFor(item);
    Widgets.showLoader(context);
    ItemModel fullItem = item;
    try {
      final res = (item.slug != null && item.slug!.trim().isNotEmpty)
          ? await ItemRepository().fetchItemFromItemSlug(item.slug!.trim())
          : (item.id != null
              ? await ItemRepository().fetchItemFromItemId(item.id!)
              : null);
      if (res != null && res.modelList.isNotEmpty) {
        fullItem = res.modelList.first;
        if ((fullItem.image ?? '').trim().isEmpty) {
          fullItem.image = item.image;
        }
        if ((fullItem.status ?? '').trim().isEmpty) {
          fullItem.status = editStatus;
        }
        if ((fullItem.galleryImages == null ||
                fullItem.galleryImages!.isEmpty) &&
            item.galleryImages != null) {
          fullItem.galleryImages = item.galleryImages;
        }
      }
    } catch (e) {
      log("⚠️ [EDIT AD FETCH ERROR]: $e");
    } finally {
      Widgets.hideLoder(context);
    }

    if (!context.mounted) return;

    addCloudData("edit_request", fullItem);
    fullItem.status = editStatus;
    addCloudData("edit_from", editStatus);

    final allCategoryIds =
        fullItem.allCategoryIds ?? "${fullItem.categoryId ?? ''}";
    final catIdList = allCategoryIds.split(',').map((e) => e.trim()).toList();
    final catSlug = (fullItem.category?.slug ?? '').toLowerCase();
    final catName = (fullItem.category?.name ?? '').toLowerCase();

    // Check if Car
    final isCar = fullItem.carMake != null ||
        fullItem.carMakeName != null ||
        catIdList.contains('5') ||
        catIdList.contains('6') ||
        catSlug.contains('car') ||
        catName.contains('car');

    // Check if Property
    final isProperty = fullItem.isPropertyCategory;

    // Check if Motor (non-car)
    final isMotor = !isCar && fullItem.isMotorsCategory;

    final breadcrumbs =
        fullItem.category != null ? [fullItem.category!] : <CategoryModel>[];

    final routeName = isCar
        ? Routes.carSpecsFormScreen
        : isProperty
            ? Routes.propertyPostingFormScreen
            : isMotor
                ? Routes.motorPostingFormScreen
                : Routes.classifiedsPostingFormScreen;
    final editResult = await Navigator.pushNamed(
      context,
      routeName,
      arguments: {
        'category': fullItem.category,
        'breadcrumbs': breadcrumbs,
        'item': fullItem,
        'isEdit': true,
        'customFields': fullItem.customFields,
      },
    );

    if (!context.mounted || editResult == null) return;
    MyAdvertisementScreen.refreshCallback?.call();

    if (editResult is ItemModel) {
      editResult.status = editStatus;
      if (_isPaymentPendingStatus(editStatus)) {
        await Navigator.pushNamed(
          context,
          Routes.carPackagePaymentScreen,
          arguments: {
            'model': editResult,
            'isEdit': true,
          },
        );
        if (context.mounted) _loadData();
      }
    }
  }

  Widget _buildAdTile(BuildContext context, ItemModel item) {
    final statusStr = (item.status ?? "").toLowerCase();
    final isHiringPost = item.isHiringPost;
    final isLive = statusStr == "approved" ||
        statusStr == "live" ||
        statusStr == "1" ||
        statusStr == "active";
    final isInactive = statusStr == "inactive" ||
        statusStr == "0" ||
        statusStr == "deactive" ||
        statusStr == "deactivated";
    final hasSoldOutStatus = statusStr == "sold out" || statusStr == "sold_out";
    final isSoldOut = !isHiringPost && hasSoldOutStatus;
    final isPaymentPending = statusStr == "pending payment" ||
        statusStr == "payment_pending" ||
        statusStr == "pending";
    final isReview = statusStr == "review" || statusStr == "under_review";
    final isRejected = statusStr == "rejected";
    final isExpired = statusStr == "expired";

    final requiresPayment = _isPaymentPendingStatus(_editStatusFor(item));

    Color badgeBg;
    Color badgeFg;
    String badgeLabel;

    if (isLive) {
      badgeBg = Colors.green.withValues(alpha: 0.12);
      badgeFg = Colors.green;
      badgeLabel = "Live";
    } else if (isHiringPost && hasSoldOutStatus) {
      badgeBg = Colors.blueGrey.withValues(alpha: 0.14);
      badgeFg = Colors.blueGrey.shade700;
      badgeLabel = "Inactive";
    } else if (isSoldOut) {
      badgeBg = Colors.purple.withValues(alpha: 0.12);
      badgeFg = Colors.purple.shade700;
      badgeLabel = "Sold Out";
    } else if (isInactive) {
      badgeBg = Colors.blueGrey.withValues(alpha: 0.14);
      badgeFg = Colors.blueGrey.shade700;
      badgeLabel = "Inactive";
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
    final specsSnippet = _extractSpecsSnippet(item);
    final hasBadge = badgeLabel.trim().isNotEmpty;

    Widget buildTitle() {
      return Text(
        item.name?.firstUpperCase() ?? "",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: context.color.textDefaultColor,
        ),
      );
    }

    return Material(
      color: isSelected
          ? context.color.territoryColor.withValues(alpha: 0.08)
          : context.color.secondaryColor,
      child: InkWell(
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
              arguments: {
                'model': item,
                'editStatus': _editStatusFor(item),
              },
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selection Checkbox
                  if (_isSelectionMode) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 24, right: 10),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected
                            ? context.color.territoryColor
                            : context.color.borderColor,
                        size: 22,
                      ),
                    ),
                  ],

                  // Thumbnail Image Tile
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      width: 86,
                      height: 86,
                      color: context.color.backgroundColor,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          UiUtils.getImage(
                            item.image ?? "",
                            fit: BoxFit.cover,
                            width: 86,
                            height: 86,
                          ),
                          if (item.isFeature == true)
                            Positioned(
                              top: 3,
                              left: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: context.color.territoryColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  "Featured",
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Information Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge + Views + Popup Menu
                        Row(
                          children: [
                            if (hasBadge)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: badgeFg,
                                  ),
                                ),
                              ),
                            if (!hasBadge) Expanded(child: buildTitle()),
                            if (hasBadge) const Spacer(),
                            // if (item.views != null && !_isSelectionMode) ...[
                            //   Icon(
                            //     Icons.visibility_outlined,
                            //     size: 13,
                            //     color: context.color.textLightColor,
                            //   ),
                            //   const SizedBox(width: 3),
                            //   Text(
                            //     "${item.views}",
                            //     style: TextStyle(
                            //       fontSize: 11,
                            //       color: context.color.textLightColor,
                            //     ),
                            //   ),
                            //   const SizedBox(width: 4),
                            // ],
                            if (!_isSelectionMode && (!isHiringPost || isLive))
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
                                      arguments: {
                                        'model': item,
                                        'editStatus': _editStatusFor(item),
                                      },
                                    );
                                  } else if (val == "edit") {
                                    _navigateToEditAd(context, item);
                                  } else if (val == "deactivate") {
                                    _updateItemStatus(
                                        context, item, "inactive");
                                  } else if (val == "sold_out") {
                                    _updateItemStatus(
                                        context, item, "sold out");
                                  } else if (val == "activate") {
                                    _updateItemStatus(context, item, "active");
                                  } else if (val == "pay") {
                                    Navigator.pushNamed(
                                      context,
                                      Routes.carPackagePaymentScreen,
                                      arguments: {
                                        'model': item,
                                        'isEdit': true,
                                      },
                                    );
                                  } else if (val == "renew") {
                                    _renewExpiredAd(context, item);
                                  } else if (val == "delete") {
                                    _confirmDeleteAd(context, item);
                                  }
                                },
                                itemBuilder: (ctx) => isHiringPost
                                    ? [
                                        _buildMenuItem(
                                          context,
                                          "deactivate",
                                          Icons.pause_circle_outline_rounded,
                                          "Deactivate Ad",
                                          Colors.amber.shade800,
                                        ),
                                      ]
                                    : [
                                        _buildMenuItem(
                                          context,
                                          "view",
                                          Icons.visibility_outlined,
                                          "View Details",
                                          context.color.textDefaultColor,
                                        ),
                                        _buildMenuItem(
                                          context,
                                          "edit",
                                          Icons.edit_outlined,
                                          "Edit Ad",
                                          context.color.textDefaultColor,
                                        ),
                                        if (isLive) ...[
                                          _buildMenuItem(
                                            context,
                                            "deactivate",
                                            Icons.pause_circle_outline_rounded,
                                            "Deactivate Ad",
                                            Colors.amber.shade800,
                                          ),
                                          _buildMenuItem(
                                            context,
                                            "sold_out",
                                            Icons.check_circle_outline_rounded,
                                            "Mark as Sold Out",
                                            Colors.purple,
                                          ),
                                        ],
                                        if (isInactive || isSoldOut)
                                          _buildMenuItem(
                                            context,
                                            "activate",
                                            Icons.play_circle_outline_rounded,
                                            "Activate Ad",
                                            Colors.green,
                                          ),
                                        if (requiresPayment)
                                          _buildMenuItem(
                                            context,
                                            "pay",
                                            Icons.payment_outlined,
                                            "Pay & Activate",
                                            const Color(0xFFD31027),
                                            bold: true,
                                          ),
                                        if (isExpired)
                                          _buildMenuItem(
                                            context,
                                            "renew",
                                            Icons.refresh_rounded,
                                            "Renew Ad",
                                            Colors.amber.shade800,
                                            bold: true,
                                          ),
                                        _buildMenuItem(
                                          context,
                                          "delete",
                                          Icons.delete_outline_rounded,
                                          "Delete Ad",
                                          Colors.red,
                                        ),
                                      ],
                              ),
                          ],
                        ),
                        if (hasBadge) ...[
                          const SizedBox(height: 3),
                          buildTitle(),
                        ],

                        // Specs / Category snippet
                        if (specsSnippet.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            specsSnippet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),

                        // Price & Date Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatPrice(item.price),
                              style: TextStyle(
                                fontSize: 15,
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
                ],
              ),

              // Inline Action for Payment Pending
              if (requiresPayment && !_isSelectionMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Ad inactive pending payment",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            Routes.carPackagePaymentScreen,
                            arguments: {
                              'model': item,
                              'isEdit': true,
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD31027),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Pay Now",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Inline Action for Expired
              if (isExpired && !_isSelectionMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Ad expired",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _renewExpiredAd(context, item),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade800,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Renew",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String value,
    IconData icon,
    String text,
    Color color, {
    bool bold = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _extractSpecsSnippet(ItemModel item) {
    List<String> parts = [];
    if (item.customFields != null) {
      for (final cf in item.customFields!) {
        final name = (cf.name ?? '').toLowerCase();
        if ((name.contains('year') ||
                name.contains('kilometer') ||
                name.contains('specs') ||
                name.contains('fuel') ||
                name.contains('brand') ||
                name.contains('make') ||
                name.contains('model')) &&
            cf.value != null &&
            cf.value!.isNotEmpty) {
          final val = cf.value!.first.toString().trim();
          if (val.isNotEmpty && !parts.contains(val)) {
            parts.add(val);
          }
        }
      }
    }
    if (parts.isEmpty) {
      if (item.category?.name != null && item.category!.name!.isNotEmpty) {
        parts.add(item.category!.name!);
      }
      if (item.area != null && item.area!.isNotEmpty) {
        parts.add(item.area!);
      } else if (item.city != null && item.city!.isNotEmpty) {
        parts.add(item.city!);
      }
    }
    return parts.take(3).join(" • ");
  }

  Widget _buildEmptyState() {
    final tabKey = _tabs[_selectedTab]['key'] ?? 'all_ads';
    final emptyTitles = <String, String>{
      'all_ads': "You haven't placed any ads yet!",
      'live': "You don't have any live ads.",
      'payment_pending': 'No ads are awaiting payment.',
      'under_review': 'No ads are currently under review.',
      'inactive': "You don't have any inactive ads.",
      'drafts': "You don't have any saved drafts.",
      'rejected': "You don't have any rejected ads.",
      'expired': "You don't have any expired ads.",
    };
    final emptyDescriptions = <String, String>{
      'all_ads': 'Create your first listing and reach interested buyers.',
      'live': 'Approved ads that are visible to buyers will appear here.',
      'payment_pending': 'Ads that still require payment will appear here.',
      'under_review': 'Ads waiting for approval will appear here.',
      'inactive': 'Ads you deactivate will appear here.',
      'drafts': 'Listings saved before posting will appear here.',
      'rejected': 'Ads that need changes after review will appear here.',
      'expired':
          'Listings that have reached their expiry date will appear here.',
    };

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
            emptyTitles[tabKey]!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: context.color.textDefaultColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            emptyDescriptions[tabKey]!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: context.color.textLightColor,
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

class _MyAdsBannerCarousel extends StatelessWidget {
  const _MyAdsBannerCarousel();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box(HiveKeys.userDetailsBox).listenable(),
      builder: (context, Box box, _) {
        final isVerified = HiveUtils.getUserDetails().isVerified == 1;

        if (isVerified) {
          return const _InsightsBanner();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth - 36;
            final cardHeight = cardWidth * 155 / 320;

            return SizedBox(
              height: cardHeight + 28,
              child: PageView(
                children: const [
                  VerificationBanner(),
                  _InsightsBanner(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _InsightsBanner extends StatelessWidget {
  const _InsightsBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: AspectRatio(
        aspectRatio: 320 / 155,
        child: Material(
          color: const Color(0xFFE7F0FC),
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: 190,
                child: UiUtils.getSvg(
                  'assets/svg/insights.svg',
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 74, 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Get detailed insights for your ads',
                              style: TextStyle(
                                color: Color(0xFF344054),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'See how many people are interested in your ad',
                        style: TextStyle(
                          color: Color(0xFF8A8178),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
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
}
