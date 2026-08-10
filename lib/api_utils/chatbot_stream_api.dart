import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/sse_parser.dart';
import '../api_utils/consts.dart';

class ChatbotStreamApi {
  static Future<Stream<String>> sendMessage({
    required String chatId,
    required String lang,
    required List contents,
  }) async {
    final url = Uri.parse(Consts.chatBotApiHost + '/app/current_chat_stream');
    final request = http.MultipartRequest('POST', url);

    request.headers['X-Custom-Token'] = Consts.chatBotApiToken;
    request.headers['Accept'] = 'text/event-stream';

    request.fields['history'] = jsonEncode({
      'id': chatId,
      'lang': lang,
      // 告知服务端本客户端支持医院卡片：查询附近医院时返回结构化
      // hospitals 数据（老服务端会忽略该字段并按纯文本返回，可平滑降级）
      'hospitalCards': true,
      'chatContent': contents,
    });

    final response = await request.send();
    /*response.stream.transform(utf8.decoder).listen(
      (data) => print('流数据: $data'),
      onError: (e) => print('流错误: $e'),
      onDone: () => print('流结束'),
    );*/

    return SSEParser.parse(
      response.stream.transform(utf8.decoder),
    );
  }
}
