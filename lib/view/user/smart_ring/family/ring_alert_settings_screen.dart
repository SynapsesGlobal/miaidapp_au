import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/ring_alert_service.dart';
import 'package:miaid/services/ring_family_service.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alert_widgets.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';

/// 「家人提醒设置」：总开关 + 各指标阈值。每次改动立即保存。
///
/// 戴戒指的人自己打开时不传 [linkId]；家人从长辈面板打开时传 [linkId] 和 [ownerName]，
/// 改的是同一份设置（双方都能改，后改的覆盖先改的，页面上显示最后由谁修改）。
class RingAlertSettingsScreen extends StatefulWidget {
  const RingAlertSettingsScreen({Key? key, this.linkId, this.ownerName}) : super(key: key);

  final int? linkId;
  final String? ownerName;

  @override
  State<RingAlertSettingsScreen> createState() => _RingAlertSettingsScreenState();
}

class _RingAlertSettingsScreenState extends State<RingAlertSettingsScreen> {
  late final RingAlertService _service = RingAlertService(RingFamilyService(getIt<ApiProvider>()));

  RingAlertSettings? _settings;
  bool _failed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final settings = await _service.fetchSettings(linkId: widget.linkId);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _failed = false;
      });
    } on RingFamilyException {
      if (mounted) setState(() => _failed = _settings == null);
    }
  }

  Future<void> _save(Map<String, dynamic> changes) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final settings = await _service.updateSettings(changes, linkId: widget.linkId);
      if (mounted) setState(() => _settings = settings);
    } on RingFamilyException {
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(S.of(context).ringAlertSaveFailed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = _settings;
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, widget.ownerName != null ? s.ringAlertSettingsFor(widget.ownerName!) : s.ringAlertSettings),
      body: settings == null
          ? (_failed
              ? ringAlertFailed(context, () => unawaited(_load()))
              : Center(child: CircularProgressIndicator(color: AppColors.k0cbcc5)))
          : Stack(children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heroCard(context, settings),
                    if (settings.updatedAt != null && settings.updatedBy != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.history, color: AppColors.kb1b1b1, size: 13),
                        const SizedBox(width: 4),
                        Expanded(child: Text(
                          s.ringAlertUpdatedBy(settings.updatedBy!, SmartRingFormat.dateTime(context, settings.updatedAt!)),
                          style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11.5),
                        )),
                      ]),
                    ],
                    const SizedBox(height: 20),
                    AnimatedOpacity(
                      opacity: settings.enabled ? 1 : 0.45,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !settings.enabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            familySectionTitle(s.familyAlertThresholds, subtitle: s.familyAlertThresholdsDesc),
                            _thresholdsCard(context, settings),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(s.smartRingDisclaimer, textAlign: TextAlign.center,
                        style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11)),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              if (_saving)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 2, color: AppColors.k0cbcc5, backgroundColor: Colors.transparent),
                ),
            ]),
    );
  }

  Widget _heroCard(BuildContext context, RingAlertSettings settings) {
    final s = S.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [AppColors.k0cbcc5, AppColors.k003f51.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: AppColors.k0cbcc5.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.family_restroom, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.familyAlertEnable, style: GoogleFonts.rubik(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(widget.linkId == null ? s.ringAlertSettingsDesc : s.ringAlertSettingsDescFamily,
                style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.82), fontSize: 12, height: 1.35)),
          ],
        )),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: settings.enabled,
          activeColor: Colors.white,
          activeTrackColor: Colors.white.withOpacity(0.45),
          onChanged: (v) => unawaited(_save({'enabled': v})),
        ),
      ]),
    );
  }

  // ---------------- 阈值 ----------------

  Widget _thresholdsCard(BuildContext context, RingAlertSettings settings) {
    final types = RingAlertSettings.types.where(settings.thresholds.containsKey).toList();
    return familyCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(children: [
        for (var i = 0; i < types.length; i++) ...[
          _thresholdRow(context, types[i], settings.thresholds[types[i]]!),
          if (i < types.length - 1) Divider(height: 1, color: AppColors.kf4f4f4),
        ],
      ]),
    );
  }

  Widget _thresholdRow(BuildContext context, String type, RingAlertThreshold t) {
    final s = S.of(context);
    final spec = _ThresholdSpec.of(type);
    final parts = <String>[
      if (t.low != null) '${s.familyAlertLow} ${spec.fmt(t.low!)}',
      if (t.high != null) '${s.familyAlertHigh} ${spec.fmt(t.high!)}',
    ];
    return InkWell(
      onTap: () => unawaited(_editThreshold(context, type, t)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          familyIconTile(ringAlertMetricIcon(type), ringAlertMetricColor(type), size: 38),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ringAlertMetricLabel(context, type),
                  style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text('${parts.join(' · ')} ${spec.unit}', style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
            ],
          )),
          Icon(Icons.chevron_right, color: AppColors.kb1b1b1, size: 20),
        ]),
      ),
    );
  }

  Future<void> _editThreshold(BuildContext context, String type, RingAlertThreshold initial) async {
    final s = S.of(context);
    final spec = _ThresholdSpec.of(type);
    final color = ringAlertMetricColor(type);
    final fields = <_Field>[
      if (initial.low != null) _Field('low', s.familyAlertLow, initial.low!),
      if (initial.high != null) _Field('high', s.familyAlertHigh, initial.high!),
      if (initial.high2 != null) _Field('high2', s.ringAlertDiastolicHigh, initial.high2!, max: 140),
      if (initial.criticalLow != null) _Field('critical_low', s.ringAlertCriticalLow, initial.criticalLow!),
      if (initial.criticalHigh != null) _Field('critical_high', s.ringAlertCriticalHigh, initial.criticalHigh!),
    ];
    var consecutive = initial.consecutive;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(context).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.kb1b1b1.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 18),
            Row(children: [
              familyIconTile(ringAlertMetricIcon(type), color, size: 44),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ringAlertMetricLabel(context, type),
                    style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(s.familyAlertThresholdsDesc, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5)),
              ])),
              TextButton(
                onPressed: () => Navigator.pop(context, <String, dynamic>{'_reset': true}),
                child: Text(s.ringAlertResetDefault, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 12.5)),
              ),
            ]),
            const SizedBox(height: 10),
            Flexible(child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
              for (final f in fields)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    SizedBox(width: 92, child: Text(f.label, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 12.5))),
                    Expanded(child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: f.key.startsWith('critical') ? AppColors.ke63030 : color,
                        inactiveTrackColor: color.withOpacity(0.15),
                        thumbColor: f.key.startsWith('critical') ? AppColors.ke63030 : color,
                        overlayColor: color.withOpacity(0.15),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: f.value.clamp(spec.min, f.max ?? spec.max),
                        min: spec.min,
                        max: f.max ?? spec.max,
                        divisions: spec.divisions(f.max ?? spec.max),
                        onChanged: (v) => setSheet(() => f.value = v),
                      ),
                    )),
                    SizedBox(width: 56, child: Text('${spec.fmt(f.value)} ${spec.unit}', textAlign: TextAlign.right,
                        style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 13, fontWeight: FontWeight.w600))),
                  ]),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: Text(s.familyAlertConsecutive(consecutive),
                      style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 13))),
                  _stepButton(Icons.remove, consecutive > 1 ? () => setSheet(() => consecutive--) : null),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('$consecutive', style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  _stepButton(Icons.add, consecutive < 5 ? () => setSheet(() => consecutive++) : null),
                ]),
              ),
            ])),
            const SizedBox(height: 18),
            familyFilledButton(s.confirm, onPressed: () {
              Navigator.pop(context, <String, dynamic>{
                for (final f in fields) f.key: spec.decimals == 0 ? f.value.roundToDouble() : double.parse(f.value.toStringAsFixed(spec.decimals)),
                'consecutive': consecutive,
              });
            }),
            const SizedBox(height: 10),
            _greyButton(s.cancel, () => Navigator.pop(context)),
          ]),
        );
      }),
    );
    if (result == null || !mounted) return;
    if (result['_reset'] == true) {
      await _save({'thresholds': {type: {'low': null, 'high': null, 'high2': null, 'critical_low': null, 'critical_high': null, 'consecutive': null}}});
    } else {
      await _save({'thresholds': {type: result}});
    }
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, size: 16, color: onTap == null ? AppColors.kb1b1b1 : AppColors.k0cbcc5),
      ),
    );
  }

  Widget _greyButton(String label, VoidCallback onPressed) {
    return MaterialButton(
      onPressed: onPressed,
      elevation: 0,
      height: 46,
      minWidth: double.infinity,
      color: AppColors.kf4f4f4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
      child: Text(label, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

class _Field {
  _Field(this.key, this.label, this.value, {this.max});

  final String key;
  final String label;
  double value;
  final double? max;
}

/// 各指标滑杆范围与格式。
class _ThresholdSpec {
  const _ThresholdSpec(this.min, this.max, this.unit, this.decimals);

  final double min;
  final double max;
  final String unit;
  final int decimals;

  static _ThresholdSpec of(String type) {
    switch (type) {
      case 'heart_rate':
        return const _ThresholdSpec(30, 200, 'bpm', 0);
      case 'blood_oxygen':
        return const _ThresholdSpec(70, 100, '%', 0);
      case 'temperature':
        return const _ThresholdSpec(34, 42, '°C', 1);
      case 'blood_pressure':
        return const _ThresholdSpec(60, 220, 'mmHg', 0);
      default:
        return const _ThresholdSpec(2, 25, 'mmol/L', 1);
    }
  }

  String fmt(double v) => decimals == 0 ? v.round().toString() : v.toStringAsFixed(decimals);

  int divisions(double max) => ((max - min) * (decimals == 0 ? 1 : 10)).round();
}
