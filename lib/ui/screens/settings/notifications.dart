import 'package:Ebozor/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/fetch_notifications_cubit.dart';
import 'package:Ebozor/data/helper/custom_exception.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/model/notification_data.dart';

import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart';

late NotificationData selectedNotification;

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  NotificationsState createState() => NotificationsState();

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(
      builder: (_) => const Notifications(),
    );
  }
}

class NotificationsState extends State<Notifications> {
  late final ScrollController _pageScrollController = ScrollController();

  /* ..addListener(() {
      if (_pageScrollController.isEndReached()) {
        if (context.read<FetchNotificationsCubit>().hasMoreData()) {
          context.read<FetchNotificationsCubit>().fetchNotificationsMore();
        }
      }
    });*/
  List<ItemModel> itemData = [];

  @override
  void initState() {
    super.initState();
    AdHelper.loadInterstitialAd();
    context.read<FetchNotificationsCubit>().fetchNotifications();
    _pageScrollController.addListener(_pageScroll);
  }

  void _pageScroll() {
    if (_pageScrollController.isEndReached()) {
      if (context.read<FetchNotificationsCubit>().hasMoreData()) {
        context.read<FetchNotificationsCubit>().fetchNotificationsMore();
      }
    }
  }

  @override
  void dispose() {
    //Routes.currentRoute = Routes.previousCustomerRoute;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AdHelper.showInterstitialAd();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "notifications".translate(context),
        showBackButton: true,
      ),
      body: BlocBuilder<FetchNotificationsCubit, FetchNotificationsState>(
          builder: (context, state) {
        if (state is FetchNotificationsInProgress) {
          return buildNotificationShimmer();
        }
        if (state is FetchNotificationsFailure) {
          if (state.errorMessage is ApiException) {
            if (state.errorMessage.error == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context.read<FetchNotificationsCubit>().fetchNotifications();
                },
              );
            }
          }

          return const SomethingWentWrong();
        }

        if (state is FetchNotificationsSuccess) {
          if (state.notificationdata.isEmpty) {
            return NoDataFound(
              onTap: () {
                context.read<FetchNotificationsCubit>().fetchNotifications();
              },
            );
          }

          return buildNotificationListWidget(state);
        }

        return const SizedBox.square();
      }),
    );
  }

  Widget buildNotificationShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemCount: 8,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: <Widget>[
              const CustomShimmer(
                width: 48,
                height: 48,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CustomShimmer(
                      height: 12,
                      width: context.screenWidth * 0.5,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 8),
                    CustomShimmer(
                      height: 10,
                      width: context.screenWidth * 0.65,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 8),
                    CustomShimmer(
                      height: 9,
                      width: 80,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.color.territoryColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Icon(
          Icons.notifications_active_outlined,
          color: context.color.territoryColor,
          size: 22,
        ),
      ),
    );
  }

  Widget buildNotificationListWidget(FetchNotificationsSuccess state) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _pageScrollController,
            // physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 78,
              color: context.color.borderColor.withValues(alpha: 0.55),
            ),
            itemCount: state.notificationdata.length,
            itemBuilder: (context, index) {
              NotificationData notificationData = state.notificationdata[index];
              final hasImage = notificationData.image != null &&
                  notificationData.image!.isNotEmpty;

              return Material(
                color: context.color.secondaryColor,
                child: InkWell(
                  onTap: () {
                    selectedNotification = notificationData;
                    HelperUtils.goToNextPage(
                        Routes.notificationDetailPage, context, false);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (hasImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: UiUtils.getImage(
                              notificationData.image!,
                              height: 48,
                              width: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          _buildFallbackIcon(),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                (notificationData.title ?? "").firstUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.color.textDefaultColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (notificationData.message ?? "")
                                    .firstUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: context.color.textLightColor,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (notificationData.createdAt != null &&
                                  notificationData.createdAt!.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: context.color.textLightColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      notificationData.createdAt!.formatDate(),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: context.color.textLightColor,
                                        fontWeight: FontWeight.w500,
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
                ),
              );
            },
          ),
        ),
        if (state.isLoadingMore) UiUtils.progress(),
      ],
    );
  }

  Future<List<ItemModel>> getItemById() async {
    Map<String, dynamic> body = {
      // ApiParams.id: itemsId,//String itemsId
    };

    var response = await Api.get(url: Api.getItemApi, queryParameters: body);

    if (!response[Api.error]) {
      List list = response['data'];
      itemData = list.map((model) => ItemModel.fromJson(model)).toList();
    } else {
      throw CustomException(response[Api.message]);
    }
    return itemData;
  }
}
