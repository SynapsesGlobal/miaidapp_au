import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/utils/sse_parser.dart';
import 'package:miaid/view/chatbot/models/chat_message.dart';

Stream<String> _sse(List<Map<String, dynamic>> events) =>
    Stream.fromIterable(events.map((e) => 'data: ${jsonEncode(e)}\n\n'));

Future<List<Map<String, dynamic>>> _parse(List<Map<String, dynamic>> events) async {
  final out = await SSEParser.parse(_sse(events)).toList();
  return out.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
}

void main() {
  group('SSEParser', () {
    test('chunk 与 hospital_chunk 都作为流式文本透传', () async {
      final result = await _parse([
        {'type': 'chunk', 'chunk': '你', 'chatId': '1'},
        {'type': 'hospital_chunk', 'chunk': '好', 'chatId': '1'},
      ]);
      expect(result.length, 2);
      expect(result[0]['type'], 'stream');
      expect(result[0]['content'], '你');
      expect(result[1]['type'], 'stream');
      expect(result[1]['content'], '好');
    });

    test('done 事件从 data.tool 提取 category 并携带 hospitals', () async {
      final hospital = {
        'name': '仁济医院',
        'address': '上海市浦东新区',
        'phone': '021-1234567',
        'has_emergency_department': true,
        'is_private': false,
        'distance': 2.3,
      };
      final result = await _parse([
        {
          'type': 'done',
          'done': true,
          'message': 'mcp_query_hospital',
          'data': {
            'id': 'x',
            'role': 'doctor',
            'content': '已为您找到以下附近医院：',
            'tool': 'mcp_query_hospital',
            'level': 'Level1',
            'hospitals': [hospital],
          },
        },
      ]);
      expect(result.length, 1);
      expect(result[0]['type'], 'no_stream');
      expect(result[0]['category'], 'mcp_query_hospital');
      expect(result[0]['more'], false);

      final msg = ChatMessage.fromJson(
          result[0]['content'] as Map<String, dynamic>);
      expect(msg.hospitals, isNotNull);
      expect(msg.hospitals!.length, 1);
      expect(msg.hospitals![0]['name'], '仁济医院');
      // toJson 回传时保留 hospitals，保证服务端历史持久化不丢卡片
      expect(msg.toJson()['hospitals'], isNotNull);
    });

    test('message_done(temp_reply) 标记 more=true（同流还有第二条消息）', () async {
      final result = await _parse([
        {
          'type': 'message_done',
          'done': true,
          'message': 'temp_reply',
          'data': {
            'id': 'x',
            'role': 'doctor',
            'content': '正在为您查找附近医院…',
            'tool': 'mcp_query_hospital',
          },
        },
      ]);
      expect(result.length, 1);
      expect(result[0]['more'], true);
    });

    test('预约医院 category 透传（data.tool 优先于顶层缺失的 tool）', () async {
      final result = await _parse([
        {
          'type': 'message_done',
          'done': true,
          'message': 'AI_reply',
          'tool': 'mcp_appoint_hospital',
          'data': {
            'id': 'x',
            'role': 'doctor',
            'content': '好的，已为您预约。',
            'tool': 'mcp_appoint_hospital',
          },
        },
      ]);
      expect(result[0]['category'], 'mcp_appoint_hospital');
      expect(result[0]['more'], false);
    });

    test('level 从顶层或 data 透传', () async {
      final result = await _parse([
        {
          'type': 'done',
          'done': true,
          'message': 'AI reply',
          'level': 'Level4',
          'data': {'id': 'x', 'role': 'doctor', 'content': 'ok', 'tool': ''},
        },
      ]);
      expect(result[0]['level'], 'Level4');
    });

    test('事件被网络分包截断时仍能完整解析（缓冲重组）', () async {
      final done = {
        'type': 'done',
        'done': true,
        'message': 'mcp_query_hospital',
        'data': {
          'id': 'x',
          'role': 'doctor',
          'content': '已为您找到以下附近医院：',
          'tool': 'mcp_query_hospital',
          'hospitals': List.generate(5, (i) => {
            'name': '医院$i',
            'address': '上海市浦东新区某某路 $i 号，一段足够长的地址用来撑大事件体积',
            'phone': '021-000000$i',
            'website': 'https://example$i.example.com',
            'has_emergency_department': i.isEven,
            'is_private': i.isOdd,
            'latitude': 31.2 + i,
            'longitude': 121.5 + i,
            'distance': 1.5 + i,
          }),
        },
      };
      final wire = 'data: ${jsonEncode({'type': 'chunk', 'chunk': '好', 'chatId': '1'})}\n\n'
          'data: ${jsonEncode(done)}\n\n';
      // 每 7 个字符切一刀，模拟与事件边界完全不对齐的网络分包
      final chunks = <String>[];
      for (var i = 0; i < wire.length; i += 7) {
        chunks.add(wire.substring(i, i + 7 > wire.length ? wire.length : i + 7));
      }
      final out = await SSEParser.parse(Stream.fromIterable(chunks)).toList();
      final events = out.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

      expect(events.length, 2);
      expect(events[0]['type'], 'stream');
      expect(events[1]['type'], 'no_stream');
      final msg = ChatMessage.fromJson(events[1]['content'] as Map<String, dynamic>);
      expect(msg.hospitals!.length, 5);
    });

    test('流结束时缓冲区中最后一个无空行结尾的事件不丢失', () async {
      final out = await SSEParser.parse(Stream.fromIterable([
        'data: ${jsonEncode({'type': 'chunk', 'chunk': 'A', 'chatId': '1'})}',
      ])).toList();
      expect(out.length, 1);
      expect(jsonDecode(out[0])['content'], 'A');
    });

    test('无 hospitals 字段时 ChatMessage.hospitals 为 null（老服务端兼容）', () {
      final msg = ChatMessage.fromJson({
        'id': 'x',
        'role': 'doctor',
        'content': '文本医院列表',
      });
      expect(msg.hospitals, isNull);
      expect(msg.toJson().containsKey('hospitals'), isFalse);
    });
  });
}
