import 'dart:convert';

class SSEParser {
  static Stream<String> parse(Stream<String> stream) async* {
    await for (final raw in stream) {
      final lines = raw.split('\n');

      for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final jsonStr = line.replaceFirst('data:', '').trim();
        if (jsonStr.isEmpty || jsonStr == '[DONE]') return;

        try {
          final map = jsonDecode(jsonStr);
          if (map['type'] == 'chunk' && map['chunk'] != null) {
            yield jsonEncode({
              'content' : map['chunk'].toString(),
              'type' : 'stream',
              'category': '',
              'level': ''
            });
          }
          if (map['done'] == true) {
            yield jsonEncode({
              'content' : map['data'],
              'type' : 'no_stream',
              'category': map['tool'],
              'level': map['level']
            });
          }
        } catch (_) {
          // 非JSON或异常，忽略该条
        }
      }
    }
  }
}