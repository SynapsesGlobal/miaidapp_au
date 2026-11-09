import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/smart_ring_models.dart';
import 'package:rwfit_ble/rwfit_ble.dart';

/// 智能戒指页面共用的格式化工具。
class SmartRingFormat {
  SmartRingFormat._();

  /// 读数文本；无数据时返回 `--`。
  static String metric(RingMetric? m, {int decimals = 0}) {
    if (m == null) return '--';
    return decimals == 0 ? m.value.round().toString() : m.value.toStringAsFixed(decimals);
  }

  /// 读数时间：当天显示「今天 08:10」，否则「11月6日 08:10」（按当前语言）。
  static String metricTime(BuildContext context, RingMetric? m) {
    if (m == null) return S.of(context).smartRingNoData;
    return dateTime(context, m.time);
  }

  static String dateTime(BuildContext context, DateTime t) {
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    if (sameDay) return S.of(context).smartRingToday + ' ' + DateFormat.Hm().format(t);
    return DateFormat.MMMd().add_Hm().format(t);
  }

  static String clock(DateTime t) => DateFormat.Hm().format(t);

  /// 440 → `7h 20m`
  static String hoursMinutes(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';

  /// 105 → `1h45`
  static String hm(int minutes) => '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';

  static String thousands(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );

  static String metricLabel(BuildContext context, RealtimeMetric metric) {
    final s = S.of(context);
    switch (metric) {
      case RealtimeMetric.hr:
        return s.smartRingHeartRate;
      case RealtimeMetric.bloodOxy:
        return s.smartRingBloodOxygen;
      case RealtimeMetric.temperature:
        return s.smartRingTemperature;
      case RealtimeMetric.hrv:
        return s.smartRingHrv;
      case RealtimeMetric.pressure:
        return s.smartRingStress;
      case RealtimeMetric.bloodPressure:
        return s.smartRingBloodPressure;
      case RealtimeMetric.bloodSugar:
        return s.smartRingBloodSugar;
    }
  }

  /// 「分享给医生」用的纯文本摘要。
  static String shareText(BuildContext context, String deviceName, SmartRingSnapshot snap) {
    final s = S.of(context);
    final lines = <String>['MiAid · ${s.smartRing} · $deviceName'];
    void add(String label, RingMetric? m, String unit, {int decimals = 0}) {
      if (m == null) return;
      lines.add('$label: ${metric(m, decimals: decimals)} $unit (${dateTime(context, m.time)})');
    }

    add(s.smartRingHeartRate, snap.heartRate, 'bpm');
    add(s.smartRingBloodOxygen, snap.bloodOxygen, '%');
    add(s.smartRingTemperature, snap.temperature, '°C', decimals: 1);
    add(s.smartRingHrv, snap.hrv, 'ms');
    add(s.smartRingStress, snap.pressure, '');
    final bp = snap.bloodPressure;
    if (bp != null) lines.add('${s.smartRingBloodPressure}: ${bp.text} mmHg (${dateTime(context, bp.time)})');
    add(s.smartRingBloodSugar, snap.bloodSugar, 'mmol/L', decimals: 1);
    final sleep = snap.sleep;
    if (sleep != null) {
      var line = '${s.smartRingSleep} (${s.smartRingLastNight}): ${hoursMinutes(sleep.totalMinutes)}';
      if (sleep.hasStages) {
        line += ' · ${s.smartRingDeepSleep} ${hm(sleep.deepMinutes)}'
            ' · ${s.smartRingLightSleep} ${hm(sleep.lightMinutes)}'
            ' · ${s.smartRingRem} ${hm(sleep.remMinutes)}'
            ' · ${s.smartRingAwake} ${hm(sleep.awakeMinutes)}';
      }
      lines.add(line);
    }
    final steps = snap.steps;
    if (steps != null) {
      lines.add('${s.smartRingSteps}: ${thousands(steps.steps)} (${DateFormat.MMMd().format(steps.date)})');
    }
    final sync = snap.lastSyncAt;
    if (sync != null) lines.add(s.smartRingLastSync(dateTime(context, sync)));
    lines.add(s.smartRingDisclaimer);
    return lines.join('\n');
  }
}
