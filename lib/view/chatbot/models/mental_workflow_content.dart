import 'dart:convert';

/// 心理工作流（Level5 Q7）消息的结构化内容。
///
/// 服务端把 LLM 输出的 JSON 原样存进 doctor 消息的 `content`：
/// ```json
/// {
///   "recommendation": {"content": "..."},
///   "mental_resources": {"m2_list": [...], "m3_list": [...], "m4_list": [...]},
///   "follow_up_question": {"content": "..."}
/// }
/// ```
/// - m2_list（心理援助热线）/ m3_list（在线支持平台）每项：country / name / description / phone
/// - m4_list（附近医院）每项：name / phone / address / website / latitude / longitude / distance
///
/// 该类只用于展示层解析，`ChatMessage.content` 保持原始 JSON 字符串不动，
/// 回传历史时服务端和 LLM 拿到的仍是原文。
class MentalWorkflowContent {
  final String? recommendation;
  final List<Map<String, dynamic>> hotlines;
  final List<Map<String, dynamic>> onlinePlatforms;
  final List<Map<String, dynamic>> clinics;
  final String? followUpQuestion;

  const MentalWorkflowContent({
    this.recommendation,
    this.hotlines = const [],
    this.onlinePlatforms = const [],
    this.clinics = const [],
    this.followUpQuestion,
  });

  bool get hasResources =>
      hotlines.isNotEmpty || onlinePlatforms.isNotEmpty || clinics.isNotEmpty;

  /// 流式阶段服务端会把这段 JSON 逐字推送；以 `{` 开头的流式文本不应直接显示
  static bool isStructuredStream(String streamed) =>
      streamed.trimLeft().startsWith('{');

  /// 不是心理工作流 JSON（普通文本、HTML、其他 JSON、或无任何可展示内容）时返回 null，
  /// 调用方按普通 doctor 消息渲染，保证既有流程不受影响。
  static MentalWorkflowContent? tryParse(String? content) {
    if (content == null) return null;
    final text = content.trim();
    if (!text.startsWith('{')) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    if (!decoded.containsKey('recommendation') &&
        !decoded.containsKey('mental_resources') &&
        !decoded.containsKey('follow_up_question')) {
      return null;
    }

    final resources = decoded['mental_resources'];
    final parsed = MentalWorkflowContent(
      recommendation: _text(decoded['recommendation']),
      hotlines: _list(resources, 'm2_list'),
      onlinePlatforms: _list(resources, 'm3_list'),
      clinics: _list(resources, 'm4_list'),
      followUpQuestion: _text(decoded['follow_up_question']),
    );
    if (parsed.recommendation == null &&
        !parsed.hasResources &&
        parsed.followUpQuestion == null) {
      return null;
    }
    return parsed;
  }

  /// `{"content": "..."}` 或直接字符串都接受；空白视为无内容
  static String? _text(dynamic node) {
    final raw = node is Map ? node['content'] : node;
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  static List<Map<String, dynamic>> _list(dynamic resources, String key) {
    if (resources is! Map) return const [];
    final list = resources[key];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
