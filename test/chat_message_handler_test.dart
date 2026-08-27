import 'package:Ebozor/utils/notification/chat_message_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ChatMessageHandler.flushMessages);
  tearDown(ChatMessageHandler.flushMessages);

  test('chat stream replays messages added before subscription', () async {
    ChatMessageHandler.add(const SizedBox(key: ValueKey<int>(1)));

    final snapshot = await ChatMessageHandler.getChatStream().first;

    expect(snapshot, hasLength(1));
    expect(snapshot.single.key, const ValueKey<int>(1));
  });

  test('new messages are exposed first for a reversed chat list', () async {
    ChatMessageHandler.add(const SizedBox(key: ValueKey<int>(1)));
    ChatMessageHandler.add(const SizedBox(key: ValueKey<int>(2)));

    final snapshot = await ChatMessageHandler.getChatStream().first;

    expect(
      snapshot.map((message) => message.key),
      const [ValueKey<int>(2), ValueKey<int>(1)],
    );
  });
}
