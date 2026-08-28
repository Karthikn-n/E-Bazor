import 'dart:async';
import 'dart:io';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/add_item_review_cubit.dart';
import 'package:Ebozor/data/cubits/chat/block_user_cubit.dart';
import 'package:Ebozor/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:Ebozor/data/cubits/chat/delete_message_cubit.dart';
import 'package:Ebozor/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:Ebozor/data/cubits/chat/get_seller_chat_users_cubit.dart';
import 'package:Ebozor/data/cubits/chat/load_chat_messages.dart';
import 'package:Ebozor/data/cubits/chat/unblock_user_cubit.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/model/chat/chated_user_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/ui/screens/chat/chat_audio/widgets/chat_widget.dart';
import 'package:Ebozor/ui/screens/chat/chat_audio/widgets/record_button.dart';
import 'package:Ebozor/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/ApiService/Socketservice.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/notification/chat_message_handler.dart';
import 'package:Ebozor/utils/notification/notification_service.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';

int totalMessageCount = 0;
ValueNotifier<bool> showDeletebutton = ValueNotifier<bool>(false);
ValueNotifier<int> selectedMessageid = ValueNotifier<int>(-5);

class ChatScreen extends StatefulWidget {
  final String? from;
  final int itemOfferId;
  final double? itemOfferPrice;
  final double itemPrice;
  final String profilePicture;
  final String userName;
  final String itemImage;
  final String itemTitle;
  final String userId;
  final String itemId;
  final String date;
  final String? status;
  final String? buyerId;
  final int isPurchased;
  final bool alreadyReview;

  const ChatScreen({
    super.key,
    required this.profilePicture,
    required this.userName,
    required this.itemImage,
    required this.itemTitle,
    required this.userId,
    required this.itemId,
    required this.date,
    this.from,
    required this.itemOfferId,
    this.status,
    required this.itemPrice,
    this.itemOfferPrice,
    this.buyerId,
    required this.isPurchased,
    required this.alreadyReview,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _recordButtonAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  final TextEditingController controller = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _offerPriceController = TextEditingController();
  final GlobalKey<FormState> _offerInputFormKey = GlobalKey<FormState>();

  PlatformFile? messageAttachment;
  bool isFetchedFirstTime = false;
  bool showRecordButton = true;
  bool _showMakeOfferInput = false;
  bool _isSubmittingOffer = false;
  bool _isMarkingSold = false;
  int _rating = 0;

  late int _currentItemOfferId;
  double? _currentItemOfferPrice;
  late String _currentStatus;

  bool get _isCurrentUserSeller {
    final currentUserId = HiveUtils.getUserId();
    return widget.buyerId != null && currentUserId != widget.buyerId;
  }

  bool get _isSoldOut {
    final norm = _currentStatus
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    return norm == 'sold out' || norm == 'sold';
  }

  Future<void> _markSoldToChatBuyer() async {
    if (_isMarkingSold) return;
    final parsedItemId = int.tryParse(widget.itemId) ?? 0;
    final buyerUserId =
        int.tryParse(widget.buyerId ?? '') ?? int.tryParse(widget.userId);
    if (parsedItemId == 0 || buyerUserId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'Unable to identify this buyer. Please try from the ad details screen.',
      );
      return;
    }

    final buyerName =
        widget.userName.trim().isEmpty ? 'this buyer' : widget.userName.trim();
    final wasSoldOut = _isSoldOut;
    final confirmed = await UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        title: wasSoldOut ? 'Record another sale?' : 'Sold to $buyerName?',
        acceptButtonName: wasSoldOut ? 'Record sale' : 'Confirm sale',
        content: Text(
          wasSoldOut
              ? 'This will add $buyerName as another buyer for this ad.'
              : 'Mark this ad as sold to $buyerName? The status will update immediately.',
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final previousStatus = _currentStatus;
    setState(() {
      _isMarkingSold = true;
      _currentStatus = 'sold out';
    });

    try {
      final response = await ItemRepository().changeMyItemStatus(
        itemId: parsedItemId,
        status: 'sold out',
        userId: buyerUserId,
      );
      if (response['error'] == true) {
        throw response['message']?.toString() ?? 'Could not record this sale';
      }
      if (!mounted) return;
      setState(() => _isMarkingSold = false);
      try {
        context
            .read<GetSellerChatListCubit>()
            .updateItemStatus(parsedItemId, 'sold out');
      } catch (_) {}
      try {
        context
            .read<GetBuyerChatListCubit>()
            .updateItemStatus(parsedItemId, 'sold out');
      } catch (_) {}
      HelperUtils.showSnackBarMessage(
        context,
        wasSoldOut ? 'Sale recorded for $buyerName' : 'Item sold to $buyerName',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMarkingSold = false;
        _currentStatus = previousStatus;
      });
      HelperUtils.showSnackBarMessage(context, e.toString());
    }
  }

  final ScrollController _pageScrollController = ScrollController();
  final ChatSocketService _socketService = ChatSocketService();
  Timer? _typingTimer;

  final List<String> supportedImageTypes = [
    'jpeg',
    'jpg',
    'png',
    'gif',
    'webp',
    'animated_webp',
  ];

  @override
  void initState() {
    super.initState();

    _currentItemOfferId = widget.itemOfferId;
    _currentItemOfferPrice = widget.itemOfferPrice;
    _currentStatus = widget.status ?? "";

    ChatMessageHandler.flushMessages();

    if (_currentItemOfferId > 0) {
      context
          .read<LoadChatMessagesCubit>()
          .load(itemOfferId: _currentItemOfferId);

      if (!_socketService.isConnected) _socketService.connect();
      _socketService.joinOffer(_currentItemOfferId);
      _startPolling();
    }

    currentlyChatItemId = widget.itemId;
    currentlyChatingWith = widget.userId;

    controller.addListener(() {
      if (controller.text.isNotEmpty) {
        if (showRecordButton) {
          setState(() => showRecordButton = false);
        }
        if (_currentItemOfferId > 0) {
          _socketService.typingStart(_currentItemOfferId);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 2), () {
            if (_currentItemOfferId > 0) {
              _socketService.typingStop(_currentItemOfferId);
            }
          });
        }
      } else {
        if (!showRecordButton && messageAttachment == null) {
          setState(() => showRecordButton = true);
        }
        if (_currentItemOfferId > 0) {
          _socketService.typingStop(_currentItemOfferId);
        }
      }
    });

    _pageScrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.status == "sold out" &&
          widget.isPurchased == 1 &&
          !widget.alreadyReview) {
        ratingsAlertDialog();
      }
    });
  }

  void _scrollListener() {
    if (_pageScrollController.position.pixels >=
        _pageScrollController.position.maxScrollExtent - 50) {
      if (context.read<LoadChatMessagesCubit>().hasMoreChat()) {
        context.read<LoadChatMessagesCubit>().loadMore();
      }
    }
  }

  Timer? _pollingTimer;

  void _startPolling() {
    _pollingTimer?.cancel();
    if (_currentItemOfferId > 0) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted && _currentItemOfferId > 0) {
          context
              .read<LoadChatMessagesCubit>()
              .load(itemOfferId: _currentItemOfferId, isBackground: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    if (_currentItemOfferId > 0) {
      _socketService.typingStop(_currentItemOfferId);
      _socketService.leaveOffer(_currentItemOfferId);
    }
    _typingTimer?.cancel();
    _pageScrollController.removeListener(_scrollListener);
    _pageScrollController.dispose();
    controller.dispose();
    _feedbackController.dispose();
    _offerPriceController.dispose();
    _recordButtonAnimation.dispose();
    super.dispose();
  }

  Future<void> _navigateToAdDetails() async {
    final parsedId = int.tryParse(widget.itemId) ?? 0;
    final normalizedStatus = (widget.status ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    final isSoldOut = normalizedStatus == 'sold out';
    final currentUser = HiveUtils.getUserDetails();
    final isCurrentUserSeller =
        widget.buyerId != null && HiveUtils.getUserId() != widget.buyerId;

    ItemModel targetItem = ItemModel(
      id: parsedId != 0 ? parsedId : null,
      name: widget.itemTitle,
      description: '',
      price: widget.itemPrice,
      image: widget.itemImage,
      status: widget.status ?? 'active',
      active: !isSoldOut,
      created: DateTime.tryParse(widget.date) != null
          ? widget.date
          : DateTime.now().toUtc().toIso8601String(),
      totalLikes: 0,
      views: 0,
      isLike: false,
      isFeature: false,
      isAlreadyOffered: true,
      isAlreadyReported: false,
      isPurchased: widget.isPurchased,
      galleryImages: const [],
      itemOffers: const [],
      customFields: const [],
      review: const [],
      user: isCurrentUserSeller
          ? User(
              id: currentUser.id,
              name: currentUser.name,
              profile: currentUser.profile,
              mobile: currentUser.mobile,
            )
          : User(
              id: int.tryParse(widget.userId),
              name: widget.userName,
              profile: widget.profilePicture,
            ),
    );

    // Public get-item intentionally excludes sold listings. Navigate with the
    // chat payload immediately instead of waiting for requests that cannot
    // return the sold item; AdDetailsScreen can still enrich it if available.
    if (!isSoldOut && parsedId != 0) {
      Widgets.showLoader(context);
      try {
        final dataOutput = await ItemRepository().fetchItemFromItemId(parsedId);
        if (dataOutput.modelList.isNotEmpty) {
          targetItem = dataOutput.modelList.first;
        }
      } catch (_) {
        // The safe chat-list model above is enough to open the details screen.
      } finally {
        if (context.mounted) Widgets.hideLoder(context);
      }
    }

    if (context.mounted) {
      Navigator.pushNamed(
        context,
        Routes.adDetailsScreen,
        arguments: {"model": targetItem},
      );
    }
  }

  Future<void> _sendMessage(String text,
      {String? filePath, String? audioPath}) async {
    if (text.trim().isEmpty && filePath == null && audioPath == null) return;

    if (_currentItemOfferId == 0) {
      try {
        final response = await ItemRepository()
            .makeAnOfferItem(int.parse(widget.itemId), null);
        if (response['data'] != null && response['data']['id'] != null) {
          final newOfferId = response['data']['id'] is int
              ? response['data']['id'] as int
              : int.parse(response['data']['id'].toString());
          setState(() {
            _currentItemOfferId = newOfferId;
            _showMakeOfferInput = false;
          });
          if (!_socketService.isConnected) _socketService.connect();
          _socketService.joinOffer(_currentItemOfferId);

          try {
            if (response['data']['buyer'] != null) {
              context
                  .read<GetBuyerChatListCubit>()
                  .addNewChat(ChatedUser.fromJson(response['data']));
            }
          } catch (_) {}
        } else {
          HelperUtils.showSnackBarMessage(
              context, "Could not initiate chat. Please try again.");
          return;
        }
      } catch (e) {
        HelperUtils.showSnackBarMessage(context, "Could not initiate chat: $e");
        return;
      }
    }

    _socketService.typingStop(_currentItemOfferId);
    _socketService.sendMessage(_currentItemOfferId, text,
        file: filePath, audio: audioPath);

    ChatMessageHandler.add(ChatMessage(
      key: ValueKey(DateTime.now().millisecondsSinceEpoch),
      message: text,
      senderId: int.parse(HiveUtils.getUserId()!),
      createdAt: DateTime.now().toString(),
      updatedAt: DateTime.now().toString(),
      isSentNow: true,
      audio: audioPath ?? "",
      file: filePath ?? "",
      itemOfferId: _currentItemOfferId,
    ));

    totalMessageCount++;
    controller.clear();
    messageAttachment = null;
    setState(() {
      showRecordButton = true;
    });
  }

  Future<void> _submitOffer(double price) async {
    setState(() {
      _isSubmittingOffer = true;
    });

    try {
      final response = await ItemRepository()
          .makeAnOfferItem(int.parse(widget.itemId), price);
      if (response['error'] == false || response['data'] != null) {
        final data = response['data'];
        final newOfferId = data != null && data['id'] != null
            ? (data['id'] is int
                ? data['id'] as int
                : int.parse(data['id'].toString()))
            : 0;

        setState(() {
          if (newOfferId > 0) {
            _currentItemOfferId = newOfferId;
          }
          _currentItemOfferPrice = price;
          _showMakeOfferInput = false;
          _isSubmittingOffer = false;
        });

        if (!_socketService.isConnected) _socketService.connect();
        if (_currentItemOfferId > 0) {
          _socketService.joinOffer(_currentItemOfferId);
          _socketService.sendMessage(_currentItemOfferId,
              "Offer made: ${Constant.currencySymbol} $price");
        }

        try {
          if (data != null && data['buyer'] != null) {
            context
                .read<GetBuyerChatListCubit>()
                .addNewChat(ChatedUser.fromJson(data));
          }
        } catch (_) {}

        if (_currentItemOfferId > 0) {
          context
              .read<LoadChatMessagesCubit>()
              .load(itemOfferId: _currentItemOfferId);
        }

        HelperUtils.showSnackBarMessage(context,
            response['message']?.toString() ?? "Offer submitted successfully");
      } else {
        setState(() {
          _isSubmittingOffer = false;
        });
        HelperUtils.showSnackBarMessage(context,
            response['message']?.toString() ?? "Failed to submit offer");
      }
    } catch (e) {
      setState(() {
        _isSubmittingOffer = false;
      });
      HelperUtils.showSnackBarMessage(context, e.toString());
    }
  }

  void _showSafetyTipsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade100,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text: "Safety ",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: "Tips",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w400,
                          color: context.color.territoryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.color.territoryColor,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        "Welcome To Ebozor! ✨ Buy And Sell Anything You Want—Easily And For Free! ✨ Posting An Ad Is Completely Free, So Start Listing Your Items Today. Happy Buying & Selling! ✨",
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.color.territoryColor,
                      side: BorderSide(
                          color: context.color.territoryColor, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      setState(() {
                        _showMakeOfferInput = true;
                      });
                    },
                    child: Text(
                      "Continue".translate(context),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.color.territoryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMakeOfferInputCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.color.borderColor.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Form(
            key: _offerInputFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Make an offer".translate(context),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _offerPriceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: context.color.textDefaultColor,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Please enter offer price".translate(context);
                    }
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) {
                      return "valueMustBeGreaterThanZeroLbl".translate(context);
                    }
                    if (widget.itemPrice > 0 && parsed > widget.itemPrice) {
                      return "offerPriceWarning".translate(context);
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: "Type Offer Price".translate(context),
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: context.color.textLightColor,
                      fontWeight: FontWeight.normal,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: context.color.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color:
                              context.color.borderColor.withValues(alpha: 0.8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color:
                              context.color.borderColor.withValues(alpha: 0.8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: context.color.territoryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showMakeOfferInput = false;
                        });
                      },
                      child: Text(
                        "Offer later".translate(context),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.color.territoryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isSubmittingOffer
                          ? null
                          : () async {
                              if (_offerInputFormKey.currentState?.validate() ==
                                  true) {
                                final price = double.tryParse(
                                    _offerPriceController.text.trim());
                                if (price != null) {
                                  await _submitOffer(price);
                                }
                              }
                            },
                      child: _isSubmittingOffer
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              "Submit".translate(context),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoConversationView() {
    if (_showMakeOfferInput) {
      return _buildMakeOfferInputCard();
    }

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.color.territoryColor.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.chat_outlined,
                color: context.color.territoryColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No Conversation Yet!".translate(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Send a message or make an offer directly to start chatting with the seller."
                  .translate(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: context.color.textLightColor,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.territoryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                _showSafetyTipsDialog();
              },
              icon: const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                "Make an offer".translate(context),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void ratingsAlertDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: context.color.secondaryColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Center(child: Text("rateSeller".translate(context))),
          content: BlocListener<AddItemReviewCubit, AddItemReviewState>(
            listener: (context, state) {
              if (state is AddItemReviewInSuccess) {
                Widgets.hideLoder(context);
                Navigator.pop(context);
                context
                    .read<GetBuyerChatListCubit>()
                    .updateAlreadyReview(int.parse(widget.itemId));
                HelperUtils.showSnackBarMessage(context, state.responseMessage);
              }
              if (state is AddItemReviewFailure) {
                Widgets.hideLoder(context);
                Navigator.pop(context);
                HelperUtils.showSnackBarMessage(
                    context, state.error.toString());
              }
              if (state is AddItemReviewInProgress) {
                Widgets.showLoader(context);
              }
            },
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setStater) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('rateYourExperience'.translate(context))
                          .color(context.color.textLightColor),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: List.generate(
                          5,
                          (index) => InkWell(
                            child: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 30,
                            ),
                            onTap: () {
                              setStater(() {
                                _rating = index + 1;
                              });
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _feedbackController,
                        decoration: InputDecoration(
                          hintText: 'shareYourExperience'.translate(context),
                          hintStyle:
                              TextStyle(color: context.color.textLightColor),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide:
                                BorderSide(color: context.color.territoryColor),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide: BorderSide(
                              color: context.color.textLightColor
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          UiUtils.buildButton(
                            context,
                            onPressed: () {
                              _feedbackController.clear();
                              _rating = 0;
                              Navigator.of(context).pop();
                            },
                            buttonTitle: "cancelBtnLbl".translate(context),
                            radius: 8,
                            fontSize: 12,
                            width: context.screenWidth / 4,
                            textColor: context.color.textDefaultColor,
                            buttonColor: context.color.backgroundColor,
                            showElevation: false,
                            height: 39,
                          ),
                          UiUtils.buildButton(
                            context,
                            showElevation: false,
                            onPressed: () {
                              context.read<AddItemReviewCubit>().addItemReview(
                                  itemId: int.parse(widget.itemId),
                                  rating: _rating,
                                  review: _feedbackController.text.trim());
                            },
                            fontSize: 12,
                            disabled: _rating < 1,
                            disabledColor: context.color.deactivateColor,
                            buttonTitle: "submitBtnLbl".translate(context),
                            radius: 8,
                            width: context.screenWidth / 4,
                            textColor: context.color.secondaryColor,
                            buttonColor: context.color.territoryColor,
                            height: 39,
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagesLoadingShimmer() {
    return ListView.builder(
      itemCount: 6,
      reverse: true,
      shrinkWrap: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemBuilder: (context, index) {
        final isMe = index % 2 == 0;
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Shimmer.fromColors(
              baseColor: context.color.borderColor.withValues(alpha: 0.35),
              highlightColor: context.color.borderColor.withValues(alpha: 0.1),
              child: Container(
                width: context.screenWidth * (isMe ? 0.6 : 0.7),
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatInputBar() {
    final attachmentMIME =
        (messageAttachment?.path?.split(".").last.toLowerCase()) ?? "";

    return Container(
      color: context.color.secondaryColor,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (messageAttachment != null) ...[
              if (supportedImageTypes.contains(attachmentMIME)) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.color.secondaryColor,
                    border: Border.all(
                        color: context.color.borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 64,
                          width: 64,
                          child: GestureDetector(
                            onTap: () {
                              UiUtils.showFullScreenImage(context,
                                  provider: FileImage(File(
                                    messageAttachment?.path ?? "",
                                  )));
                            },
                            child: Image.file(
                              File(messageAttachment?.path ?? ""),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              messageAttachment?.name ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.color.textDefaultColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              HelperUtils.getFileSizeString(
                                bytes: messageAttachment!.size,
                              ).toString(),
                              style: TextStyle(
                                color: context.color.textLightColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          setState(() {
                            messageAttachment = null;
                            if (controller.text.isEmpty) {
                              showRecordButton = true;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                )
              ] else ...[
                Container(
                  color: context.color.secondaryColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: AttachmentMessage(url: messageAttachment!.path!),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                border: Border(
                  top: BorderSide(
                    color: context.color.borderColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
              ),
              child: Directionality(
                textDirection: Directionality.of(context),
                child: widget.status == "review" ||
                        widget.status == "rejected" ||
                        widget.status == "inactive"
                    ? Container(
                        height: 40,
                        width: double.maxFinite,
                        color: context.color.secondaryColor,
                        alignment: Alignment.center,
                        child: Text(
                          "${"thisItemIs".translate(context)} ${widget.status}",
                          style: TextStyle(
                            fontSize: 14,
                            color: context.color.textLightColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BlocProvider(
                            create: (context) => UnblockUserCubit(),
                            child: Builder(builder: (context) {
                              bool isBlocked = context
                                  .read<BlockedUsersListCubit>()
                                  .isUserBlocked(int.parse(widget.userId));
                              return BlocConsumer<BlockedUsersListCubit,
                                  BlockedUsersListState>(
                                listener: (context, state) {
                                  if (state is BlockedUsersListSuccess) {
                                    isBlocked = context
                                        .read<BlockedUsersListCubit>()
                                        .isUserBlocked(
                                            int.parse(widget.userId));
                                  }
                                },
                                builder: (context, blockedUsersListState) {
                                  return isBlocked
                                      ? BlocListener<UnblockUserCubit,
                                          UnblockUserState>(
                                          listener: (context, unblockState) {
                                            if (unblockState
                                                is UnblockUserSuccess) {
                                              context
                                                  .read<BlockedUsersListCubit>()
                                                  .unblockUser(
                                                      int.parse(widget.userId));
                                              HelperUtils.showSnackBarMessage(
                                                  context,
                                                  unblockState.message);
                                            } else if (unblockState
                                                is UnblockUserFail) {
                                              HelperUtils.showSnackBarMessage(
                                                  context,
                                                  unblockState.error
                                                      .toString());
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 6),
                                            child: InkWell(
                                              child: Text(
                                                "youBlockedThisContact"
                                                    .translate(context),
                                                style: TextStyle(
                                                  color: context
                                                      .color.textColorDark
                                                      .withValues(alpha: 0.7),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              onTap: () async {
                                                var unBlock = await UiUtils
                                                    .showBlurredDialoge(
                                                  context,
                                                  dialoge: BlurredDialogBox(
                                                    acceptButtonName:
                                                        "unBlockLbl"
                                                            .translate(context),
                                                    content: Text(
                                                      "${"unBlockLbl".translate(context)}\t${widget.userName}\t${"toSendMessage".translate(context)}"
                                                          .translate(context),
                                                    ),
                                                  ),
                                                );
                                                if (unBlock == true) {
                                                  context
                                                      .read<UnblockUserCubit>()
                                                      .unBlockUser(
                                                        blockUserId: int.parse(
                                                            widget.userId),
                                                      );
                                                }
                                              },
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink();
                                },
                              );
                            }),
                          ),

                          // typing status
                          ValueListenableBuilder<bool>(
                            valueListenable: _socketService.isOtherUserTyping,
                            builder: (context, isTyping, _) {
                              if (!isTyping) return const SizedBox();
                              return Padding(
                                padding:
                                    const EdgeInsets.only(left: 12, bottom: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "${widget.userName} is typing...",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: context.color.textLightColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: context.color.backgroundColor,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: context.color.borderColor
                                          .withValues(alpha: 0.8),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        onPressed: () async {
                                          if (messageAttachment == null) {
                                            FilePickerResult? pickedAttachment =
                                                await FilePicker.platform
                                                    .pickFiles(
                                              allowMultiple: false,
                                              type: FileType.custom,
                                              allowedExtensions: [
                                                'jpg',
                                                'jpeg',
                                                'png'
                                              ],
                                            );
                                            messageAttachment =
                                                pickedAttachment?.files.first;
                                            showRecordButton = false;
                                            setState(() {});
                                          } else {
                                            messageAttachment = null;
                                            if (controller.text.isEmpty) {
                                              showRecordButton = true;
                                            }
                                            setState(() {});
                                          }
                                        },
                                        icon: messageAttachment != null
                                            ? const Icon(Icons.close_rounded,
                                                size: 20)
                                            : Icon(
                                                Icons.attach_file_rounded,
                                                size: 20,
                                                color: context
                                                    .color.textLightColor,
                                              ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: controller,
                                          cursorColor:
                                              context.color.territoryColor,
                                          onTap: () {
                                            showDeletebutton.value = false;
                                          },
                                          textInputAction:
                                              TextInputAction.newline,
                                          minLines: 1,
                                          maxLines: 4,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            color:
                                                context.color.textDefaultColor,
                                          ),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              vertical: 10,
                                              horizontal: 4,
                                            ),
                                            border: InputBorder.none,
                                            hintText: "Type a message..."
                                                .translate(context),
                                            hintStyle: TextStyle(
                                              color:
                                                  context.color.textLightColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (showRecordButton)
                                RecordButton(
                                  controller: _recordButtonAnimation,
                                  callback: (path) async {
                                    await _sendMessage("", audioPath: path);
                                  },
                                  isSending: false,
                                ),
                              if (!showRecordButton)
                                GestureDetector(
                                  onTap: () async {
                                    if (controller.text.trim().isEmpty &&
                                        messageAttachment == null) return;
                                    final text = controller.text.trim();
                                    final filePath = messageAttachment?.path;
                                    await _sendMessage(text,
                                        filePath: filePath);
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: context.color.territoryColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.color.territoryColor
                                              .withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
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

  @override
  Widget build(BuildContext context) {
    var chatBackground = "assets/chat_background/chat_background.svg";

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: PopScope(
        canPop: showDeletebutton.value != true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            currentlyChatingWith = "";
            currentlyChatItemId = "";
            showDeletebutton.value = false;
            ChatMessageHandler.flushMessages();
            return;
          }
          if (showDeletebutton.value == true) {
            showDeletebutton.value = false;
            selectedMessageid.value = -5;
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: context.color.backgroundColor,
          appBar: AppBar(
            centerTitle: false,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: context.color.textDefaultColor,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: context.color.secondaryColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0.5,
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.color.territoryColor.withValues(alpha: 0.1),
                  ),
                  child: ClipOval(
                    child: widget.profilePicture.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.profilePicture,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Shimmer.fromColors(
                              baseColor: context.color.borderColor
                                  .withValues(alpha: 0.4),
                              highlightColor: context.color.borderColor
                                  .withValues(alpha: 0.15),
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.person_rounded,
                              color: context.color.territoryColor,
                              size: 20,
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.userName.isNotEmpty ? widget.userName : "User",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.color.textDefaultColor,
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _socketService.isOtherUserTyping,
                        builder: (context, isTyping, _) {
                          return Text(
                            isTyping
                                ? "typing...".translate(context)
                                : "Online".translate(context),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isTyping
                                  ? context.color.territoryColor
                                  : Colors.green.shade600,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              MultiBlocProvider(
                providers: [
                  BlocProvider(create: (context) => UnblockUserCubit()),
                  BlocProvider(create: (context) => BlockUserCubit()),
                ],
                child: Builder(builder: (context) {
                  bool isBlocked = context
                      .read<BlockedUsersListCubit>()
                      .isUserBlocked(int.parse(widget.userId));
                  return BlocConsumer<BlockedUsersListCubit,
                      BlockedUsersListState>(
                    listener: (context, state) {
                      if (state is BlockedUsersListSuccess) {
                        isBlocked = context
                            .read<BlockedUsersListCubit>()
                            .isUserBlocked(int.parse(widget.userId));
                      }
                    },
                    builder: (context, blockedUsersListState) {
                      return BlocListener<BlockUserCubit, BlockUserState>(
                        listener: (context, blockState) {
                          if (blockState is BlockUserSuccess) {
                            context
                                .read<BlockedUsersListCubit>()
                                .addBlockedUser(
                                  BlockedUserModel(
                                    id: int.parse(widget.userId),
                                    name: widget.userName,
                                    profile: widget.profilePicture,
                                  ),
                                );
                            HelperUtils.showSnackBarMessage(
                                context, blockState.message);
                          } else if (blockState is BlockUserFail) {
                            HelperUtils.showSnackBarMessage(
                                context, blockState.error.toString());
                          }
                        },
                        child: BlocListener<UnblockUserCubit, UnblockUserState>(
                          listener: (context, unblockState) {
                            if (unblockState is UnblockUserSuccess) {
                              context
                                  .read<BlockedUsersListCubit>()
                                  .unblockUser(int.parse(widget.userId));
                              HelperUtils.showSnackBarMessage(
                                  context, unblockState.message);
                            } else if (unblockState is UnblockUserFail) {
                              HelperUtils.showSnackBarMessage(
                                  context, unblockState.error.toString());
                            }
                          },
                          child: Padding(
                            padding:
                                const EdgeInsetsDirectional.only(end: 16.0),
                            child: PopupMenuButton(
                              color: context.color.secondaryColor,
                              offset: const Offset(-12, 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SvgPicture.asset(
                                AppIcons.more,
                                width: 20,
                                height: 20,
                                fit: BoxFit.contain,
                                colorFilter: ColorFilter.mode(
                                  context.color.textDefaultColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                              itemBuilder: (context) => [
                                if (!isBlocked)
                                  PopupMenuItem(
                                    onTap: () async {
                                      var block =
                                          await UiUtils.showBlurredDialoge(
                                        context,
                                        dialoge: BlurredDialogBox(
                                          acceptButtonName:
                                              "blockLbl".translate(context),
                                          title:
                                              "${"blockLbl".translate(context)}\t${widget.userName}?",
                                          content: Text(
                                            "blockWarning".translate(context),
                                          ),
                                        ),
                                      );
                                      if (block == true) {
                                        context
                                            .read<BlockUserCubit>()
                                            .blockUser(
                                              blockUserId:
                                                  int.parse(widget.userId),
                                            );
                                      }
                                    },
                                    child: Text("blockLbl".translate(context))
                                        .color(context.color.textColorDark),
                                  ),
                                if (isBlocked)
                                  PopupMenuItem(
                                    onTap: () async {
                                      var unBlock =
                                          await UiUtils.showBlurredDialoge(
                                        context,
                                        dialoge: BlurredDialogBox(
                                          acceptButtonName:
                                              "unBlockLbl".translate(context),
                                          title:
                                              "${"unBlockLbl".translate(context)}\t${widget.userName}?",
                                          content: Text(
                                            "unBlockWarning".translate(context),
                                          ),
                                        ),
                                      );
                                      if (unBlock == true) {
                                        context
                                            .read<UnblockUserCubit>()
                                            .unBlockUser(
                                              blockUserId:
                                                  int.parse(widget.userId),
                                            );
                                      }
                                    },
                                    child: Text("unBlockLbl".translate(context))
                                        .color(context.color.textColorDark),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              )
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(66),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                decoration: BoxDecoration(
                  color: context.color.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.color.borderColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _navigateToAdDetails,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: CachedNetworkImage(
                                imageUrl: widget.itemImage,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Shimmer.fromColors(
                                  baseColor: context.color.borderColor
                                      .withValues(alpha: 0.4),
                                  highlightColor: context.color.borderColor
                                      .withValues(alpha: 0.15),
                                  child: Container(color: Colors.white),
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.shopping_bag_outlined,
                                  color: context.color.territoryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.itemTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.color.textDefaultColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${Constant.currencySymbol} ${widget.itemPrice.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.color.territoryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildAdBannerStatusWidget(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: BlocProvider(
            create: (context) => AddItemReviewCubit(),
            child: Stack(
              children: [
                // 1. Background
                Container(
                  color: context.color.backgroundColor,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                ),
                SvgPicture.asset(
                  chatBackground,
                  height: MediaQuery.of(context).size.height,
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width,
                  colorFilter: ColorFilter.mode(
                    context.color.backgroundColor.withValues(alpha: 0.9),
                    BlendMode.srcOver,
                  ),
                ),

                // 2. Chat content Column: Expanded Message Area (pinned to bottom) + Bottom Input Bar
                Column(
                  children: [
                    Expanded(
                      child:
                          BlocListener<DeleteMessageCubit, DeleteMessageState>(
                        listener: (context, state) {
                          if (state is DeleteMessageSuccess) {
                            ChatMessageHandler.removeMessage(state.id);
                            showDeletebutton.value = false;
                          }
                        },
                        child: GestureDetector(
                          onTap: () {
                            showDeletebutton.value = false;
                          },
                          child: BlocConsumer<LoadChatMessagesCubit,
                              LoadChatMessagesState>(
                            listener: (context, state) {
                              if (state is LoadChatMessagesSuccess) {
                                ChatMessageHandler.loadMessages(
                                    state.messages, context);
                                totalMessageCount = state.messages.length;
                                isFetchedFirstTime = true;
                                setState(() {});
                              }
                            },
                            builder: (context, state) {
                              if (state is LoadChatMessagesInProgress &&
                                  !isFetchedFirstTime) {
                                return _buildMessagesLoadingShimmer();
                              }

                              return StreamBuilder<List<Widget>>(
                                stream: ChatMessageHandler.getChatStream(),
                                initialData: List<Widget>.of(
                                    ChatMessageHandler.messages),
                                builder: (context,
                                    AsyncSnapshot<List<Widget>> snapshot) {
                                  final hasMessages = snapshot.hasData &&
                                      snapshot.data!.isNotEmpty;

                                  if (!hasMessages) {
                                    if (_currentItemOfferId == 0 ||
                                        _showMakeOfferInput) {
                                      return _buildNoConversationView();
                                    }
                                    final currentUserId = HiveUtils.getUserId();
                                    final isMyOffer = widget.buyerId == null ||
                                        currentUserId == widget.buyerId;

                                    return SingleChildScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(
                                        parent: BouncingScrollPhysics(),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 20),
                                      child: Column(
                                        children: [
                                          offerWidget(),
                                          const SizedBox(height: 16),
                                          Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                color: context
                                                    .color.secondaryColor
                                                    .withValues(alpha: 0.8),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: context
                                                      .color.borderColor
                                                      .withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Text(
                                                isMyOffer
                                                    ? "You made an offer. Send a message to chat with the seller."
                                                        .translate(context)
                                                    : "${widget.userName.isNotEmpty ? widget.userName : 'Buyer'} made an offer. Reply below to chat."
                                                        .translate(context),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: context
                                                      .color.textLightColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    reverse: true,
                                    shrinkWrap: false,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    controller: _pageScrollController,
                                    addAutomaticKeepAlives: true,
                                    itemCount: snapshot.data!.length,
                                    padding:
                                        const EdgeInsets.fromLTRB(8, 12, 8, 12),
                                    itemBuilder: (context, index) {
                                      dynamic chat = snapshot.data![index];

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (index ==
                                              snapshot.data!.length - 1)
                                            offerWidget(),
                                          chat,
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Bottom Chat Input Bar
                    _buildChatInputBar(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget offerWidget() {
    if (_currentItemOfferPrice != null && _currentItemOfferPrice! > 0) {
      final currentUserId = HiveUtils.getUserId();
      final isMyOffer =
          widget.buyerId == null || currentUserId == widget.buyerId;

      return Align(
        alignment: isMyOffer
            ? AlignmentDirectional.topEnd
            : AlignmentDirectional.topStart,
        child: Container(
          margin: EdgeInsetsDirectional.only(
            top: 12,
            bottom: 12,
            end: isMyOffer ? 12 : 60,
            start: isMyOffer ? 60 : 12,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: context.color.territoryColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
            color: isMyOffer
                ? context.color.territoryColor.withValues(alpha: 0.15)
                : context.color.secondaryColor,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(isMyOffer ? 0 : 14),
              topLeft: Radius.circular(isMyOffer ? 14 : 0),
              bottomRight: const Radius.circular(14),
              bottomLeft: const Radius.circular(14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                isMyOffer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 15,
                    color: context.color.territoryColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isMyOffer
                        ? "yourOffer".translate(context)
                        : "${widget.userName.isNotEmpty ? widget.userName : 'Buyer'}'s Offer",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.color.textLightColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "${Constant.currencySymbol} ${_currentItemOfferPrice!.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAdBannerStatusWidget() {
    if (_isSoldOut) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 13,
              color: Colors.red.shade700,
            ),
            const SizedBox(width: 3.5),
            Text(
              "soldOut".translate(context),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.color.territoryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "viewAd".translate(context),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.color.territoryColor,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 10,
            color: context.color.territoryColor,
          ),
        ],
      ),
    );
  }
}
