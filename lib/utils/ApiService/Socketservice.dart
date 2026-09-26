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
  Timer? _typingTimeoutTimer;
  bool _isConnecting = false;
  String? _connectedUserId;
  final Set<int> _joinedOfferIds = <int>{};

  bool get isConnected => _socket?.connected ?? false;
  final ValueNotifier<bool> isOtherUserTyping = ValueNotifier(false);

  /// Connect socket safely
  Future<void> connect({bool force = false}) async {
    final currentUserId = HiveUtils.getUserId() ?? '';
    final token = HiveUtils.getJWT();
    if (token == null || token.isEmpty || currentUserId.isEmpty) {
      disconnect();
      return;
    }

    if (!force && _socket?.connected == true && _connectedUserId == currentUserId) {
      return;
    }

    if (_isConnecting && _connectedUserId == currentUserId) return;

    if (_socket != null) {
      disconnect();
    }

    _connectedUserId = currentUserId;
    _isConnecting = true;

    // Trigger backend WS authorization session if available
    try {
      final authRes = await wsAuth();
      log("[ChatSocket] wsAuth handshake response: $authRes");
    } catch (e) {
      log("[ChatSocket] wsAuth optional check: $e");
    }

    _connectWithUrl(AppSettings.socketUrl);
  }

  void _connectWithUrl(String targetUrl) {
    _isConnecting = true;
    final token = HiveUtils.getJWT();
    final rawToken = token != null && token.startsWith('Bearer ')
        ? token.substring(7).trim()
        : (token?.trim() ?? '');
    final userId = HiveUtils.getUserId() ?? '';

    final uri = Uri.parse(targetUrl);
    final baseUrl = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
    final socketPath = uri.path.isNotEmpty && uri.path != '/'
        ? (uri.path.endsWith('/') ? uri.path : '${uri.path}/')
        : '/socket.io/';

    log("[ChatSocket] Connecting to: $baseUrl (path: $socketPath, User: $userId, JWT present: ${rawToken.isNotEmpty})");

    if (_socket != null) {
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    final authPayload = <String, dynamic>{
      if (rawToken.isNotEmpty) "token": rawToken,
      if (rawToken.isNotEmpty) "accessToken": rawToken,
      if (rawToken.isNotEmpty) "Authorization": "Bearer $rawToken",
      if (rawToken.isNotEmpty) "authorization": "Bearer $rawToken",
      if (userId.isNotEmpty) "userId": userId,
      if (userId.isNotEmpty) "user_id": userId,
    };

    final queryPayload = <String, dynamic>{
      if (rawToken.isNotEmpty) "token": rawToken,
      if (userId.isNotEmpty) "userId": userId,
      if (userId.isNotEmpty) "user_id": userId,
    };

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath(socketPath)
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(5)
          .setTimeout(5000)
          .setAuth(authPayload)
          .setQuery(queryPayload)
          .setExtraHeaders({
            if (rawToken.isNotEmpty) "Authorization": "Bearer $rawToken",
          })
          .build(),
    );

    final typingEvents = ["typing", "user:typing", "user-typing", "user_typing"];
    for (final event in typingEvents) {
      _socket!.off(event);
      _socket!.on(event, _onTypingReceived);
    }

    // Add message listeners
    final messageEvents = ["message", "chat-message", "receive-message", "newMessage"];
    for (final event in messageEvents) {
      _socket!.off(event);
      _socket!.on(event, _onMessageReceived);
    }

    _socket!.onConnect((_) {
      _isConnecting = false;
      log("[ChatSocket] 🔥 Socket Connected successfully to $baseUrl$socketPath");
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
      log("[ChatSocket] Socket connection error ($baseUrl$socketPath): $error");
    });

    _socket!.onError((error) {
      log("[ChatSocket] Socket error ($baseUrl$socketPath): $error");
    });

    _socket!.connect();
  }

  void _onTypingReceived(dynamic data) {
    final payload = _messagePayload(data);
    if (payload == null) return;

    final myId = HiveUtils.getUserId();
    final senderId = (payload["userId"] ??
            payload["user_id"] ??
            payload["sender_id"] ??
            payload["senderId"] ??
            payload["from"])
        ?.toString();

    // Ignore own typing
    if (senderId != null && senderId == myId) return;

    final itemOfferId = _asInt(
        payload['item_offer_id'] ?? payload['offerId'] ?? payload['cid']);
    if (itemOfferId != null && !_joinedOfferIds.contains(itemOfferId)) return;

    final rawStatus = payload["status"]?.toString().toLowerCase();
    final isTyping = rawStatus == "start" ||
        rawStatus == "typing" ||
        rawStatus == "true" ||
        payload["isTyping"] == true ||
        payload["typing"] == true ||
        payload["on"] == true;

    _typingTimeoutTimer?.cancel();
    if (isTyping) {
      log("[ChatSocket] ✍️ Other user typing in offer: $itemOfferId");
      isOtherUserTyping.value = true;
      _typingTimeoutTimer = Timer(const Duration(seconds: 5), () {
        isOtherUserTyping.value = false;
      });
    } else {
      log("[ChatSocket] 🛑 Other user stopped typing in offer: $itemOfferId");
      isOtherUserTyping.value = false;
    }
  }

  /// Handle incoming messages
  void _onMessageReceived(dynamic data) {
    final payload = _messagePayload(data);
    if (payload == null) return;

    final senderId = _asInt(payload['sender_id'] ?? payload['senderId'] ?? payload['userId'] ?? payload['user_id']);
    final itemOfferId = _asInt(payload['item_offer_id'] ?? payload['offerId'] ?? payload['cid']);
    if (senderId == null || itemOfferId == null) return;
    if (!_joinedOfferIds.contains(itemOfferId)) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final messageId = _asInt(payload['id']);
    final createdAt = payload['created_at']?.toString() ?? now;

    // Reset typing status on incoming message
    _typingTimeoutTimer?.cancel();
    isOtherUserTyping.value = false;

    final chat = ChatMessage(
      key: ValueKey(
          messageId ?? '${itemOfferId}_$createdAt'),
      id: messageId,
      message: payload['message']?.toString() ?? "",
      senderId: senderId,
      createdAt: createdAt,
      updatedAt: payload['updated_at']?.toString() ?? now,
      itemOfferId: itemOfferId,
      file: payload['file']?.toString() ?? "",
      audio: payload['audio']?.toString() ?? "",
      messageType: payload['message_type']?.toString(),
      isSentNow: false,
    );

    log("[ChatSocket] 📥 Processing message: id=$messageId sender=$senderId offerId=$itemOfferId");
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
    wsCanJoin(itemOfferId: offerId).then((res) {
      log("[ChatSocket] wsCanJoin($offerId) response: $res");
    }).catchError((e) {
      log("[ChatSocket] wsCanJoin($offerId) error: $e");
    });
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
      "userId": HiveUtils.getUserId(),
    };
    _socket?.emit("join", payload);
    _socket?.emit("join-room", payload);
    _socket?.emit("join_room", payload);
  }

  /// Send a chat message
  void sendMessage(int offerId, String message, {String? file, String? audio}) {
    final myId = HiveUtils.getUserId();
    final payload = {
      "offerId": offerId,
      "item_offer_id": offerId,
      "room": "offer_$offerId",
      "message": message,
      "sender_id": myId,
      "userId": myId,
      "user_id": myId,
      "file": file ?? "",
      "audio": audio ?? "",
      "created_at": DateTime.now().toUtc().toIso8601String(),
    };

    if (_socket?.connected != true) {
      log("[ChatSocket] Direct socket not connected. Connecting...");
      connect();
      return;
    }

    log("[ChatSocket] 🔥 Emitting message: $payload");
    _socket?.emit("message", payload);
    _socket?.emit("sendMessage", payload);
  }

  /// Typing indicators
  void typingStart(int offerId) {
    if (_socket?.connected != true) return;
    final myId = HiveUtils.getUserId();
    final payload = {
      "offerId": offerId,
      "item_offer_id": offerId,
      "room": "offer_$offerId",
      "userId": myId,
      "user_id": myId,
      "sender_id": myId,
      "status": "start",
      "isTyping": true,
      "typing": true,
      "on": true,
    };
    _socket?.emit("typing", payload);
    _socket?.emit("user:typing", payload);
    _socket?.emit("user-typing", payload);
  }

  void typingStop(int offerId) {
    if (_socket?.connected != true) return;
    final myId = HiveUtils.getUserId();
    final payload = {
      "offerId": offerId,
      "item_offer_id": offerId,
      "room": "offer_$offerId",
      "userId": myId,
      "user_id": myId,
      "sender_id": myId,
      "status": "stop",
      "isTyping": false,
      "typing": false,
      "on": false,
    };
    _socket?.emit("typing", payload);
    _socket?.emit("user:typing", payload);
    _socket?.emit("user-typing", payload);
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
    _typingTimeoutTimer?.cancel();
    isOtherUserTyping.value = false;
    _isConnecting = false;
    _connectedUserId = null;
    _joinedOfferIds.clear();
    final messageEvents = ["message", "chat-message", "receive-message", "newMessage"];
    for (final event in messageEvents) {
      _socket?.off(event);
    }
    final typingEvents = ["typing", "user:typing", "user-typing", "user_typing"];
    for (final event in typingEvents) {
      _socket?.off(event);
    }
    _socket?.disconnect();
    _socket?.dispose();
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
