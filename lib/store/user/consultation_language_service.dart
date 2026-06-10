import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/utils/json_utils.dart';

/// 面诊语言（用于后端按语言匹配医生）的数据操作。
///
/// 说明：App 以「每设备一个常驻登录账号」运行，账号里的 languages 不代表当前正在使用
/// 设备的人。进入 App 首页时让当前用户选择本次希望医生使用的语言，写回账号 languages，
/// 后端据此匹配对应语言的医生。这与界面显示语言是两个概念，也与「通话」本身无关，
/// 故从 CallScreenStore 拆出独立放置。
class ConsultationLanguageService {
  ConsultationLanguageService._();

  static ApiProvider get _api => getIt<ApiProvider>();
  static UserProvider get _user => getIt<UserProvider>();

  // 可选语言列表的进程内缓存。后端语言列表基本不变，缓存后再次弹框/使用直接复用，
  // 不再重复打接口。注意：各资料页用的是自己 store 里的列表，并不会预先填充这里，
  // 所以本会话首次仍需拉一次。
  static List<Language>? _cachedLanguages;

  /// 当前账号已设置的面诊语言（用于弹框默认预选）。
  static Language? get current => _user.user?.customer?.language;

  /// 拉取后端可选语言列表（与资料页同源）。
  ///
  /// 默认走进程内缓存：本会话已拉过就直接返回，不再请求接口；传 [forceRefresh] 可强制刷新。
  static Future<List<Language>> fetchLanguages({bool forceRefresh = false}) async {
    final cached = _cachedLanguages;
    if (!forceRefresh && cached != null) return cached;

    final response = await _api.apiClient.languagesGetLanguagesList();
    final list = await ApiSuccessParser.payloadOrThrowWithMessage<List<Language>>(
      response,
    );
    _cachedLanguages = list;
    return list;
  }

  /// 读取 profile 接口返回的 `need_select_language` 字段：
  /// 仅当后端返回 true 时才需要弹出语言选择框；false 则跳过。
  ///
  /// 该字段未包含在生成的 model 中，故直接解析原始 JSON（递归查找，兼容字段所在层级）。
  /// 解析失败/缺失时按 false 处理（不弹框）。
  static Future<bool> needSelect() async {
    final response = await _api.apiClient.profileGetMyProfile();
    if (!response.isSuccessful) return false;
    try {
      final decoded = jsonDecode(response.bodyString);
      return findBoolDeep(decoded, 'need_select_language') ?? false;
    } catch (e) {
      debugPrint('parse need_select_language failed: $e');
      return false;
    }
  }

  /// 仅更新账号的偏好语言；其余资料字段从当前 user/customer 原样回填，避免被覆盖。
  static Future<void> update(Language lang) async {
    final u = _user.user!;
    final c = u.customer!;
    final response = await _api.apiClient.profilePutUpdateCustomerProfile(
      first_name: u.firstName,
      last_name: u.lastName,
      email: u.email,
      phone: u.phone,
      dob: c.dob != null
          ? DateFormat('y-MM-d').format(DateTime.parse(c.dob!))
          : null,
      language_id: lang.id,
      language_ids: [if (lang.id != null) lang.id!],
      gender_id: c.gender?.id,
      doctor_preference: c.doctorPreference,
      travel_agency_name: c.travelAgencyName,
      medicare_number: c.medicareNumber,
      customer_type_id: c.customerType?.id,
      next_of_kin_name: c.nextOfKinName,
      next_of_kin_email: c.nextOfKinEmail,
      next_of_kin_mobile: c.nextOfKinMobile,
      regular_doctor_name: c.regularDoctorName,
      regular_doctor_email: c.regularDoctorEmail,
      subscribe_email: c.subscribeEmail,
    );
    // 确认更新成功（失败会抛出，由调用方处理）。
    await ApiSuccessParser.payloadOrThrowWithMessage<User>(response);
    // 刷新内存中的 user，使后续逻辑使用最新语言。
    final profileResp = await _api.apiClient.profileGetMyProfile();
    final payload =
        await ApiSuccessParser.payloadOrThrowWithMessage<User>(profileResp);
    _user.onUserUpdated(payload);
  }
}
