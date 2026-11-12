import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/ring_alert_service.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';

/// 异常提醒相关页面共用的小组件：级别颜色 / 文案、指标图标、提醒行、高危弹层。

Color ringAlertLevelColor(RingAlertItem a) {
  if (a.isRecovered) return AppColors.k25d000;
  switch (a.level) {
    case RingAlertItem.levelCritical:
      return AppColors.ke63030;
    default:
      return AppColors.ke68c30;
  }
}

String ringAlertLevelText(BuildContext context, RingAlertItem a) {
  final s = S.of(context);
  if (a.isRecovered) return s.familyAlertLevelRecovered;
  switch (a.level) {
    case RingAlertItem.levelCritical:
      return s.familyAlertLevelHigh;
    default:
      return s.familyAlertLevelWarn;
  }
}

IconData ringAlertMetricIcon(String type) {
  switch (type) {
    case 'heart_rate':
      return Icons.favorite;
    case 'blood_oxygen':
      return Icons.water_drop;
    case 'temperature':
      return Icons.thermostat;
    case 'blood_pressure':
      return Icons.speed;
    case 'blood_sugar':
      return Icons.bloodtype;
    default:
      return Icons.monitor_heart;
  }
}

Color ringAlertMetricColor(String type) {
  switch (type) {
    case 'heart_rate':
    case 'blood_sugar':
      return AppColors.ke63030;
    case 'blood_oxygen':
      return AppColors.k30bee6;
    case 'temperature':
      return AppColors.ke68c30;
    case 'blood_pressure':
      return AppColors.k0cbcc5;
    default:
      return AppColors.k8f8e94;
  }
}

String ringAlertMetricLabel(BuildContext context, String type) {
  final s = S.of(context);
  switch (type) {
    case 'heart_rate':
      return s.smartRingHeartRate;
    case 'blood_oxygen':
      return s.smartRingBloodOxygen;
    case 'temperature':
      return s.smartRingTemperature;
    case 'blood_pressure':
      return s.smartRingBloodPressure;
    case 'blood_sugar':
      return s.smartRingBloodSugar;
    default:
      return type;
  }
}

/// 「血氧偏低」「心率已恢复正常」。
String ringAlertTitle(BuildContext context, RingAlertItem a) {
  final s = S.of(context);
  final metric = ringAlertMetricLabel(context, a.type);
  if (a.isRecovered) return s.familyAlertRecoveredTitle(metric);
  return a.isHigh ? s.familyAlertTooHigh(metric) : s.familyAlertTooLow(metric);
}

/// 长辈状态文案与颜色（normal / abnormal）。
String ringOwnerStatusText(BuildContext context, String status) {
  final s = S.of(context);
  return status == 'abnormal' ? s.familyAlertStatusAbnormal : s.familyAlertStatusNormal;
}

Color ringOwnerStatusColor(String status) => status == 'abnormal' ? AppColors.ke63030 : AppColors.k25d000;

/// 红点 / 未读数角标。
Widget ringUnreadBadge(int count, {double size = 18}) {
  if (count <= 0) return const SizedBox.shrink();
  return Container(
    constraints: BoxConstraints(minWidth: size),
    height: size,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: AppColors.ke63030, borderRadius: BorderRadius.circular(size / 2)),
    child: Text(count > 99 ? '99+' : '$count',
        style: GoogleFonts.rubik(color: Colors.white, fontSize: size * 0.6, fontWeight: FontWeight.w700, height: 1)),
  );
}

/// 提醒列表里的一行：级别色图标、「妈妈 · 血氧偏低」、时间、已处理标记、数值。
Widget ringAlertTile(
  BuildContext context,
  RingAlertItem a, {
  required VoidCallback onTap,
  String? ownerName,
  bool showOwner = true,
}) {
  final s = S.of(context);
  final color = ringAlertLevelColor(a);
  final unread = a.seen == false;
  final name = ownerName ?? a.ownerAlias;
  final title = showOwner && name != null && name.isNotEmpty ? '$name · ${ringAlertTitle(context, a)}' : ringAlertTitle(context, a);
  final time = a.measuredAt ?? a.createdAt;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: familyCard(
      child: Row(children: [
        Stack(children: [
          familyIconTile(ringAlertMetricIcon(a.type), color, size: 42),
          if (unread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.ke63030, border: Border.all(color: Colors.white, width: 1.5)),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(child: Text(title,
                  style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: unread ? FontWeight.w700 : FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              familyChip(ringAlertLevelText(context, a), color),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              if (time != null)
                Text(SmartRingFormat.dateTime(context, time), style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
              if (a.isHandled) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, color: AppColors.k25d000, size: 13),
                const SizedBox(width: 2),
                Text(s.familyAlertHandled, style: GoogleFonts.rubik(color: AppColors.k25d000, fontSize: 11.5)),
              ],
            ]),
          ],
        )),
        const SizedBox(width: 8),
        if (a.valueText.isNotEmpty)
          Text.rich(TextSpan(children: [
            TextSpan(text: a.valueText, style: GoogleFonts.rubik(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
            TextSpan(text: ' ${a.unit}', style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11)),
          ])),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, color: AppColors.kb1b1b1, size: 20),
      ]),
    ),
  );
}

/// 首页横幅 / 家人面板顶部的提醒条：彩底一行，点击进入。
Widget ringAlertStrip(
  BuildContext context,
  RingAlertItem a, {
  required VoidCallback onTap,
  String? ownerName,
  int extraCount = 0,
}) {
  final s = S.of(context);
  final color = ringAlertLevelColor(a);
  final name = ownerName ?? a.ownerAlias;
  final title = name != null && name.isNotEmpty ? '$name · ${ringAlertTitle(context, a)}' : ringAlertTitle(context, a);
  final time = a.measuredAt ?? a.createdAt;
  final detail = <String>[
    if (a.valueText.isNotEmpty) '${a.valueText}${a.unit == '%' ? '%' : ' ${a.unit}'}',
    if (time != null) SmartRingFormat.dateTime(context, time),
    if (extraCount > 0) s.ringAlertMoreCount(extraCount),
  ].join(' · ');
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [color, color.withOpacity(0.78)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(11)),
          child: Icon(ringAlertMetricIcon(a.type), color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.rubik(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(detail, style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.88), fontSize: 11.5),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        )),
        const SizedBox(width: 6),
        Text(s.ringAlertView, style: GoogleFonts.rubik(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        Icon(Icons.chevron_right, color: Colors.white, size: 18),
      ]),
    ),
  );
}

/// 高危提醒弹层：冷启动 / 回到前台时对未读的高危提醒弹一次。返回 true 表示用户点了「查看」。
Future<bool?> showRingAlertCriticalSheet(BuildContext context, RingAlertItem a) {
  final s = S.of(context);
  final color = ringAlertLevelColor(a);
  final name = a.ownerAlias;
  final time = a.measuredAt ?? a.createdAt;
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 22, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(ringAlertMetricIcon(a.type), color: color, size: 30),
        ),
        const SizedBox(height: 14),
        Text(s.ringAlertCriticalTitle, style: GoogleFonts.rubik(color: color, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(name != null && name.isNotEmpty ? '$name · ${ringAlertTitle(context, a)}' : ringAlertTitle(context, a),
            textAlign: TextAlign.center,
            style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 18, fontWeight: FontWeight.w600)),
        if (a.valueText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text.rich(TextSpan(children: [
            TextSpan(text: a.valueText, style: GoogleFonts.rubik(color: color, fontSize: 40, fontWeight: FontWeight.w700, height: 1)),
            TextSpan(text: '  ${a.unit}', style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 14)),
          ])),
        ],
        if (time != null) ...[
          const SizedBox(height: 8),
          Text(s.familyAlertMeasuredAt(SmartRingFormat.dateTime(context, time)),
              style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5)),
        ],
        const SizedBox(height: 22),
        familyFilledButton(s.ringAlertView, color: color, onPressed: () => Navigator.pop(context, true)),
        const SizedBox(height: 10),
        MaterialButton(
          onPressed: () => Navigator.pop(context, false),
          elevation: 0,
          height: 46,
          minWidth: double.infinity,
          color: AppColors.kf4f4f4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
          child: Text(s.ringAlertLater, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ]),
    ),
  );
}

/// 页面级的「加载失败 + 重试」。
Widget ringAlertFailed(BuildContext context, VoidCallback onRetry) {
  final s = S.of(context);
  return Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off, color: AppColors.kb1b1b1, size: 40),
      const SizedBox(height: 12),
      Text(s.ringFamilyLoadFailed, textAlign: TextAlign.center, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13)),
      const SizedBox(height: 16),
      SizedBox(width: 160, child: familyOutlinedButton(s.retry, onPressed: () => unawaited(Future<void>.sync(onRetry)))),
    ]),
  ));
}
