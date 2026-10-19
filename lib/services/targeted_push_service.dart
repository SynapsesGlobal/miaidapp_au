import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/services/marketing_api.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 商品定向推送（miaid_mispace 后端 `GET /product/targeted`）。
///
/// 不是真实推送：App 打开到首页时带用户坐标去后端查一次，后端返回「开启了定向推送、
/// 且推送地点覆盖用户当前位置」的商品，App 自己弹框轮播展示。
///
/// 屏蔽规则（本地 SharedPreferences）：只有用户点了「不再显示」的商品才被屏蔽，仅关闭
/// 弹框不记录。屏蔽按后端返回的 `pushKey`（商品 id + 推送最近一次开启的时间）记录：
/// 后台把该商品的推送关掉再打开，key 会变，于是会重新提醒；改地址、时间窗不影响。
class TargetedProduct {
  final String pushKey;
  final String productId;
  final String companyId;
  final String? companyName;
  final String title;
  final String? description;
  final String? instruction;
  final String currency;
  final String price;
  final String discountPrice;
  final String image;
  final String? location;
  final String? address;
  final double? distance;

  const TargetedProduct({
    required this.pushKey,
    required this.productId,
    required this.companyId,
    required this.title,
    required this.currency,
    required this.price,
    required this.discountPrice,
    required this.image,
    this.companyName,
    this.description,
    this.instruction,
    this.location,
    this.address,
    this.distance,
  });

  bool get hasDiscount => price != discountPrice;

  factory TargetedProduct.fromJson(Map<String, dynamic> json) {
    return TargetedProduct(
      pushKey: json['pushKey']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      companyId: json['companyId']?.toString() ?? '',
      companyName: json['companyName']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      instruction: json['instruction']?.toString(),
      currency: json['currency']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      discountPrice: json['discount_price']?.toString() ?? json['price']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      location: json['location']?.toString(),
      address: json['address']?.toString(),
      distance: double.tryParse(json['distance']?.toString() ?? ''),
    );
  }

  static List<TargetedProduct> listFromResponse(String body) {
    final decoded = jsonDecode(body);
    final items = decoded is Map ? decoded['products'] : null;
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => TargetedProduct.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.productId.isNotEmpty && p.pushKey.isNotEmpty)
        .toList();
  }
}

/// 纯函数的筛选逻辑，便于单测：去掉被「不再显示」的商品（按 pushKey）。
class TargetedPushFilter {
  TargetedPushFilter._();

  static List<TargetedProduct> select(
    List<TargetedProduct> products, {
    required Set<String> hiddenKeys,
  }) {
    return products.where((p) => !hiddenKeys.contains(p.pushKey)).toList();
  }
}

/// 本地「不再显示」记录（SharedPreferences）。
class TargetedPushHistory {
  static const hiddenKeysPref = 'targeted_push_hidden_keys';

  /// 最多保留这么多条，最旧的先淘汰（后台每次重新开启推送都会产生新 key）。
  static const maxHiddenKeys = 300;

  final SharedPreferences _prefs;

  TargetedPushHistory(this._prefs);

  static Future<TargetedPushHistory> load() async {
    return TargetedPushHistory(await SharedPreferences.getInstance());
  }

  Set<String> get hiddenKeys => (_prefs.getStringList(hiddenKeysPref) ?? const []).toSet();

  List<TargetedProduct> visible(List<TargetedProduct> products) {
    return TargetedPushFilter.select(products, hiddenKeys: hiddenKeys);
  }

  /// 「不再显示」：记录该商品当前这一轮推送的 key。
  Future<void> hide(TargetedProduct product) async {
    final current = _prefs.getStringList(hiddenKeysPref) ?? <String>[];
    if (current.contains(product.pushKey)) return;
    final merged = [...current, product.pushKey];
    final trimmed = merged.length > maxHiddenKeys
        ? merged.sublist(merged.length - maxHiddenKeys)
        : merged;
    await _prefs.setStringList(hiddenKeysPref, trimmed);
  }
}

/// 弹框的触发开关：只有「App 启动」和「登录成功」之后进入首页才弹一次。
/// 抽屉里点「首页」重建首页、从其他页面返回首页、从后台恢复都不弹。
class TargetedPushTrigger {
  TargetedPushTrigger._();

  /// App 进程启动时为 true，首页消费一次后置 false；登录成功后由 [arm] 再次置 true。
  static bool _armed = true;

  static bool get isArmed => _armed;

  /// 登录成功后调用：下一次进入首页弹框。
  static void arm() => _armed = true;

  /// 首页进入时调用：返回是否应当检查，并复位。
  static bool consume() {
    final armed = _armed;
    _armed = false;
    return armed;
  }

  /// 仅测试用。
  static void reset({bool armed = true}) => _armed = armed;
}

class TargetedPushService {
  TargetedPushService._();

  /// 查询覆盖给定坐标的定向推送商品，按距离升序。
  /// 网络或后端错误时抛出异常，由调用方静默处理（弹框是锦上添花，不打扰用户）。
  static Future<List<TargetedProduct>> fetch({
    required double latitude,
    required double longitude,
    String? gender,
    String? birthday,
    http.Client? client,
  }) async {
    final params = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (birthday != null && birthday.isNotEmpty) 'birthday': birthday,
    };
    final url = Uri.parse('${getIt<ApiSettings>().marketingApiHost}/product/targeted')
        .replace(queryParameters: params);

    final response = await (client ?? http.Client())
        .get(url, headers: MarketingApi.headers())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw http.ClientException('targeted push HTTP ${response.statusCode}', url);
    }
    return TargetedProduct.listFromResponse(response.body);
  }

  /// 以当前登录用户为准：取定位（复用首页的 determinePosition，含权限申请），
  /// 带上生日用于后端年龄过滤。定位不可用时返回空列表。
  static Future<List<TargetedProduct>> fetchForCurrentUser() async {
    Position position;
    try {
      position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
    } catch (_) {
      return const [];
    }

    final user = getIt<ApiProvider>().userProvider.user;
    return fetch(
      latitude: position.latitude,
      longitude: position.longitude,
      birthday: user?.customer?.dob,
    );
  }
}
