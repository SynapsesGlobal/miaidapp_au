import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/miaid_card.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/smart_ring_models.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_monitoring_screen.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_pair_screen.dart';
import 'package:rwfit_ble/rwfit_ble.dart';
import 'package:share/share.dart';

/// 智能戒指健康看板：设备状态、四项体征、睡眠、步数和操作按钮。
///
/// 全部数据来自 [SmartRingService]：进入页面时若未连接则后台重连；
/// 「立即测量」依次实时测量心率 / 血氧 / 体温 / HRV，「同步数据」拉取戒指上的历史记录，
/// 「分享给医生」把当前数据整理成文本走系统分享（一期不经后端）。
class SmartRingScreen extends StatefulWidget {
  const SmartRingScreen({Key? key}) : super(key: key);

  @override
  State<SmartRingScreen> createState() => _SmartRingScreenState();
}

class _SmartRingScreenState extends State<SmartRingScreen> {
  static const _stepsGoal = 8000;

  final SmartRingService _ring = SmartRingService.instance;
  bool _unbinding = false;

  @override
  void initState() {
    super.initState();
    if (_ring.isBound && !_ring.isConnected && !_ring.isConnecting) {
      unawaited(_reconnect(silent: true));
    }
  }

  Future<void> _reconnect({bool silent = false}) async {
    try {
      await _ring.reconnect();
    } catch (e) {
      debugPrint('SmartRing: reconnect failed: $e');
      if (!silent && mounted) unawaited(HttpExceptionNotifyUser.showInfo(S.of(context).smartRingConnectFailed));
    }
  }

  Future<void> _measure() async {
    final s = S.of(context);
    try {
      await _ring.measureNow();
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(s.smartRingMeasureDone));
    } on SmartRingMeasureException catch (e) {
      debugPrint('SmartRing: measure partly failed: $e');
      if (!mounted) return;
      final names = e.failed.map((m) => SmartRingFormat.metricLabel(context, m)).join(', ');
      unawaited(HttpExceptionNotifyUser.showInfo(s.smartRingMeasureItemFailed(names)));
    } catch (e) {
      debugPrint('SmartRing: measure failed: $e');
      if (!mounted) return;
      unawaited(HttpExceptionNotifyUser.showInfo(_ring.isConnected ? s.smartRingMeasureFailed : s.smartRingConnectFailed));
    }
  }

  Future<void> _sync() async {
    final s = S.of(context);
    try {
      await _ring.syncHealthData();
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(s.smartRingSyncDone));
    } catch (e) {
      debugPrint('SmartRing: sync failed: $e');
      if (!mounted) return;
      unawaited(HttpExceptionNotifyUser.showInfo(_ring.isConnected ? s.smartRingSyncFailed : s.smartRingConnectFailed));
    }
  }

  Future<void> _share() async {
    final s = S.of(context);
    if (_ring.snapshot.isEmpty) {
      unawaited(HttpExceptionNotifyUser.showInfo(s.smartRingNoData));
      return;
    }
    await Share.share(SmartRingFormat.shareText(context, _ring.displayName, _ring.snapshot), subject: s.smartRingShareSubject);
  }

  Future<void> _confirmUnbind() async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(s.smartRingUnbind, textAlign: TextAlign.center,
            style: GoogleFonts.rubik(fontWeight: FontWeight.w500, fontSize: 17, color: AppColors.k010101)),
        content: Text(s.smartRingUnbindConfirm, textAlign: TextAlign.center,
            style: GoogleFonts.rubik(fontSize: 13, color: AppColors.k010101)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.confirm, style: TextStyle(color: AppColors.ke63030)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _unbinding = true);
    try {
      await _ring.unbind();
    } finally {
      if (mounted) setState(() => _unbinding = false);
    }
    if (!mounted) return;
    await Navigator.pushReplacement(context, MaterialPageRoute<void>(
      builder: (context) => const SmartRingPairScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
        ),
        title: Text(s.smartRing, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        )),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: AppColors.k010101),
            onPressed: _unbinding ? null : () => unawaited(_showActions()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _ring,
        builder: (context, _) {
          final snap = _ring.snapshot;
          final caps = _ring.capabilities;
          final busy = _ring.busy || _unbinding;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _deviceCard(context),
                const SizedBox(height: 20),
                if (_hasVitals(caps)) _sectionTitle(s.smartRingVitals),
                ..._metricRows(context, snap, caps),
                if (caps.sleep || caps.steps) ...[
                  const SizedBox(height: 8),
                  _sectionTitle(s.smartRingSleepActivity),
                ],
                if (caps.sleep) ...[
                  _sleepCard(context, snap.sleep),
                  const SizedBox(height: 12),
                ],
                if (caps.steps) ...[
                  _stepsCard(context, snap.steps),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                if (!_ring.isConnected) ...[
                  Text(
                    _ring.isConnecting ? s.smartRingConnecting : s.smartRingNotConnectedHint,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(children: [
                  Expanded(child: _actionButton(
                    _ring.measuring != null
                        ? s.smartRingMeasuring(SmartRingFormat.metricLabel(context, _ring.measuring!))
                        : s.smartRingMeasureNow,
                    Icons.play_arrow,
                    filled: true,
                    loading: _ring.measuring != null,
                    onPressed: busy || _ring.isConnecting ? null : () => unawaited(_measure()),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _actionButton(
                    _ring.syncing ? s.smartRingSyncing : s.smartRingSyncData,
                    Icons.sync,
                    filled: false,
                    loading: _ring.syncing,
                    onPressed: busy || _ring.isConnecting ? null : () => unawaited(_sync()),
                  )),
                ]),
                const SizedBox(height: 12),
                _actionButton(
                  s.smartRingShareDoctor,
                  Icons.medical_services_outlined,
                  filled: false,
                  onPressed: snap.isEmpty ? null : () => unawaited(_share()),
                ),
                const SizedBox(height: 16),
                Text(s.smartRingDisclaimer, textAlign: TextAlign.center,
                    style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11)),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _deviceCard(BuildContext context) {
    final s = S.of(context);
    final name = _ring.displayName;

    String status;
    Color dot;
    if (_ring.isConnected) {
      status = s.smartRingConnected;
      dot = AppColors.k25d000;
    } else if (_ring.isConnecting) {
      status = s.smartRingConnecting;
      dot = AppColors.ke68c30;
    } else {
      status = s.smartRingDisconnected;
      dot = AppColors.kb1b1b1;
    }
    final lastSync = _ring.snapshot.lastSyncAt;
    final syncText = lastSync == null ? s.smartRingNotSynced : s.smartRingLastSync(SmartRingFormat.dateTime(context, lastSync));
    final battery = _ring.battery;

    return activeSubscriptionCard(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.donut_large, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.rubik(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(status,
                      style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.9), fontSize: 12))),
                  if (!_ring.isConnected && !_ring.isConnecting) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => unawaited(_reconnect()),
                      child: Text(s.smartRingReconnect, style: GoogleFonts.rubik(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      )),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(syncText, style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.8), fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Icon(_batteryIcon(battery), color: Colors.white, size: 22),
              Text(battery == null ? '--' : '$battery%', style: GoogleFonts.rubik(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
            ],
          ),
        ],
      ),
    ));
  }

  static IconData _batteryIcon(int? level) {
    if (level == null) return Icons.battery_unknown;
    if (level >= 90) return Icons.battery_full;
    if (level >= 75) return Icons.battery_6_bar;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 45) return Icons.battery_4_bar;
    if (level >= 30) return Icons.battery_3_bar;
    if (level >= 15) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  /// 体征卡两列排布，只显示能力表声明支持的项目（能力表未知时全部显示）；奇数张时末行留空位。
  List<Widget> _metricRows(BuildContext context, SmartRingSnapshot snap, RingCapabilities caps) {
    final s = S.of(context);
    final bp = snap.bloodPressure;
    final tiles = <Widget>[
      if (caps.heartRate)
        _metricTile(context, Icons.favorite, AppColors.ke63030, s.smartRingHeartRate,
            snap.heartRate, 'bpm', realtime: RealtimeMetric.hr, info: _MetricInfo.heartRate),
      if (caps.bloodOxygen)
        _metricTile(context, Icons.water_drop, AppColors.k30bee6, s.smartRingBloodOxygen,
            snap.bloodOxygen, '%', realtime: RealtimeMetric.bloodOxy, info: _MetricInfo.bloodOxygen),
      if (caps.temperature)
        _metricTile(context, Icons.thermostat, AppColors.ke68c30, s.smartRingTemperature,
            snap.temperature, '°C', decimals: 1, realtime: RealtimeMetric.temperature, info: _MetricInfo.temperature,
            emptyHint: caps.temperatureRealtime ? null : s.smartRingTemperatureMonitorHint),
      if (caps.hrv)
        _metricTile(context, Icons.monitor_heart, AppColors.k5251f7, s.smartRingHrv,
            snap.hrv, 'ms', realtime: RealtimeMetric.hrv, info: _MetricInfo.hrv),
      if (caps.stress)
        _metricTile(context, Icons.self_improvement, AppColors.k0CC58F, s.smartRingStress,
            snap.pressure, '', realtime: RealtimeMetric.pressure, info: _MetricInfo.stress),
      if (caps.bloodPressure)
        _metricTile(context, Icons.bloodtype, AppColors.ke63030, s.smartRingBloodPressure,
            null, 'mmHg', realtime: RealtimeMetric.bloodPressure, info: _MetricInfo.bloodPressure,
            valueText: bp?.text, time: bp?.time),
      if (caps.bloodSugar)
        _metricTile(context, Icons.bubble_chart, AppColors.k0cbcc5, s.smartRingBloodSugar,
            snap.bloodSugar, 'mmol/L', decimals: 1, realtime: RealtimeMetric.bloodSugar, info: _MetricInfo.bloodSugar),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Row(children: [
        tiles[i],
        const SizedBox(width: 12),
        if (i + 1 < tiles.length) tiles[i + 1] else const Expanded(child: SizedBox()),
      ]));
      rows.add(const SizedBox(height: 12));
    }
    return rows;
  }

  /// [metric] 为普通单值读数；血压等复合读数改传 [valueText] + [time]。
  /// [emptyHint] 在暂无数据时代替「暂无数据」显示（如体温只能靠全天监测获取）。
  Widget _metricTile(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
    RingMetric? metric,
    String unit, {
    int decimals = 0,
    required RealtimeMetric realtime,
    required _MetricInfo info,
    String? valueText,
    DateTime? time,
    String? emptyHint,
  }) {
    final s = S.of(context);
    final measuringThis = _ring.measuring == realtime;
    final value = valueText ?? SmartRingFormat.metric(metric, decimals: decimals);
    final readingTime = time ?? metric?.time;
    return Expanded(
      child: GestureDetector(
        onTap: () => unawaited(_showMetricInfo(info)),
        child: miAidCard(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: GoogleFonts.rubik(
                color: AppColors.k5e5e5e,
                fontSize: 12,
              ), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              if (measuringThis)
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
              else
                Icon(Icons.info_outline, size: 14, color: AppColors.kb1b1b1),
            ]),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                )),
                const SizedBox(width: 4),
                if (readingTime != null && unit.isNotEmpty)
                  Text(unit, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              readingTime == null ? (emptyHint ?? s.smartRingNoData) : SmartRingFormat.dateTime(context, readingTime),
              style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      )),
      ),
    );
  }

  static bool _hasVitals(RingCapabilities caps) =>
      caps.heartRate || caps.bloodOxygen || caps.temperature || caps.hrv || caps.stress || caps.bloodPressure || caps.bloodSugar;

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(title.toUpperCase(), style: GoogleFonts.rubik(
          color: AppColors.k8f8e94,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        )),
      );

  /// 指标说明底部弹层：当前读数 + 「这是什么 / 参考范围 / 测量建议」三段。
  Future<void> _showMetricInfo(_MetricInfo kind) async {
    final s = S.of(context);
    final c = _infoContent(s, kind);
    final snap = _ring.snapshot;
    var value = '--';
    var unit = '';
    String? when;
    switch (kind) {
      case _MetricInfo.heartRate:
        value = SmartRingFormat.metric(snap.heartRate);
        unit = 'bpm';
        when = snap.heartRate == null ? null : SmartRingFormat.dateTime(context, snap.heartRate!.time);
        break;
      case _MetricInfo.bloodOxygen:
        value = SmartRingFormat.metric(snap.bloodOxygen);
        unit = '%';
        when = snap.bloodOxygen == null ? null : SmartRingFormat.dateTime(context, snap.bloodOxygen!.time);
        break;
      case _MetricInfo.temperature:
        value = SmartRingFormat.metric(snap.temperature, decimals: 1);
        unit = '°C';
        when = snap.temperature == null ? null : SmartRingFormat.dateTime(context, snap.temperature!.time);
        break;
      case _MetricInfo.hrv:
        value = SmartRingFormat.metric(snap.hrv);
        unit = 'ms';
        when = snap.hrv == null ? null : SmartRingFormat.dateTime(context, snap.hrv!.time);
        break;
      case _MetricInfo.stress:
        value = SmartRingFormat.metric(snap.pressure);
        when = snap.pressure == null ? null : SmartRingFormat.dateTime(context, snap.pressure!.time);
        break;
      case _MetricInfo.bloodPressure:
        final bp = snap.bloodPressure;
        value = bp?.text ?? '--';
        unit = 'mmHg';
        when = bp == null ? null : SmartRingFormat.dateTime(context, bp.time);
        break;
      case _MetricInfo.bloodSugar:
        value = SmartRingFormat.metric(snap.bloodSugar, decimals: 1);
        unit = 'mmol/L';
        when = snap.bloodSugar == null ? null : SmartRingFormat.dateTime(context, snap.bloodSugar!.time);
        break;
      case _MetricInfo.sleep:
        final sleep = snap.sleep;
        value = sleep == null ? '--' : SmartRingFormat.hoursMinutes(sleep.totalMinutes);
        when = sleep == null ? null : _sleepDateLabel(context, sleep);
        break;
      case _MetricInfo.steps:
        final steps = snap.steps;
        value = steps == null ? '--' : SmartRingFormat.thousands(steps.steps);
        when = steps == null ? null : SmartRingFormat.dateTime(context, steps.date).split(' ').first;
        break;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.kb1b1b1.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.color.withOpacity(0.12)),
                  child: Icon(c.icon, color: c.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      )),
                      const SizedBox(height: 3),
                      Text(when ?? s.smartRingNoData,
                          style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    )),
                    if (unit.isNotEmpty && when != null) ...[
                      const SizedBox(width: 4),
                      Text(unit, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
                    ],
                  ],
                ),
              ]),
              const SizedBox(height: 20),
              Divider(height: 1, color: AppColors.kf4f4f4),
              const SizedBox(height: 18),
              _infoSection(Icons.help_outline, s.smartRingWhatIsIt, c.desc, c.color),
              const SizedBox(height: 16),
              _infoSection(Icons.straighten, s.smartRingReferenceRange, c.range, c.color),
              const SizedBox(height: 16),
              _infoSection(Icons.lightbulb_outline, s.smartRingTips, c.tip, c.color),
              const SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.kb1b1b1),
                const SizedBox(width: 6),
                Expanded(child: Text(s.smartRingDisclaimer,
                    style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11, height: 1.4))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoSection(IconData icon, String title, String body, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(body, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 13, height: 1.5)),
        ),
      ],
    );
  }

  static _InfoContent _infoContent(S s, _MetricInfo kind) {
    switch (kind) {
      case _MetricInfo.heartRate:
        return _InfoContent(s.smartRingHeartRate, Icons.favorite, AppColors.ke63030,
            s.smartRingHeartRateDesc, s.smartRingHeartRateRange, s.smartRingHeartRateTip);
      case _MetricInfo.bloodOxygen:
        return _InfoContent(s.smartRingBloodOxygen, Icons.water_drop, AppColors.k30bee6,
            s.smartRingBloodOxygenDesc, s.smartRingBloodOxygenRange, s.smartRingBloodOxygenTip);
      case _MetricInfo.temperature:
        return _InfoContent(s.smartRingTemperature, Icons.thermostat, AppColors.ke68c30,
            s.smartRingTemperatureDesc, s.smartRingTemperatureRange, s.smartRingTemperatureTip);
      case _MetricInfo.hrv:
        return _InfoContent(s.smartRingHrv, Icons.monitor_heart, AppColors.k5251f7,
            s.smartRingHrvDesc, s.smartRingHrvRange, s.smartRingHrvTip);
      case _MetricInfo.stress:
        return _InfoContent(s.smartRingStress, Icons.self_improvement, AppColors.k0CC58F,
            s.smartRingStressDesc, s.smartRingStressRange, s.smartRingStressTip);
      case _MetricInfo.bloodPressure:
        return _InfoContent(s.smartRingBloodPressure, Icons.bloodtype, AppColors.ke63030,
            s.smartRingBloodPressureDesc, s.smartRingBloodPressureRange, s.smartRingBloodPressureTip);
      case _MetricInfo.bloodSugar:
        return _InfoContent(s.smartRingBloodSugar, Icons.bubble_chart, AppColors.k0cbcc5,
            s.smartRingBloodSugarDesc, s.smartRingBloodSugarRange, s.smartRingBloodSugarTip);
      case _MetricInfo.sleep:
        return _InfoContent(s.smartRingSleep, Icons.bedtime, AppColors.k5251f7,
            s.smartRingSleepDesc, s.smartRingSleepRange, s.smartRingSleepTip);
      case _MetricInfo.steps:
        return _InfoContent(s.smartRingSteps, Icons.directions_walk, AppColors.k0CC58F,
            s.smartRingStepsDesc, s.smartRingStepsRange, s.smartRingStepsTip);
    }
  }

  /// 改昵称弹框：预填当前昵称，留空或点「恢复原名」则回到蓝牙名。
  Future<void> _rename() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initial: _ring.nickname ?? '', bleName: _ring.boundDevice?.name ?? ''),
    );
    if (result == null || !mounted) return;
    await _ring.setNickname(result);
  }

  /// 右上角「更多」底部弹层：全天监测、戒指功能、解绑。
  Future<void> _showActions() async {
    final s = S.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(12, 12, 12, 16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.kb1b1b1.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            _actionRow(
              icon: Icons.schedule,
              color: AppColors.k0cbcc5,
              title: s.smartRingAllDayMonitoring,
              subtitle: s.smartRingAllDayMonitoringDesc,
              onTap: () => Navigator.pop(context, 'monitoring'),
            ),
            _actionRow(
              icon: Icons.edit,
              color: AppColors.ke68c30,
              title: s.smartRingRename,
              subtitle: s.smartRingRenameDesc,
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            _actionRow(
              icon: Icons.memory,
              color: AppColors.k5251f7,
              title: s.smartRingDeviceFeatures,
              subtitle: s.smartRingDeviceFeaturesDesc,
              onTap: () => Navigator.pop(context, 'features'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Divider(height: 1, color: AppColors.kf4f4f4),
            ),
            _actionRow(
              icon: Icons.link_off,
              color: AppColors.ke63030,
              title: s.smartRingUnbind,
              subtitle: s.smartRingUnbindDesc,
              destructive: true,
              onTap: () => Navigator.pop(context, 'unbind'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'monitoring':
        await Navigator.push(context, MaterialPageRoute<void>(
          builder: (context) => const SmartRingMonitoringScreen(),
        ));
        break;
      case 'rename':
        await _rename();
        break;
      case 'features':
        await _showFeatures();
        break;
      case 'unbind':
        await _confirmUnbind();
        break;
    }
  }

  Widget _actionRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.rubik(
                  color: destructive ? AppColors.ke63030 : AppColors.k010101,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.kb1b1b1, size: 20),
        ]),
      ),
    );
  }

  /// 「戒指功能」底部弹层：设备头部（型号 / 固件 / 电量）+ 支持与不支持的功能标签。
  /// 看板只显示支持的项目，用户在这里能看到为什么某些指标没有出现。
  Future<void> _showFeatures() async {
    final s = S.of(context);
    final caps = _ring.capabilities;
    final features = <_Feature>[
      _Feature(s.smartRingHeartRate, Icons.favorite, caps.heartRate),
      _Feature(s.smartRingBloodOxygen, Icons.water_drop, caps.bloodOxygen),
      _Feature(s.smartRingTemperature, Icons.thermostat, caps.temperature),
      _Feature(s.smartRingHrv, Icons.monitor_heart, caps.hrv),
      _Feature(s.smartRingStress, Icons.self_improvement, caps.stress),
      _Feature(s.smartRingBloodPressure, Icons.bloodtype, caps.bloodPressure),
      _Feature(s.smartRingBloodSugar, Icons.bubble_chart, caps.bloodSugar),
      _Feature(s.smartRingSleep, Icons.bedtime, caps.sleep),
      _Feature(s.smartRingSteps, Icons.directions_walk, caps.steps),
    ];
    final supported = features.where((f) => f.supported).toList();
    final unsupported = features.where((f) => !f.supported).toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.kb1b1b1.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _featureHeader(context),
              const SizedBox(height: 20),
              Divider(height: 1, color: AppColors.kf4f4f4),
              const SizedBox(height: 18),
              if (caps.isUnknown)
                Text(s.smartRingNotConnectedHint, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13))
              else ...[
                _featureSection(s.smartRingSupportedFeatures, supported, active: true),
                if (unsupported.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _featureSection(s.smartRingUnsupportedFeatures, unsupported, active: false),
                ],
              ],
              const SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.kb1b1b1),
                const SizedBox(width: 6),
                Expanded(child: Text(s.smartRingFeaturesNote,
                    style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11, height: 1.4))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureHeader(BuildContext context) {
    final s = S.of(context);
    final device = _ring.boundDevice;
    final firmware = _ring.firmware;
    final battery = _ring.battery;
    final name = _ring.displayName;
    final bleName = device?.name ?? '';
    final details = <String>[
      if (_ring.nickname != null && bleName.isNotEmpty && bleName != name) bleName,
      if (firmware != null && firmware.deviceClazz.isNotEmpty) firmware.deviceClazz,
      if (firmware != null && firmware.deviceNo.isNotEmpty) '${s.smartRingFirmware} ${firmware.deviceNo}',
    ];
    if (details.isEmpty) {
      final id = device == null ? '' : (device.mac.isNotEmpty ? device.mac : (device.uuid ?? ''));
      if (id.isNotEmpty) details.add(id);
    }
    return Row(children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.k0cbcc5, AppColors.k0CC58F],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: AppColors.k0cbcc5.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.donut_large, color: Colors.white, size: 28),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(details.join(' · '), style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_batteryIcon(battery), size: 16,
              color: battery != null && battery <= 15 ? AppColors.ke63030 : AppColors.k25d000),
          const SizedBox(width: 4),
          Text(battery == null ? '--' : '$battery%', style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )),
        ]),
      ),
    ]);
  }

  Widget _featureSection(String title, List<_Feature> items, {required bool active}) {
    final accent = active ? AppColors.k0cbcc5 : AppColors.kb1b1b1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.rubik(
            color: active ? AppColors.k010101 : AppColors.k8f8e94,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Text('${items.length}', style: GoogleFonts.rubik(color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.k0cbcc5.withOpacity(0.1) : AppColors.kf4f4f4,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.icon, size: 15, color: active ? AppColors.k0cbcc5 : AppColors.kb1b1b1),
                  const SizedBox(width: 6),
                  Text(f.label, style: GoogleFonts.rubik(
                    color: active ? AppColors.k010101 : AppColors.k8f8e94,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    decoration: active ? null : TextDecoration.lineThrough,
                  )),
                ]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sleepCard(BuildContext context, SleepSummary? sleep) {
    final s = S.of(context);
    final segments = sleep == null
        ? const <MapEntry<int, Color>>[]
        : <MapEntry<int, Color>>[
            MapEntry(sleep.deepMinutes, AppColors.k5251f7),
            MapEntry(sleep.lightMinutes, AppColors.k30bee6),
            MapEntry(sleep.remMinutes, AppColors.k0cbcc5),
            MapEntry(sleep.awakeMinutes, AppColors.ke68c30),
          ];
    final labels = [s.smartRingDeepSleep, s.smartRingLightSleep, s.smartRingRem, s.smartRingAwake];
    final showStages = sleep != null && sleep.hasStages;
    return GestureDetector(
      onTap: () => unawaited(_showMetricInfo(_MetricInfo.sleep)),
      child: miAidCard(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.bedtime, color: AppColors.k5251f7, size: 18),
            const SizedBox(width: 6),
            Text(s.smartRingSleep, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 12)),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 14, color: AppColors.kb1b1b1),
            const SizedBox(width: 6),
            Expanded(child: Text(
              sleep == null ? '' : _sleepDateLabel(context, sleep),
              style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
            Text(
              sleep == null ? '--' : SmartRingFormat.hoursMinutes(sleep.totalMinutes),
              style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ]),
          if (sleep == null) ...[
            const SizedBox(height: 8),
            Text(s.smartRingSleepHint, style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11)),
          ],
          if (showStages) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(children: [
                  for (final seg in segments)
                    if (seg.key > 0) Expanded(flex: seg.key, child: Container(color: seg.value)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                for (var i = 0; i < segments.length; i++)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: segments[i].value)),
                    const SizedBox(width: 4),
                    Text(
                      labels[i] + ' ' + SmartRingFormat.hm(segments[i].key),
                      style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11),
                    ),
                  ]),
              ],
            ),
          ],
        ],
      ),
    )));
  }

  /// 睡眠记录归属：醒来时间在今天 → 「昨晚」，否则显示日期。
  String _sleepDateLabel(BuildContext context, SleepSummary sleep) {
    final now = DateTime.now();
    final d = sleep.date;
    final today = d.year == now.year && d.month == now.month && d.day == now.day;
    return today ? S.of(context).smartRingLastNight : DateFormat.MMMd().format(d);
  }

  Widget _stepsCard(BuildContext context, StepsSummary? steps) {
    final s = S.of(context);
    final count = steps?.steps ?? 0;
    final ratio = (count / _stepsGoal).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () => unawaited(_showMetricInfo(_MetricInfo.steps)),
      child: miAidCard(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.directions_walk, color: AppColors.k0CC58F, size: 18),
            const SizedBox(width: 6),
            Text(s.smartRingSteps, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 12)),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 14, color: AppColors.kb1b1b1),
            const SizedBox(width: 6),
            Expanded(child: Text(
              steps == null ? '' : SmartRingFormat.dateTime(context, steps.date).split(' ').first,
              style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
            Text(
              steps == null ? '--' : SmartRingFormat.thousands(count),
              style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Text(
              '/ ' + s.smartRingStepsGoal(SmartRingFormat.thousands(_stepsGoal)),
              style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11),
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: AppColors.kf4f4f4,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.k0CC58F),
            ),
          ),
          if (steps != null) ...[
            const SizedBox(height: 8),
            Text(
              '${(steps.distanceMeters / 1000).toStringAsFixed(2)} km · ${steps.calories.toStringAsFixed(0)} kcal',
              style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11),
            ),
          ],
        ],
      ),
    )));
  }

  Widget _actionButton(
    String label,
    IconData icon, {
    required bool filled,
    bool loading = false,
    VoidCallback? onPressed,
  }) {
    final fg = filled ? Colors.white : AppColors.k0cbcc5;
    return MaterialButton(
      onPressed: onPressed,
      elevation: 0,
      height: 48,
      color: filled ? AppColors.k0cbcc5 : Colors.white,
      disabledColor: filled ? AppColors.k0cbcc5.withOpacity(0.5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: filled
            ? BorderSide.none
            : BorderSide(color: AppColors.k0cbcc5.withOpacity(onPressed == null ? 0.5 : 1), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          else
            Icon(icon, color: fg.withOpacity(onPressed == null && !filled ? 0.5 : 1), size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: GoogleFonts.rubik(
            color: fg.withOpacity(onPressed == null && !filled ? 0.5 : 1),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature(this.label, this.icon, this.supported);

  final String label;
  final IconData icon;
  final bool supported;
}

enum _MetricInfo { heartRate, bloodOxygen, temperature, hrv, stress, bloodPressure, bloodSugar, sleep, steps }

class _InfoContent {
  const _InfoContent(this.title, this.icon, this.color, this.desc, this.range, this.tip);

  final String title;
  final IconData icon;
  final Color color;
  final String desc;
  final String range;
  final String tip;
}

/// 昵称输入框。控制器由本 widget 持有，随对话框一起 dispose（在 showDialog 返回后立刻 dispose
/// 会在关闭动画期间触发 "used after being disposed"）。
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial, required this.bleName});

  final String initial;
  final String bleName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(s.smartRingRename, style: GoogleFonts.rubik(
        color: AppColors.k010101,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      )),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 20,
            textInputAction: TextInputAction.done,
            style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 15),
            decoration: InputDecoration(
              hintText: s.smartRingNicknameHint,
              hintStyle: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 14),
              filled: true,
              fillColor: AppColors.kf4f4f4,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              counterStyle: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11),
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          if (widget.bleName.isNotEmpty)
            Text('${s.smartRingOriginalName}: ${widget.bleName}',
                style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        if (widget.initial.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(s.smartRingResetName, style: GoogleFonts.rubik(color: AppColors.k8f8e94)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel, style: GoogleFonts.rubik(color: AppColors.k8f8e94)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(s.confirm, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
