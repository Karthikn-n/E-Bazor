import 'dart:async';

import 'package:Ebozor/ui/screens/chat/chat_audio/widgets/chat_widget.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';

int sentMessages = 0;

class ChatMessageHandler {
  static List<Widget> messages = [];
  static final List<Widget> _chat = [];
  static final StreamController<List<Widget>> _chatMessageStream =
      StreamController<List<Widget>>.broadcast();

  static void add(Widget chat) {
    if (chat is ChatMessage) {
      final newMsg = chat;

      // 1. Check if message with same id already exists
      if (newMsg.id != null) {
        final existingIndex = messages.indexWhere((m) {
          if (m is ChatMessage && m.id != null) {
            return m.id == newMsg.id;
          }
          return false;
        });
        if (existingIndex != -1) {
          // Already in list, do not duplicate
          return;
        }
      }

      // 2. Reconcile optimistic message: if incoming message has an id, check if an optimistic
      // message exists from the same sender with matching text and no id
      if (newMsg.id != null) {
        final optimisticIndex = messages.indexWhere((m) {
          if (m is ChatMessage && m.id == null && m.senderId == newMsg.senderId) {
            return m.message == newMsg.message;
          }
          return false;
        });
        if (optimisticIndex != -1) {
          messages[optimisticIndex] = newMsg;
          _emitMessages();
          return;
        }
      }

      // 3. Check if message with same ValueKey already exists
      if (newMsg.key is ValueKey) {
        final newKeyVal = (newMsg.key as ValueKey).value;
        final existingIndex = messages.indexWhere((m) {
          if (m is ChatMessage && m.key is ValueKey) {
            return (m.key as ValueKey).value == newKeyVal;
          }
          return false;
        });
        if (existingIndex != -1) {
          return;
        }
      }
    }

    _chat.clear();
    _chat.insert(0, chat);
    messages = [..._chat, ...messages];
    _emitMessages();
  }

  static void loadMessages(List<Widget> chats, BuildContext context) {
    // 1. Deduplicate incoming chats by ID
    final seenIds = <int>{};
    final uniqueChats = <Widget>[];

    for (var chat in chats) {
      if (chat is ChatMessage) {
        if (chat.id != null) {
          if (seenIds.contains(chat.id)) continue;
          seenIds.add(chat.id!);
        }
      }
      uniqueChats.add(chat);
    }

    // 2. Deduplicate historical duplicates (same sender, same text, sent within 3 seconds)
    final filteredChats = <Widget>[];
    for (int i = 0; i < uniqueChats.length; i++) {
      final current = uniqueChats[i];
      if (current is ChatMessage && i + 1 < uniqueChats.length) {
        final next = uniqueChats[i + 1];
        if (next is ChatMessage &&
            current.senderId == next.senderId &&
            current.message == next.message &&
            current.message != null &&
            current.message!.isNotEmpty) {
          final t1 = DateTime.tryParse(current.createdAt);
          final t2 = DateTime.tryParse(next.createdAt);
          if (t1 != null && t2 != null && t1.difference(t2).abs().inSeconds <= 3) {
            continue;
          }
        }
      }
      filteredChats.add(current);
    }

    // 3. Preserve any pending optimistic messages currently in messages
    final pendingOptimistic = <ChatMessage>[];
    for (var m in messages) {
      if (m is ChatMessage && m.id == null) {
        final alreadyInChats = filteredChats.any((c) =>
            c is ChatMessage &&
            c.senderId == m.senderId &&
            c.message == m.message);
        if (!alreadyInChats) {
          pendingOptimistic.add(m);
        }
      }
    }

    List<Widget> messagesWithDate = [];
    String previousDate = "";
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));

    for (int i = filteredChats.length - 1; i >= 0; i--) {
      DateTime date =
          DateTime.parse((filteredChats[i] as ChatMessage).createdAt).toLocal();
      String formattedDate;

      if (date.isAfter(today)) {
        formattedDate = "today".translate(context);
      } else if (date.isAfter(yesterday)) {
        formattedDate = "yesterday".translate(context);
      } else {
        formattedDate = (date.toString()).formatDate();
      }

      // Add date widget if date has changed
      if (formattedDate != previousDate) {
        messagesWithDate.insert(0, messageDateChip(context, formattedDate));
        previousDate = formattedDate;
      }

      // Add message widget
      messagesWithDate.insert(0, filteredChats[i]);
    }

    // Place any pending optimistic messages at index 0 (bottom)
    for (var opt in pendingOptimistic) {
      messagesWithDate.insert(0, opt);
    }

    // Update the messages list and sink the new messages to the stream
    messages = messagesWithDate;
    _emitMessages();
  }

  static Widget messageDateChip(BuildContext context, String formattedDate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
          child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: context.color.territoryColor.withValues(alpha: 0.3)),
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Text(formattedDate),
        ),
      )),
    );
  }

  static void flushMessages() {
    messages.clear();
    _chat.clear();
    _emitMessages();
  }

  static Stream<List<Widget>> get chatStream => _chatMessageStream.stream;

  static Stream<List<Widget>> getChatStream() => _chatMessageStream.stream;

  static void _emitMessages() {
    _chatMessageStream.sink.add(List<Widget>.unmodifiable(messages));
  }

  static void attachListener(void Function(dynamic)? onData) {
    _chatMessageStream.stream.listen(onData);
  }

  static void removeMessage(int id) {
    List<Widget> msgs = (messages);
    msgs.removeWhere((element) {
      if (element is! Padding) {
        return ((element as ChatMessage).key as ValueKey).value == id;
      }
      return false;
    });

    messages = msgs;
    _emitMessages();
  }

  ///This will replace message's key with server key so we will be able to delete message if we want
  static void updateMessageId(String identifier, int id) {
    try {
      List<Widget> msgs = _chat;
      for (var i = 0; i < _chat.length; i++) {
        if (msgs[i] is BlocProvider) {
          Widget? bloc = (msgs[i] as BlocProvider).child;
          ChatMessage chat = (bloc as ChatMessage);
          String chatKey = (chat.key as ValueKey).value.toString();

          if (identifier == chatKey) {
            var map = chat.toJson();
            map['key'] = ValueKey(id);
            map['id'] = id;

            try {
              ChatMessage chatMessage = ChatMessage.fromJson(map);
              _chat[i] = chatMessage;
            } catch (e) {}

            msgs = [..._chat, ...messages];
            _chatMessageStream.sink.add(msgs);
          }
        }
      }
    } catch (e) {}
  }
}
