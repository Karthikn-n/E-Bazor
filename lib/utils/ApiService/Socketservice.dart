import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:Ebozor/settings.dart';
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
  bool _attemptedFallback = false;

  bool get isConnected => _socket?.connected ?? false;
  final ValueNotifier<bool> isOtherUserTyping = ValueNotifier(false);

  /// Connect socket safely
  void connect() {
    if (_socket?.connected == true || _isConnecting) return;

    if (_socket != null) {
      _isConnecting = true;
      _socket!.connect();
      return;
    }

    _connectWithUrl(AppSettings.socketUrl);
  }

  void _connectWithUrl(String targetUrl) {
    _isConnecting = true;
    final token = HiveUtils.getJWT();
    log("[ChatSocket] Connecting to: $targetUrl (JWT present: ${token != null && token.isNotEmpty})");

    _socket = IO.io(
      targetUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(5)
          .setTimeout(5000)
          .setAuth({"token": "Bearer $token"})
          .setExtraHeaders({"Authorization": "Bearer $token"})
          .build(),
    );

    _socket!.on("typing", (data) {
      final myId = HiveUtils.getUserId();
      final senderId = data is Map ? (data["userId"] ?? data["sender_id"] ?? data["senderId"])?.toString() : null;

      // ignore own typing
      if (senderId != null && senderId == myId) return;

      final status = data is Map ? data["status"]?.toString() : null;
      if (status == "start") {
        print("[ChatSocket] ✍️ Other user typing");
        isOtherUserTyping.value = true;
      } else {
        print("[ChatSocket] 🛑 Other user stopped typing");
        isOtherUserTyping.value = false;
      }
    });

    // Add listeners
    _socket!.off("message");
    _socket!.off("chat-message");
    _socket!.off("receive-message");
    _socket!.off("newMessage");

    _socket!.on("message", _onMessageReceived);
    _socket!.on("chat-message", _onMessageReceived);
    _socket!.on("receive-message", _onMessageReceived);
    _socket!.on("newMessage", _onMessageReceived);

    _socket!.onConnect((_) {
      _isConnecting = false;
      log("[ChatSocket] 🔥 Socket Connected successfully to $targetUrl");
      for (final offerId in _joinedOfferIds) {
        _emitJoin(offerId);
      }
      _startPresencePing();
    });

    _socket!.onDisconnect((reason) {
      _isConnecting = false;
      log("[ChatSocket] 🔥 Socket Disconnected: $reason");
      _stopPresencePing();
    });

    _socket!.onConnectError((error) {
      _isConnecting = false;
      log("[ChatSocket] Socket connection error ($targetUrl): $error");
      if (!_attemptedFallback && targetUrl.contains(":6002")) {
        _attemptedFallback = true;
        log("[ChatSocket] Retrying connection on host URL without port 6002: ${AppSettings.hostUrl}");
        disconnect();
        _connectWithUrl(AppSettings.hostUrl);
      }
    });

    _socket!.onError((error) {
      log("[ChatSocket] Socket error ($targetUrl): $error");
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
      log("🔥 Ignored own message");
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
    log("[ChatSocket] 🔥 Emitting join for room: $offerId");
    final payload = {
      "offerId": offerId,
      "item_offer_id": offerId,
      "room": "offer_$offerId",
      "user_id": HiveUtils.getUserId(),
    };
    _socket?.emit("join", payload);
    _socket?.emit("join-room", payload);
    _socket?.emit("join_room", payload);
  }

  /// Send a chat message
  void sendMessage(int offerId, String message, {String? file, String? audio}) {
    if (_socket?.connected != true) {
      connect();
      return;
    }
    final payload = {
      "offerId": offerId,
      "item_offer_id": offerId,
      "message": message,
      "sender_id": HiveUtils.getUserId(),
      "file": file ?? "",
      "audio": audio ?? "",
      "created_at": DateTime.now().toUtc().toIso8601String(),
    };
    log("[ChatSocket] 🔥 Emitting message: $payload");
    _socket?.emit("message", payload);
    _socket?.emit("send-message", payload);
    _socket?.emit("sendMessage", payload);
  }

  /// Typing indicators
  void typingStart(int offerId) {
    if (_socket?.connected != true) return;
    final payload = {
      "offerId": offerId,
      "item_offer_id": offerId,
      "userId": HiveUtils.getUserId(),
      "sender_id": HiveUtils.getUserId(),
      "status": "start",
    };
    _socket?.emit("typing", payload);
  }

  void typingStop(int offerId) {
    if (_socket?.connected != true) return;
    final payload = {
      "offerId": offerId,
      "item_offer_id": offerId,
      "userId": HiveUtils.getUserId(),
      "sender_id": HiveUtils.getUserId(),
      "status": "stop",
    };
    _socket?.emit("typing", payload);
  }

  /// Presence ping
  void _startPresencePing() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      log("🔥 Emitting presence:ping");
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
      log("🔥 Emitting leave: {offerId: $offerId}");
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
    log("🔥 Hot reload detected, disconnecting old socket");
    disconnect();
  }
}
