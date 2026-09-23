// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:Ebozor/data/repositories/chat_repository.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/ui/screens/chat/chat_audio/widgets/chat_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoadChatMessagesState {}

class LoadChatMessagesInitial extends LoadChatMessagesState {}

class LoadChatMessagesInProgress extends LoadChatMessagesState {}

class LoadChatMessagesSuccess extends LoadChatMessagesState {
  List<ChatMessage> messages;
  int currentPage;
  int itemOfferId;
  int totalPage;
  bool isLoadingMore;

  LoadChatMessagesSuccess({
    required this.messages,
    required this.currentPage,
    required this.itemOfferId,
    required this.totalPage,
    required this.isLoadingMore,
  });

  LoadChatMessagesSuccess copyWith({
    List<ChatMessage>? messages,
    int? currentPage,
    int? userId,
    int? itemOfferId,
    int? totalPage,
    bool? isLoadingMore,
  }) {
    return LoadChatMessagesSuccess(
      messages: messages ?? this.messages,
      currentPage: currentPage ?? this.currentPage,
      itemOfferId: itemOfferId ?? this.itemOfferId,
      totalPage: totalPage ?? this.totalPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  String toString() {
    return 'LoadChatMessagesSuccess(messages: $messages, currentPage: $currentPage, itemOfferId: $itemOfferId,totalPage: $totalPage, isLoadingMore: $isLoadingMore)';
  }
}

class LoadChatMessagesFailed extends LoadChatMessagesState {
  final dynamic error;

  LoadChatMessagesFailed({
    required this.error,
  });
}

class LoadChatMessagesCubit extends Cubit<LoadChatMessagesState> {
  LoadChatMessagesCubit() : super(LoadChatMessagesInitial());
  final ChatRepostiory _chatRepostiory = ChatRepostiory();

  Future<void> load({required int itemOfferId}) async {
    try {
      emit(LoadChatMessagesInProgress());
      final result = await _chatRepostiory.getMessagesApi(
        itemOfferId: itemOfferId,
        page: 1,
      );

      var messages = List<ChatMessage>.of(result.modelList);
      var currentPage = 1;

      emit(LoadChatMessagesSuccess(
        messages: messages,
        currentPage: currentPage,
        itemOfferId: itemOfferId,
        isLoadingMore: messages.length < result.total,
        totalPage: result.total,
      ));
    } catch (e) {
      emit(LoadChatMessagesFailed(error: e.toString()));
    }
  }

  void addOrUpdateMessage(ChatMessage message) {
    if (state is LoadChatMessagesSuccess) {
      final success = state as LoadChatMessagesSuccess;
      final currentList = List<ChatMessage>.from(success.messages);

      // Check if message with same id already exists
      if (message.id != null) {
        final idIndex =
            currentList.indexWhere((m) => m.id != null && m.id == message.id);
        if (idIndex != -1) {
          return;
        }

        // Check if matching optimistic message exists (same sender, same text, id == null)
        final optIndex = currentList.indexWhere((m) =>
            m.id == null &&
            m.senderId == message.senderId &&
            m.message == message.message);
        if (optIndex != -1) {
          currentList[optIndex] = message;
          emit(success.copyWith(messages: currentList));
          return;
        }
      }

      // Check if key matches
      if (message.key is ValueKey) {
        final keyVal = (message.key as ValueKey).value;
        final keyIndex = currentList.indexWhere(
            (m) => m.key is ValueKey && (m.key as ValueKey).value == keyVal);
        if (keyIndex != -1) {
          return;
        }
      }

      // Add to beginning (index 0 is newest)
      currentList.insert(0, message);
      emit(success.copyWith(
        messages: currentList,
        totalPage: success.totalPage + 1,
      ));
    }
  }

  Future<void> loadMore() async {
    try {
      if (state is LoadChatMessagesSuccess) {
        if ((state as LoadChatMessagesSuccess).isLoadingMore) {
          return;
        }
        emit((state as LoadChatMessagesSuccess).copyWith(isLoadingMore: true));

        DataOutput<ChatMessage> result = await _chatRepostiory.getMessagesApi(
            page: (state as LoadChatMessagesSuccess).currentPage + 1,
            itemOfferId: (state as LoadChatMessagesSuccess).itemOfferId);

        LoadChatMessagesSuccess messagesSuccessState =
            (state as LoadChatMessagesSuccess);

        final mergedMessages =
            _mergeMessages(messagesSuccessState.messages, result.modelList);

        emit(LoadChatMessagesSuccess(
          messages: mergedMessages,
          currentPage: (state as LoadChatMessagesSuccess).currentPage + 1,
          itemOfferId: (state as LoadChatMessagesSuccess).itemOfferId,
          isLoadingMore: false,
          totalPage: result.total,
        ));
      }
    } catch (e) {
      emit((state as LoadChatMessagesSuccess).copyWith(isLoadingMore: false));
    }
  }

  bool hasMoreChat() {
    if (state is LoadChatMessagesSuccess) {
      return (state as LoadChatMessagesSuccess).messages.length <
          (state as LoadChatMessagesSuccess).totalPage;
    }
    return false;
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> current,
    List<ChatMessage> incoming,
  ) {
    final existingIds = current.map((m) => m.id).whereType<int>().toSet();
    final existingKeys = current
        .map((message) => message.key)
        .whereType<ValueKey>()
        .map((key) => key.value)
        .toSet();

    return <ChatMessage>[
      ...current,
      ...incoming.where((message) {
        if (message.id != null && existingIds.contains(message.id)) {
          return false;
        }
        if (message.key is ValueKey &&
            existingKeys.contains((message.key as ValueKey).value)) {
          return false;
        }
        return true;
      }),
    ];
  }

  LoadChatMessagesState? fromJson(Map<String, dynamic> json) {
    return null;
  }

  Map<String, dynamic>? toJson(LoadChatMessagesState state) {
    return null;
  }
}
