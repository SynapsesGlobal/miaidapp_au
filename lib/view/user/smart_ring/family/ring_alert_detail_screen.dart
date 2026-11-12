import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/ring_alert_center.dart';
import 'package:miaid/services/ring_alert_service.dart';
import 'package:miaid/services/ring_family_service.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alert_widgets.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';
import 'package:miaid/view/user/smart_ring/family/ring_trend_chart.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';
import 'package:url_launcher/url_launcher.dart';

/// 家人端提醒详情：级别色头卡（数值、参考范围、时间）+ 该指标最近 24 小时走势（叠加阈值带）
/// + 长辈信息 + 拨打电话 / 标记已处理。返回时把更新后的提醒传回列表。
class RingAlertDetailScreen extends StatefulWidget {
  const RingAlertDetailScreen({Key? key, required this.alert}) : super(key: key);

  final RingAlertItem alert;

  @override
  State<RingAlertDetailScreen> createState() => _RingAlertDetailScreenState();
}

class _RingAlertDetailScreenState extends State<RingAlertDetailScreen> {
  late final RingFamilyService _family = RingFamilyService(getIt<ApiProvider>());
  late final RingAlertService _service = RingAlertService(_family);

  late RingAlertItem _alert = widget.alert;
  RingTrend? _trend;
  bool _trendFailed = false;
  RingFamilyOwner? _owner;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTrend());
    unawaited(_loadOwner());
    if (_alert.seen == false) {
      unawaited(RingAlertCenter.instance.markSeen(ids: [_alert.id]));
      _alert = _alert.copyWith(seen: true);
    }
  }

  Future<void> _loadTrend() async {
    final linkId = _alert.linkId;
    if (linkId == null) return;
    try {
      final trend = await _family.fetchTrend(type: _alert.type, range: '24h', linkId: linkId);
      if (mounted) setState(() => _trend = trend);
    } on RingFamilyException {
      if (mounted) setState(() => _trendFailed = true);
    }
  }

  /// 长辈资料（电话等）从家人列表里取。
  Future<void> _loadOwner() async {
    try {
      final summary = await _family.fetch();
      if (!mounted) return;
      for (final o in summary.owners) {
        if (o.linkId == _alert.linkId) {
          setState(() => _owner = o);
          return;
        }
      }
    } on RingFamilyException {
      // 没有资料时只是不显示电话
    }
  }

  Future<void> _call() async {
    final phone = _owner?.phone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    try {
      if (!await launchUrl(uri)) throw Exception('cannot launch');
    } catch (_) {
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(S.of(context).ringFamilyActionFailed));
    }
  }

  Future<void> _markHandled() async {
    if (_handling) return;
    setState(() => _handling = true);
    try {
      final updated = await _service.markHandled(_alert.id);
      if (!mounted) return;
      setState(() => _alert = updated.copyWith(seen: true));
      unawaited(RingAlertCenter.instance.refresh());
    } on RingFamilyException {
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(S.of(context).ringFamilyActionFailed));
    } finally {
      if (mounted) setState(() => _handling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final a = _alert;
    final phone = _owner?.phone;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _alert);
      },
      child: Scaffold(
        backgroundColor: AppColors.kf4f4f4,
        appBar: familyAlertAppBar(context, s.familyAlertDetail),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heroCard(context, a),
              const SizedBox(height: 16),
              _chartCard(context, a),
              if (_owner != null) ...[
                const SizedBox(height: 16),
                _ownerCard(context, _owner!),
              ],
              const SizedBox(height: 20),
              if (phone != null && phone.isNotEmpty)
                familyFilledButton(s.familyAlertPhone, icon: Icons.call, onPressed: () => unawaited(_call())),
              const SizedBox(height: 10),
              if (!a.isHandled)
                familyOutlinedButton(s.familyAlertMarkHandled, icon: Icons.check_circle_outline,
                    onPressed: _handling ? null : () => unawaited(_markHandled()))
              else
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle, color: AppColors.k25d000, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    a.handledBy != null && a.handledBy!.isNotEmpty ? s.ringAlertHandledBy(a.handledBy!) : s.familyAlertHandled,
                    style: GoogleFonts.rubik(color: AppColors.k25d000, fontSize: 13.5, fontWeight: FontWeight.w500),
                  ),
                ]),
              const SizedBox(height: 16),
              Text(s.smartRingDisclaimer, textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, RingAlertItem a) {
    final s = S.of(context);
    final color = ringAlertLevelColor(a);
    final name = _owner?.displayName ?? a.ownerAlias;
    final title = name != null && name.isNotEmpty ? '$name · ${ringAlertTitle(context, a)}' : ringAlertTitle(context, a);
    final time = a.measuredAt ?? a.createdAt;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [color.withOpacity(0.95), color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(10)),
              child: Text(ringAlertLevelText(context, a),
                  style: GoogleFonts.rubik(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            Icon(ringAlertMetricIcon(a.type), color: Colors.white.withOpacity(0.9), size: 22),
          ]),
          const SizedBox(height: 14),
          Text(title, style: GoogleFonts.rubik(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          if (a.valueText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text.rich(TextSpan(children: [
              TextSpan(text: a.valueText, style: GoogleFonts.rubik(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w700, height: 1)),
              TextSpan(text: '  ${a.unit}', style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.85), fontSize: 16)),
            ])),
          ],
          if (time != null) ...[
            const SizedBox(height: 10),
            Text(s.familyAlertMeasuredAt(SmartRingFormat.dateTime(context, time)),
                style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.8), fontSize: 12)),
          ],
          if (a.isRecovered && a.recoveredAt != null)
            Text('${s.familyAlertLevelRecovered} · ${SmartRingFormat.dateTime(context, a.recoveredAt!)}',
                style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _chartCard(BuildContext context, RingAlertItem a) {
    final s = S.of(context);
    final trend = _trend;
    final color = ringAlertMetricColor(a.type);
    final band = _band(a);
    return familyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(s.familyAlertLast24h, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (band != null) ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.k25d000.withOpacity(0.18), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text(s.smartRingReferenceRange, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11)),
            ],
          ]),
          const SizedBox(height: 10),
          if (trend == null)
            SizedBox(
              height: 160,
              child: Center(child: _trendFailed
                  ? Text(s.ringFamilyLoadFailed, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5))
                  : CircularProgressIndicator(color: AppColors.k0cbcc5)),
            )
          else if (trend.isEmpty)
            SizedBox(
              height: 120,
              child: Center(child: Text(s.ringTrendEmpty, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5))),
            )
          else
            RingTrendChart(
              points: trend.points,
              from: trend.from,
              to: trend.to,
              color: color,
              color2: a.type == 'blood_pressure' ? AppColors.k5251f7 : null,
              unit: a.unit,
              decimals: a.type == 'temperature' || a.type == 'blood_sugar' ? 1 : 0,
              gap: const Duration(hours: 3),
              dayTicks: false,
              height: 200,
              bandLow: band?.$1,
              bandHigh: band?.$2,
            ),
        ],
      ),
    );
  }

  /// 参考范围带：用看板说明里的常用范围（与后端默认阈值一致）。
  (double?, double?)? _band(RingAlertItem a) {
    switch (a.type) {
      case 'heart_rate':
        return (45, 120);
      case 'blood_oxygen':
        return (90, null);
      case 'temperature':
        return (35, 38);
      case 'blood_pressure':
        return (90, 160);
      case 'blood_sugar':
        return (3.9, 11.1);
      default:
        return null;
    }
  }

  Widget _ownerCard(BuildContext context, RingFamilyOwner o) {
    final s = S.of(context);
    final realName = o.alias != null && o.alias!.isNotEmpty && o.name.isNotEmpty ? o.name : null;
    final detail = <String>[
      if (o.snapshotAt != null) s.familyAlertLastReading(SmartRingFormat.dateTime(context, o.snapshotAt!)),
      if (o.battery != null) s.ringFamilyRingBattery(o.battery!),
    ].join(' · ');
    return familyCard(
      child: Row(children: [
        familyAvatar(o.displayName, AppColors.k0cbcc5, size: 44),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(o.displayName, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 15, fontWeight: FontWeight.w600)),
              if (realName != null) ...[
                const SizedBox(width: 8),
                Flexible(child: Text(realName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12))),
              ],
            ]),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11.5)),
            ],
          ],
        )),
        if (o.phone != null && o.phone!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(o.phone!, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ]),
    );
  }
}
