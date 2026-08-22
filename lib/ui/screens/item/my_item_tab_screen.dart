import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/data/cubits/item/fetch_my_item_cubit.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/cloudState/cloud_state.dart';

import 'package:Ebozor/data/helper/designs.dart';

import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';

Map<String, FetchMyItemsCubit> myAdsCubitReference = {};

class MyItemTab extends StatefulWidget {
  //final bool? getActiveItems;
  final String? getItemsWithStatus;

  const MyItemTab({super.key, this.getItemsWithStatus});

  @override
  CloudState<MyItemTab> createState() => _MyItemTabState();
}

class _MyItemTabState extends CloudState<MyItemTab> {
  late final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    if (HiveUtils.isUserAuthenticated()) {
      context.read<FetchMyItemsCubit>().fetchMyItems(
            getItemsWithStatus: widget.getItemsWithStatus,
          );
      _pageScrollController.addListener(_pageScroll);
      setReferenceOfCubit();
    }

    super.initState();
  }

  void _pageScroll() {
    if (_pageScrollController.isEndReached()) {
      if (context.read<FetchMyItemsCubit>().hasMoreData()) {
        context
            .read<FetchMyItemsCubit>()
            .fetchMyMoreItems(getItemsWithStatus: widget.getItemsWithStatus);
      }
    }
  }

  void setReferenceOfCubit() {
    myAdsCubitReference[widget.getItemsWithStatus!] =
        context.read<FetchMyItemsCubit>();
  }

  ListView shimmerEffect() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        vertical: 10 + defaultPadding,
        horizontal: defaultPadding,
      ),
      itemCount: 5,
      separatorBuilder: (context, index) {
        return const SizedBox(
          height: 12,
        );
      },
      itemBuilder: (context, index) {
        return Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ClipRRect(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                borderRadius: BorderRadius.all(Radius.circular(15)),
                child: CustomShimmer(height: 90, width: 90),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(
                        height: 10,
                      ),
                      CustomShimmer(
                        height: 10,
                        width: c.maxWidth - 50,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      const CustomShimmer(
                        height: 10,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      CustomShimmer(
                        height: 10,
                        width: c.maxWidth / 1.2,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Align(
                        alignment: AlignmentDirectional.bottomStart,
                        child: CustomShimmer(
                          width: c.maxWidth / 4,
                        ),
                      ),
                    ],
                  );
                }),
              )
            ],
          ),
        );
      },
    );
  }

  Widget showStatus(ItemModel model) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      //margin: EdgeInsetsDirectional.only(end: 4, start: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _getStatusColor(model.status),
      ),
      child: Text(
        _getStatusText(model.status)!,
      ).size(context.font.small).color(
            _getStatusTextColor(model.status),
          ),
    );
  }

  String? _getStatusText(String? status) {
    switch (status) {
      case "review":
        return "underReview".translate(context);
      case "active":
        return "active".translate(context);
      case "approved":
        return "approved".translate(context);
      case "inactive":
        return "deactivate".translate(context);
      case "sold out":
        return "soldOut".translate(context);
      case "rejected":
        return "rejected".translate(context);
      case "expired":
        return "expired".translate(context);
      default:
        return status;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case "review":
        return pendingButtonColor.withValues(alpha: 0.1);
      case "active" || "approved":
        return activateButtonColor.withValues(alpha: 0.1);
      case "inactive":
        return deactivateButtonColor.withValues(alpha: 0.1);
      case "sold out":
        return soldOutButtonColor.withValues(alpha: 0.1);
      case "rejected":
        return deactivateButtonColor.withValues(alpha: 0.1);
      case "expired":
        return deactivateButtonColor.withValues(alpha: 0.1);
      default:
        return context.color.territoryColor.withValues(alpha: 0.1);
    }
  }

  Color _getStatusTextColor(String? status) {
    switch (status) {
      case "review":
        return pendingButtonColor;
      case "active" || "approved":
        return activateButtonColor;
      case "inactive":
        return deactivateButtonColor;
      case "sold out":
        return soldOutButtonColor;
      case "rejected":
        return deactivateButtonColor;
      case "expired":
        return deactivateButtonColor;
      default:
        return context.color.territoryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<FetchMyItemsCubit>().fetchMyItems(
              getItemsWithStatus: widget.getItemsWithStatus,
            );

        setReferenceOfCubit();
      },
      color: context.color.territoryColor,
      child: BlocBuilder<FetchMyItemsCubit, FetchMyItemsState>(
        builder: (context, state) {
          if (state is FetchMyItemsInProgress) {
            return shimmerEffect();
          }

          if (state is FetchMyItemsFailed) {
            if (state.error is ApiException) {
              if (state.error.error == "no-internet") {
                return NoInternet(
                  onRetry: () {
                    context.read<FetchMyItemsCubit>().fetchMyItems(
                        getItemsWithStatus: widget.getItemsWithStatus);
                  },
                );
              }
            }

            return const SomethingWentWrong();
          }

          if (state is FetchMyItemsSuccess) {
            if (state.items.isEmpty) {
              return NoDataFound(
                mainMessage: "noAdsFound".translate(context),
                subMessage: "noAdsAvailable".translate(context),
                onTap: () {
                  context.read<FetchMyItemsCubit>().fetchMyItems(
                      getItemsWithStatus: widget.getItemsWithStatus);
                },
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    controller: _pageScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: sidePadding,
                      vertical: 8,
                    ),
                    separatorBuilder: (context, index) {
                      return Container(
                        height: 8,
                      );
                    },
                    itemBuilder: (context, index) {
                      ItemModel item = state.items[index];
                      return InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, Routes.adDetailsScreen,
                              arguments: {
                                "model": item,
                              }).then((value) {
                            if (value == "refresh") {
                              context.read<FetchMyItemsCubit>().fetchMyItems(
                                    getItemsWithStatus:
                                        widget.getItemsWithStatus,
                                  );

                              setReferenceOfCubit();
                            }
                          });
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            height: 130,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: item.status == "inactive"
                                    ? context.color.deactivateColor.brighten(70)
                                    : context.color.secondaryColor,
                                border: Border.all(
                                    color: context.color.borderColor.darken(30),
                                    width: 1)),
                            width: double.infinity,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: SizedBox(
                                    width: 116,
                                    height: double.infinity,
                                    child: UiUtils.getImage(item.image ?? "",
                                        height: double.infinity,
                                        fit: BoxFit.cover),
                                  ),
                                ),
                                Expanded(
                                  flex: 8,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0, vertical: 15),
                                    child: Column(
                                      //mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text("${Constant.currencySymbol}\t${item.price}")
                                                .color(context
                                                    .color.territoryColor)
                                                .bold(),
                                            Spacer(),
                                            showStatus(item)
                                          ],
                                        ),
                                        //SizedBox(height: 7,),
                                        Text(item.name ?? "")
                                            .setMaxLines(lines: 2)
                                            .firstUpperCaseWidget(),
                                        //SizedBox(height: 12,),
                                        Row(
                                          //mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              flex: 1,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SvgPicture.asset(AppIcons.eye,
                                                      width: 14,
                                                      height: 14,
                                                      colorFilter: ColorFilter.mode(
                                                          context.color
                                                              .textDefaultColor,
                                                          BlendMode.srcIn)),
                                                  const SizedBox(
                                                    width: 4,
                                                  ),
                                                  Text("${"views".translate(context)}:${item.views}")
                                                      .size(context.font.small)
                                                      .color(context
                                                          .color.textColorDark
                                                          .withValues(alpha: 0.5)),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 20,
                                            ),
                                            Flexible(
                                              flex: 1,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SvgPicture.asset(
                                                      AppIcons.heart,
                                                      width: 14,
                                                      height: 14,
                                                      colorFilter: ColorFilter.mode(
                                                          context.color
                                                              .textDefaultColor,
                                                          BlendMode.srcIn)),
                                                  const SizedBox(
                                                    width: 4,
                                                  ),
                                                  Text("${"like".translate(context)}:${item.totalLikes.toString()}")
                                                      .size(context.font.small)
                                                      .color(context
                                                          .color.textColorDark
                                                          .withValues(alpha: 0.5)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    itemCount: state.items.length,
                  ),
                ),
                if (state.isLoadingMore) UiUtils.progress()
              ],
            );
          }
          return Container();
        },
      ),
    );
  }

/*  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<FetchMyItemsCubit>().fetchMyItems(
              getItemsWithStatus: widget.getItemsWithStatus,
            );

        setReferenceOfCubit();
      },
      color: context.color.territoryColor,
      child: BlocBuilder<FetchMyItemsCubit, FetchMyItemsState>(
        builder: (context, state) {
          if (state is FetchMyItemsInProgress) {
            return shimmerEffect();
          }

          if (state is FetchMyItemsFailed) {
            if (state.error is ApiException) {
              if (state.error.error == "no-internet") {
                return NoInternet(
                  onRetry: () {
                    context.read<FetchMyItemsCubit>().fetchMyItems(
                        getItemsWithStatus: widget.getItemsWithStatus);
                  },
                );
              }
            }

            return const SomethingWentWrong();
          }

          if (state is FetchMyItemsSuccess) {
            if (state.items.isEmpty) {
              return NoDataFound(
                mainMessage: "noAdsFound".translate(context),
                subMessage: "noAdsAvailable".translate(context),
                onTap: () {
                  context.read<FetchMyItemsCubit>().fetchMyItems(
                      getItemsWithStatus: widget.getItemsWithStatus);
                },
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    controller: _pageScrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: sidePadding,
                      vertical: 8,
                    ),
                    separatorBuilder: (context, index) {
                      return Container(
                        height: 8,
                      );
                    },
                    itemBuilder: (context, index) {
                      ItemModel item = state.items[index];
                      return MultiBlocProvider(
                        providers: [
                          BlocProvider(create: (context) => DeleteItemCubit()),
                          BlocProvider(
                              create: (context) => CreateFeaturedAdCubit()),
                          BlocProvider(
                              create: (context) =>
                                  FetchUserPackageLimitCubit()),
                          BlocProvider(
                              create: (context) => ChangeMyItemStatusCubit()),
                        ],
                        child: Builder(builder: (context) {
                          return BlocListener<CreateFeaturedAdCubit,
                              CreateFeaturedAdState>(
                            listener: (context, state) {
                              if (state is CreateFeaturedAdInSuccess) {
                                HelperUtils.showSnackBarMessage(
                                    context, state.responseMessage.toString(),
                                    messageDuration: 3);

                                context.read<FetchMyItemsCubit>().fetchMyItems(
                                      getItemsWithStatus:
                                          widget.getItemsWithStatus,
                                    );
                              }

                              if (state is CreateFeaturedAdFailure) {
                                HelperUtils.showSnackBarMessage(
                                    context, state.error.toString(),
                                    messageDuration: 3);
                              }
                            },
                            child: BlocListener<FetchUserPackageLimitCubit,
                                FetchUserPackageLimitState>(
                              listener: (context, state) async {
                                if (state is FetchUserPackageLimitFailure) {
                                  UiUtils.noPackageAvailableDialog(context);
                                }
                                if (state is FetchUserPackageLimitInSuccess) {
                                  await UiUtils.showBlurredDialoge(
                                    context,
                                    dialoge: BlurredDialogBox(
                                        title: "createFeaturedAd"
                                            .translate(context),
                                        content: Text(
                                          "areYouSureToCreateThisItemAsAFeaturedAd"
                                              .translate(context),
                                        ),
                                        isAcceptContainesPush: true,
                                        onAccept: () =>
                                            Future.value().then((_) {
                                              Future.delayed(
                                                Duration.zero,
                                                () {
                                                  context
                                                      .read<
                                                          CreateFeaturedAdCubit>()
                                                      .createFeaturedAds(
                                                        itemId: item.id!,
                                                      );
                                                  Navigator.pop(context);
                                                  return;
                                                },
                                              );
                                            })),
                                  );
                                }
                              },
                              child: BlocListener<ChangeMyItemStatusCubit,
                                  ChangeMyItemStatusState>(
                                listener: (context, changeState) {
                                  if (changeState
                                      is ChangeMyItemStatusSuccess) {
                                    HelperUtils.showSnackBarMessage(
                                        context, changeState.message);
                                    context
                                        .read<FetchMyItemsCubit>()
                                        .fetchMyItems(
                                          getItemsWithStatus:
                                              widget.getItemsWithStatus,
                                        );
                                  } else if (changeState
                                      is ChangeMyItemStatusFailure) {
                                    HelperUtils.showSnackBarMessage(
                                        context, changeState.errorMessage);
                                  }
                                },
                                child: BlocListener<DeleteItemCubit,
                                    DeleteItemState>(
                                  listener: (context, deleteState) {
                                    if (deleteState is DeleteItemSuccess) {
                                      HelperUtils.showSnackBarMessage(
                                          context,
                                          "deleteItemSuccessMsg"
                                              .translate(context));
                                      context
                                          .read<FetchMyItemsCubit>()
                                          .deleteItem(item);
                                    } else if (deleteState
                                        is DeleteItemFailure) {
                                      HelperUtils.showSnackBarMessage(
                                          context, deleteState.errorMessage);
                                    }
                                  },
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pushNamed(
                                          context, Routes.adDetailsScreen,
                                          arguments: {
                                            "model": item,
                                          }).then((value) {
                                        if (value == "refresh") {
                                          context
                                              .read<FetchMyItemsCubit>()
                                              .fetchMyItems(
                                                getItemsWithStatus:
                                                    widget.getItemsWithStatus,
                                              );

                                          setReferenceOfCubit();
                                        }
                                      });
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Container(
                                        height: 130,
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            color: item.status == "inactive"
                                                ? context.color.deactivateColor
                                                    .brighten(70)
                                                : context.color.secondaryColor,
                                            border: Border.all(
                                                color: context.color.borderColor
                                                    .darken(30),
                                                width: 1)),
                                        width: double.infinity,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              child: SizedBox(
                                                width: 116,
                                                height: double.infinity,
                                                child: UiUtils.getImage(
                                                    item.image ?? "",
                                                    height: double.infinity,
                                                    fit: BoxFit.cover),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 8,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10.0,
                                                        vertical: 15),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text("${Constant.currencySymbol}\t${item.price}")
                                                        .color(context.color
                                                            .territoryColor)
                                                        .bold(),
                                                    Text(item.name ?? "")
                                                        .setMaxLines(lines: 2)
                                                        .firstUpperCaseWidget(),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            SvgPicture.asset(
                                                                AppIcons.eye,
                                                                width: 14,
                                                                height: 14,
                                                                colorFilter: ColorFilter.mode(
                                                                    context
                                                                        .color
                                                                        .textDefaultColor,
                                                                    BlendMode
                                                                        .srcIn)),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text("${"views".translate(context)}:${item.views}")
                                                                .size(context
                                                                    .font.small)
                                                                .color(context
                                                                    .color
                                                                    .textColorDark
                                                                    .withValues(alpha: 
                                                                        0.8))
                                                          ],
                                                        ),
                                                        Row(
                                                          children: [
                                                            SvgPicture.asset(
                                                                AppIcons.heart,
                                                                width: 14,
                                                                height: 14,
                                                                colorFilter: ColorFilter.mode(
                                                                    context
                                                                        .color
                                                                        .textDefaultColor,
                                                                    BlendMode
                                                                        .srcIn)),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text("${"like".translate(context)}:${item.totalLikes.toString()}")
                                                                .size(context
                                                                    .font.small)
                                                                .color(context
                                                                    .color
                                                                    .textColorDark
                                                                    .withValues(alpha: 
                                                                        0.8)),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Spacer(),
                                            */ /*  Container(
                                              height: 50,
                                              width: 50,
                                              alignment:
                                                  AlignmentDirectional.center,
                                              child: PopupMenuButton(
                                                color: context
                                                    .color.territoryColor,
                                                offset: Offset(-12, 15),
                                                shape:
                                                    const RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    bottomLeft:
                                                        Radius.circular(17),
                                                    bottomRight:
                                                        Radius.circular(17),
                                                    topLeft:
                                                        Radius.circular(17),
                                                    topRight:
                                                        Radius.circular(0),
                                                  ),
                                                ),
                                                child: SvgPicture.asset(
                                                  AppIcons.more,
                                                  width: 20,
                                                  height: 20,
                                                  fit: BoxFit.contain,
                                                  colorFilter: ColorFilter.mode(
                                                      context.color
                                                          .textDefaultColor,
                                                      BlendMode.srcIn),
                                                ),
                                                itemBuilder: (context) => [
                                                   if (item.isFeature != true)
                                                     if (item.status ==
                                                             "active" ||
                                                         item.status ==
                                                             "approved")
                                                       PopupMenuItem(
                                                         onTap: () {
                                                           Future.delayed(
                                                               Duration.zero,
                                                               () {
                                                             context
                                                                 .read<
                                                                     FetchUserPackageLimitCubit>()
                                                                 .fetchUserPackageLimit(
                                                                     packageType:
                                                                         "advertisement");
                                                           });
                                                         },
                                                         child: Text("featureAd"
                                                                 .translate(
                                                                     context))
                                                             .color(context.color
                                                                 .buttonColor),
                                                       ),
                                                   if (item.status == "active" ||
                                                       item.status ==
                                                           "inactive" ||
                                                       item.status == "approved")
                                                     PopupMenuItem(
                                                       onTap: () async {
                                                         var soldOut = await UiUtils
                                                             .showBlurredDialoge(
                                                           context,
                                                           dialoge:
                                                               BlurredDialogBox(
                                                             title:
                                                                 "confirmSoldOut"
                                                                     .translate(
                                                                         context),
                                                             acceptButtonName:
                                                                 "comfirmBtnLbl"
                                                                     .translate(
                                                                         context),
                                                             content: Text(
                                                               "soldOutWarning"
                                                                   .translate(
                                                                       context),
                                                             ),
                                                           ),
                                                         );
                                                         if (soldOut == true) {
                                                           Future.delayed(
                                                             Duration.zero,
                                                             () {
                                                               context
                                                                   .read<
                                                                       ChangeMyItemStatusCubit>()
                                                                   .changeMyItemStatus(
                                                                       id: item
                                                                           .id!,
                                                                       status:
                                                                           'sold out');
                                                             },
                                                           );
                                                         }
                                                       },
                                                       child: Text("soldOut"
                                                               .translate(
                                                                   context))
                                                           .color(context.color
                                                               .buttonColor),
                                                     ),
                                                   // Live / Active items -> Mark as Inactive
                                                   if (item.status == "active" ||
                                                       item.status == "approved")
                                                     PopupMenuItem(
                                                       onTap: () {
                                                         Future.delayed(
                                                             Duration.zero, () {
                                                           context
                                                               .read<
                                                                   ChangeMyItemStatusCubit>()
                                                               .changeMyItemStatus(
                                                                   id: item.id!,
                                                                   status:
                                                                       'inactive');
                                                         });
                                                       },
                                                       child: Text("deactivate"
                                                               .translate(
                                                                   context))
                                                           .color(context.color
                                                               .buttonColor),
                                                     ),
                                                   // Inactive items -> Mark as Active
                                                   if (item.status == "inactive")
                                                     PopupMenuItem(
                                                       onTap: () {
                                                         Future.delayed(
                                                             Duration.zero, () {
                                                           context
                                                               .read<
                                                                   ChangeMyItemStatusCubit>()
                                                               .changeMyItemStatus(
                                                                   id: item.id!,
                                                                   status:
                                                                       'active');
                                                         });
                                                       },
                                                       child: Text("activate"
                                                               .translate(
                                                                   context))
                                                           .color(context.color
                                                               .buttonColor),
                                                     ),
                                                   if (item.status == "active" ||
                                                       item.status ==
                                                           "inactive" ||
                                                       item.status == "review" ||
                                                       item.status == "approved")
                                                     PopupMenuItem(
                                                       child: Text("edit"
                                                               .translate(
                                                                   context))
                                                           .color(context.color
                                                               .buttonColor),
                                                       onTap: () {
                                                         addCloudData(
                                                             "edit_request",
                                                             item);
                                                         addCloudData(
                                                             "edit_from",
                                                             widget
                                                                 .getItemsWithStatus);
                                                         Navigator.pushNamed(
                                                             context,
                                                             Routes
                                                                 .addItemDetails,
                                                             arguments: {
                                                               "isEdit": true
                                                             });
                                                       },
                                                     ),
                                                  PopupMenuItem(
                                                    child: Text("lblremove"
                                                            .translate(context))
                                                        .color(context
                                                            .color.buttonColor),
                                                    onTap: () async {
                                                      var delete = await UiUtils
                                                          .showBlurredDialoge(
                                                        context,
                                                        dialoge:
                                                            BlurredDialogBox(
                                                          title: "deleteBtnLbl"
                                                              .translate(
                                                                  context),
                                                          content: Text(
                                                            "deleteitemwarning"
                                                                .translate(
                                                                    context),
                                                          ),
                                                        ),
                                                      );
                                                      if (delete == true) {
                                                        Future.delayed(
                                                          Duration.zero,
                                                          () {
                                                            context
                                                                .read<
                                                                    DeleteItemCubit>()
                                                                .deleteItem(
                                                                    item.id!);
                                                          },
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),*/ /*
                                            */ /* const SizedBox(
                                            width: 14,
                                          ),*/ /*
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                    itemCount: state.items.length,
                  ),
                ),
                if (state.isLoadingMore) UiUtils.progress()
              ],
            );
          }
          return Container();
        },
      ),
    );
  }*/
}
