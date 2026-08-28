import 'package:Ebozor/data/model/chat/chated_user_model.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/seller_ratings_model.dart';
import 'package:Ebozor/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class GetBuyerChatListState {}

class GetBuyerChatListInitial extends GetBuyerChatListState {}

class GetBuyerChatListInProgress extends GetBuyerChatListState {}

class GetBuyerChatListInternalProcess extends GetBuyerChatListState {}

class GetBuyerChatListSuccess extends GetBuyerChatListState {
  final int total;
  final bool isLoadingMore;
  final bool hasError;
  final int page;
  final List<ChatedUser> chatedUserList;

  GetBuyerChatListSuccess({
    required this.total,
    required this.isLoadingMore,
    required this.hasError,
    required this.chatedUserList,
    required this.page,
  });

  GetBuyerChatListSuccess copyWith({
    int? total,
    int? currentPage,
    bool? isLoadingMore,
    bool? hasError,
    int? page,
    List<ChatedUser>? chatedUserList,
  }) {
    return GetBuyerChatListSuccess(
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
      chatedUserList: chatedUserList ?? this.chatedUserList,
      page: page ?? this.page,
    );
  }
}

class GetBuyerChatListFailed extends GetBuyerChatListState {
  final dynamic error;

  GetBuyerChatListFailed(this.error);
}

class GetBuyerChatListCubit extends Cubit<GetBuyerChatListState> {
  GetBuyerChatListCubit() : super(GetBuyerChatListInitial());
  final ChatRepostiory _chatRepository = ChatRepostiory();

  ///Setting build context for later use
  void setContext(BuildContext context) {
    _chatRepository.setContext(context);
  }

  void fetch() async {
    try {
      emit(GetBuyerChatListInProgress());

      DataOutput<ChatedUser> result =
          await _chatRepository.fetchBuyerChatList(1);

      emit(
        GetBuyerChatListSuccess(
            isLoadingMore: false,
            hasError: false,
            chatedUserList: result.modelList,
            total: result.total,
            page: 1),
      );
    } catch (e) {
      emit(GetBuyerChatListFailed(e));
    }
  }

  void addNewChat(ChatedUser user) {
    //this will create new chat in chat list if there is no already
    if (state is GetBuyerChatListSuccess) {
      List<ChatedUser> chatedUserList =
          (state as GetBuyerChatListSuccess).chatedUserList;
      bool contains = chatedUserList.any(
        (element) => element.itemId == user.itemId,
      );
      if (contains == false) {
        chatedUserList.insert(0, user);
        emit((state as GetBuyerChatListSuccess)
            .copyWith(chatedUserList: chatedUserList));
      }
    }
  }

  void updateAlreadyReview(int itemId) {
    //this will create new chat in chat list if there is no already
    if (state is GetBuyerChatListSuccess) {
      List<ChatedUser> chatedUserList =
          (state as GetBuyerChatListSuccess).chatedUserList;
      int index =
          chatedUserList.indexWhere((element) => element.itemId == itemId);

      chatedUserList[index].item!.review = UserRatings(
        sellerId: chatedUserList[index].sellerId,
        itemId: itemId,
        buyerId: chatedUserList[index].buyerId,
      );
      if (!isClosed) {
        emit((state as GetBuyerChatListSuccess)
            .copyWith(chatedUserList: chatedUserList));
      }
    }
  }

  void updateItemStatus(int itemId, String status) {
    if (state is! GetBuyerChatListSuccess || isClosed) return;
    final current = state as GetBuyerChatListSuccess;
    final chats = List<ChatedUser>.from(current.chatedUserList);
    for (final chat in chats.where((chat) => chat.itemId == itemId)) {
      chat.item?.status = status;
    }
    emit(current.copyWith(chatedUserList: chats));
  }

  Future<void> loadMore() async {
    try {
      if (state is GetBuyerChatListSuccess) {
        if ((state as GetBuyerChatListSuccess).isLoadingMore) {
          return;
        }
        emit((state as GetBuyerChatListSuccess).copyWith(isLoadingMore: true));

        DataOutput<ChatedUser> result =
            await _chatRepository.fetchBuyerChatList(
          (state as GetBuyerChatListSuccess).page + 1,
        );

        GetBuyerChatListSuccess messagesSuccessState =
            (state as GetBuyerChatListSuccess);

        // messagesSuccessState.await.insertAll(0, result.modelList);
        messagesSuccessState.chatedUserList.addAll(result.modelList);
        emit(GetBuyerChatListSuccess(
          chatedUserList: messagesSuccessState.chatedUserList,
          page: (state as GetBuyerChatListSuccess).page + 1,
          hasError: false,
          isLoadingMore: false,
          total: result.total,
        ));
      }
    } catch (e) {
      emit((state as GetBuyerChatListSuccess)
          .copyWith(isLoadingMore: false, hasError: true));
    }
  }

  bool hasMoreData() {
    if (state is GetBuyerChatListSuccess) {
      return (state as GetBuyerChatListSuccess).chatedUserList.length <
          (state as GetBuyerChatListSuccess).total;
    }

    return false;
  }

  GetBuyerChatListState? fromJson(Map<String, dynamic> json) {
    return null;
  }

  Map<String, dynamic>? toJson(GetBuyerChatListState state) {
    return null;
  }

  ChatedUser? getOfferForItem(int itemId) {
    if (state is GetBuyerChatListSuccess) {
      List<ChatedUser> offerList =
          (state as GetBuyerChatListSuccess).chatedUserList;

      int matchingOffer = offerList.indexWhere(
        (offer) => offer.itemId == itemId,
      );
      if (matchingOffer != -1) {
        return (state as GetBuyerChatListSuccess).chatedUserList[matchingOffer];
      } else {
        return null;
      }
    }
    return null; // Return null if state is not GetBuyerChatListSuccess
  }

  void resetState() {
    emit(GetBuyerChatListInProgress());
  }
}
