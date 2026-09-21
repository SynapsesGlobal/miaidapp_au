import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/view/chatbot/models/hospital_booking.dart';

void main() {
  group('HospitalBooking 解析', () {
    test('列表项：只有概要字段，医院与症状为空', () {
      final booking = HospitalBooking.fromJson(jsonDecode('''
        {"id":19,"chatbot_id":"5467aaed","requested_at":"2026-09-21T01:07:10+00:00","hospitals_count":3,"confirmed_count":1}
      ''') as Map<String, dynamic>);

      expect(booking.id, 19);
      expect(booking.chatbotId, '5467aaed');
      expect(booking.requestedAt, DateTime.utc(2026, 9, 21, 1, 7, 10).toLocal());
      expect(booking.hospitalsCount, 3);
      expect(booking.confirmedCount, 1);
      expect(booking.symptoms, isEmpty);
      expect(booking.hospitals, isEmpty);
    });

    test('详情：已确认的医院带就诊信息，未确认的 visit 为 null', () {
      final booking = HospitalBooking.fromJson(jsonDecode('''
        {"id":19,"chatbot_id":"5467aaed","requested_at":"2026-09-21T01:07:10+00:00","hospitals_count":2,"confirmed_count":1,
         "symptoms":["发烧两天","咳嗽"],
         "hospitals":[
           {"id":31,"name":"AIM Health Melbourne","status":"confirmed","confirmed_at":"2026-09-21T02:15:00+00:00",
            "visit":{"visit_time":"2026-09-22 14:30:00","address":"1 Collins St","phone":"+61 3 8103 8218","accepts_insurance":true,"doctor_name":"Dr. Smith"}},
           {"id":32,"name":"City Clinic","status":"unconfirmed","confirmed_at":null,"visit":null}
         ]}
      ''') as Map<String, dynamic>);

      expect(booking.symptoms, ['发烧两天', '咳嗽']);
      expect(booking.hospitals, hasLength(2));

      final confirmed = booking.hospitals[0];
      expect(confirmed.isConfirmed, isTrue);
      expect(confirmed.confirmedAt, isNotNull);
      // 就诊时间是医院当地时间，不做时区换算
      expect(confirmed.visit!.visitTime, DateTime(2026, 9, 22, 14, 30));
      expect(confirmed.visit!.address, '1 Collins St');
      expect(confirmed.visit!.phone, '+61 3 8103 8218');
      expect(confirmed.visit!.acceptsInsurance, isTrue);
      expect(confirmed.visit!.doctorName, 'Dr. Smith');

      final pending = booking.hospitals[1];
      expect(pending.name, 'City Clinic');
      expect(pending.isConfirmed, isFalse);
      expect(pending.confirmedAt, isNull);
      expect(pending.visit, isNull);
    });

    test('字段缺失或类型不规范时不抛异常', () {
      final booking = HospitalBooking.fromJson({
        'id': '7',
        'requested_at': 'not a date',
        'hospitals': [
          {'id': 1, 'name': null, 'status': 'confirmed', 'visit': {'accepts_insurance': 0}},
          'garbage',
        ],
      });

      expect(booking.id, 7);
      expect(booking.requestedAt, isNull);
      expect(booking.hospitals, hasLength(1));
      expect(booking.hospitals.first.name, '');
      expect(booking.hospitals.first.visit!.acceptsInsurance, isFalse);
      expect(booking.hospitals.first.visit!.visitTime, isNull);
    });
  });
}
