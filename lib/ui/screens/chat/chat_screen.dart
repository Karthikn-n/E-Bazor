import 'dart:async';
import 'dart:io';

import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/add_item_review_cubit.dart';
import 'package:Ebozor/data/cubits/chat/block_user_cubit.dart';
import 'package:Ebozor/data/cubits/chat/delete_message_cubit.dart';
import 'package:Ebozor/data/cubits/chat/get_buyer_chat_users_cubit.dart';
import 'package:Ebozor/data/cubits/chat/load_chat_messages.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/ui/screens/chat/chat_audio/widgets/chat_widget.dart';
import 'package:Ebozor/ui/screens/chat/chat_audio/widgets/record_button.dart';
import 'package:Ebozor/utils/ApiService/Socketservice.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/notification/chat_message_handler.dart';
import 'package:Ebozor/utils/notification/notification_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:Ebozor/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:Ebozor/data/cubits/chat/unblock_user_cubit.dart';
import 'package:Ebozor/data/model/chat/chated_user_model.dart';
import 'package:Ebozor/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/extensions/lib/build_context.dart' show CustomContext;
import 'package:Ebozor/utils/extensions/lib/textWidgetExtention.dart';
import 'package:Ebozor/utils/extensions/lib/translate.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final String userId; //for which we are messageing
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
    duration: const Duration(
      milliseconds: 500,
    ),
  );
  TextEditingController controller = TextEditingController();
  PlatformFile? messageAttachment;
  bool isFetchedFirstTime = false;
  double scrollPositionWhenLoadMore = 0;
  late Stream<PermissionStatus> notificationStream = notificationPermission();
  late StreamSubscription notificationStreamSubsctription;
  bool isNotificationPermissionGranted = true;
  bool showRecordButton = true;
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  late int _currentItemOfferId = widget.itemOfferId;
  late double? _currentItemOfferPrice = widget.itemOfferPrice;
  bool _showMakeOfferInput = false;
  final TextEditingController _offerPriceController = TextEditingController();
  final GlobalKey<FormState> _offerInputFormKey = GlobalKey<FormState>();
  bool _isSubmittingOffer = false;

  late final ScrollController _pageScrollController = ScrollController()
    ..addListener(
          () {
        if (_pageScrollController.offset >=
            _pageScrollController.position.maxScrollExtent) {
          if (context.read<LoadChatMessagesCubit>().hasMoreChat()) {
            setState(() {});
            context.read<LoadChatMessagesCubit>().loadMore();
          }
        }
      },
    );
  final ChatSocketService _socketService = ChatSocketService();
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();

    ChatMessageHandler.flushMessages();

    if (_currentItemOfferId > 0) {
      // Load messages from API
      context.read<LoadChatMessagesCubit>().load(itemOfferId: _currentItemOfferId);

      final socketService = ChatSocketService();
      if (!socketService.isConnected) socketService.connect();
      socketService.joinOffer(_currentItemOfferId);
    }

    // Set current chat info
    currentlyChatItemId = widget.itemId;
    currentlyChatingWith = widget.userId;

    // Listen for notification permission changes
    notificationStreamSubsctription = notificationStream.listen((PermissionStatus permissionStatus) {
      isNotificationPermissionGranted = permissionStatus.isGranted;
      if (mounted) setState(() {});
    });

    // Handle typing & show/hide record button
    controller.addListener(() {
      if (controller.text.isNotEmpty) {
        showRecordButton = false;
        if (_currentItemOfferId > 0) {
          _socketService.typingStart(_currentItemOfferId);
        }
      } else {
        showRecordButton = true;
        if (_currentItemOfferId > 0) {
          _socketService.typingStop(_currentItemOfferId);
        }
      }
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.status == "sold out" &&
          widget.isPurchased == 1 &&
          !widget.alreadyReview) {
        ratingsAlertDialog();
      }
    });
  }

  Stream<PermissionStatus> notificationPermission() async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      yield* Permission.notification.request().asStream();
    }
  }

  @override
  void dispose() {
    if (_currentItemOfferId > 0) {
      _socketService.typingStop(_currentItemOfferId);
      _socketService.leaveOffer(_currentItemOfferId);
    }
    _typingTimer?.cancel();
    notificationStreamSubsctription.cancel();
    _offerPriceController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text, {String? filePath, String? audioPath}) async {
    if (text.trim().isEmpty && filePath == null && audioPath == null) return;

    if (_currentItemOfferId == 0) {
      try {
        final response = await ItemRepository().makeAnOfferItem(int.parse(widget.itemId), null);
        if (response['data'] != null && response['data']['id'] != null) {
          final newOfferId = response['data']['id'] is int
              ? response['data']['id'] as int
              : int.parse(response['data']['id'].toString());
          setState(() {
            _currentItemOfferId = newOfferId;
            _showMakeOfferInput = false;
          });
          final socketService = ChatSocketService();
          if (!socketService.isConnected) socketService.connect();
          socketService.joinOffer(_currentItemOfferId);

          try {
            if (response['data']['buyer'] != null) {
              context.read<GetBuyerChatListCubit>().addNewChat(ChatedUser.fromJson(response['data']));
            }
          } catch (_) {}
        } else {
          HelperUtils.showSnackBarMessage(context, "Could not initiate chat. Please try again.");
          return;
        }
      } catch (e) {
        HelperUtils.showSnackBarMessage(context, "Could not initiate chat: $e");
        return;
      }
    }

    _socketService.typingStop(_currentItemOfferId);
    _socketService.sendMessage(_currentItemOfferId, text);

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
      final response = await ItemRepository().makeAnOfferItem(int.parse(widget.itemId), price);
      if (response['error'] == false || response['data'] != null) {
        final data = response['data'];
        final newOfferId = data != null && data['id'] != null
            ? (data['id'] is int ? data['id'] as int : int.parse(data['id'].toString()))
            : 0;

        setState(() {
          if (newOfferId > 0) {
            _currentItemOfferId = newOfferId;
          }
          _currentItemOfferPrice = price;
          _showMakeOfferInput = false;
          _isSubmittingOffer = false;
        });

        // Join socket room
        final socketService = ChatSocketService();
        if (!socketService.isConnected) socketService.connect();
        if (_currentItemOfferId > 0) {
          socketService.joinOffer(_currentItemOfferId);
          socketService.sendMessage(_currentItemOfferId, "Offer made: ${Constant.currencySymbol} $price");
        }

        try {
          if (data != null && data['buyer'] != null) {
            context.read<GetBuyerChatListCubit>().addNewChat(ChatedUser.fromJson(data));
          }
        } catch (_) {}

        if (_currentItemOfferId > 0) {
          context.read<LoadChatMessagesCubit>().load(itemOfferId: _currentItemOfferId);
        }

        HelperUtils.showSnackBarMessage(context, response['message']?.toString() ?? "Offer submitted successfully");
      } else {
        setState(() {
          _isSubmittingOffer = false;
        });
        HelperUtils.showSnackBarMessage(context, response['message']?.toString() ?? "Failed to submit offer");
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top close button
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

                // Title
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

                // Red checkmark circle + text
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

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.color.territoryColor,
                      side: BorderSide(color: context.color.territoryColor, width: 1.2),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: context.color.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.color.borderColor.withValues(alpha: 0.8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.color.borderColor.withValues(alpha: 0.8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.color.territoryColor),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isSubmittingOffer
                          ? null
                          : () async {
                              if (_offerInputFormKey.currentState?.validate() == true) {
                                final price = double.tryParse(_offerPriceController.text.trim());
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "No Conversation with Seller Yet!".translate(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You haven't initiated any chat with the seller. Feel free to make your offer for this product or start a direct chat with the seller!".translate(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: context.color.textDefaultColor.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.color.territoryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
                size: 20,
              ),
              label: Text(
                "Make an offer".translate(context),
                style: const TextStyle(
                  fontSize: 15,
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

  List<String> supportedImageTypes = [
    'jpeg',
    'jpg',
    'png',
    'gif',
    'webp',
    'animated_webp',
  ];

  void ratingsAlertDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,

      // Set to false if you don't want the dialog to close by tapping outside
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
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('rateYourExperience'.translate(context))
                          .color(context.color.textLightColor),
                      SizedBox(height: 8),
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
                      SizedBox(height: 16),
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
                              color:
                              context.color.textLightColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          UiUtils.buildButton(context, onPressed: () {
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
                              height: 39),
                          UiUtils.buildButton(context, showElevation: false,
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
                              height: 39),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [

            ElevatedButton(
              onPressed: _rating >= 1
                  ? () {
                context.read<AddItemReviewCubit>().addItemReview(
                    itemId: int.parse(widget.itemId),
                    rating: _rating,
                    review: _feedbackController.text.trim());
              }
                  : null, // Disable button if rating is less than 1
              style: ElevatedButton.styleFrom(
                backgroundColor: _rating >= 1
                    ? context.color.territoryColor
                    : context.color.deactivateColor,
              ),
              child: Text("submitBtnLbl".translate(context)),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    var chatBackground = "assets/chat_background/chat_background.svg";
    var attachmentMIME = "";
    if (messageAttachment != null) {
      attachmentMIME =
          (messageAttachment?.path?.split(".").last.toLowerCase()) ?? "";
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result)  {

        currentlyChatingWith = "";
        showDeletebutton.value = false;

        currentlyChatItemId = "";
        notificationStreamSubsctription.cancel();
        ChatMessageHandler.flushMessages();
        //context.read<ChatMessageHandlerCubit>().flushMessages();
        return;
      },
      /*  onWillPop: () async {
      currentlyChatingWith = "";
      showDelet ebutton.value = false;

      currentlyChatItemId = "";
      notificationStreamSubsctription.cancel();
      ChatMessageHandler.flushMessages();
      return true;
    },*/
      child: SafeArea(
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (messageAttachment != null) ...[
                    if (supportedImageTypes.contains(attachmentMIME)) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: context.color.secondaryColor,
                            border: Border.all(color: context.color.borderColor, width: 1.5)),
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
                                      File(
                                        messageAttachment?.path ?? "",
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  )),
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
                          child:
                          AttachmentMessage(url: messageAttachment!.path!),
                        ),
                      ),
                    ],
                    const SizedBox(
                      height: 10,
                    ),
                  ],
                  BottomAppBar(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    elevation: 5,
                    color: context.color.secondaryColor,
                    child: Directionality(
                      textDirection: Directionality.of(context),
                      child: widget.status == "review" ||
                          widget.status == "rejected" ||
                          widget.status == "sold out" ||
                          widget.status == "inactive"
                          ? Container(
                          height: 40,
                          width: double.maxFinite,
                          color: context.color.secondaryColor,
                          alignment: Alignment.center,
                          child: Text(
                              "${"thisItemIs".translate(context)} ${widget.status}")
                              .size(context.font.large))
                          : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BlocProvider(
                              create: (context) => UnblockUserCubit(),
                              child: Builder(builder: (context) {
                                bool isBlocked = context
                                    .read<BlockedUsersListCubit>()
                                    .isUserBlocked(
                                    int.parse(widget.userId));
                                return BlocConsumer<BlockedUsersListCubit,
                                    BlockedUsersListState>(
                                    listener: (context, state) {
                                      if (state is BlockedUsersListSuccess) {
                                        isBlocked = context
                                            .read<BlockedUsersListCubit>()
                                            .isUserBlocked(
                                            int.parse(widget.userId));
                                      }
                                    }, builder:
                                    (context, blockedUsersListState) {
                                  return isBlocked
                                      ? BlocListener<UnblockUserCubit,
                                      UnblockUserState>(
                                      listener:
                                          (context, unblockState) {
                                        if (unblockState
                                        is UnblockUserSuccess) {
                                          // Remove the unblocked user from the list
                                          context
                                              .read<
                                              BlockedUsersListCubit>()
                                              .unblockUser(int.parse(
                                              widget.userId));
                                          HelperUtils
                                              .showSnackBarMessage(
                                              context,
                                              unblockState
                                                  .message);
                                        } else if (unblockState
                                        is UnblockUserFail) {
                                          HelperUtils
                                              .showSnackBarMessage(
                                              context,
                                              unblockState.error
                                                  .toString());
                                        }
                                      },
                                      child: InkWell(
                                        child: Text(
                                            "youBlockedThisContact"
                                                .translate(
                                                context))
                                            .color(context
                                            .color.textColorDark
                                            .withValues(alpha: 0.7)),
                                        onTap: () async {
                                          var unBlock = await UiUtils
                                              .showBlurredDialoge(
                                            context,
                                            dialoge: BlurredDialogBox(
                                              acceptButtonName:
                                              "unBlockLbl"
                                                  .translate(
                                                  context),
                                              content: Text(
                                                "${"unBlockLbl".translate(context)}\t${widget.userName}\t${"toSendMessage".translate(context)}"
                                                    .translate(
                                                    context),
                                              ),
                                            ),
                                          );
                                          if (unBlock == true) {
                                            Future.delayed(
                                                Duration.zero, () {
                                              context
                                                  .read<
                                                  UnblockUserCubit>()
                                                  .unBlockUser(
                                                blockUserId: int
                                                    .parse(widget
                                                    .userId),
                                              );
                                            });
                                          }
                                        },
                                      ))
                                      : SizedBox();
                                });
                              })),


                          //// typing status showing
                          ValueListenableBuilder<bool>(
                            valueListenable: _socketService.isOtherUserTyping,
                            builder: (context, isTyping, _) {
                              if (!isTyping) return const SizedBox();

                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 4),
                                child: Text(
                                  "${widget.userName} is typing...",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: context.color.textLightColor,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 4),
                          Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: context.color.secondaryColor,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: context.color.borderColor.withValues(alpha: 0.6),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          onPressed: () async {
                                            if (messageAttachment == null) {
                                              FilePickerResult? pickedAttachment =
                                                  await FilePicker.platform.pickFiles(
                                                allowMultiple: false,
                                                type: FileType.custom,
                                                allowedExtensions: ['jpg', 'jpeg', 'png'],
                                              );
                                              messageAttachment = pickedAttachment?.files.first;
                                              showRecordButton = false;
                                              setState(() {});
                                            } else {
                                              messageAttachment = null;
                                              showRecordButton = true;
                                              setState(() {});
                                            }
                                          },
                                          icon: messageAttachment != null
                                              ? const Icon(Icons.close_rounded, size: 20)
                                              : Icon(
                                                  Icons.attach_file_rounded,
                                                  size: 20,
                                                  color: context.color.textLightColor,
                                                ),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: controller,
                                            onChanged: (value) {
                                              if (_currentItemOfferId > 0) {
                                                _socketService.typingStart(_currentItemOfferId);
                                                _typingTimer?.cancel();
                                                _typingTimer = Timer(const Duration(seconds: 1), () {
                                                  _socketService.typingStop(_currentItemOfferId);
                                                });
                                              }
                                              if (value.trim().isNotEmpty && showRecordButton) {
                                                setState(() => showRecordButton = false);
                                              } else if (value.trim().isEmpty && !showRecordButton && messageAttachment == null) {
                                                setState(() => showRecordButton = true);
                                              }
                                            },
                                            cursorColor: context.color.territoryColor,
                                            onTap: () {
                                              showDeletebutton.value = false;
                                            },
                                            textInputAction: TextInputAction.newline,
                                            minLines: 1,
                                            maxLines: 4,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              color: context.color.textDefaultColor,
                                            ),
                                            decoration: InputDecoration(
                                              contentPadding: const EdgeInsets.symmetric(
                                                vertical: 10,
                                                horizontal: 4,
                                              ),
                                              border: InputBorder.none,
                                              hintText: "Type a message...".translate(context),
                                              hintStyle: TextStyle(
                                                color: context.color.textLightColor,
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
                                      if (controller.text.trim().isEmpty && messageAttachment == null) return;
                                      final text = controller.text.trim();
                                      final filePath = messageAttachment?.path;
                                      await _sendMessage(text, filePath: filePath);
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: context.color.territoryColor,
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.color.territoryColor.withValues(alpha: 0.3),
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: context.color.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.color.borderColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        try {
                          Widgets.showLoader(context);
                          DataOutput<ItemModel> dataOutput =
                              await ItemRepository().fetchItemFromItemId(
                            int.parse(widget.itemId),
                          );
                          if (context.mounted) {
                            Widgets.hideLoder(context);
                            Navigator.pushNamed(
                              context,
                              Routes.adDetailsScreen,
                              arguments: {
                                "model": dataOutput.modelList[0],
                              },
                            );
                          }
                        } catch (e) {
                          if (context.mounted) Widgets.hideLoder(context);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: CachedNetworkImage(
                            imageUrl: widget.itemImage,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.shopping_bag_outlined,
                              color: context.color.territoryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            Widgets.showLoader(context);
                            DataOutput<ItemModel> dataOutput =
                                await ItemRepository().fetchItemFromItemId(
                              int.parse(widget.itemId),
                            );
                            if (context.mounted) {
                              Widgets.hideLoder(context);
                              Navigator.pushNamed(
                                context,
                                Routes.adDetailsScreen,
                                arguments: {
                                  "model": dataOutput.modelList[0],
                                },
                              );
                            }
                          } catch (e) {
                            if (context.mounted) Widgets.hideLoder(context);
                          }
                        },
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
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: context.color.textLightColor,
                    ),
                  ],
                ),
              ),
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
                            // Add the blocked user to the list
                            context
                                .read<BlockedUsersListCubit>()
                                .addBlockedUser(
                              BlockedUserModel(
                                  id: int.parse(widget.userId),
                                  name: widget.userName,
                                  profile: widget.profilePicture
                                // Add other necessary user data
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
                              // Remove the unblocked user from the list
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
                            padding: EdgeInsetsDirectional.only(end: 30.0),
                            child: Container(
                              height: 24,
                              width: 24,
                              alignment: AlignmentDirectional.center,
                              child: PopupMenuButton(
                                color: context.color.secondaryColor,
                                offset: Offset(-12, 15),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(17),
                                    bottomRight: Radius.circular(17),
                                    topLeft: Radius.circular(17),
                                    topRight: Radius.circular(0),
                                  ),
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
                                          Future.delayed(Duration.zero, () {
                                            context
                                                .read<BlockUserCubit>()
                                                .blockUser(
                                              blockUserId:
                                              int.parse(widget.userId),
                                            );
                                          });
                                        }
                                      },
                                      child: Text("blockLbl".translate(context))
                                          .color(context.color.textColorDark),
                                    )
                                  else
                                    PopupMenuItem(
                                      onTap: () async {
                                        var unBlock =
                                        await UiUtils.showBlurredDialoge(
                                          context,
                                          dialoge: BlurredDialogBox(
                                            acceptButtonName:
                                            "unBlockLbl".translate(context),
                                            content: Text(
                                              "${"unBlockLbl".translate(context)}\t${widget.userName}\t${"toSendMessage".translate(context)}"
                                                  .translate(context),
                                            ),
                                          ),
                                        );
                                        if (unBlock == true) {
                                          Future.delayed(Duration.zero, () {
                                            context
                                                .read<UnblockUserCubit>()
                                                .unBlockUser(
                                              blockUserId:
                                              int.parse(widget.userId),
                                            );
                                          });
                                        }
                                      },
                                      child: Text(
                                          "unBlockLbl".translate(context))
                                          .color(context.color.textColorDark),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              )
            ],
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
          ),
          body: BlocProvider(
            create: (context) => AddItemReviewCubit(),
            child: Stack(
              children: [
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
                    child: BlocConsumer<LoadChatMessagesCubit, LoadChatMessagesState>(
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
                        return Stack(
                          children: [
                            StreamBuilder<List<Widget>>(
                                stream: ChatMessageHandler.getChatStream(),
                                builder: (context,
                                    AsyncSnapshot<List<Widget>> snapshot) {
                                  Widget? loadingMoreWidget;
                                  if (state is LoadChatMessagesSuccess && state.isLoadingMore) {
                                    loadingMoreWidget = Text("loading".translate(context));
                                  }

                                  if (snapshot.connectionState == ConnectionState.active ||
                                      snapshot.connectionState == ConnectionState.done) {
                                    if ((snapshot.data as List?)?.isEmpty ?? true) {
                                      if (_currentItemOfferId == 0 || _showMakeOfferInput) {
                                        return _buildNoConversationView();
                                      }
                                      return offerWidget();
                                    }

                                    if (snapshot.hasData) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          loadingMoreWidget ??
                                              const SizedBox.shrink(),
                                          Expanded(
                                            child: ListView.builder(
                                              key: ValueKey('chat_list_${snapshot.data!.length}'),
                                              reverse: true,
                                              shrinkWrap: true,
                                              physics: const AlwaysScrollableScrollPhysics(),
                                              controller: _pageScrollController,
                                              addAutomaticKeepAlives: true,
                                              itemCount: snapshot.data!.length,
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              itemBuilder: (context, index) {
                                                dynamic chat = snapshot.data![index];

                                                return Column(
                                                  mainAxisSize:
                                                  MainAxisSize.min,
                                                  children: [
                                                    if (index == snapshot.data!.length - 1)
                                                      offerWidget(),
                                                    chat
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                  }

                                  if (_currentItemOfferId == 0 || _showMakeOfferInput) {
                                    return _buildNoConversationView();
                                  }

                                  return offerWidget();
                                }),
                                
                            if (state is LoadChatMessagesInProgress)
                              Positioned.fill(
                                child: Container(
                                  color: context.color.backgroundColor,
                                  child: ListView.builder(
                                    itemCount: 6,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    itemBuilder: (context, index) {
                                      final isMe = index % 2 == 1;
                                      return Align(
                                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          width: context.screenWidth * 0.55,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: context.color.borderColor.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget offerWidget() {
    if (_currentItemOfferPrice != null) {
      final currentUserId = HiveUtils.getUserId();
      final isMyOffer = widget.buyerId == null || currentUserId == widget.buyerId;
      if (isMyOffer) {
        return Align(
          alignment: AlignmentDirectional.topEnd,
          child: Container(
              margin: const EdgeInsetsDirectional.only(top: 15, bottom: 15, end: 15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: context.color.territoryColor.withValues(alpha: 0.3)),
                  color: context.color.territoryColor.withValues(alpha: 0.17),
                  borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(0),
                      topLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                      bottomLeft: Radius.circular(8))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("yourOffer".translate(context))
                      .color(context.color.textDefaultColor.withValues(alpha: 0.5)),
                  Text(Constant.currencySymbol +
                      _currentItemOfferPrice.toString())
                      .bold()
                      .size(context.font.larger)
                      .color(context.color.textDefaultColor)
                ],
              )),
        );
      } else {
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Container(
              margin:
              const EdgeInsetsDirectional.only(top: 15, bottom: 15, start: 15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: context.color.territoryColor.withValues(alpha: 0.3)),
                  color: context.color.territoryColor.withValues(alpha: 0.17),
                  borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      topLeft: Radius.circular(0),
                      bottomRight: Radius.circular(8),
                      bottomLeft: Radius.circular(8))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("offerLbl".translate(context))
                      .color(context.color.textDefaultColor.withValues(alpha: 0.5)),
                  Text(Constant.currencySymbol +
                      _currentItemOfferPrice.toString())
                      .bold()
                      .size(context.font.larger)
                      .color(context.color.textDefaultColor)
                ],
              )),
        );
      }
    } else {
      return const SizedBox.shrink();
    }
  }
}