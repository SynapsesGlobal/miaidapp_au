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

  /// 查询附近医院时服务端返回的结构化医院列表（卡片模式），
  /// 每项含 name/address/phone/website/is_private/has_emergency_department
  /// 以及可选的 latitude/longitude/distance
  final List<Map<String, dynamic>>? hospitals;

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
    this.hospitals,
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
      hospitals: hospitals,
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
    // 回传给服务端，保证医院卡片数据在会话历史中持久化不丢失
    if (hospitals != null) 'hospitals': hospitals,
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
      hospitals: (json['hospitals'] as List?)
          ?.whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}