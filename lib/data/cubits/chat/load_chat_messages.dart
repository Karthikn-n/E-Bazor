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

      // Render the newest page immediately, then hydrate the rest of the
      // thread without requiring the user to scroll to trigger every page.
      while (messages.length < result.total) {
        try {
          final nextPage = await _chatRepostiory.getMessagesApi(
            itemOfferId: itemOfferId,
            page: currentPage + 1,
          );
          if (nextPage.modelList.isEmpty) break;

          final merged = _mergeMessages(messages, nextPage.modelList);
          if (merged.length == messages.length) break;

          messages = merged;
          currentPage++;
          emit(LoadChatMessagesSuccess(
            messages: messages,
            currentPage: currentPage,
            itemOfferId: itemOfferId,
            isLoadingMore: messages.length < result.total,
            totalPage: result.total,
          ));
        } catch (_) {
          break;
        }
      }

      if (state is LoadChatMessagesSuccess &&
          (state as LoadChatMessagesSuccess).isLoadingMore) {
        emit((state as LoadChatMessagesSuccess).copyWith(isLoadingMore: false));
      }
    } catch (e) {
      emit(LoadChatMessagesFailed(error: e.toString()));
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
    final existingKeys = current
        .map((message) => message.key)
        .whereType<ValueKey>()
        .map((key) => key.value)
        .toSet();
    return <ChatMessage>[
      ...current,
      ...incoming.where(
        (message) =>
            message.key is! ValueKey ||
            !existingKeys.contains((message.key as ValueKey).value),
      ),
    ];
  }

  LoadChatMessagesState? fromJson(Map<String, dynamic> json) {
    return null;
  }

  Map<String, dynamic>? toJson(LoadChatMessagesState state) {
    return null;
  }
}
