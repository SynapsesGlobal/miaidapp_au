import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

String formatDate(DateTime date) =>
    DateFormat('d MMM yyyy hh:mma').format(date);

/// 订单列表 / 详情里的下单时间：按当前 App 语言的习惯格式化，并转成本机时区。
/// 后端返回的是 UTC（形如 2026-08-28T19:27:12.000000Z），之前直接按 UTC 显示会差几个小时。
/// 例：en → 28 Aug 2026, 7:27 PM；zh → 2026年8月28日 下午7:27；ko → 2026년 8월 28일 오후 7:27
String formatOrderDateTime(BuildContext context, String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).add_jm().format(parsed.toLocal());
}
