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
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
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
    {"label": "Payment Pending", "key": "payment_pending", "status": "pending payment"},
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
        final msg = response['message']?.toString() ?? "Failed to update status";
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
        context.read<FetchMyPromotedItemsCubit>().updateItemStatus(item.id!, newStatus);
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
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: state.itemModel.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.8,
                  indent: 106,
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

  Future<void> _navigateToEditAd(BuildContext context, ItemModel item) async {
    Widgets.showLoader(context);
    ItemModel fullItem = item;
    try {
      // The API omits saved custom-field values for some nested categories
      // when category_id is supplied. The web edit flow also fetches by ID only.
      final res = await ItemRepository().fetchItemFromItemId(item.id!);
      if (res.modelList.isNotEmpty) {
        fullItem = res.modelList.first;
        if ((fullItem.image ?? '').trim().isEmpty) {
          fullItem.image = item.image;
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
    addCloudData("edit_from", fullItem.status);

    final allCategoryIds = fullItem.allCategoryIds ?? "${fullItem.categoryId ?? ''}";
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
    final isProperty = catIdList.contains('65') ||
        catIdList.contains('66') ||
        catIdList.contains('85') ||
        catIdList.contains('139') ||
        catIdList.contains('140') ||
        catIdList.contains('68') ||
        catIdList.contains('143') ||
        catSlug.contains('property') ||
        catName.contains('property');

    // Check if Motor (non-car)
    final isMotor = catIdList.contains('1') ||
        catIdList.contains('13') ||
        catIdList.contains('14') ||
        catIdList.contains('37') ||
        catIdList.contains('38') ||
        catIdList.contains('53') ||
        catIdList.contains('54') ||
        catSlug.contains('motor') ||
        catName.contains('motor') ||
        catSlug.contains('bike') ||
        catName.contains('bike') ||
        catSlug.contains('boat') ||
        catName.contains('boat') ||
        catSlug.contains('truck') ||
        catName.contains('truck');

    final breadcrumbs = fullItem.category != null ? [fullItem.category!] : <CategoryModel>[];

    if (isCar) {
      Navigator.pushNamed(
        context,
        Routes.carSpecsFormScreen,
        arguments: {
          'category': fullItem.category,
          'breadcrumbs': breadcrumbs,
          'item': fullItem,
          'isEdit': true,
          'customFields': fullItem.customFields,
        },
      ).then((_) {
        MyAdvertisementScreen.refreshCallback?.call();
      });
    } else if (isProperty) {
      Navigator.pushNamed(
        context,
        Routes.propertyPostingFormScreen,
        arguments: {
          'category': fullItem.category,
          'breadcrumbs': breadcrumbs,
          'item': fullItem,
          'isEdit': true,
          'customFields': fullItem.customFields,
        },
      ).then((_) {
        MyAdvertisementScreen.refreshCallback?.call();
      });
    } else if (isMotor) {
      Navigator.pushNamed(
        context,
        Routes.motorPostingFormScreen,
        arguments: {
          'category': fullItem.category,
          'breadcrumbs': breadcrumbs,
          'item': fullItem,
          'isEdit': true,
          'customFields': fullItem.customFields,
        },
      ).then((_) {
        MyAdvertisementScreen.refreshCallback?.call();
      });
    } else {
      // Classifieds / Jobs / Other
      Navigator.pushNamed(
        context,
        Routes.classifiedsPostingFormScreen,
        arguments: {
          'category': fullItem.category,
          'breadcrumbs': breadcrumbs,
          'item': fullItem,
          'isEdit': true,
          'customFields': fullItem.customFields,
        },
      ).then((_) {
        MyAdvertisementScreen.refreshCallback?.call();
      });
    }
  }

  Widget _buildAdTile(BuildContext context, ItemModel item) {
    final statusStr = (item.status ?? "").toLowerCase();
    final isLive = statusStr == "approved" ||
        statusStr == "live" ||
        statusStr == "1" ||
        statusStr == "active";
    final isInactive = statusStr == "inactive" ||
        statusStr == "0" ||
        statusStr == "deactive" ||
        statusStr == "deactivated";
    final isSoldOut = statusStr == "sold out" || statusStr == "sold_out";
    final isPaymentPending = statusStr == "pending payment" ||
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
              arguments: {'model': item},
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
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 78,
                      height: 78,
                      color: context.color.backgroundColor,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          UiUtils.getImage(
                            item.image ?? "",
                            fit: BoxFit.cover,
                            width: 78,
                            height: 78,
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  fontSize: 10,
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
                              const SizedBox(width: 4),
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
                                  } else if (val == "edit") {
                                    _navigateToEditAd(context, item);
                                  } else if (val == "deactivate") {
                                    _updateItemStatus(
                                        context, item, "inactive");
                                  } else if (val == "sold_out") {
                                    _updateItemStatus(
                                        context, item, "sold out");
                                  } else if (val == "activate") {
                                    _updateItemStatus(
                                        context, item, "active");
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
                                  _buildMenuItem(
                                    context,
                                    "view",
                                    Icons.visibility_outlined,
                                    "View Details",
                                    context.color.textDefaultColor,
                                  ),
                                  if (isLive || isInactive || isSoldOut || isReview)
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
                                  if (isPaymentPending)
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
                        const SizedBox(height: 3),

                        // Title
                        Text(
                          item.name?.firstUpperCase() ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.color.textDefaultColor,
                          ),
                        ),

                        // Specs / Category snippet
                        if (specsSnippet.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            specsSnippet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
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
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: context.color.territoryColor,
                              ),
                            ),
                            if (item.created != null)
                              Text(
                                item.created.toString().formatDate(),
                                style: TextStyle(
                                  fontSize: 10.5,
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
              if (isPaymentPending && !_isSelectionMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
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
                            arguments: {'model': item},
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
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
