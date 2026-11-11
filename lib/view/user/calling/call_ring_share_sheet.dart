import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/smart_ring_models.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/view/user/calling/call_ring_tiles.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';
import 'package:rwfit_ble/rwfit_ble.dart';

/// 患者端：通话中「分享戒指数据给医生」的确认弹层，和医生端面板同一套紧凑网格，
/// 列出即将分享的全部读数；点某一格可看参考范围；确认返回 true。
Future<bool?> showCallRingShareSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _CallRingShareSheet(),
  );
}

class _CallRingShareSheet extends StatefulWidget {
  const _CallRingShareSheet();

  @override
  State<_CallRingShareSheet> createState() => _CallRingShareSheetState();
}

class _CallRingShareSheetState extends State<_CallRingShareSheet> {
  RingShareTile? _selected;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ring = SmartRingService.instance;
    final snap = ring.snapshot;
    final vitals = _vitalTiles(context, snap);
    final activity = _activityTiles(context, snap);
    final hasData = vitals.isNotEmpty || activity.isNotEmpty;
    final lastSync = snap.lastSyncAt;
    final subtitle = [
      ring.displayName,
      if (ring.battery != null) '${ring.battery}%',
      if (lastSync != null) s.smartRingLastSync(SmartRingFormat.dateTime(context, lastSync)),
    ].join(' · ');

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ringSheetHandle(),
          const SizedBox(height: 12),
          ringSheetHeader(
            icon: Icons.medical_services_outlined,
            title: s.smartRingShareToDoctor,
            subtitle: subtitle,
          ),
          const SizedBox(height: 6),
          Text(s.smartRingShareToDoctorDesc, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11.5)),
          const SizedBox(height: 10),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                if (vitals.isNotEmpty) ...[
                  ringSectionTitle(s.smartRingVitals),
                  const SizedBox(height: 6),
                  ringTileGrid(vitals, selectedKey: _selected?.key, onTap: _toggle),
                ],
                if (activity.isNotEmpty) ...[
                  SizedBox(height: vitals.isEmpty ? 0 : 10),
                  ringSectionTitle(s.smartRingSleepActivity),
                  const SizedBox(height: 6),
                  ringTileGrid(activity, selectedKey: _selected?.key, onTap: _toggle),
                ],
                if (!hasData)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(s.smartRingNoData, textAlign: TextAlign.center,
                        style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5)),
                  ),
                if (_selected != null) ...[
                  const SizedBox(height: 8),
                  ringRangeBar(context, _selected!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(s.smartRingDisclaimer, textAlign: TextAlign.center,
              style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 10.5)),
          const SizedBox(height: 10),
          ringSheetButton(s.smartRingShareToDoctor, onPressed: hasData ? () => Navigator.pop(context, true) : null),
          const SizedBox(height: 8),
          ringSheetButton(s.cancel, onPressed: () => Navigator.pop(context, false), filled: false),
        ],
      ),
    );
  }

  void _toggle(RingShareTile t) => setState(() => _selected = _selected?.key == t.key ? null : t);

  List<RingShareTile> _vitalTiles(BuildContext context, SmartRingSnapshot snap) {
    final s = S.of(context);
    final tiles = <RingShareTile>[];

    void add(String key, RealtimeMetric metric, RingMetric? m, String unit, String range, IconData icon, Color color,
        {int decimals = 0}) {
      if (m == null) return;
      tiles.add(RingShareTile(
        key: key,
        label: SmartRingFormat.metricLabel(context, metric),
        value: SmartRingFormat.metric(m, decimals: decimals),
        unit: unit,
        caption: SmartRingFormat.metricTime(context, m),
        range: range,
        icon: icon,
        color: color,
      ));
    }

    add('heart_rate', RealtimeMetric.hr, snap.heartRate, 'bpm', s.smartRingHeartRateRange, Icons.favorite, AppColors.ke63030);
    add('blood_oxygen', RealtimeMetric.bloodOxy, snap.bloodOxygen, '%', s.smartRingBloodOxygenRange, Icons.water_drop,
        AppColors.k30bee6);
    add('temperature', RealtimeMetric.temperature, snap.temperature, '°C', s.smartRingTemperatureRange, Icons.thermostat,
        AppColors.ke68c30, decimals: 1);
    add('hrv', RealtimeMetric.hrv, snap.hrv, 'ms', s.smartRingHrvRange, Icons.monitor_heart, AppColors.k5251f7);
    add('stress', RealtimeMetric.pressure, snap.pressure, '', s.smartRingStressRange, Icons.psychology, AppColors.ke68c30);
    final bp = snap.bloodPressure;
    if (bp != null) {
      tiles.add(RingShareTile(
        key: 'blood_pressure',
        label: s.smartRingBloodPressure,
        value: bp.text,
        unit: 'mmHg',
        caption: SmartRingFormat.dateTime(context, bp.time),
        range: s.smartRingBloodPressureRange,
        icon: Icons.speed,
        color: AppColors.k0cbcc5,
      ));
    }
    add('blood_sugar', RealtimeMetric.bloodSugar, snap.bloodSugar, 'mmol/L', s.smartRingBloodSugarRange, Icons.bloodtype,
        AppColors.ke63030, decimals: 1);
    return tiles;
  }

  List<RingShareTile> _activityTiles(BuildContext context, SmartRingSnapshot snap) {
    final s = S.of(context);
    final tiles = <RingShareTile>[];

    final sleep = snap.sleep;
    if (sleep != null) {
      tiles.add(RingShareTile(
        key: 'sleep',
        label: s.smartRingSleep,
        value: SmartRingFormat.hoursMinutes(sleep.totalMinutes),
        unit: '',
        caption: sleep.hasStages
            ? '${s.smartRingDeepSleep} ${SmartRingFormat.hm(sleep.deepMinutes)} · ${s.smartRingRem} ${SmartRingFormat.hm(sleep.remMinutes)}'
            : s.smartRingLastNight,
        range: s.smartRingSleepRange,
        detail: sleep.hasStages
            ? '${s.smartRingDeepSleep} ${SmartRingFormat.hm(sleep.deepMinutes)} · ${s.smartRingLightSleep} ${SmartRingFormat.hm(sleep.lightMinutes)}'
                ' · ${s.smartRingRem} ${SmartRingFormat.hm(sleep.remMinutes)} · ${s.smartRingAwake} ${SmartRingFormat.hm(sleep.awakeMinutes)}'
            : null,
        icon: Icons.bedtime,
        color: AppColors.k5251f7,
      ));
    }
    final steps = snap.steps;
    if (steps != null) {
      tiles.add(RingShareTile(
        key: 'steps',
        label: s.smartRingSteps,
        value: SmartRingFormat.thousands(steps.steps),
        unit: '',
        caption: DateFormat.MMMd().format(steps.date),
        range: s.smartRingStepsRange,
        icon: Icons.directions_walk,
        color: AppColors.k25d000,
      ));
    }
    return tiles;
  }
}
