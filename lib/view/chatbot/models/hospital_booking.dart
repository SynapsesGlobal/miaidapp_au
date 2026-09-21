/// chatbot 帮用户发起的一次医院预约请求（GET /api/v1/hospital-bookings 的一项）。
/// 一次请求会发给用户所在城市的多家医院；详情接口才带 [hospitals] 和 [symptoms]
class HospitalBooking {
  final int id;
  final String chatbotId;

  /// 预约请求发出的时间（本地时区），服务端没给或解析失败时为 null
  final DateTime? requestedAt;
  final int hospitalsCount;
  final int confirmedCount;
  final List<String> symptoms;
  final List<BookedHospital> hospitals;

  const HospitalBooking({
    required this.id,
    this.chatbotId = '',
    this.requestedAt,
    this.hospitalsCount = 0,
    this.confirmedCount = 0,
    this.symptoms = const [],
    this.hospitals = const [],
  });

  factory HospitalBooking.fromJson(Map<String, dynamic> json) {
    return HospitalBooking(
      id: _toInt(json['id']),
      chatbotId: json['chatbot_id']?.toString() ?? '',
      requestedAt: _toLocalTime(json['requested_at']),
      hospitalsCount: _toInt(json['hospitals_count']),
      confirmedCount: _toInt(json['confirmed_count']),
      symptoms: (json['symptoms'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      hospitals: (json['hospitals'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => BookedHospital.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

/// 预约请求发给的其中一家医院。医院通过邮件里的链接补充就诊信息后才算已确认
class BookedHospital {
  final int id;
  final String name;
  final bool isConfirmed;
  final DateTime? confirmedAt;

  /// 医院确认的就诊信息，未确认时为 null
  final HospitalVisit? visit;

  const BookedHospital({
    required this.id,
    required this.name,
    this.isConfirmed = false,
    this.confirmedAt,
    this.visit,
  });

  factory BookedHospital.fromJson(Map<String, dynamic> json) {
    final visit = json['visit'];
    return BookedHospital(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      isConfirmed: json['status'] == 'confirmed',
      confirmedAt: _toLocalTime(json['confirmed_at']),
      visit: visit is Map ? HospitalVisit.fromJson(Map<String, dynamic>.from(visit)) : null,
    );
  }
}

class HospitalVisit {
  /// 就诊时间是医院当地时间，服务端不带时区（"2026-09-22 14:30:00"），原样展示不做时区换算
  final DateTime? visitTime;
  final String address;
  final String phone;
  final bool? acceptsInsurance;
  final String doctorName;

  const HospitalVisit({
    this.visitTime,
    this.address = '',
    this.phone = '',
    this.acceptsInsurance,
    this.doctorName = '',
  });

  factory HospitalVisit.fromJson(Map<String, dynamic> json) {
    final accepts = json['accepts_insurance'];
    return HospitalVisit(
      visitTime: DateTime.tryParse(json['visit_time']?.toString() ?? ''),
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      acceptsInsurance: accepts == null ? null : (accepts == true || accepts == 1 || accepts == '1'),
      doctorName: json['doctor_name']?.toString() ?? '',
    );
  }
}

int _toInt(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

DateTime? _toLocalTime(dynamic value) => DateTime.tryParse(value?.toString() ?? '')?.toLocal();
