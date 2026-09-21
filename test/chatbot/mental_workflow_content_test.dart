import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/view/chatbot/models/chat_message.dart';
import 'package:miaid/view/chatbot/models/mental_workflow_content.dart';

void main() {
  // 服务端 Level5 Q7 消息样例（三个列表为空）
  const emptyListsContent =
      '{"recommendation":{"content":"根据你的情况，建议你尽快去看全科医生（GP）以获得专业诊断，并可协助你使用医保/保险报销。"},'
      '"mental_resources":{"m2_list":[],"m3_list":[],"m4_list":[]},'
      '"follow_up_question":{"content":"是否需要我们告知或联系您的雇主或管理员以获得支持？"}}';

  final fullContent = jsonEncode({
    'recommendation': {'content': 'Please visit a GP soon.'},
    'mental_resources': {
      'm2_list': [
        {'country': 'Australia', 'name': 'Lifeline', 'description': 'Crisis support.', 'phone': '13 11 14'},
        {'country': 'Australia', 'name': 'Beyond Blue', 'description': null, 'phone': '1300 22 4636'},
      ],
      'm3_list': [
        {'country': 'Australia', 'name': 'Lifeline', 'phone': '13 11 14'},
      ],
      'm4_list': [
        {
          'name': 'Royal Hospital',
          'phone': '111',
          'address': '1 Main St',
          'website': 'https://royal.example',
          'latitude': -37.8036,
          'longitude': 144.9631,
          'distance': 1.1,
        },
      ],
    },
    'follow_up_question': {'content': 'Notify your employer?'},
  });

  group('MentalWorkflowContent.tryParse', () {
    test('解析完整 Q7 消息：三段内容与三组列表', () {
      final c = MentalWorkflowContent.tryParse(fullContent)!;
      expect(c.recommendation, 'Please visit a GP soon.');
      expect(c.hotlines.length, 2);
      expect(c.hotlines[0]['name'], 'Lifeline');
      expect(c.hotlines[0]['phone'], '13 11 14');
      expect(c.onlinePlatforms.length, 1);
      expect(c.clinics.length, 1);
      expect(c.clinics[0]['name'], 'Royal Hospital');
      expect(c.clinics[0]['distance'], 1.1);
      expect(c.hasResources, isTrue);
      expect(c.followUpQuestion, 'Notify your employer?');
    });

    test('三个列表为空：只有建议和后续询问，资源气泡不显示', () {
      final c = MentalWorkflowContent.tryParse(emptyListsContent)!;
      expect(c.recommendation, startsWith('根据你的情况'));
      expect(c.hasResources, isFalse);
      expect(c.hotlines, isEmpty);
      expect(c.onlinePlatforms, isEmpty);
      expect(c.clinics, isEmpty);
      expect(c.followUpQuestion, '是否需要我们告知或联系您的雇主或管理员以获得支持？');
    });

    test('普通文本、HTML、空串、null 都返回 null（走原有渲染）', () {
      expect(MentalWorkflowContent.tryParse('你好，请问哪里不舒服？'), isNull);
      expect(MentalWorkflowContent.tryParse('<span style="background-color:#fff">点击</span>'), isNull);
      expect(MentalWorkflowContent.tryParse(''), isNull);
      expect(MentalWorkflowContent.tryParse(null), isNull);
    });

    test('以 { 开头但不是合法 JSON 或不是心理工作流结构时返回 null', () {
      expect(MentalWorkflowContent.tryParse('{not json'), isNull);
      expect(MentalWorkflowContent.tryParse('{"reply":"ok","tool":"mcp_query_hospital"}'), isNull);
      expect(MentalWorkflowContent.tryParse('[{"name":"x"}]'), isNull);
    });

    test('结构匹配但没有任何可展示内容时返回 null', () {
      expect(
        MentalWorkflowContent.tryParse(
            '{"recommendation":{"content":"  "},"mental_resources":{},"follow_up_question":{}}'),
        isNull,
      );
    });

    test('列表里的非对象项被忽略，缺少 mental_resources 也能解析', () {
      final c = MentalWorkflowContent.tryParse(jsonEncode({
        'recommendation': {'content': 'r'},
        'mental_resources': {'m2_list': ['bad', 1, {'name': 'ok'}], 'm4_list': 'oops'},
      }))!;
      expect(c.hotlines.length, 1);
      expect(c.clinics, isEmpty);
      final noResources = MentalWorkflowContent.tryParse(
          jsonEncode({'recommendation': {'content': 'r'}}))!;
      expect(noResources.hasResources, isFalse);
    });

    test('bubbleCount：有内容的部分各算一个气泡，三组资源合为一个', () {
      expect(MentalWorkflowContent.tryParse(fullContent)!.bubbleCount, 3);
      // 三个列表为空：只剩建议和后续询问
      expect(MentalWorkflowContent.tryParse(emptyListsContent)!.bubbleCount, 2);
      expect(
        MentalWorkflowContent.tryParse(
            jsonEncode({'recommendation': {'content': 'r'}}))!.bubbleCount,
        1,
      );
    });

    test('流式阶段以 { 开头的文本判定为结构化内容', () {
      expect(MentalWorkflowContent.isStructuredStream('{"recomm'), isTrue);
      expect(MentalWorkflowContent.isStructuredStream('  \n{'), isTrue);
      expect(MentalWorkflowContent.isStructuredStream('好的，'), isFalse);
      expect(MentalWorkflowContent.isStructuredStream(''), isFalse);
    });
  });

  group('ChatMessage 与心理工作流消息', () {
    test('content 原样保留，toJson 回传的仍是原始 JSON 字符串', () {
      final msg = ChatMessage.fromJson({
        'id': '10559222',
        'role': 'doctor',
        'content': emptyListsContent,
        'createdTime': '2026-09-15T09:25:02.136+00:00',
        'tool': '',
        'level': 'Level5',
      });
      expect(msg.toJson()['content'], emptyListsContent);
      expect(MentalWorkflowContent.tryParse(msg.content), isNotNull);
    });

    test('level5_resources 往返保留', () {
      final resources = {
        'level5_hotline_resource': [{'name': 'Lifeline'}],
        'level5_online_platform_resource': <Map<String, dynamic>>[],
        'level5_partner_clinic_resource': <Map<String, dynamic>>[],
      };
      final msg = ChatMessage.fromJson({
        'id': 'x',
        'role': 'doctor',
        'content': emptyListsContent,
        'createdTime': '2026-09-15T09:25:02.136+00:00',
        'level5_resources': resources,
      });
      expect(msg.level5Resources, resources);
      expect(msg.toJson()['level5_resources'], resources);
      expect(msg.copyWith(videoConsultation: true).toJson()['level5_resources'], resources);

      final plain = ChatMessage.fromJson({
        'id': 'y', 'role': 'doctor', 'content': 'hi', 'createdTime': '2026-09-15T09:25:02.136+00:00',
      });
      expect(plain.toJson().containsKey('level5_resources'), isFalse);
    });
  });
}
