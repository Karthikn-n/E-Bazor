// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:Ebozor/ui/screens/widgets/promoted_widget.dart';
import 'package:Ebozor/ui/theme/theme.dart';

import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/string_extenstion.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/ui/screens/widgets/dialogs/save_to_favorite_bottom_sheet.dart';
import 'package:Ebozor/data/repositories/favourites_repository.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/manage_fav_cubit.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/utils/constant.dart';

class ItemHorizontalCard extends StatelessWidget {
  final ItemModel item;
  final List<Widget>? addBottom;
  final double? additionalHeight;
  final StatusButton? statusButton;
  final bool? useRow;
  final VoidCallback? onDeleteTap;
  final double? additionalImageWidth;
  final bool? showLikeButton;
  final VoidCallback? onTap;

  const ItemHorizontalCard({
    super.key,
    required this.item,
    this.useRow,
    this.addBottom,
    this.additionalHeight,
    this.statusButton,
    this.onDeleteTap,
    this.showLikeButton,
    this.additionalImageWidth,
    this.onTap,
  });

  Widget favButton(BuildContext context) {
    bool isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);

    return BlocProvider(
        create: (context) => UpdateFavoriteCubit(FavoriteRepository()),
        child: BlocConsumer<FavoriteCubit, FavoriteState>(
            bloc: context.read<FavoriteCubit>(),
            listener: ((context, state) {
              if (state is FavoriteFetchSuccess) {
                isLike = context.read<FavoriteCubit>().isItemFavorite(item.id!);
              }
            }),
            builder: (context, likeAndDislikeState) {
              return BlocConsumer<UpdateFavoriteCubit, UpdateFavoriteState>(
                  bloc: context.read<UpdateFavoriteCubit>(),
                  listener: ((context, state) {
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
                  }),
                  builder: (context, state) {
                    return InkWell(
                      onTap: () {
                        UiUtils.checkUser(
                            onNotGuest: () {
                              if (isLike) {
                                context
                                    .read<UpdateFavoriteCubit>()
                                    .setFavoriteItem(
                                      item: item,
                                      type: 0,
                                    );
                                return;
                              }
                              context
                                  .read<UpdateFavoriteCubit>()
                                  .setFavoriteItem(item: item, type: 1);
                              SaveToFavoriteBottomSheet.show(context, item: item);
                            },
                            context: context);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.color.secondaryColor,
                          shape: BoxShape.circle,
                          boxShadow:
                              context.watch<AppThemeCubit>().state.appTheme ==
                                      AppTheme.dark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Color.fromARGB(12, 0, 0, 0),
                                        offset: Offset(0, 2),
                                        blurRadius: 10,
                                        spreadRadius: 4,
                                      )
                                    ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.none,
                          child: state is UpdateFavoriteInProgress
                              ? Center(child: UiUtils.progress())
                              : UiUtils.getSvg(
                                  isLike ? AppIcons.like_fill : AppIcons.like,
                                  width: 22,
                                  height: 22,
                                  color: context.color.territoryColor,
                                ),
                        ),
                      ),
                    );
                  });
            }));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: context.color.secondaryColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: context.color.borderColor.withValues(alpha: 0.6),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SECTION
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: UiUtils.getImage(
                    item.image ?? "",
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                if (item.isFeature ?? false)
                  const Positioned(
                    top: 8,
                    left: 8,
                    child: PromotedCard(type: PromoteCardType.icon),
                  ),

                if (showLikeButton ?? true)
                  Positioned(
                    top: 8,
                    right: 8,

                    child: favButton(context,),
                  ),
              ],
            ),

            // CONTENT
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PRICE
                  SizedBox(height: 10,),
                  Text(
                    Constant.currencySymbol +
                        item.price!
                            .toString()
                            .priceFormate(
                            disabled:
                            Constant.isNumberWithSuffix == false),
                  )
                      .size(context.font.large)
                      .color(context.color.territoryColor)
                      .bold(weight: FontWeight.w700),

                  const SizedBox(height: 10),

                  // NAME
                  Text(item.name!.firstUpperCase())
                      .setMaxLines(lines: 2)
                      .size(context.font.normal)
                      .color(context.color.textDefaultColor),

                  const SizedBox(height: 10),

                  // LOCATION
                  if (item.address != "")
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: context.color.textDefaultColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(item.address?.trim() ?? "")
                              .setMaxLines(lines: 1)
                              .size(context.font.smaller)
                              .color(context.color.textDefaultColor
                              .withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // STATUS BUTTON
            if (statusButton != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusButton!.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(statusButton!.lable)
                      .size(context.font.small)
                      .bold()
                      .color(
                      statusButton?.textColor ?? Colors.black),
                ),
              ),

            // ADD BOTTOM WIDGETS
            if (useRow == false || useRow == null) ...addBottom ?? [],
            if (useRow == true)
              Row(children: addBottom ?? []),
          ],
        ),
      ),
    ),
  ),
),
);
  }
}

class StatusButton {
  final String lable;
  final Color color;
  final Color? textColor;

  StatusButton({
    required this.lable,
    required this.color,
    this.textColor,
  });
}
