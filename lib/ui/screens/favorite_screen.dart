import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_listings_cubit.dart';
import 'package:Ebozor/data/model/favorite_listing_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/favorite_list_options_bottom_sheet.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/save_to_favorite_bottom_sheet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(
      builder: (context) {
        return const FavoriteScreen();
      },
    );
  }

  @override
  FavoriteScreenState createState() => FavoriteScreenState();
}

class FavoriteScreenState extends State<FavoriteScreen> {
  @override
  void initState() {
    super.initState();
    AdHelper.loadInterstitialAd();
    _fetchData();
  }

  void _fetchData() {
    context.read<FavoriteListingsCubit>().fetchListings();
    context.read<FavoriteCubit>().getFavorite();
  }

  void _showCreateListDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.color.secondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "New List".translate(context),
                style: TextStyle(
                  color: context.color.textDefaultColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: context.color.textDefaultColor),
                  decoration: InputDecoration(
                    hintText: "Enter list title...".translate(context),
                    hintStyle: TextStyle(color: context.color.textLightColor),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.color.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.color.territoryColor),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Please enter a list name".translate(context);
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    "Cancel".translate(context),
                    style: TextStyle(color: context.color.textLightColor),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.color.territoryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isCreating = true);
                          final name = controller.text.trim();
                          final success = await context
                              .read<FavoriteListingsCubit>()
                              .createListing(name);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (success && mounted) {
                            HelperUtils.showSnackBarMessage(
                              context,
                              "List created successfully".translate(context),
                            );
                          }
                        },
                  child: isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          "Create".translate(context),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToCollection(FavoriteListingModel listing) {
    Navigator.pushNamed(
      context,
      Routes.favoriteCollectionItemsScreen,
      arguments: listing,
    ).then((_) {
      _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    AdHelper.showInterstitialAd();
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: "Favorites".translate(context),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _fetchData(),
        color: context.color.territoryColor,
        child: BlocBuilder<FavoriteListingsCubit, FavoriteListingsState>(
          builder: (context, listingsState) {
            if (listingsState is FavoriteListingsFetchInProgress) {
              return _buildShimmer();
            } else if (listingsState is FavoriteListingsFetchFailure) {
              return const Center(
                child: SomethingWentWrong(),
              );
            } else if (listingsState is FavoriteListingsFetchSuccess) {
              final defaultListing = listingsState.defaultListing ??
                  FavoriteListingModel(title: "All Favorites", count: 0);
              final customListings = listingsState.customListings;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // SECTION 1: All Favorites
                  _buildAllFavoritesSection(defaultListing),

                  const SizedBox(height: 24),

                  // SECTION 2: Personalized Favorite Lists
                  _buildPersonalizedListsSection(customListings),

                  const SizedBox(height: 24),

                  // Info Notice at Bottom
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: context.color.borderColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: context.color.textLightColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Expired and deleted listings will automatically be removed from your favorites"
                                .translate(context),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildAllFavoritesSection(FavoriteListingModel defaultListing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: All Favorites [Default badge] + View All ->
        Row(
          children: [
            Text(
              "All Favorites".translate(context),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "Default".translate(context),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () => _navigateToCollection(defaultListing),
              child: Row(
                children: [
                  Text(
                    "View All".translate(context),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: context.color.textDefaultColor,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          "${defaultListing.count} saved ads".translate(context),
          style: TextStyle(
            fontSize: 12.5,
            color: context.color.textLightColor,
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal Preview Card Carousel
        BlocBuilder<FavoriteCubit, FavoriteState>(
          builder: (context, favState) {
            if (favState is FavoriteFetchInProgress) {
              return SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 2,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) => Container(
                    width: 150,
                    decoration: BoxDecoration(
                      color: context.color.secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const CustomShimmer(height: 180, width: 150),
                  ),
                ),
              );
            } else if (favState is FavoriteFetchSuccess) {
              final items = favState.favorite;
              if (items.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.color.borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "No saved ads in All Favorites yet".translate(context),
                      style: TextStyle(
                        color: context.color.textLightColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      // "View All ->" End Card Tile
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _navigateToCollection(defaultListing),
                        child: Container(
                          width: 140,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "View All".translate(context),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: context.color.textDefaultColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final item = items[index];
                    return _buildHorizontalItemCard(item);
                  },
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildHorizontalItemCard(ItemModel item) {
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
        width: 155,
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.color.borderColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SizedBox(
                    width: 155,
                    height: 110,
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
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      SaveToFavoriteBottomSheet.show(context, item: item);
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Color(0xFFEF4444),
                        size: 15,
                      ),
                    ),
                  ),
                ),
                if ((item.galleryImages?.length ?? 0) > 0)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 11),
                          const SizedBox(width: 3),
                          Text(
                            "${(item.galleryImages?.length ?? 0) + 1}",
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.category?.name ?? "Property",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.color.textLightColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${Constant.currencySymbol} ${(item.price ?? 0).toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: context.color.territoryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizedListsSection(List<FavoriteListingModel> customListings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Personalized Favorite lists + [+ New List] Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Personalized Favorite lists".translate(context),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              onPressed: _showCreateListDialog,
              icon: const Icon(Icons.add, size: 15),
              label: Text(
                "New List".translate(context),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          "Create a list to organize your favorite listings".translate(context),
          style: TextStyle(
            fontSize: 12.5,
            color: context.color.textLightColor,
          ),
        ),
        const SizedBox(height: 14),

        // List of Custom Collections
        if (customListings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.5),
              ),
            ),
            child: Center(
              child: Text(
                "No personalized lists created yet".translate(context),
                style: TextStyle(
                  color: context.color.textLightColor,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: customListings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final listing = customListings[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _navigateToCollection(listing),
                child: Container(
                  padding: const EdgeInsets.all(10),
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
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey.shade200,
                          child: listing.latestItem?.image != null &&
                                  listing.latestItem!.image!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: listing.latestItem!.image!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.image, color: Colors.grey),
                                )
                              : const Icon(Icons.bookmark_border_rounded, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: context.color.textDefaultColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "${listing.count} saved ad${listing.count == 1 ? '' : 's'}".translate(context),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.color.textLightColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Private".translate(context),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.color.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: context.color.textDefaultColor,
                          size: 22,
                        ),
                        onPressed: () {
                          FavoriteListOptionsBottomSheet.show(
                            context,
                            listing: listing,
                            onDeleted: _fetchData,
                            onRenamed: (_) => _fetchData(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const CustomShimmer(height: 200, width: double.infinity),
        ),
        const SizedBox(height: 20),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const CustomShimmer(height: 120, width: double.infinity),
        ),
      ],
    );
  }
}
