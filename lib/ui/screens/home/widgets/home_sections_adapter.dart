import 'dart:developer';

import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:Ebozor/data/model/item/item_model.dart';

import 'package:flutter/material.dart';

import 'package:Ebozor/utils/app_icon.dart';

import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/model/home/home_screen_section.dart';

import 'package:Ebozor/ui/screens/widgets/promoted_widget.dart';
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

    return Column(
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
        GridListAdapter(
          type: ListUiType.List,
          listAxis: Axis.horizontal,
          height: 210,
          listSaperator: (_, __) => const SizedBox(width: 14),
          builder: (context, index, _) {
            final item = section.sectionData![index];
            return ItemCard(
              item: item,
            );
          },
          total: section.sectionData!.length,
        ),
      ],
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
  final double likeButtonSize = 24;
  final double imageHeight = 130;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? 160,
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.color.borderColor.darken(30),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            log(widget.item?.toJson().toString() ?? "");
            // Navigator.pushNamed(
            //   context,
            //   Routes.adDetailsScreen,
            //   arguments: {"model": widget.item},
            // );
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
                      top: Radius.circular(18),
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
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// PRICE
                      Text(
                        "${Constant.currencySymbol} ${widget.item?.price ?? ""}",
                      )
                          .bold()
                          .size(context.font.large)
                          .color(context.color.territoryColor),

                      const SizedBox(height: 5),

                      /// ITEM NAME
                      Text(widget.item?.name ?? "")
                      .bold()
                          .firstUpperCaseWidget()
                          .setMaxLines(lines: 1)
                          .size(context.font.small),

                      const SizedBox(height: 5),

                      /// LOCATION (compact)
                      if ((widget.item?.address ?? "").isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            UiUtils.getSvg(
                              height: 20,
                              width: 20,
                              AppIcons.location,
                            ),
                            const SizedBox(width: 1),
                            Expanded(
                              child: Text(
                                widget.item?.address ?? "",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: context.font.small,
                                  height: 1,
                                  color: context.color.textDefaultColor
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),

            /// FAVORITE BUTTON
            _favButton(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _favButton() {
    bool isLike =
    context.read<FavoriteCubit>().isItemFavorite(widget.item!.id!);

    return BlocProvider(
      create: (_) => UpdateFavoriteCubit(FavoriteRepository()),
      child: BlocConsumer<FavoriteCubit, FavoriteState>(
        bloc: context.read<FavoriteCubit>(),
        listener: (_, __) {
          isLike = context
              .read<FavoriteCubit>()
              .isItemFavorite(widget.item!.id!);
        },
        builder: (context, _) {
          return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
            listener: (context, state) {
              if (state is UpdateFavoriteSuccess) {
                if (state.wasProcess) {
                  context
                      .read<FavoriteCubit>()
                      .addFavoriteitem(state.item);
                } else {
                  context
                      .read<FavoriteCubit>()
                      .removeFavoriteItem(state.item);
                }
              }
            },
            builder: (context, state) {
              return Positioned(
                top: imageHeight - (likeButtonSize / 2),
                right: 12,
                child: InkWell(
                  onTap: () {
                    UiUtils.checkUser(
                      context: context,
                      onNotGuest: () {
                        context
                            .read<UpdateFavoriteCubit>()
                            .setFavoriteItem(
                          item: widget.item!,
                          type: isLike ? 0 : 1,
                        );
                      },
                    );
                  },
                   child: Container(
                  width: likeButtonSize,
                  height: likeButtonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.color.secondaryColor,
                    boxShadow:
                    context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark
                        ? null
                        : [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 3,
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
                    child: UiUtils.getSvg(
                      isLike ? AppIcons.like_fill : AppIcons.like,
                      width: 14,
                      height: 14,
                      color: context.color.territoryColor
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
      padding: EdgeInsetsDirectional.only(
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
                    .color(context.color.deactivateColor),
              ),
            ),
        ],
      ),
    );
  }
}


