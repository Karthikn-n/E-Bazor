import 'dart:async';
import 'dart:convert';
import 'package:Ebozor/ui/screens/chat/chat_audio/widgets/chat_widget.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/notification/chat_message_handler.dart';
import 'package:flutter/cupertino.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';

class ChatSocketService {
  // Singleton instance
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;
  ChatSocketService._internal();

  IO.Socket? _socket;
  Timer? _presenceTimer;
  bool _isConnecting = false;
  final Set<int> _joinedOfferIds = <int>{};

  bool get isConnected => _socket?.connected ?? false;
  final ValueNotifier<bool> isOtherUserTyping = ValueNotifier(false);

  /// Connect socket safely
  void connect() {
    if (_socket?.connected == true || _isConnecting) return;

    // Reuse the existing Socket.IO instance so repeated join calls while the
    // handshake is in progress cannot tear it down and lose the room join.
    if (_socket != null) {
      _isConnecting = true;
      _socket!.connect();
      return;
    }

    _isConnecting = true;

    _socket = IO.io(
      "http://143.110.251.34:6002",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setAuth({"token": "Bearer ${HiveUtils.getJWT()}"})
          .build(),
    );

    _socket!.on("typing", (data) {
      final myId = HiveUtils.getUserId();

      // ignore own typing
      if (data["userId"].toString() == myId) return;

      if (data["status"] == "start") {
        print("✍️ Other user typing");
        isOtherUserTyping.value = true;
      } else {
        print("🛑 Other user stopped typing");
        isOtherUserTyping.value = false;
      }
    });

    // Add listeners once
    _socket!.off("message");
    _socket!.on("message", _onMessageReceived);

    _socket!.onConnect((_) {
      _isConnecting = false;
      for (final offerId in _joinedOfferIds) {
        _emitJoin(offerId);
      }
      print("🔥 Socket Connected");
      _startPresencePing();
    });

    _socket!.onDisconnect((_) {
      _isConnecting = false;
      print("🔥 Socket Disconnected");
      _stopPresencePing();
    });

    _socket!.onConnectError((error) {
      _isConnecting = false;
      print("Socket connection error: $error");
    });

    _socket!.onError((error) {
      print("Socket error: $error");
    });

    _socket!.connect();
  }

  /// Handle incoming messages
  void _onMessageReceived(dynamic data) {
    final payload = _messagePayload(data);
    if (payload == null) return;

    final senderId = _asInt(payload['sender_id'] ?? payload['senderId']);
    final itemOfferId = _asInt(payload['item_offer_id'] ?? payload['offerId']);
    if (senderId == null || itemOfferId == null) return;
    if (!_joinedOfferIds.contains(itemOfferId)) return;

    final myId = HiveUtils.getUserId();

    // Ignore own messages
    if (senderId.toString() == myId) {
      print("🔥 Ignored own message");
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final messageId = _asInt(payload['id']);

    final chat = ChatMessage(
      key: ValueKey(
          messageId ?? '${itemOfferId}_${payload['created_at'] ?? now}'),
      id: messageId,
      message: payload['message']?.toString() ?? "",
      senderId: senderId,
      createdAt: payload['created_at']?.toString() ?? now,
      updatedAt: payload['updated_at']?.toString() ?? now,
      itemOfferId: itemOfferId,
      file: payload['file']?.toString() ?? "",
      audio: payload['audio']?.toString() ?? "",
      messageType: payload['message_type']?.toString(),
    );

    ChatMessageHandler.add(chat);
  }

  Map<String, dynamic>? _messagePayload(dynamic data) {
    dynamic decoded = data;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return null;
      }
    }
    if (decoded is! Map) return null;

    var payload = Map<String, dynamic>.from(decoded);
    if (payload['data'] is Map) {
      payload = Map<String, dynamic>.from(payload['data'] as Map);
    }
    return payload;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  /// Join a specific offer room
  void joinOffer(int offerId) {
    _joinedOfferIds.add(offerId);
    if (_socket?.connected == true) {
      _emitJoin(offerId);
    } else {
      connect();
    }
  }

  void _emitJoin(int offerId) {
    print("🔥 Emitting join: {offerId: $offerId}");
    _socket?.emit("join", {
      "offerId": offerId,
      "item_offer_id": offerId,
    });
  }

  /// Send a chat message
  void sendMessage(int offerId, String message) {
    if (_socket?.connected != true) {
      connect();
      return;
    }
    print("🔥 Emitting message: {offerId: $offerId, message: $message}");
    _socket?.emit("message", {
      "offerId": offerId,
      "item_offer_id": offerId,
      "message": message,
    });
  }

  /// Typing indicators
  void typingStart(int offerId) {
    if (_socket?.connected != true) return;
    _socket?.emit("typing", {
      "offerId": offerId,
      "item_offer_id": offerId,
      "status": "start",
    });
  }

  void typingStop(int offerId) {
    if (_socket?.connected != true) return;
    _socket?.emit("typing", {
      "offerId": offerId,
      "item_offer_id": offerId,
      "status": "stop",
    });
  }

  /// Presence ping
  void _startPresencePing() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      print("🔥 Emitting presence:ping");
      _socket?.emit("presence:ping");
    });
  }

  void _stopPresencePing() {
    _presenceTimer?.cancel();
  }

  /// Leave a specific offer room
  void leaveOffer(int offerId) {
    _joinedOfferIds.remove(offerId);
    if (_socket != null && _socket!.connected) {
      print("🔥 Emitting leave: {offerId: $offerId}");
      _socket?.emit("leave", {
        "offerId": offerId,
        "item_offer_id": offerId,
      });
    }
  }

  /// REST WebSocket Helpers (from API_DOCUMENTATION 1.md section 3.9)

  /// GET /api/ws/auth
  static Future<Map<String, dynamic>> wsAuth() async {
    try {
      return await Api.get(url: Api.wsAuthApi);
    } catch (e) {
      rethrow;
    }
  }

  /// GET /api/ws/can-join?item_offer_id={id}
  static Future<Map<String, dynamic>> wsCanJoin(
      {required int itemOfferId}) async {
    try {
      return await Api.get(
        url: Api.wsCanJoinApi,
        queryParameters: {"item_offer_id": itemOfferId},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// GET /api/ws/ping
  static Future<Map<String, dynamic>> wsPing() async {
    try {
      return await Api.get(url: Api.wsPingApi);
    } catch (e) {
      rethrow;
    }
  }

  /// GET /api/ws/presence?item_offer_id={id}&details=1
  static Future<Map<String, dynamic>> wsPresence({
    int? itemOfferId,
    int? details = 1,
  }) async {
    try {
      return await Api.get(
        url: Api.wsPresenceApi,
        queryParameters: {
          if (itemOfferId != null) "item_offer_id": itemOfferId,
          if (details != null) "details": details,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// POST /api/ws/message (Proxy endpoint for Socket.IO server)
  static Future<Map<String, dynamic>> wsSendMessageProxy({
    required int itemOfferId,
    String? message,
    dynamic file,
    dynamic audio,
  }) async {
    try {
      Map<String, dynamic> parameters = {
        "item_offer_id": itemOfferId,
      };
      if (message != null && message.isNotEmpty)
        parameters["message"] = message;
      if (file != null) parameters["file"] = file;
      if (audio != null) parameters["audio"] = audio;

      return await Api.post(url: Api.wsMessageApi, parameter: parameters);
    } catch (e) {
      rethrow;
    }
  }

  /// Disconnect socket safely
  void disconnect() {
    _stopPresencePing();
    _isConnecting = false;
    _joinedOfferIds.clear();
    _socket?.off("message");
    _socket?.disconnect();
    _socket = null;
  }

  /// Hot reload safety
  @mustCallSuper
  void reassemble() {
    // This runs on hot reload
    print("🔥 Hot reload detected, disconnecting old socket");
    disconnect();
  }
}
