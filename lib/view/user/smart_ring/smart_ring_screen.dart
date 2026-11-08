import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/miaid_card.dart';
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
    final name = _ring.boundDevice?.name ?? '';
    await Share.share(SmartRingFormat.shareText(context, name, _ring.snapshot), subject: s.smartRingShareSubject);
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
        iconTheme: IconThemeData(color: AppColors.k010101),
        title: Text(s.smartRing, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        )),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            enabled: !_unbinding,
            onSelected: (value) {
              if (value == 'monitoring') {
                unawaited(Navigator.push(context, MaterialPageRoute<void>(
                  builder: (context) => const SmartRingMonitoringScreen(),
                )));
              } else if (value == 'unbind') {
                unawaited(_confirmUnbind());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'monitoring',
                child: Text(s.smartRingAllDayMonitoring, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14)),
              ),
              PopupMenuItem(
                value: 'unbind',
                child: Text(s.smartRingUnbind, style: GoogleFonts.rubik(color: AppColors.ke63030, fontSize: 14)),
              ),
            ],
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
                const SizedBox(height: 16),
                Row(children: [
                  _metricTile(context, Icons.favorite, AppColors.ke63030, s.smartRingHeartRate,
                      snap.heartRate, 'bpm', realtime: RealtimeMetric.hr, supported: caps.heartRate),
                  const SizedBox(width: 12),
                  _metricTile(context, Icons.water_drop, AppColors.k30bee6, s.smartRingBloodOxygen,
                      snap.bloodOxygen, '%', realtime: RealtimeMetric.bloodOxy, supported: caps.bloodOxygen),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _metricTile(context, Icons.thermostat, AppColors.ke68c30, s.smartRingTemperature,
                      snap.temperature, '°C', decimals: 1, realtime: RealtimeMetric.temperature, supported: caps.temperature),
                  const SizedBox(width: 12),
                  _metricTile(context, Icons.monitor_heart, AppColors.k5251f7, s.smartRingHrv,
                      snap.hrv, 'ms', realtime: RealtimeMetric.hrv, supported: caps.hrv),
                ]),
                const SizedBox(height: 12),
                _sleepCard(context, snap.sleep),
                const SizedBox(height: 12),
                _stepsCard(context, snap.steps),
                const SizedBox(height: 20),
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
    final device = _ring.boundDevice;
    final name = (device?.name.isNotEmpty ?? false) ? device!.name : 'RWFIT Ring';

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

  Widget _metricTile(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
    RingMetric? metric,
    String unit, {
    int decimals = 0,
    required RealtimeMetric realtime,
    required bool supported,
  }) {
    final s = S.of(context);
    final measuringThis = _ring.measuring == realtime;
    return Expanded(
      child: Opacity(
        opacity: supported ? 1 : 0.45,
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
                if (measuringThis)
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: color)),
              ]),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(SmartRingFormat.metric(metric, decimals: decimals), style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(width: 4),
                  if (metric != null)
                    Text(unit, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                metric == null ? s.smartRingNoData : SmartRingFormat.metricTime(context, metric),
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
    return miAidCard(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.bedtime, color: AppColors.k5251f7, size: 18),
            const SizedBox(width: 6),
            Text(s.smartRingSleep, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 12)),
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
            Text(s.smartRingNoData, style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11)),
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
    ));
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
    return miAidCard(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.directions_walk, color: AppColors.k0CC58F, size: 18),
            const SizedBox(width: 6),
            Text(s.smartRingSteps, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 12)),
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
    ));
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
