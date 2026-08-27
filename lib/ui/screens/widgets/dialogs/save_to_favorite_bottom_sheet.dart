import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_listings_cubit.dart';
import 'package:Ebozor/data/model/favorite_listing_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SaveToFavoriteBottomSheet extends StatefulWidget {
  final ItemModel item;

  const SaveToFavoriteBottomSheet({
    super.key,
    required this.item,
  });

  static Future<void> show(BuildContext context,
      {required ItemModel item}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<FavoriteListingsCubit>()),
            BlocProvider.value(value: context.read<FavoriteCubit>()),
          ],
          child: SaveToFavoriteBottomSheet(item: item),
        );
      },
    );
  }

  @override
  State<SaveToFavoriteBottomSheet> createState() =>
      _SaveToFavoriteBottomSheetState();
}

class _SaveToFavoriteBottomSheetState extends State<SaveToFavoriteBottomSheet> {
  final Set<int> _savingListIds = {};
  final Set<int> _addedListIds = {};
  bool _isLoadingMemberships = true;

  @override
  void initState() {
    super.initState();
    _loadListingsAndMemberships();
  }

  Future<void> _loadListingsAndMemberships() async {
    await context.read<FavoriteListingsCubit>().fetchListings();
    if (!mounted || widget.item.id == null) return;

    final favoriteCubit = context.read<FavoriteCubit>();
    final itemId = widget.item.id!;
    if (favoriteCubit.hasLoadedFavoriteListings(itemId)) {
      setState(() {
        _addedListIds
          ..clear()
          ..addAll(favoriteCubit.favoriteListingIds(itemId));
        _isLoadingMemberships = false;
      });
      return;
    }

    final listingIds = context
        .read<FavoriteListingsCubit>()
        .currentListings
        .where((listing) => listing.favouritelistingId != null)
        .map((listing) => listing.favouritelistingId!);

    try {
      final addedIds =
          await FavoriteRepository().fetchFavoriteListingIdsForItem(
        itemId: itemId,
        listingIds: listingIds,
      );
      favoriteCubit.setFavoriteListingIds(itemId, addedIds);
      if (mounted) {
        setState(() {
          _addedListIds
            ..clear()
            ..addAll(addedIds);
          _isLoadingMemberships = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMemberships = false);
    }
  }

  Future<void> _toggleItemInList(FavoriteListingModel listing) async {
    if (listing.favouritelistingId == null) return;
    final listId = listing.favouritelistingId!;
    final isRemoving = _addedListIds.contains(listId);

    setState(() {
      _savingListIds.add(listId);
    });

    try {
      final response = await FavoriteRepository().manageFavorites(
        widget.item.id!,
        favouritelistingId: listId,
      );
      if (!mounted) return;

      context.read<FavoriteCubit>().setFavoriteListingMembership(
            widget.item.id!,
            listId,
            isAdded: !isRemoving,
          );
      context.read<FavoriteListingsCubit>().updateListCount(
            listId,
            isRemoving ? -1 : 1,
          );

      setState(() {
        if (isRemoving) {
          _addedListIds.remove(listId);
        } else {
          _addedListIds.add(listId);
        }
        _savingListIds.remove(listId);
      });

      if (mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          response['message']?.toString() ?? "Updated favorite list",
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingListIds.remove(listId);
      });
      if (mounted) {
        HelperUtils.showSnackBarMessage(context, e.toString());
      }
    }
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(color: context.color.textDefaultColor),
                      decoration: InputDecoration(
                        hintText: "Enter list title...".translate(context),
                        hintStyle:
                            TextStyle(color: context.color.textLightColor),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: context.color.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: context.color.territoryColor),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return "Please enter a list name".translate(context);
                        }
                        return null;
                      },
                    ),
                  ],
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
                          if (success && widget.item.id != null) {
                            // Fetch fresh listings
                            await context
                                .read<FavoriteListingsCubit>()
                                .fetchListings();
                            final listings = context
                                .read<FavoriteListingsCubit>()
                                .currentListings;
                            final created = listings.firstWhere(
                              (l) =>
                                  l.title.toLowerCase() == name.toLowerCase(),
                              orElse: () => listings.last,
                            );
                            if (created.favouritelistingId != null) {
                              await _toggleItemInList(created);
                            }
                          }
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                        },
                  child: isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          "Create".translate(context),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title + Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved to "All Favorites"'.translate(context),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.color.textDefaultColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.color.textDefaultColor,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Top "All Favorites" Tile
                  Material(
                    color: context.color.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              context.color.borderColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 52,
                              height: 52,
                              color: Colors.grey.shade200,
                              child: widget.item.image != null &&
                                      widget.item.image!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: widget.item.image!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => const Icon(
                                          Icons.image,
                                          color: Colors.grey),
                                    )
                                  : const Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "All Favorites".translate(context),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 24,
                              color: Color(0xFFE53935),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section Header: "Add to a list" + "+ New List"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Add to a list".translate(context),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          foregroundColor: context.color.territoryColor,
                        ),
                        onPressed: _showCreateListDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          "New List".translate(context),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Personalized Lists Builder
                  BlocBuilder<FavoriteListingsCubit, FavoriteListingsState>(
                    builder: (context, state) {
                      if (state is FavoriteListingsFetchInProgress ||
                          _isLoadingMemberships) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      } else if (state is FavoriteListingsFetchSuccess) {
                        final customLists = state.customListings;
                        if (customLists.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                              child: Text(
                                "No custom lists yet. Tap + New List to create one!"
                                    .translate(context),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.color.textLightColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: customLists.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final list = customLists[index];
                            final listId = list.favouritelistingId;
                            final isSaving = listId != null &&
                                _savingListIds.contains(listId);
                            final isAdded = listId != null &&
                                _addedListIds.contains(listId);

                            return Material(
                              color: isAdded
                                  ? context.color.territoryColor
                                      .withValues(alpha: 0.05)
                                  : context.color.backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: isSaving
                                    ? null
                                    : () => _toggleItemInList(list),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isAdded
                                          ? context.color.territoryColor
                                              .withValues(alpha: 0.6)
                                          : context.color.borderColor
                                              .withValues(alpha: 0.5),
                                      width: isAdded ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 54,
                                          height: 54,
                                          color: Colors.grey.shade200,
                                          child: list.latestItem?.image !=
                                                      null &&
                                                  list.latestItem!.image!
                                                      .isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl:
                                                      list.latestItem!.image!,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) =>
                                                      const Icon(Icons.image,
                                                          color: Colors.grey),
                                                )
                                              : const Icon(
                                                  Icons.bookmark_border_rounded,
                                                  color: Colors.grey),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              list.title,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.bold,
                                                color: context
                                                    .color.textDefaultColor,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              "${list.count} saved ads • Private"
                                                  .translate(context),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context
                                                    .color.textLightColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSaving)
                                        const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      else
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isAdded
                                                ? const Color(0xFF10B981)
                                                : Colors.grey.shade200,
                                          ),
                                          child: Icon(
                                            isAdded ? Icons.check : Icons.add,
                                            color: isAdded
                                                ? Colors.white
                                                : Colors.black87,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
