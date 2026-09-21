import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/view/chatbot/models/chat_message.dart';

void main() {
  group('ChatMessage tool 字段往返', () {
    test('fromJson 读取服务端的 tool，toJson 原样回传', () {
      final msg = ChatMessage.fromJson({
        'id': 'm1',
        'role': 'doctor',
        'content': '正在为您查找附近医院…',
        'createdTime': '2026-09-15T01:00:00.000Z',
        'tool': 'mcp_query_hospital',
        'level': 'Level1',
      });
      expect(msg.tool, 'mcp_query_hospital');
      expect(msg.toJson()['tool'], 'mcp_query_hospital');
    });

    test('服务端 tool 为空串时回传空串，缺失时也回传空串', () {
      final empty = ChatMessage.fromJson({
        'id': 'm2',
        'role': 'doctor',
        'content': 'ok',
        'createdTime': '2026-09-15T01:00:00.000Z',
        'tool': '',
      });
      expect(empty.toJson()['tool'], '');

      final missing = ChatMessage.fromJson({
        'id': 'm3',
        'role': 'patient',
        'content': 'hi',
        'createdTime': '2026-09-15T01:00:00.000Z',
      });
      expect(missing.tool, '');
      expect(missing.toJson().containsKey('tool'), isTrue);
      expect(missing.toJson()['tool'], '');
    });

    test('本地新建的患者消息 tool 默认为空串', () {
      final msg = ChatMessage(
        id: 'p1',
        role: MessageRole.patient,
        content: '头疼',
        createdTime: DateTime.now(),
      );
      expect(msg.toJson()['tool'], '');
    });

    test('copyWith 保留 tool', () {
      final msg = ChatMessage.fromJson({
        'id': 'm4',
        'role': 'doctor',
        'content': '好的，已为您预约。',
        'createdTime': '2026-09-15T01:00:00.000Z',
        'tool': 'mcp_appoint_hospital',
      }).copyWith(videoConsultation: true);
      expect(msg.tool, 'mcp_appoint_hospital');
      expect(msg.toJson()['tool'], 'mcp_appoint_hospital');
    });

    test('整段历史 JSON 往返后每条消息的 tool 都还在', () {
      const raw = '['
          '{"id":"a","role":"doctor","content":"你好","createdTime":"2026-09-15T01:00:00.000Z","tool":""},'
          '{"id":"b","role":"patient","content":"附近医院","createdTime":"2026-09-15T01:01:00.000Z","tool":""},'
          '{"id":"c","role":"doctor","content":"已找到","createdTime":"2026-09-15T01:02:00.000Z","tool":"mcp_query_hospital"}'
          ']';
      final messages = (jsonDecode(raw) as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      final sent = messages.map((m) => m.toJson()).toList();
      expect(sent.map((m) => m['tool']).toList(), ['', '', 'mcp_query_hospital']);
    });
  });
}
