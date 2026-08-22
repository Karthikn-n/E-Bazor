import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:Ebozor/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:Ebozor/data/cubits/chat/get_seller_chat_users_cubit.dart';
import 'package:Ebozor/ui/screens/chat/chatTile.dart' show ChatTile;
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/ui/screens/widgets/shimmerLoadingContainer.dart' show CustomShimmer;
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(
      builder: (context) {
        return const ChatListScreen();
      },
    );
  }

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final ScrollController _chatBuyerScreenController = ScrollController();
  final ScrollController _chatSellerScreenController = ScrollController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (HiveUtils.isUserAuthenticated()) {
      context.read<GetBuyerChatListCubit>().setContext(context);
      context.read<GetSellerChatListCubit>().setContext(context);
      context.read<GetBuyerChatListCubit>().fetch();
      context.read<GetSellerChatListCubit>().fetch();
      context.read<BlockedUsersListCubit>().blockedUsersList();

      _chatBuyerScreenController.addListener(() {
        if (_chatBuyerScreenController.isEndReached()) {
          if (context.read<GetBuyerChatListCubit>().hasMoreData()) {
            context.read<GetBuyerChatListCubit>().loadMore();
          }
        }
      });

      _chatSellerScreenController.addListener(() {
        if (_chatSellerScreenController.isEndReached()) {
          if (context.read<GetSellerChatListCubit>().hasMoreData()) {
            context.read<GetSellerChatListCubit>().loadMore();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatBuyerScreenController.dispose();
    _chatSellerScreenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.color.secondaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: Text(
          "Messages".translate(context),
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.block_outlined,
              color: context.color.textDefaultColor,
              size: 22,
            ),
            tooltip: "Blocked Users".translate(context),
            onPressed: () {
              Navigator.pushNamed(context, Routes.blockedUserListScreen);
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              border: Border(
                bottom: BorderSide(
                  color: context.color.borderColor.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Buying'.translate(context)),
                Tab(text: 'Selling'.translate(context)),
              ],
              indicatorColor: context.color.territoryColor,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: context.color.territoryColor,
              unselectedLabelColor: context.color.textLightColor,
              labelStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBuyingChatListData(),
          _buildSellingChatListData(),
        ],
      ),
    );
  }

  Widget _buildBuyingChatListData() {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<GetBuyerChatListCubit>().setContext(context);
        context.read<GetBuyerChatListCubit>().fetch();
      },
      color: context.color.territoryColor,
      child: BlocBuilder<GetBuyerChatListCubit, GetBuyerChatListState>(
        builder: (context, state) {
          if (state is GetBuyerChatListFailed) {
            if (state.error is ApiException &&
                (state.error as ApiException).errorMessage == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context.read<GetBuyerChatListCubit>().fetch();
                },
              );
            }
            return _buildEmptyState("No conversations yet");
          }

          if (state is GetBuyerChatListInProgress) {
            return _buildChatListLoadingShimmer();
          }

          if (state is GetBuyerChatListSuccess) {
            if (state.chatedUserList.isEmpty) {
              return _buildEmptyState("No messages from sellers");
            }

            return ListView.separated(
              controller: _chatBuyerScreenController,
              padding: const EdgeInsets.symmetric(vertical: 4),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: state.chatedUserList.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 82,
                endIndent: 16,
                color: context.color.borderColor.withValues(alpha: 0.35),
              ),
              itemBuilder: (context, index) {
                final chatedUser = state.chatedUserList[index];

                return ChatTile(
                  id: chatedUser.sellerId.toString(),
                  itemId: chatedUser.itemId.toString(),
                  profilePicture: chatedUser.seller?.profile ?? "",
                  userName: chatedUser.seller?.name ?? "Seller",
                  itemPicture: chatedUser.item?.image ?? "",
                  itemName: chatedUser.item?.name ?? "",
                  pendingMessageCount: "0",
                  date: chatedUser.createdAt ?? "",
                  itemOfferId: chatedUser.id ?? 0,
                  itemPrice: chatedUser.item?.price ?? 0.0,
                  itemAmount: chatedUser.amount,
                  status: chatedUser.item?.status,
                  buyerId: chatedUser.buyerId.toString(),
                  isPurchased: chatedUser.item?.isPurchased ?? 0,
                  alreadyReview: chatedUser.item?.review != null,
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSellingChatListData() {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<GetSellerChatListCubit>().setContext(context);
        context.read<GetSellerChatListCubit>().fetch();
      },
      color: context.color.territoryColor,
      child: BlocBuilder<GetSellerChatListCubit, GetSellerChatListState>(
        builder: (context, state) {
          if (state is GetSellerChatListFailed) {
            if (state.error is ApiException &&
                (state.error as ApiException).errorMessage == "no-internet") {
              return NoInternet(
                onRetry: () {
                  context.read<GetSellerChatListCubit>().fetch();
                },
              );
            }
            return _buildEmptyState("No conversations yet");
          }

          if (state is GetSellerChatListInProgress) {
            return _buildChatListLoadingShimmer();
          }

          if (state is GetSellerChatListSuccess) {
            if (state.chatedUserList.isEmpty) {
              return _buildEmptyState("No messages from buyers");
            }

            return ListView.separated(
              controller: _chatSellerScreenController,
              padding: const EdgeInsets.symmetric(vertical: 4),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: state.chatedUserList.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 82,
                endIndent: 16,
                color: context.color.borderColor.withValues(alpha: 0.35),
              ),
              itemBuilder: (context, index) {
                final chatedUser = state.chatedUserList[index];

                return ChatTile(
                  id: chatedUser.buyerId.toString(),
                  itemId: chatedUser.itemId.toString(),
                  profilePicture: chatedUser.buyer?.profile ?? "",
                  userName: chatedUser.buyer?.name ?? "Buyer",
                  itemPicture: chatedUser.item?.image ?? "",
                  itemName: chatedUser.item?.name ?? "",
                  pendingMessageCount: "0",
                  date: chatedUser.createdAt ?? "",
                  itemOfferId: chatedUser.id ?? 0,
                  itemPrice: chatedUser.item?.price ?? 0.0,
                  itemAmount: chatedUser.amount,
                  status: chatedUser.item?.status,
                  buyerId: chatedUser.buyerId.toString(),
                  isPurchased: chatedUser.item?.isPurchased ?? 0,
                  alreadyReview: chatedUser.item?.review != null,
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: context.color.territoryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 40,
                  color: context.color.territoryColor,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                message.translate(context),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.color.textDefaultColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "When you chat with buyers or sellers, messages will appear here."
                    .translate(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: context.color.textLightColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatListLoadingShimmer() {
    return ListView.separated(
      itemCount: 8,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 82,
        endIndent: 16,
        color: context.color.borderColor.withValues(alpha: 0.35),
      ),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: context.color.secondaryColor,
          child: Row(
            children: [
              Shimmer.fromColors(
                baseColor: context.color.borderColor.withValues(alpha: 0.4),
                highlightColor: context.color.borderColor.withValues(alpha: 0.15),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer(
                      height: 14,
                      borderRadius: 4,
                      width: context.screenWidth * 0.45,
                    ),
                    const SizedBox(height: 8),
                    CustomShimmer(
                      height: 12,
                      borderRadius: 4,
                      width: context.screenWidth * 0.3,
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

  @override
  bool get wantKeepAlive => true;
}
