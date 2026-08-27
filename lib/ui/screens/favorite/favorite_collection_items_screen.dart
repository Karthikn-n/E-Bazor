import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/category/fetch_category_cubit.dart';
import 'package:Ebozor/data/cubits/chat/delete_message_cubit.dart';
import 'package:Ebozor/data/cubits/chat/load_chat_messages.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_listings_cubit.dart';
import 'package:Ebozor/data/model/favorite_listing_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/ui/screens/chat/chat_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/favorite_list_options_bottom_sheet.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/inquire_ad_dialog.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/seller_contact_dialog.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

enum FavoriteViewMode { list, grid }

class FavoriteCollectionItemsScreen extends StatefulWidget {
  final FavoriteListingModel listing;

  const FavoriteCollectionItemsScreen({
    super.key,
    required this.listing,
  });

  static Route route(RouteSettings settings) {
    final listing = settings.arguments as FavoriteListingModel;
    return BlurredRouter(
      builder: (_) => FavoriteCollectionItemsScreen(listing: listing),
    );
  }

  @override
  State<FavoriteCollectionItemsScreen> createState() =>
      _FavoriteCollectionItemsScreenState();
}

class _FavoriteCollectionItemsScreenState
    extends State<FavoriteCollectionItemsScreen> {
  late FavoriteListingModel _currentListing = widget.listing;
  FavoriteViewMode _viewMode = FavoriteViewMode.list;
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryId;
  final Set<int> _removingFavoriteIds = <int>{};
  late final ScrollController _scrollController = ScrollController()
    ..addListener(_onScroll);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    _fetchItems();
  }

  void _fetchItems() {
    context.read<FavoriteCubit>().getFavorite(
          favouritelistingId: _currentListing.favouritelistingId,
        );
  }

  Future<void> _removeFavorite(ItemModel item) async {
    final itemId = item.id;
    if (itemId == null || _removingFavoriteIds.contains(itemId)) return;

    setState(() => _removingFavoriteIds.add(itemId));
    try {
      final repository = FavoriteRepository();
      final response = _currentListing.isDefault
          ? await repository.removeFavoriteEverywhere(itemId)
          : await repository.manageFavorites(
              itemId,
              favouritelistingId: _currentListing.favouritelistingId,
            );
      if (!mounted) return;

      final favoriteCubit = context.read<FavoriteCubit>();
      favoriteCubit.removeFavoriteItem(item);
      if (_currentListing.isDefault) {
        favoriteCubit.setFavoriteListingIds(itemId, const <int>[]);
        await context.read<FavoriteListingsCubit>().fetchListings();
      } else {
        context.read<FavoriteListingsCubit>().updateListCount(
              _currentListing.favouritelistingId,
              -1,
            );
      }
      if (!mounted) return;

      final removedCount = int.tryParse(
              response['removed_membership_count']?.toString() ?? '') ??
          1;
      setState(() {
        _currentListing = _currentListing.copyWith(
          count: (_currentListing.count - removedCount).clamp(0, 999999),
        );
      });
      HelperUtils.showSnackBarMessage(
        context,
        response['message']?.toString() ??
            'Removed from Favorites'.translate(context),
      );
    } catch (error) {
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _removingFavoriteIds.remove(itemId));
      }
    }
  }

  List<ItemModel> _getFilteredItems(List<ItemModel> allItems) {
    final query = _searchController.text.trim().toLowerCase();
    return allItems.where((item) {
      // Local Category Filter
      if (_selectedCategoryId != null) {
        final itemCatId = item.categoryId ?? item.category?.id;
        final allCatIds = item.allCategoryIds
                ?.split(',')
                .map((e) => int.tryParse(e.trim()))
                .whereType<int>()
                .toList() ??
            [];
        if (itemCatId != _selectedCategoryId &&
            !allCatIds.contains(_selectedCategoryId)) {
          return false;
        }
      }
      // Local Search Query Filter
      if (query.isNotEmpty) {
        final title = (item.name ?? '').toLowerCase();
        final desc = (item.description ?? '').toLowerCase();
        final catName = (item.category?.name ?? '').toLowerCase();
        final area = (item.area ?? '').toLowerCase();
        final city = (item.city ?? '').toLowerCase();
        if (!title.contains(query) &&
            !desc.contains(query) &&
            !catName.contains(query) &&
            !area.contains(query) &&
            !city.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (context.read<FavoriteCubit>().hasMoreFavorite()) {
        context.read<FavoriteCubit>().getMoreFavorite();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _shareListing() {
    final shareText =
        "Check out my favorite list '${_currentListing.title}' on Ebozor!\n${Constant.shareappText}";
    Share.share(shareText);
  }

  void _openEditOptions() {
    FavoriteListOptionsBottomSheet.show(
      context,
      listing: _currentListing,
      onDeleted: () {
        Navigator.pop(context, true);
      },
      onRenamed: (newName) {
        setState(() {
          _currentListing = _currentListing.copyWith(title: newName);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = _currentListing.isDefault;

    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.color.secondaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: context.color.textDefaultColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _currentListing.title,
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          if (!isDefault) ...[
            IconButton(
              icon: Icon(
                Icons.more_horiz_rounded,
                color: context.color.textDefaultColor,
                size: 24,
              ),
              onPressed: _openEditOptions,
            ),
            IconButton(
              icon: Icon(
                Icons.share_outlined,
                color: context.color.textDefaultColor,
                size: 22,
              ),
              onPressed: _shareListing,
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _fetchItems(),
        color: context.color.territoryColor,
        child: Column(
          children: [
            // Search Bar + List/Grid Toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.color.secondaryColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              context.color.borderColor.withValues(alpha: 0.8),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.color.textDefaultColor,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              "Search your saved listings".translate(context),
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: context.color.textLightColor,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20,
                            color: context.color.textLightColor,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // View Toggle Switch
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: context.color.borderColor.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildViewToggleButton(
                          icon: Icons.table_rows_rounded,
                          isSelected: _viewMode == FavoriteViewMode.list,
                          onTap: () {
                            if (_viewMode != FavoriteViewMode.list) {
                              setState(() => _viewMode = FavoriteViewMode.list);
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        _buildViewToggleButton(
                          icon: Icons.grid_view_rounded,
                          isSelected: _viewMode == FavoriteViewMode.grid,
                          onTap: () {
                            if (_viewMode != FavoriteViewMode.grid) {
                              setState(() => _viewMode = FavoriteViewMode.grid);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Category Filter Tabs (if All Favorites)
            if (isDefault) _buildCategoryFilterChips(),

            // Items List / Grid
            Expanded(
              child: BlocBuilder<FavoriteCubit, FavoriteState>(
                builder: (context, state) {
                  if (state is FavoriteFetchInProgress) {
                    return _buildShimmer();
                  } else if (state is FavoriteFetchSuccess) {
                    final displayedItems = _getFilteredItems(state.favorite);
                    if (displayedItems.isEmpty) {
                      return Center(
                        child: NoDataFound(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _selectedCategoryId = null);
                          },
                          mainMessage: _searchController.text.isNotEmpty ||
                                  _selectedCategoryId != null
                              ? "No matching listings found".translate(context)
                              : "No Saved Listings".translate(context),
                        ),
                      );
                    }

                    if (_viewMode == FavoriteViewMode.list) {
                      return ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: displayedItems.length +
                            (state.isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          if (index == displayedItems.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final item = displayedItems[index];
                          return _buildListItemCard(item);
                        },
                      );
                    } else {
                      return GridView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: displayedItems.length +
                            (state.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == displayedItems.length) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final item = displayedItems[index];
                          return _buildGridItemCard(item);
                        },
                      );
                    }
                  } else if (state is FavoriteFetchFailure) {
                    return const Center(child: SomethingWentWrong());
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isSelected ? context.color.territoryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : context.color.textLightColor,
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    return BlocBuilder<FetchCategoryCubit, FetchCategoryState>(
      builder: (context, catState) {
        if (catState is FetchCategorySuccess &&
            catState.categories.isNotEmpty) {
          final categories = catState.categories;
          return SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = _selectedCategoryId == null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text("All".translate(context)),
                      selected: isSelected,
                      selectedColor: context.color.territoryColor,
                      backgroundColor: context.color.secondaryColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : context.color.textDefaultColor,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategoryId = null);
                      },
                    ),
                  );
                }

                final cat = categories[index - 1];
                final isSelected = _selectedCategoryId == cat.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat.name ?? ""),
                    selected: isSelected,
                    selectedColor: context.color.territoryColor,
                    backgroundColor: context.color.secondaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : context.color.textDefaultColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = cat.id);
                    },
                  ),
                );
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildListItemCard(ItemModel item) {
    final imagesList = item.galleryImages ?? [];
    final allImages = [
      if (item.image != null && item.image!.isNotEmpty) item.image!,
      ...imagesList.map((g) => g.image ?? "").where((img) => img.isNotEmpty)
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(
          context,
          Routes.adDetailsScreen,
          arguments: {'model': item},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Slider
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: allImages.isNotEmpty
                        ? PageView.builder(
                            itemCount: allImages.length,
                            itemBuilder: (context, imgIndex) {
                              return CachedNetworkImage(
                                imageUrl: allImages[imgIndex],
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    Container(color: Colors.grey.shade200),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image,
                                size: 40, color: Colors.grey),
                          ),
                  ),
                ),

                // Image Count Tag
                if (allImages.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_outlined,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${allImages.length}",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Verified User Badge
                if (item.user?.isVerified == 1)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          )
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified,
                              color: Color(0xFF2563EB), size: 14),
                          SizedBox(width: 4),
                          Text(
                            "VERIFIED USER",
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Favorite Heart + Options Button
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _removeFavorite(item),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Item Details
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.name ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Category breadcrumbs
                  Text(
                    item.category?.name ?? "General",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.color.textLightColor,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Price
                  Text(
                    "${Constant.currencySymbol} ${(item.price ?? 0).toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.color.territoryColor,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Location
                  if (item.address != null && item.address!.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: context.color.textLightColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),

                  // 3 Action Buttons: Call, Chat, SMS
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(
                                color: Color(0xFFDC2626), width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () {
                            SellerContactBottomSheet.show(context, model: item);
                          },
                          icon: const Icon(Icons.phone_outlined, size: 16),
                          label: Text("Call".translate(context),
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7C3AED),
                            side: const BorderSide(
                                color: Color(0xFF7C3AED), width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () {
                            UiUtils.checkUser(
                              onNotGuest: () {
                                Navigator.push(
                                  context,
                                  BlurredRouter(
                                    builder: (context) {
                                      return MultiBlocProvider(
                                        providers: [
                                          BlocProvider(
                                            create: (context) =>
                                                LoadChatMessagesCubit(),
                                          ),
                                          BlocProvider(
                                            create: (context) =>
                                                DeleteMessageCubit(),
                                          ),
                                        ],
                                        child: Builder(builder: (context) {
                                          return ChatScreen(
                                            profilePicture:
                                                item.user?.profile ?? "",
                                            itemTitle: item.name ?? "",
                                            userId: item.user?.id?.toString() ??
                                                item.userId?.toString() ??
                                                "",
                                            itemImage: item.image ?? "",
                                            userName: item.user?.name ?? "",
                                            itemId: item.id?.toString() ?? "",
                                            date: item.created ?? "",
                                            from: "item",
                                            itemOfferId: 0,
                                            itemPrice: item.price ?? 0.0,
                                            itemOfferPrice: null,
                                            status: item.status,
                                            buyerId: HiveUtils.getUserId(),
                                            alreadyReview: false,
                                            isPurchased: item.isPurchased ?? 0,
                                          );
                                        }),
                                      );
                                    },
                                  ),
                                );
                              },
                              context: context,
                            );
                          },
                          icon: const Icon(Icons.forum_outlined, size: 16),
                          label: Text("Chat".translate(context),
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEA580C),
                            side: const BorderSide(
                                color: Color(0xFFEA580C), width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () {
                            InquireAdBottomSheet.show(context, model: item);
                          },
                          icon:
                              const Icon(Icons.mail_outline_rounded, size: 16),
                          label: Text("Email".translate(context),
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItemCard(ItemModel item) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.pushNamed(
          context,
          Routes.adDetailsScreen,
          arguments: {'model': item},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: item.image != null && item.image!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.image!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  Container(color: Colors.grey.shade200),
                            )
                          : Container(color: Colors.grey.shade200),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removeFavorite(item),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Color(0xFFEF4444),
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Text Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.color.textDefaultColor,
                      ),
                    ),
                    Text(
                      "${Constant.currencySymbol} ${(item.price ?? 0).toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.color.territoryColor,
                      ),
                    ),
                    if (item.address != null)
                      Text(
                        item.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.color.textLightColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 260,
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const CustomShimmer(height: 260, width: double.infinity),
        );
      },
    );
  }
}
