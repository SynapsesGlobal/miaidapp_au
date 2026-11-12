import 'package:flutter/material.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';

/// 「家人提醒」演示页用的静态数据。只用于给客户确认界面效果，不与后端交互；
/// 功能确认后由真实接口替换（见 docs/smart-ring-family-alerts.md）。

enum DemoMetric { heartRate, bloodOxygen, temperature, bloodPressure }

extension DemoMetricX on DemoMetric {
  String label(BuildContext context) {
    final s = S.of(context);
    switch (this) {
      case DemoMetric.heartRate:
        return s.smartRingHeartRate;
      case DemoMetric.bloodOxygen:
        return s.smartRingBloodOxygen;
      case DemoMetric.temperature:
        return s.smartRingTemperature;
      case DemoMetric.bloodPressure:
        return s.smartRingBloodPressure;
    }
  }

  IconData get icon {
    switch (this) {
      case DemoMetric.heartRate:
        return Icons.favorite;
      case DemoMetric.bloodOxygen:
        return Icons.water_drop;
      case DemoMetric.temperature:
        return Icons.thermostat;
      case DemoMetric.bloodPressure:
        return Icons.speed;
    }
  }

  Color get color {
    switch (this) {
      case DemoMetric.heartRate:
        return AppColors.ke63030;
      case DemoMetric.bloodOxygen:
        return AppColors.k30bee6;
      case DemoMetric.temperature:
        return AppColors.ke68c30;
      case DemoMetric.bloodPressure:
        return AppColors.k0cbcc5;
    }
  }
}

/// 可调阈值：[low]/[high] 当前值，[min]/[max] 滑杆范围。
class DemoThreshold {
  DemoThreshold({
    required this.metric,
    required this.low,
    required this.high,
    required this.min,
    required this.max,
    required this.unit,
    this.decimals = 0,
    this.consecutive = 2,
  });

  final DemoMetric metric;
  double low;
  double high;
  final double min;
  final double max;
  final String unit;
  final int decimals;
  int consecutive;

  String fmt(double v) => decimals == 0 ? v.round().toString() : v.toStringAsFixed(decimals);
}

enum DemoMemberStatus { active, pending }

class DemoMember {
  const DemoMember({required this.name, required this.relation, required this.status});

  final String name;
  final String relation;
  final DemoMemberStatus status;
}

enum DemoElderStatus { normal, abnormal, noData }

class DemoElder {
  const DemoElder({
    required this.name,
    required this.relation,
    required this.status,
    required this.lastReading,
    required this.ringName,
    required this.battery,
    required this.phone,
  });

  final String name;
  final String relation;
  final DemoElderStatus status;
  final DateTime lastReading;
  final String ringName;
  final int battery;
  final String phone;
}

enum DemoAlertLevel { high, warn, recovered, noData }

class DemoAlert {
  DemoAlert({
    required this.id,
    required this.elder,
    required this.metric,
    required this.level,
    required this.value,
    required this.unit,
    required this.time,
    required this.low,
    required this.high,
    required this.points,
    this.handled = false,
    this.noDataHours,
  });

  final int id;
  final DemoElder elder;
  final DemoMetric metric;
  final DemoAlertLevel level;
  final String value;
  final String unit;
  final DateTime time;
  final double low;
  final double high;

  /// 最近 24 小时的读数（每小时一个点），用于详情页折线。
  final List<double> points;
  bool handled;
  final int? noDataHours;

  String title(BuildContext context) {
    final s = S.of(context);
    final name = metric.label(context);
    switch (level) {
      case DemoAlertLevel.recovered:
        return s.familyAlertRecoveredTitle(name);
      case DemoAlertLevel.noData:
        return s.familyAlertNoDataTitle(noDataHours ?? 12);
      case DemoAlertLevel.high:
      case DemoAlertLevel.warn:
        final v = double.tryParse(value.split('/').first) ?? 0;
        return v > high ? s.familyAlertTooHigh(name) : s.familyAlertTooLow(name);
    }
  }
}

class FamilyAlertDemoData {
  FamilyAlertDemoData._();

  static final thresholds = <DemoThreshold>[
    DemoThreshold(metric: DemoMetric.heartRate, low: 45, high: 120, min: 30, max: 180, unit: 'bpm'),
    DemoThreshold(metric: DemoMetric.bloodOxygen, low: 90, high: 100, min: 70, max: 100, unit: '%', consecutive: 2),
    DemoThreshold(metric: DemoMetric.temperature, low: 35, high: 38, min: 34, max: 42, unit: '°C', decimals: 1, consecutive: 1),
    DemoThreshold(metric: DemoMetric.bloodPressure, low: 90, high: 160, min: 60, max: 220, unit: 'mmHg', consecutive: 1),
  ];

  static final members = <DemoMember>[
    const DemoMember(name: 'Li Wei', relation: '儿子', status: DemoMemberStatus.active),
    const DemoMember(name: 'Li Na', relation: '女儿', status: DemoMemberStatus.pending),
  ];

  static final DateTime _now = DateTime.now();

  static final mum = DemoElder(
    name: '妈妈',
    relation: 'Wang Fang',
    status: DemoElderStatus.abnormal,
    lastReading: _now.subtract(const Duration(minutes: 18)),
    ringName: 'RWFIT Ring',
    battery: 64,
    phone: '+61 400 000 001',
  );

  static final dad = DemoElder(
    name: '爸爸',
    relation: 'Li Guo',
    status: DemoElderStatus.normal,
    lastReading: _now.subtract(const Duration(minutes: 42)),
    ringName: 'RWFIT Ring',
    battery: 81,
    phone: '+61 400 000 002',
  );

  static final elders = <DemoElder>[mum, dad];

  static final alerts = <DemoAlert>[
    DemoAlert(
      id: 1,
      elder: mum,
      metric: DemoMetric.bloodOxygen,
      level: DemoAlertLevel.high,
      value: '86',
      unit: '%',
      time: _now.subtract(const Duration(minutes: 18)),
      low: 90,
      high: 100,
      points: [97, 97, 96, 97, 96, 96, 95, 96, 96, 95, 95, 94, 95, 94, 93, 94, 93, 92, 92, 91, 90, 89, 88, 86],
    ),
    DemoAlert(
      id: 2,
      elder: mum,
      metric: DemoMetric.heartRate,
      level: DemoAlertLevel.warn,
      value: '126',
      unit: 'bpm',
      time: _now.subtract(const Duration(hours: 3, minutes: 5)),
      low: 45,
      high: 120,
      points: [62, 60, 58, 57, 58, 60, 66, 72, 78, 84, 90, 96, 101, 108, 112, 118, 121, 124, 126, 119, 110, 98, 88, 80],
    ),
    DemoAlert(
      id: 3,
      elder: dad,
      metric: DemoMetric.heartRate,
      level: DemoAlertLevel.recovered,
      value: '72',
      unit: 'bpm',
      time: _now.subtract(const Duration(hours: 9, minutes: 40)),
      low: 45,
      high: 120,
      points: [58, 57, 56, 55, 56, 58, 64, 70, 76, 84, 96, 108, 118, 124, 122, 112, 98, 86, 78, 74, 72, 70, 71, 72],
      handled: true,
    ),
    DemoAlert(
      id: 4,
      elder: dad,
      metric: DemoMetric.heartRate,
      level: DemoAlertLevel.noData,
      value: '--',
      unit: '',
      time: _now.subtract(const Duration(days: 1, hours: 2)),
      low: 45,
      high: 120,
      points: const [],
      handled: true,
      noDataHours: 12,
    ),
  ];
}
