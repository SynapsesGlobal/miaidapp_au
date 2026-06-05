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
    this.sessionLevel = ''
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
      sessionLevel: json['level'].toString() ?? ''
    );
  }
}