import 'dart:convert';

class SSEParser {
  static Stream<String> parse(Stream<String> stream) async* {
    // SSE 事件以空行分隔；网络分包不保证与事件边界对齐，必须先缓冲
    // 再按事件切分。否则较大的事件（如带医院卡片数据的 done 事件）会
    // 被截成两半，jsonDecode 失败后被静默丢弃
    var buffer = '';
    await for (final raw in stream) {
      buffer += raw;
      int idx;
      while ((idx = buffer.indexOf('\n\n')) >= 0) {
        final block = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 2);
        for (final line in block.split('\n')) {
          final event = _parseLine(line);
          if (event == null) continue;
          if (event == _terminate) return;
          yield event;
        }
      }
    }
    // 流关闭时缓冲区里可能还剩最后一个未跟空行的事件
    for (final line in buffer.split('\n')) {
      final event = _parseLine(line);
      if (event == null) continue;
      if (event == _terminate) return;
      yield event;
    }
  }

  static const _terminate = '__SSE_TERMINATE__';

  static String? _parseLine(String line) {
    line = line.trimRight(); // 去掉可能的 \r
    if (!line.startsWith('data:')) return null;
    final jsonStr = line.replaceFirst('data:', '').trim();
    if (jsonStr.isEmpty) return null;
    if (jsonStr == '[DONE]') return _terminate;

    try {
      final map = jsonDecode(jsonStr);
      // chunk：普通流式文本；hospital_chunk：医院查询第二条消息的
      // 流式文本（服务端未启用卡片模式时的纯文本降级路径）
      if ((map['type'] == 'chunk' || map['type'] == 'hospital_chunk') &&
          map['chunk'] != null) {
        return jsonEncode({
          'content' : map['chunk'].toString(),
          'type' : 'stream',
          'category': '',
          'level': ''
        });
      }
      if (map['done'] == true) {
        final data = map['data'];
        return jsonEncode({
          'content' : data,
          'type' : 'no_stream',
          // 触发的工具在 data.tool（顶层 tool 仅部分事件才有）
          'category': (data is Map ? data['tool'] : null) ?? map['tool'] ?? '',
          // message_done(temp_reply) 表示这是医院查询的过渡消息，
          // 同一流里还会有第二条消息
          'more': map['message'] == 'temp_reply',
          'level': map['level'] ?? (data is Map ? data['level'] : null),
        });
      }
    } catch (_) {
      // 非JSON或异常，忽略该条
    }
    return null;
  }
}
