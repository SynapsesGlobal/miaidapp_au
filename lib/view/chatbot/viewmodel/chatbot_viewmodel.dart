import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

import '../../../api_utils/api_provider.dart';
import '../../../api_utils/chatbot_stream_api.dart';
import '../../../api_utils/consts.dart';
import '../../../country/translations.dart';
import '../../../store/home/home_screen_store.dart';
import '../../../utils/configure_dependencies.dart';
import '../models/chat_message.dart';
import 'package:miaid/config/api_settings.dart';

class ChatBotViewModel extends ChangeNotifier {
  final _api = getIt<ApiProvider>();
  final _uuid = const Uuid();

  List<ChatMessage> messages = [];
  String chatId = '';
  bool isLoading = false;
  bool isSending = false;
  String? errorMessage;

  // 流式内容专用 notifier，chunk 更新只触发气泡局部重绘
  final ValueNotifier<String> streamingContent = ValueNotifier('');

  late final String _lang;
  late final String _currentLang;

  ChatBotViewModel() {
    _initLocale();
    createNewChat();
  }

  ChatBotViewModel.fromHistory({
    required String chatId,
    required String rawContent,
  }) {
    _initLocale();
    this.chatId = chatId;
    try {
      final list = jsonDecode(rawContent) as List;
      messages = list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to parse history content: $e');
      errorMessage = 'Failed to load chat history';
    }
  }

  @override
  void dispose() {
    streamingContent.dispose();
    super.dispose();
  }

  void _initLocale() {
    _currentLang = Intl.getCurrentLocale();
    _lang = (_currentLang == 'zh' || _currentLang == 'zh_Hant') ? 'zh-cn' : 'en-en';
  }

  // ─── Public API ────────────────────────────────────────────

  Future<void> createNewChat() async {
    _setLoading(true);
    errorMessage = null;

    try {
      final position = await _getPosition();
      final countryCode = await getCountryCodeFromLocation(position);
      final countryName = _resolveCountryName(countryCode);
      final localTime = _formatLocalTime();

      final requestBody = {
        'userId': '${_api.userProvider.user!.id}_au',
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
        'localTime': DateTime.now().toUtc().toIso8601String(),
        'createdTime': DateTime.now().toUtc().toIso8601String(),
        'lang': _lang,
        'country': countryName,
        'country_code': countryCode,
        'local_time': localTime,
      };

      final response = await http.post(
        Uri.parse('${getIt<ApiSettings>().chatBotApiHost}/app/create_chat'),
        headers: {'X-Custom-Token': getIt<ApiSettings>().chatBotApiToken},
        body: {'newChat': jsonEncode(requestBody)},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes))['data'];
        chatId = data['id'] ?? '';
        messages = ((data['chatContent'] as List?) ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        errorMessage = 'Failed to create chat (${response.statusCode})';
      }
    } catch (e) {
      errorMessage = 'Network error: $e';
      debugPrint('Create chat error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || chatId.isEmpty || isSending) return;

    isSending = true;
    streamingContent.value = '';

    try {
      final position = await _getPosition();

      messages.add(ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.patient,
        content: trimmed,
        latitude: position.latitude,
        longitude: position.longitude,
        createdTime: DateTime.now(),
      ));

      // 添加 streaming 占位，content 保持空，内容由 streamingContent 驱动
      messages.add(ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.doctor,
        content: '',
        createdTime: DateTime.now(),
        isStreaming: true,
      ));
      notifyListeners();

      final paramContents = messages
          .sublist(0, messages.length - 1)
          .map((m) => m.toJson())
          .toList();

      final stream = await ChatbotStreamApi.sendMessage(
        chatId: chatId,
        lang: _lang,
        contents: paramContents,
      );

      stream.listen(
        _handleStreamChunk,
        onDone: () {
          _removeStreamingMessage();
          isSending = false;
          notifyListeners();
        },
        onError: (error) {
          _removeStreamingMessage();
          isSending = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Send message error: $e');
      isSending = false;
      notifyListeners();
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  // ─── Private Helpers ───────────────────────────────────────

  void _handleStreamChunk(String chunk) {
    try {
      final data = jsonDecode(chunk) as Map<String, dynamic>;
      if (data['type'] == 'stream') {
        // 只更新 ValueNotifier，不触发整个列表重建
        streamingContent.value += data['content'] as String? ?? '';
      } else if (data['type'] == 'no_stream') {
        final content = data['content'] as Map<String, dynamic>;
        final finalMsg = ChatMessage.fromJson(content).copyWith(
          videoConsultation: data['category'] == Consts.AIVideoConsultation,
          appointInterpreter: data['category'] == Consts.AIAppointInterpreter,
        );
        streamingContent.value = '';
        // 移除当前 streaming 占位（按标记查找，同一流可能有多条完整消息，
        // 不能按固定下标删，否则会误删上一条过渡消息）
        _removeStreamingMessage();
        messages.add(finalMsg);

        // 医院查询的过渡消息：同一流稍后还有第二条（医院列表），
        // 重新挂一个 streaming 占位继续显示输入中动画
        final hasMore = data['more'] == true;
        if (hasMore) {
          messages.add(ChatMessage(
            id: _uuid.v4(),
            role: MessageRole.doctor,
            content: '',
            createdTime: DateTime.now(),
            isStreaming: true,
          ));
        } else {
          isSending = false;
        }
        notifyListeners();

        if (data['category'] == Consts.AIBookHospitals) {
          _bookHospitals();
        }

        if (data['level'].toString().toUpperCase() == Consts.AINotifyFamilyOrCompany) {
          _scheduleNotification();
        }
      }
    } catch (e) {
      debugPrint('Chunk parse error: $e');
    }
  }

  void _removeStreamingMessage() {
    messages.removeWhere((m) => m.isStreaming);
    streamingContent.value = '';
  }

  Future<void> _bookHospitals() async {
    try {
      final position = await _getPosition();
      final response = await http.post(
        Uri.parse('${_api.baseUrl}/api/v1/book/hospitals'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': _api.userProvider.user!.id.toString(),
          'x-api-key': _api.apiKey,
        },
        body: jsonEncode({
          'userId': _api.userProvider.user!.id.toString(),
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
          'lang': Intl.getCurrentLocale(),
          'chatbotId': chatId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final pos = await _getPosition();
        messages.add(ChatMessage(
          id: _uuid.v4(),
          role: MessageRole.doctor,
          content: responseData['message'] ?? '',
          latitude: pos.latitude,
          longitude: pos.longitude,
          createdTime: DateTime.now(),
        ));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Book hospitals error: $e');
    }
  }

  Future<void> _scheduleNotification() async {
    try {
      await http.post(
        Uri.parse('${_api.baseUrl}/api/v1/consultation/scheduled'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': _api.userProvider.user!.id.toString(),
          'x-api-key': _api.apiKey,
        },
        body: jsonEncode({
          'chatbot_id': chatId,
          'userId': _api.userProvider.user!.id.toString(),
        }),
      );
    } catch (e) {
      debugPrint('Schedule notification error: $e');
    }
  }

  Future<Position> _getPosition() =>
      determinePosition(desiredAccuracy: LocationAccuracy.medium);

  String _resolveCountryName(String? countryCode) {
    final lang = (_currentLang == 'zh' || _currentLang == 'zh_Hant') ? 'zh' : 'en';
    if (countryCode != null &&
        Countries.AllCountryNames.containsKey(countryCode) &&
        Countries.AllCountryNames[countryCode]!.containsKey(lang)) {
      return Countries.AllCountryNames[countryCode]![lang]!.toString();
    }
    return 'Australia';
  }

  String _formatLocalTime() {
    const langCodeMap = {
      'zh': 'zh-CN',
      'zh_Hant': 'zh_TW',
      'en': 'en_US',
      'ko': 'ko_KR',
      'id': 'id_ID',
    };
    final langCode = langCodeMap[_currentLang] ?? 'en_US';
    return DateFormat('yyyy-MM-dd HH:mm:ss', langCode).format(DateTime.now());
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
