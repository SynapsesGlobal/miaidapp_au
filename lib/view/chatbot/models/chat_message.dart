enum MessageRole { doctor, patient }

class ChatMessage {
  final String id;
  final MessageRole role;
  String content;
  final double? latitude;
  final double? longitude;
  final DateTime createdTime;
  final bool isStreaming;
  final bool videoConsultation;
  final bool appointInterpreter;
  final String sessionLevel;

  /// 服务端为这条消息记录的触发工具（如 mcp_query_hospital、mcp_video_consultation），
  /// 未触发工具时为空串。发送消息时随历史整体回传：服务端会用 App 回传的
  /// chatContent 覆盖库里的会话历史，不回传就会把之前所有消息的 tool 抹掉
  final String tool;

  /// 查询附近医院时服务端返回的结构化医院列表（卡片模式），
  /// 每项含 name/address/phone/website/is_private/has_emergency_department
  /// 以及可选的 latitude/longitude/distance
  final List<Map<String, dynamic>>? hospitals;

  /// 心理工作流消息上服务端附带的原始资源数据（level5_resources），
  /// 展示不用它，只为回传历史时不丢字段
  final Map<String, dynamic>? level5Resources;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.latitude,
    this.longitude,
    required this.createdTime,
    this.isStreaming = false,
    this.videoConsultation = false,
    this.appointInterpreter = false,
    this.sessionLevel = '',
    this.tool = '',
    this.hospitals,
    this.level5Resources,
  });

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    bool? videoConsultation,
    bool? appointInterpreter,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      latitude: latitude,
      longitude: longitude,
      createdTime: createdTime,
      isStreaming: isStreaming ?? this.isStreaming,
      videoConsultation: videoConsultation ?? this.videoConsultation,
      appointInterpreter: appointInterpreter ?? this.appointInterpreter,
      sessionLevel: sessionLevel,
      tool: tool,
      hospitals: hospitals,
      level5Resources: level5Resources,
    );
  }

  /// 将 ChatMessage 转为发送给 API 的 Map
  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'latitude': latitude?.toString(),
    'longitude': longitude?.toString(),
    'localTime': createdTime.toUtc().toIso8601String(),
    'createdTime': createdTime.toUtc().toIso8601String(),
    // 服务端每条消息都带 tool（无工具时为空串），历史回传必须原样带上
    'tool': tool,
    // 回传给服务端，保证医院卡片数据在会话历史中持久化不丢失
    if (hospitals != null) 'hospitals': hospitals,
    if (level5Resources != null) 'level5_resources': level5Resources,
    // DoctorMessage 按 key 是否存在决定是否显示对应操作入口
    if (videoConsultation) 'video_consultation': true,
    if (appointInterpreter) 'appoint_interpreter': true,
  };

  /// 从 API 返回的 Map 构建 ChatMessage
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      role: json['role'] == 'doctor' ? MessageRole.doctor : MessageRole.patient,
      content: json['content'] ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      createdTime: DateTime.tryParse(json['createdTime'] ?? '') ?? DateTime.now(),
      videoConsultation: json['video_consultation'] == true,
      appointInterpreter: json['appoint_interpreter'] == true,
      sessionLevel: json['level'].toString() ?? '',
      tool: json['tool']?.toString() ?? '',
      hospitals: (json['hospitals'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .toList(),
      level5Resources: json['level5_resources'] is Map
          ? Map<String, dynamic>.from(json['level5_resources'] as Map)
          : null,
    );
  }
}