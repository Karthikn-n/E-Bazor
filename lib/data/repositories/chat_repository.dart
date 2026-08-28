import 'package:dio/dio.dart';
import 'package:Ebozor/data/model/chat/chated_user_model.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/ui/screens/chat/chat_audio/widgets/chat_widget.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:flutter/material.dart';

class ChatRepostiory {
  void setContext(BuildContext context) {
    // Retained for existing callers; chat requests no longer depend on a
    // widget context.
  }

  Future<DataOutput<ChatedUser>> fetchBuyerChatList(int page) async {
    /* Map<String, dynamic> response = await Api.get(
        url: Api.getChatListApi, queryParameters: {*/ /*"page": page, */ /*"type": "buyer"});*/

    Map<String, dynamic> response = await Api.get(
        url: Api.getChatListApi,
        queryParameters: {"type": "buyer", "page": page});

    List<ChatedUser> modelList = (response['data']['data'] as List).map(
      (e) {
        return ChatedUser.fromJson(e);
      },
    ).toList();

    return DataOutput(total: response['data']['total'], modelList: modelList);
  }

  Future<DataOutput<ChatedUser>> fetchSellerChatList(int page) async {
    Map<String, dynamic> response = await Api.get(
        url: Api.getChatListApi,
        queryParameters: {"page": page, "type": "seller"});

    List<ChatedUser> modelList = (response['data']["data"] as List).map(
      (e) {
        return ChatedUser.fromJson(e /*, context: _setContext*/);
      },
    ).toList();

    return DataOutput(
        total: response['data']['total'] ?? 0, modelList: modelList);
  }

  Future<DataOutput<ChatMessage>> getMessagesApi(
      {required int page, required int itemOfferId}) async {
    Map<String, dynamic> response = await Api.get(
      url: Api.chatMessagesApi,
      queryParameters: {
        "item_offer_id": itemOfferId,
        "page": page,
      },
    );

    List<ChatMessage> modelList = (response['data']['data'] as List).map(
      (result) {
        int senderId = int.tryParse(result['sender_id']?.toString() ?? '0') ?? 0;
        String message = result['message']?.toString() ?? "";
        String file = result['file']?.toString() ?? "";
        String audio = result['audio']?.toString() ?? "";
        String createdAt = result['created_at']?.toString() ?? DateTime.now().toIso8601String();
        int itemOfferId = int.tryParse(result['item_offer_id']?.toString() ?? '0') ?? 0;
        int id = int.tryParse(result['id']?.toString() ?? '0') ?? 0;

        return ChatMessage(
          key: ValueKey(id),
          message: message,
          senderId: senderId,
          createdAt: createdAt,
          file: file,
          audio: audio,
          itemOfferId: itemOfferId,
          updatedAt: createdAt,
        );
      },
    ).toList();

    return DataOutput(
      total: (response['data']['total'] as num?)?.toInt() ?? modelList.length,
      modelList: modelList,
    );
  }

  /// send msg api here
  Future<Map<String, dynamic>> sendMessageApi(
      {required int itemOfferId,
      required String message,
      MultipartFile? audio,
      MultipartFile? attachment}) async {
    Map<String, dynamic> parameters = {
      "item_offer_id": itemOfferId,
    };

    if (attachment != null) {
      parameters['file'] = attachment;
    }
    if (audio != null) {
      parameters['audio'] = audio;
    }

    if (message != "") {
      parameters['message'] = message;
    }

    print("/////////////// send message param");
    print(parameters);
    print("///////////////");

    // Logger.error(parameters, name: "CHAT PARAMS");
    Map<String, dynamic> map =
        await Api.post(url: Api.sendMessageApi, parameter: parameters);

    print("/////////////// API RESPONSE //////////////////////");
    print(map);
    print("////////////////////////////////////////////////////");

    return map;
  }

  Future<Map<String, dynamic>> blockUserApi({required int blockUserId}) async {
    Map<String, dynamic> parameters = {
      "blocked_user_id": blockUserId,
    };

    Map<String, dynamic> map =
        await Api.post(url: Api.blockUserApi, parameter: parameters);

    return map;
  }

  Future<Map<String, dynamic>> unBlockUserApi(
      {required int blockUserId}) async {
    Map<String, dynamic> parameters = {
      "blocked_user_id": blockUserId,
    };

    Map<String, dynamic> map =
        await Api.post(url: Api.unBlockUserApi, parameter: parameters);

    return map;
  }

  Future<DataOutput<BlockedUserModel>> blockedUsersListApi() async {
    Map<String, dynamic> response =
        await Api.get(url: Api.blockedUsersListApi, queryParameters: {});

    List<BlockedUserModel> modelList = (response['data'] as List).map(
      (e) {
        return BlockedUserModel.fromJson(e);
      },
    ).toList();

    return DataOutput(modelList: modelList, total: modelList.length);
  }

/*  Future<Map<String, dynamic>> blockedUsersListApi() async {
    Map<String, dynamic> map =
        await Api.get(url: Api.blockedUsersListApi, queryParameters: {});

    return map;
  }*/
}
