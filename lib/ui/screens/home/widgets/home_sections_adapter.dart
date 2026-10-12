import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/save_to_favorite_bottom_sheet.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:flutter/material.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/model/home/home_screen_section.dart';
import 'package:Ebozor/ui/screens/home/widgets/grid_list_adapter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeSectionsAdapter extends StatelessWidget {
  final HomeScreenSection section;

  const HomeSectionsAdapter({
    super.key,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    if (section.sectionData == null || section.sectionData!.isEmpty) {
      return const SizedBox.shrink();
    }

    final data = section.sectionData!;
    final bool hasMore = data.length > 8;
    final int itemCount = hasMore ? 9 : data.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitleHeader(
          title: section.title ?? "",
          onTap: () {
            Navigator.pushNamed(
              context,
              Routes.sectionWiseItemsScreen,
              arguments: {
                "title": section.title,
                "sectionId": section.sectionId,
              },
            );
          },
        ),
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: sidePadding),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 8 && hasMore) {
                return _buildViewAllCard(context);
              }
              final item = data[index];
              return ItemCard(
                item: item,
                width: 175,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildViewAllCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(
          context,
          Routes.sectionWiseItemsScreen,
          arguments: {
            "title": section.title,
            "sectionId": section.sectionId,
          },
        );
      },
      child: Container(
        width: 135,
        height: 232,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF007AFF).withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF007AFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "seeAll".translate(context).isNotEmpty
                  ? "seeAll".translate(context)
                  : "View all",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF007AFF),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${section.sectionData!.length} ads",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.color.textLightColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ItemCard extends StatefulWidget {
  final double? width;
  final ItemModel? item;

  const ItemCard({
    super.key,
    required this.item,
    this.width,
  });

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  final double imageHeight = 125;

  String _buildSpecsAndLocation() {
    final List<String> parts = [];
    final city =
        widget.item?.city?.trim() ?? widget.item?.address?.trim() ?? '';
    if (city.isNotEmpty) {
      parts.add(city);
    }

    // Extract dynamic specs ONLY if present in customFields
    if (widget.item?.customFields != null &&
        widget.item!.customFields!.isNotEmpty) {
      for (final field in widget.item!.customFields!) {
        final name = (field.name ?? field.label ?? '').toLowerCase();
        if (name.contains('year') ||
            name.contains('model') ||
            name.contains('mileage') ||
            name.contains('km')) {
          if (field.value != null) {
            String val = '';
            if (field.value is List && (field.value as List).isNotEmpty) {
              val = (field.value as List).first.toString().trim();
            } else if (field.value is String) {
              val = (field.value as String).trim();
            }
            if (val.isNotEmpty && !parts.contains(val)) {
              parts.add(val);
            }
          }
        }
      }
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        Constant.currencySymbol.isNotEmpty ? Constant.currencySymbol : 'TJS';
    final specsLocation = _buildSpecsAndLocation();
    final bool isVerified = widget.item?.user?.isVerified == 1;

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.color.borderColor.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pushNamed(
              context,
              Routes.adDetailsScreen,
              arguments: {"model": widget.item},
            );
          },
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// IMAGE
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: UiUtils.getImage(
                        widget.item?.image ?? "",
                        width: double.infinity,
                        height: imageHeight,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  /// CONTENT
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// ITEM NAME
                        Text(
                          widget.item?.name ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.color.textColorDark,
                          ),
                        ),

                        const SizedBox(height: 3),

                        /// PRICE (Bold blue)
                        Text(
                          "${widget.item?.price ?? ""} $currency",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF007AFF),
                          ),
                        ),

                        const SizedBox(height: 3),

                        /// LOCATION & DYNAMIC SPECS
                        if (specsLocation.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  specsLocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.color.textColorDark
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 13,
                                  color: Color(0xFF007AFF),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              /// FAVORITE BUTTON (floating in top right of photo)
              _favButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _favButton() {
    if (widget.item?.id == null) return const SizedBox.shrink();
    bool isLike =
        context.read<FavoriteCubit>().isItemFavorite(widget.item!.id!);

    return BlocProvider(
      create: (_) => UpdateFavoriteCubit(FavoriteRepository()),
      child: BlocConsumer<FavoriteCubit, FavoriteState>(
        bloc: context.read<FavoriteCubit>(),
        listener: (_, __) {
          isLike =
              context.read<FavoriteCubit>().isItemFavorite(widget.item!.id!);
        },
        builder: (context, _) {
          return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
            listener: (context, state) {
              if (state is UpdateFavoriteSuccess) {
                if (state.wasProcess) {
                  context.read<FavoriteCubit>().addFavoriteitem(state.item);
                } else {
                  context.read<FavoriteCubit>().removeFavoriteItem(state.item);
                }
              }
            },
            builder: (context, state) {
              final isDark = context.watch<AppThemeCubit>().state.appTheme ==
                  AppTheme.dark;

              return Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    UiUtils.checkUser(
                      context: context,
                      onNotGuest: () {
                        if (isLike) {
                          context.read<UpdateFavoriteCubit>().setFavoriteItem(
                                item: widget.item!,
                                type: 0,
                              );
                          return;
                        }
                        context
                            .read<UpdateFavoriteCubit>()
                            .setFavoriteItem(item: widget.item!, type: 1);
                        SaveToFavoriteBottomSheet.show(context,
                            item: widget.item!);
                      },
                    );
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.88),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: state is UpdateFavoriteInProgress
                        ? Center(
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: UiUtils.progress(),
                            ),
                          )
                        : Center(
                            child: Icon(
                              isLike
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 17,
                              color: isLike
                                  ? Colors.redAccent
                                  : (isDark
                                      ? Colors.white
                                      : context.color.textColorDark
                                          .withValues(alpha: 0.7)),
                            ),
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TitleHeader extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool hideSeeAll;

  const TitleHeader({
    super.key,
    required this.title,
    required this.onTap,
    this.hideSeeAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: 18,
        bottom: 12,
        start: sidePadding,
        end: sidePadding,
      ),
      child: Row(
        children: [
          /// TITLE
          Expanded(
            child: Text(title)
                .size(context.font.large)
                .bold(weight: FontWeight.bold)
                .color(context.color.textColorDark)
                .setMaxLines(lines: 1),
          ),

          /// SEE ALL
          if (!hideSeeAll)
            GestureDetector(
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text("seeAll".translate(context))
                    .size(context.font.smaller + 3)
                    .color(const Color(0xFF007AFF)),
              ),
            ),
        ],
      ),
    );
  }
}
