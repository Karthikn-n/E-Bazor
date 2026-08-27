import 'package:Ebozor/data/cubits/chat/delete_message_cubit.dart';
import 'package:Ebozor/data/cubits/chat/load_chat_messages.dart';
import 'package:Ebozor/ui/screens/chat/chat_screen.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/notification/notification_service.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import 'package:shimmer/shimmer.dart';

class ChatTile extends StatelessWidget {
  final String profilePicture;
  final String userName;
  final String itemPicture;
  final String itemName;
  final String itemId;
  final String pendingMessageCount;
  final String id;
  final String date;
  final int itemOfferId;
  final double itemPrice;
  final double? itemAmount;
  final String? status;
  final String? buyerId;
  final int isPurchased;
  final bool alreadyReview;

  const ChatTile({
    super.key,
    required this.profilePicture,
    required this.userName,
    required this.itemPicture,
    required this.itemName,
    required this.pendingMessageCount,
    required this.id,
    required this.date,
    required this.itemId,
    required this.itemOfferId,
    required this.itemPrice,
    this.status,
    this.itemAmount,
    this.buyerId,
    required this.isPurchased,
    required this.alreadyReview,
  });

  String _formatChatDate(String rawDate) {
    try {
      final parsed = DateTime.parse(rawDate).toLocal();
      final now = DateTime.now();
      final difference = now.difference(parsed);

      if (difference.inDays == 0 && parsed.day == now.day) {
        return parsed.toIso8601String().formatDate(format: "hh:mm aa");
      } else if (difference.inDays <= 1 || (difference.inDays == 0 && parsed.day != now.day)) {
        return "Yesterday";
      } else if (difference.inDays < 7) {
        return parsed.toIso8601String().formatDate(format: "EEE");
      } else {
        return parsed.toIso8601String().formatDate(format: "dd MMM");
      }
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectivePrice = itemAmount ?? itemPrice;

    return Material(
      color: context.color.secondaryColor,
      child: InkWell(
        onTap: () {
          currentlyChatingWith = id;
          currentlyChatItemId = itemId;
          Navigator.push(
            context,
            BlurredRouter(
              builder: (context) {
                return MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (context) => LoadChatMessagesCubit(),
                    ),
                    BlocProvider(
                      create: (context) => DeleteMessageCubit(),
                    ),
                  ],
                  child: Builder(builder: (context) {
                    return ChatScreen(
                      profilePicture: profilePicture,
                      itemTitle: itemName,
                      userId: id,
                      itemImage: itemPicture,
                      userName: userName,
                      itemId: itemId,
                      date: date,
                      itemOfferId: itemOfferId,
                      itemPrice: itemPrice,
                      itemOfferPrice: itemAmount,
                      status: status,
                      buyerId: buyerId,
                      alreadyReview: alreadyReview,
                      isPurchased: isPurchased,
                    );
                  }),
                );
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar with overlapping item thumbnail
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // User profile avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.color.territoryColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: context.color.borderColor.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: ClipOval(
                        child: profilePicture.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: profilePicture,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Shimmer.fromColors(
                                  baseColor: context.color.borderColor.withValues(alpha: 0.4),
                                  highlightColor: context.color.borderColor.withValues(alpha: 0.15),
                                  child: Container(
                                    color: Colors.white,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.person_rounded,
                                  color: context.color.territoryColor,
                                  size: 24,
                                ),
                              )
                            : SvgPicture.asset(
                                AppIcons.profile,
                                fit: BoxFit.scaleDown,
                                colorFilter: ColorFilter.mode(
                                  context.color.territoryColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                      ),
                    ),
                    // Overlapping Item Image badge
                    if (itemPicture.isNotEmpty)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.color.secondaryColor,
                            border: Border.all(
                              color: context.color.secondaryColor,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              )
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: itemPicture,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Shimmer.fromColors(
                                baseColor: context.color.borderColor.withValues(alpha: 0.4),
                                highlightColor: context.color.borderColor.withValues(alpha: 0.15),
                                child: Container(
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (_, __, ___) => Icon(
                                Icons.shopping_bag_outlined,
                                size: 12,
                                color: context.color.territoryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Middle Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User Name & Date Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            userName.isNotEmpty ? userName : "User",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.color.textDefaultColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatChatDate(date),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: context.color.textLightColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Item Title & Price / Status Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            itemName.isNotEmpty ? itemName : "Item Offer",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: context.color.textLightColor,
                            ),
                          ),
                        ),
                        if (effectivePrice > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.color.territoryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              "${Constant.currencySymbol} ${effectivePrice.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.color.territoryColor,
                              ),
                            ),
                          ),
                        ],
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
  }
}
