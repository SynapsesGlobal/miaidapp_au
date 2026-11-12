import 'package:rwfit_ble/rwfit_ble.dart';

/// 智能戒指在 App 侧的数据模型：最近一次体征值、睡眠与步数概要，以及
/// 由 SDK 同步结果 / 实时测量结果填充这些模型的解析逻辑。
///
/// 时间统一用本地 [DateTime]；SDK 侧的时间戳均为 Unix 秒。

/// 一次体征读数（心率、血氧、体温、HRV）。
class RingMetric {
  const RingMetric({required this.value, required this.time, this.realtime = false});

  final double value;
  final DateTime time;

  /// 来自实时单次测量（而不是戒指定时监测后同步回来的历史值）。
  final bool realtime;

  Map<String, dynamic> toJson() => {
        'value': value,
        'time': time.millisecondsSinceEpoch,
        'realtime': realtime,
      };

  static RingMetric? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final value = json['value'];
    final time = json['time'];
    if (value is! num || time is! num) return null;
    return RingMetric(
      value: value.toDouble(),
      time: DateTime.fromMillisecondsSinceEpoch(time.toInt()),
      realtime: json['realtime'] == true,
    );
  }
}

/// 一次血压读数（mmHg）。
class BloodPressureMetric {
  const BloodPressureMetric({
    required this.systolic,
    required this.diastolic,
    required this.time,
    this.realtime = false,
  });

  final int systolic;
  final int diastolic;
  final DateTime time;
  final bool realtime;

  String get text => '$systolic/$diastolic';

  Map<String, dynamic> toJson() => {
        'systolic': systolic,
        'diastolic': diastolic,
        'time': time.millisecondsSinceEpoch,
        'realtime': realtime,
      };

  static BloodPressureMetric? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['time'] is! num) return null;
    final systolic = _int(json['systolic']);
    final diastolic = _int(json['diastolic']);
    if (systolic <= 0) return null;
    return BloodPressureMetric(
      systolic: systolic,
      diastolic: diastolic,
      time: DateTime.fromMillisecondsSinceEpoch((json['time'] as num).toInt()),
      realtime: json['realtime'] == true,
    );
  }
}

/// 一晚睡眠概要（分钟）。
class SleepSummary {
  const SleepSummary({
    required this.date,
    required this.totalMinutes,
    required this.deepMinutes,
    required this.lightMinutes,
    required this.remMinutes,
    required this.awakeMinutes,
    this.beginTime,
    this.endTime,
  });

  final DateTime date;
  final int totalMinutes;
  final int deepMinutes;
  final int lightMinutes;
  final int remMinutes;
  final int awakeMinutes;
  final DateTime? beginTime;
  final DateTime? endTime;

  bool get hasStages => deepMinutes + lightMinutes + remMinutes + awakeMinutes > 0;

  Map<String, dynamic> toJson() => {
        'date': date.millisecondsSinceEpoch,
        'total': totalMinutes,
        'deep': deepMinutes,
        'light': lightMinutes,
        'rem': remMinutes,
        'awake': awakeMinutes,
        'begin': beginTime?.millisecondsSinceEpoch,
        'end': endTime?.millisecondsSinceEpoch,
      };

  static SleepSummary? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['date'] is! num) return null;
    DateTime? ms(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    return SleepSummary(
      date: ms(json['date'])!,
      totalMinutes: _int(json['total']),
      deepMinutes: _int(json['deep']),
      lightMinutes: _int(json['light']),
      remMinutes: _int(json['rem']),
      awakeMinutes: _int(json['awake']),
      beginTime: ms(json['begin']),
      endTime: ms(json['end']),
    );
  }
}

/// 某一天的步数概要。
class StepsSummary {
  const StepsSummary({
    required this.date,
    required this.steps,
    required this.distanceMeters,
    required this.calories,
  });

  final DateTime date;
  final int steps;
  final int distanceMeters;

  /// 千卡。
  final double calories;

  Map<String, dynamic> toJson() => {
        'date': date.millisecondsSinceEpoch,
        'steps': steps,
        'distance': distanceMeters,
        'calories': calories,
      };

  static StepsSummary? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['date'] is! num) return null;
    return StepsSummary(
      date: DateTime.fromMillisecondsSinceEpoch((json['date'] as num).toInt()),
      steps: _int(json['steps']),
      distanceMeters: _int(json['distance']),
      calories: _double(json['calories']),
    );
  }
}

/// 展示层需要的全部最新数据。不可变，每次更新产生新对象。
class SmartRingSnapshot {
  const SmartRingSnapshot({
    this.heartRate,
    this.bloodOxygen,
    this.temperature,
    this.hrv,
    this.pressure,
    this.bloodPressure,
    this.bloodSugar,
    this.sleep,
    this.steps,
    this.lastSyncAt,
  });

  static const empty = SmartRingSnapshot();

  final RingMetric? heartRate;
  final RingMetric? bloodOxygen;
  final RingMetric? temperature;
  final RingMetric? hrv;

  /// 压力指数（设备算法值，无单位）。
  final RingMetric? pressure;
  final BloodPressureMetric? bloodPressure;

  /// 血糖（mmol/L，设备算法估算值）。
  final RingMetric? bloodSugar;

  /// 最近一晚睡眠。
  final SleepSummary? sleep;

  /// 最近一天（通常是今天）的步数。
  final StepsSummary? steps;
  final DateTime? lastSyncAt;

  bool get isEmpty =>
      heartRate == null &&
      bloodOxygen == null &&
      temperature == null &&
      hrv == null &&
      pressure == null &&
      bloodPressure == null &&
      bloodSugar == null &&
      sleep == null &&
      steps == null;

  SmartRingSnapshot copyWith({
    RingMetric? heartRate,
    RingMetric? bloodOxygen,
    RingMetric? temperature,
    RingMetric? hrv,
    RingMetric? pressure,
    BloodPressureMetric? bloodPressure,
    RingMetric? bloodSugar,
    SleepSummary? sleep,
    StepsSummary? steps,
    DateTime? lastSyncAt,
  }) {
    return SmartRingSnapshot(
      heartRate: heartRate ?? this.heartRate,
      bloodOxygen: bloodOxygen ?? this.bloodOxygen,
      temperature: temperature ?? this.temperature,
      hrv: hrv ?? this.hrv,
      pressure: pressure ?? this.pressure,
      bloodPressure: bloodPressure ?? this.bloodPressure,
      bloodSugar: bloodSugar ?? this.bloodSugar,
      sleep: sleep ?? this.sleep,
      steps: steps ?? this.steps,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'heartRate': heartRate?.toJson(),
        'bloodOxygen': bloodOxygen?.toJson(),
        'temperature': temperature?.toJson(),
        'hrv': hrv?.toJson(),
        'pressure': pressure?.toJson(),
        'bloodPressure': bloodPressure?.toJson(),
        'bloodSugar': bloodSugar?.toJson(),
        'sleep': sleep?.toJson(),
        'steps': steps?.toJson(),
        'lastSyncAt': lastSyncAt?.millisecondsSinceEpoch,
      };

  factory SmartRingSnapshot.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? map(Object? v) => v is Map ? v.cast<String, dynamic>() : null;
    final lastSync = json['lastSyncAt'];
    return SmartRingSnapshot(
      heartRate: RingMetric.fromJson(map(json['heartRate'])),
      bloodOxygen: RingMetric.fromJson(map(json['bloodOxygen'])),
      temperature: RingMetric.fromJson(map(json['temperature'])),
      hrv: RingMetric.fromJson(map(json['hrv'])),
      pressure: RingMetric.fromJson(map(json['pressure'])),
      bloodPressure: BloodPressureMetric.fromJson(map(json['bloodPressure'])),
      bloodSugar: RingMetric.fromJson(map(json['bloodSugar'])),
      sleep: SleepSummary.fromJson(map(json['sleep'])),
      steps: StepsSummary.fromJson(map(json['steps'])),
      lastSyncAt: lastSync is num ? DateTime.fromMillisecondsSinceEpoch(lastSync.toInt()) : null,
    );
  }
}

/// 设备功能表（`onFunctionMenu.raw`）的类型安全读法。
class RingCapabilities {
  const RingCapabilities(this.raw);

  static const empty = RingCapabilities(<String, dynamic>{});

  final Map<String, dynamic> raw;

  bool _has(String key) => raw[key] == true;

  /// 功能表未知（尚未收到）时按"都支持"处理，避免把按钮全部禁掉。
  bool get isUnknown => raw.isEmpty;

  bool get heartRate => isUnknown || _has('isHr');
  bool get bloodOxygen => isUnknown || _has('isBloodOxy');

  /// 体温有两个能力位：`isBodyTemp`（单次实时测量）与 `isSupportTemperatureMonitoring`
  /// （全天定时监测）。任一为真就算支持体温，面板显示体温卡；只有后者时不能「立即测量」，
  /// 要开全天监测后同步才有数值（见 [temperatureRealtime]）。
  bool get temperature => isUnknown || _has('isBodyTemp') || _has('isSupportTemperatureMonitoring');
  bool get temperatureRealtime => isUnknown || _has('isBodyTemp');
  bool get hrv => isUnknown || _has('isHrv');
  bool get stress => isUnknown || _has('isPressure');
  bool get bloodPressure => isUnknown || _has('isBloodPress');
  bool get bloodSugar => isUnknown || _has('isBloodSugar');
  bool get sleep => isUnknown || _has('isSleep');
  bool get steps => isUnknown || _has('isStep');

  /// 能否对该项做单次实时测量（「立即测量」用）。
  bool supportsRealtime(RealtimeMetric metric) {
    switch (metric) {
      case RealtimeMetric.hr:
        return heartRate;
      case RealtimeMetric.bloodOxy:
        return bloodOxygen;
      case RealtimeMetric.temperature:
        return temperatureRealtime;
      case RealtimeMetric.hrv:
        return hrv;
      case RealtimeMetric.pressure:
        return stress;
      case RealtimeMetric.bloodSugar:
        return bloodSugar;
      case RealtimeMetric.bloodPressure:
        return bloodPressure;
    }
  }

  /// 能否对该项做全天定时监测（「全天监测」设置页用）。
  bool supportsTimed(RealtimeMetric metric) =>
      metric == RealtimeMetric.temperature ? temperature : supportsRealtime(metric);
}

/// 一条要上报到后端的历史读数（走势图用）。[type] 是后端的指标名：
/// heart_rate / blood_oxygen / hrv / stress / temperature / blood_pressure / blood_sugar / steps（每日累计）。
class RingReading {
  const RingReading({
    required this.type,
    required this.value,
    required this.time,
    this.value2,
    this.realtime = false,
  });

  final String type;

  /// 读数；血压时为收缩压。
  final double value;

  /// 血压的舒张压，其它指标为空。
  final double? value2;
  final DateTime time;

  /// 手动「立即测量」得到的（否则来自戒指定时监测的同步）。
  final bool realtime;

  /// 去重键：同一指标同一秒只算一条，与后端唯一索引一致。
  String get key => '$type|${time.millisecondsSinceEpoch ~/ 1000}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'value': value,
        if (value2 != null) 'value2': value2,
        'time': time.toUtc().toIso8601String(),
        if (realtime) 'realtime': true,
      };

  static RingReading? fromJson(Object? json) {
    if (json is! Map) return null;
    final type = json['type'];
    final value = json['value'];
    final time = DateTime.tryParse(json['time'] is String ? json['time'] as String : '');
    if (type is! String || value is! num || time == null) return null;
    final value2 = json['value2'];
    return RingReading(
      type: type,
      value: value.toDouble(),
      value2: value2 is num ? value2.toDouble() : null,
      time: time.toLocal(),
      realtime: json['realtime'] == true,
    );
  }
}

/// 把 SDK 的同步结果 / 实时数据合并进 [SmartRingSnapshot]。
///
/// 字段含义见插件文档 §3.2.2.4：`hr`/`bo`/`temp`/`hrv` 按日期返回 `items[{time, 值}]`，
/// 体温 `temp` 为 ℃×10；`sleep` 每日一条，`items[{len, sleepType}]`（0 清醒 1 浅 2 深 3 REM）；
/// `step` 每日一条，含 `totalSteps`/`totalDistance`/`totalCalorie`（cal）。
class SmartRingSyncParser {
  SmartRingSyncParser._();

  static SmartRingSnapshot applySyncResult(SmartRingSnapshot snapshot, SyncResult result) {
    switch (result.type) {
      case 'hr':
        return snapshot.copyWith(heartRate: _latestMetric(result.data, 'hr', snapshot.heartRate));
      case 'bo':
        return snapshot.copyWith(bloodOxygen: _latestMetric(result.data, 'bloodOxy', snapshot.bloodOxygen));
      case 'hrv':
        return snapshot.copyWith(hrv: _latestMetric(result.data, 'hrv', snapshot.hrv));
      case 'pressure':
        return snapshot.copyWith(pressure: _latestMetric(result.data, 'pressure', snapshot.pressure));
      case 'bp':
        return snapshot.copyWith(bloodPressure: _latestBloodPressure(result.data, snapshot.bloodPressure));
      case 'bloodSugar':
        return snapshot.copyWith(bloodSugar: _latestMetric(result.data, 'bloodSugar', snapshot.bloodSugar));
      case 'temp':
        return snapshot.copyWith(
          temperature: _latestMetric(result.data, 'temp', snapshot.temperature, scale: 0.1),
        );
      case 'sleep':
        return snapshot.copyWith(sleep: _latestSleep(result.data, snapshot.sleep));
      case 'step':
        return snapshot.copyWith(steps: _latestSteps(result.data, snapshot.steps));
      default:
        return snapshot;
    }
  }

  static SmartRingSnapshot applyRealtime(SmartRingSnapshot snapshot, RealtimeData data) {
    // 测量过程中设备会先推 0 或占位值（体温尤其明显），不能覆盖已有读数
    if (data.value <= 0) return snapshot;
    final time = data.timestampSec > 0 ? _fromSec(data.timestampSec) : DateTime.now();
    final metric = RingMetric(value: data.value, time: time, realtime: true);
    switch (data.type) {
      case HealthType.pressure:
        return snapshot.copyWith(pressure: metric);
      case HealthType.bloodBp:
        final diastolic = data.diastolic ?? 0;
        if (diastolic <= 0) return snapshot;
        return snapshot.copyWith(
          bloodPressure: BloodPressureMetric(
            systolic: data.value.round(),
            diastolic: diastolic,
            time: time,
            realtime: true,
          ),
        );
      case HealthType.hr:
        return snapshot.copyWith(heartRate: metric);
      case HealthType.bloodOxy:
        return snapshot.copyWith(bloodOxygen: metric);
      case HealthType.temperature:
        return snapshot.copyWith(temperature: metric);
      case HealthType.hrv:
        return snapshot.copyWith(hrv: metric);
      case HealthType.bloodSugar:
        return snapshot.copyWith(bloodSugar: metric);
      default:
        return snapshot;
    }
  }

  /// 同步结果类型 → (后端指标名, 明细里的取值字段, 换算系数)。
  static const Map<String, List<Object>> _readingTypes = {
    'hr': ['heart_rate', 'hr', 1.0],
    'bo': ['blood_oxygen', 'bloodOxy', 1.0],
    'hrv': ['hrv', 'hrv', 1.0],
    'pressure': ['stress', 'pressure', 1.0],
    'bloodSugar': ['blood_sugar', 'bloodSugar', 1.0],
    'temp': ['temperature', 'temp', 0.1],
  };

  /// 步数读数的指标名。
  static const stepsType = 'steps';

  /// 把一次同步结果里的全部有效明细转成历史读数（步数为每日累计值；睡眠不在此列）。
  static List<RingReading> readingsFromSync(SyncResult result) {
    final readings = <RingReading>[];
    if (result.type == 'step') {
      // 步数按天累计：每天一条，时间取当天日期，当天的数随同步不断变大（后端按天覆盖）
      for (final day in result.data) {
        final daySec = _int(day['time']);
        final steps = _int(day['totalSteps']);
        if (daySec <= 0 || steps <= 0) continue;
        readings.add(RingReading(type: stepsType, value: steps.toDouble(), time: _fromSec(daySec)));
      }
      return readings;
    }
    final spec = _readingTypes[result.type];
    if (spec == null && result.type != 'bp') return readings;
    for (final day in result.data) {
      final dayTime = _int(day['time']);
      final items = day['items'];
      if (items is! List) continue;
      for (final raw in items) {
        if (raw is! Map) continue;
        final sec = _int(raw['time']);
        final time = _fromSec(sec > 0 ? sec : dayTime);
        if (spec == null) {
          final systolic = _int(raw['systolic']);
          final diastolic = _int(raw['diastolic']);
          if (systolic <= 0 || diastolic <= 0) continue;
          readings.add(RingReading(
            type: 'blood_pressure',
            value: systolic.toDouble(),
            value2: diastolic.toDouble(),
            time: time,
          ));
        } else {
          final value = _double(raw[spec[1]]) * (spec[2] as double);
          if (value <= 0) continue;
          readings.add(RingReading(type: spec[0] as String, value: value, time: time));
        }
      }
    }
    return readings;
  }

  /// 快照里手动「立即测量」得到的读数（实时测量结束后上报用）。
  static List<RingReading> realtimeReadings(SmartRingSnapshot snapshot) {
    final readings = <RingReading>[];
    void add(String type, RingMetric? m) {
      if (m != null && m.realtime) {
        readings.add(RingReading(type: type, value: m.value, time: m.time, realtime: true));
      }
    }

    add('heart_rate', snapshot.heartRate);
    add('blood_oxygen', snapshot.bloodOxygen);
    add('hrv', snapshot.hrv);
    add('stress', snapshot.pressure);
    add('temperature', snapshot.temperature);
    add('blood_sugar', snapshot.bloodSugar);
    final bp = snapshot.bloodPressure;
    if (bp != null && bp.realtime) {
      readings.add(RingReading(
        type: 'blood_pressure',
        value: bp.systolic.toDouble(),
        value2: bp.diastolic.toDouble(),
        time: bp.time,
        realtime: true,
      ));
    }
    return readings;
  }

  /// 同步结果里时间最新的一条有效读数；若不比 [current] 新则保留 [current]。
  static RingMetric? _latestMetric(
    List<Map<String, dynamic>> days,
    String valueKey,
    RingMetric? current, {
    double scale = 1,
  }) {
    var latest = current;
    for (final day in days) {
      final dayTime = _int(day['time']);
      final items = day['items'];
      if (items is! List) continue;
      for (final raw in items) {
        if (raw is! Map) continue;
        final value = _double(raw[valueKey]) * scale;
        if (value <= 0) continue;
        final sec = _int(raw['time']);
        final time = _fromSec(sec > 0 ? sec : dayTime);
        if (latest == null || time.isAfter(latest.time)) {
          latest = RingMetric(value: value, time: time);
        }
      }
    }
    return latest;
  }

  /// 血压明细 `items[{time, systolic, diastolic}]`，取时间最新的一条。
  static BloodPressureMetric? _latestBloodPressure(List<Map<String, dynamic>> days, BloodPressureMetric? current) {
    var latest = current;
    for (final day in days) {
      final dayTime = _int(day['time']);
      final items = day['items'];
      if (items is! List) continue;
      for (final raw in items) {
        if (raw is! Map) continue;
        final systolic = _int(raw['systolic']);
        final diastolic = _int(raw['diastolic']);
        if (systolic <= 0 || diastolic <= 0) continue;
        final sec = _int(raw['time']);
        final time = _fromSec(sec > 0 ? sec : dayTime);
        if (latest == null || time.isAfter(latest.time)) {
          latest = BloodPressureMetric(systolic: systolic, diastolic: diastolic, time: time);
        }
      }
    }
    return latest;
  }

  static SleepSummary? _latestSleep(List<Map<String, dynamic>> days, SleepSummary? current) {
    var latest = current;
    for (final day in days) {
      final endSec = _int(day['endTime']);
      final daySec = _int(day['time']);
      final date = _fromSec(endSec > 0 ? endSec : daySec);
      var deep = 0, light = 0, rem = 0, awake = 0;
      final items = day['items'];
      if (items is List) {
        for (final raw in items) {
          if (raw is! Map) continue;
          final len = _int(raw['len']);
          switch (_int(raw['sleepType'])) {
            case 0:
              awake += len;
              break;
            case 1:
              light += len;
              break;
            case 2:
              deep += len;
              break;
            case 3:
              rem += len;
              break;
          }
        }
      }
      var total = _int(day['duration']);
      if (total <= 0) total = deep + light + rem;
      if (total <= 0) continue;
      if (latest == null || date.isAfter(latest.date)) {
        final beginSec = _int(day['beginTime']);
        latest = SleepSummary(
          date: date,
          totalMinutes: total,
          deepMinutes: deep,
          lightMinutes: light,
          remMinutes: rem,
          awakeMinutes: awake,
          beginTime: beginSec > 0 ? _fromSec(beginSec) : null,
          endTime: endSec > 0 ? _fromSec(endSec) : null,
        );
      }
    }
    return latest;
  }

  static StepsSummary? _latestSteps(List<Map<String, dynamic>> days, StepsSummary? current) {
    var latest = current;
    for (final day in days) {
      final daySec = _int(day['time']);
      if (daySec <= 0) continue;
      final date = _fromSec(daySec);
      final steps = _int(day['totalSteps']);
      // 同一天以同步结果为准（今天的步数会随时间增长），更早的日期忽略
      if (latest != null && date.isBefore(latest.date) && !_sameDay(date, latest.date)) continue;
      latest = StepsSummary(
        date: date,
        steps: steps,
        distanceMeters: _int(day['totalDistance']),
        calories: _double(day['totalCalorie']) / 1000,
      );
    }
    return latest;
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _fromSec(int sec) => DateTime.fromMillisecondsSinceEpoch(sec * 1000);
}

int _int(Object? v) => v is num ? v.toInt() : 0;

double _double(Object? v) => v is num ? v.toDouble() : 0;
