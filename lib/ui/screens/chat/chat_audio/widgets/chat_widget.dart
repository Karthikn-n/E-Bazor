// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:Ebozor/data/cubits/chat/send_message.dart';
import 'package:Ebozor/ui/screens/chat/chat_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/lib/build_context.dart';
import 'package:Ebozor/utils/extensions/lib/textWidgetExtention.dart';
import 'package:Ebozor/utils/extensions/lib/translate.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

part "parts/attachment.part.dart";

part "parts/linkpreview.part.dart";

part "parts/recordmsg.part.dart";

Set sentMessages = {};

class ChatMessage extends StatefulWidget {
  final int? id;
  final int senderId;
  final int itemOfferId;
  final String? message;
  final String? file;
  final String? audio;
  final String createdAt;
  final String updatedAt;
  final String? messageType;
  final bool? isSentNow;

  const ChatMessage(
      {super.key,
      this.id,
      required this.senderId,
      required this.itemOfferId,
      this.message,
      this.file,
      this.audio,
      required this.createdAt,
      required this.updatedAt,
      this.messageType,
      this.isSentNow});

  Map toJson() {
    Map data = {};

    data['key'] = key;
    data['id'] = this.id;
    data['sender_id'] = this.senderId;
    data['item_offer_id'] = this.itemOfferId;
    data['message'] = this.message;
    data['file'] = this.file;
    data['audio'] = this.audio;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['is_sent_now'] = this.isSentNow;
    data['message_type'] = this.messageType;
    return data;
  }

  factory ChatMessage.fromJson(Map json) {
    var chat = ChatMessage(
        key: json['key'],
        id: json['id'],
        senderId: json['sender_id'],
        itemOfferId: json['item_offer_id'],
        message: json['message'],
        file: json['file'],
        audio: json['audio'],
        createdAt: json['created_at'],
        updatedAt: json['updated_at'],
        isSentNow: json['is_sent_now'],
        messageType: json['message_type']);
    return chat;
  }

  @override
  State<ChatMessage> createState() => ChatMessageState();
}

class ChatMessageState extends State<ChatMessage>
    with AutomaticKeepAliveClientMixin {
  bool isChatSent = false;
  bool selectedMessage = false;
  static bool isMounted = false;
  String? link;
  final ValueNotifier _linkAddNotifier = ValueNotifier("");

  @override

  void initState() {
    if (widget.senderId.toString() == HiveUtils.getUserId() &&
        (widget.isSentNow == true) &&
        isChatSent == false) {
      if (!sentMessages.contains(widget.key)) {
        context.read<SendMessageCubit>().send(
              attachment: widget.file,
              message: widget.message!,
              itemOfferId: widget.itemOfferId,
              audio: widget.audio,
            );
      }
      sentMessages.add(widget.key);

      isMounted = true;
    }

    super.initState();
  }

  String _emptyTextIfAttachmentHasNoText() {
    if (widget.file != "") {
      if (widget.message == "[File]") {
        return "";
      } else {
        return widget.message!;
      }
    } else if (widget.message == null) {
      return "";
    } else {
      return widget.message!;
    }
  }

  bool _isLink(String input) {
    ///This will check if text contains link
    final matcher = RegExp(
        r"(http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)");
    return matcher.hasMatch(input);
  }

  List _replaceLink() {
    //This function will make part of text where link starts. we put invisible charector so we can split it with it
    final linkPattern = RegExp(
        r"(http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)");

    ///This is invisible charector [You can replace it with any special charector which generally nobody use]
    const String substringIdentifier = "‎";

    ///This will find and add invisible charector in prefix and suffix
    String splitMapJoin = _emptyTextIfAttachmentHasNoText().splitMapJoin(
      linkPattern,
      onMatch: (match) {
        return substringIdentifier + match.group(0)! + substringIdentifier;
      },
      onNonMatch: (match) {
        return match;
      },
    );
    //finally we split it with invisible charector so it will become list
    return splitMapJoin.split(substringIdentifier);
  }

  List<String> _matchAstric(String data) {
    var pattern = RegExp(r"\*(.*?)\*");

    String mapJoin = data.splitMapJoin(
      pattern,
      onMatch: (p0) {
        return "‎${p0.group(0)!}‎";
      },
      onNonMatch: (p0) {
        return p0;
      },
    );

    return mapJoin.split("‎");
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final bool isMe = widget.senderId.toString() == HiveUtils.getUserId();
    // final bool isDark = context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: context.color.secondaryColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.message != null && widget.message!.isNotEmpty)
                      ListTile(
                        leading: Icon(
                          Icons.copy_rounded,
                          color: context.color.textDefaultColor,
                        ),
                        title: Text(
                          "Copy Message".translate(context),
                          style: TextStyle(
                            color: context.color.textDefaultColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.message!));
                          Navigator.pop(ctx);
                          HelperUtils.showSnackBarMessage(
                            context,
                            "Message copied".translate(context),
                          );
                        },
                      ),
                    if (isMe)
                      ListTile(
                        leading: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                        ),
                        title: Text(
                          "Delete Message".translate(context),
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          selectedMessageid.value = (widget.key as ValueKey).value;
                          showDeletebutton.value = true;
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          width: MediaQuery.of(context).size.width,
          margin: EdgeInsetsDirectional.only(
            end: isMe ? 14 : 0,
            start: isMe ? 0 : 14,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: context.screenWidth * 0.76),
                decoration: BoxDecoration(
                  color: isMe
                      ? context.color.territoryColor
                      : context.color.secondaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: isMe
                      ? null
                      : Border.all(
                          color: context.color.borderColor.withValues(alpha: 0.6),
                          width: 1,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (widget.audio != "")
                        RecordMessage(
                          url: widget.audio ?? "",
                          isSentByMe: isMe,
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.file != "")
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: AttachmentMessage(url: widget.file!),
                              ),
                            ValueListenableBuilder(
                              valueListenable: _linkAddNotifier,
                              builder: (context, dynamic value, c) {
                                if (value == null || value.toString().isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return FutureBuilder(
                                  future: AnyLinkPreview.getMetadata(link: value),
                                  builder: (context, AsyncSnapshot snapshot) {
                                    if (snapshot.connectionState == ConnectionState.done &&
                                        snapshot.data != null) {
                                      return LinkPreviw(
                                        snapshot: snapshot,
                                        link: value,
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                );
                              },
                            ),
                            if (_emptyTextIfAttachmentHasNoText().isNotEmpty)
                              Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    color: isMe ? Colors.white : context.color.textDefaultColor,
                                    height: 1.35,
                                  ),
                                  children: _replaceLink().map((data) {
                                    if (_isLink(data)) {
                                      _linkAddNotifier.value = data;
                                      _linkAddNotifier.notifyListeners();

                                      return TextSpan(
                                        text: data,
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () async {
                                            await launchUrl(Uri.parse(data));
                                          },
                                        style: TextStyle(
                                          decoration: TextDecoration.underline,
                                          color: isMe ? Colors.white : Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    }
                                    return TextSpan(
                                      text: "",
                                      children: _matchAstric(data).map((text) {
                                        if (text.toString().startsWith("*") &&
                                            text.toString().endsWith("*")) {
                                          return TextSpan(
                                            text: text.replaceAll("*", ""),
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : context.color.textDefaultColor,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          );
                                        }
                                        return TextSpan(
                                          text: text,
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white
                                                : context.color.textDefaultColor,
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                (DateTime.tryParse(widget.createdAt) ?? DateTime.now())
                    .toLocal()
                    .toIso8601String()
                    .formatDate(format: "hh:mm aa"),
                style: TextStyle(
                  fontSize: 11,
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

  @override
  bool get wantKeepAlive => true;
}
