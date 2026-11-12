import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/call_ring_share_service.dart';
import 'package:miaid/services/ring_family_service.dart';
import 'package:miaid/view/user/calling/call_ring_tiles.dart';
import 'package:miaid/view/user/smart_ring/family/ring_trend_screen.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alert_settings_screen.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alert_widgets.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alerts_screen.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';

/// 家人端：查看某位家人最新的戒指面板（只读）。
///
/// 数据是对方手机最近一次上传的快照，页面打开期间每分钟静默刷新一次，也可以下拉刷新。
class RingFamilyDashboardScreen extends StatefulWidget {
  const RingFamilyDashboardScreen({Key? key, required this.service, required this.owner}) : super(key: key);

  final RingFamilyService service;
  final RingFamilyOwner owner;

  @override
  State<RingFamilyDashboardScreen> createState() => _RingFamilyDashboardScreenState();
}

class _RingFamilyDashboardScreenState extends State<RingFamilyDashboardScreen> {
  static const _refreshInterval = Duration(minutes: 1);

  late RingFamilyOwner _owner = widget.owner;
  CallRingSnapshotRecord? _record;
  bool _loaded = false;
  bool _failed = false;
  Timer? _timer;
  bool _refreshing = false;

  /// 当前点选、在下方显示参考范围的指标。
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(_refreshInterval, (_) => unawaited(_load()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await widget.service.fetchSnapshot(_owner.linkId);
      if (!mounted) return;
      setState(() {
        _owner = result.owner;
        _record = result.record;
        _loaded = true;
        _failed = false;
      });
    } on RingFamilyException {
      if (!mounted) return;
      // 已有数据时刷新失败不打断查看，保留上一次的内容
      setState(() => _failed = !_loaded);
    }
  }

  Future<void> _openAlerts({int? initialAlertId}) async {
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (context) => RingAlertsScreen(linkId: _owner.linkId, title: _owner.displayName, initialAlertId: initialAlertId),
    ));
    if (mounted) unawaited(_load());
  }

  /// 「获取最新数据」：重新拉对方上传的最新快照，并告诉用户有没有更新。
  /// 家人端拿不到对方的戒指，只能取对方手机已经上传的数据。
  Future<void> _refreshLatest() async {
    final s = S.of(context);
    final before = _record?.capturedAt ?? _record?.createdAt ?? _owner.snapshotAt;
    setState(() => _refreshing = true);
    try {
      await _load();
      if (!mounted) return;
      final after = _record?.capturedAt ?? _record?.createdAt ?? _owner.snapshotAt;
      if (after == null) {
        unawaited(HttpExceptionNotifyUser.showInfo(s.ringFamilyNoDataYet));
      } else if (before != null && !after.isAfter(before)) {
        unawaited(HttpExceptionNotifyUser.showInfo(s.ringFamilyNoNewData(SmartRingFormat.dateTime(context, after))));
      } else {
        unawaited(HttpExceptionNotifyUser.showInfo(s.ringFamilyRefreshedAt(SmartRingFormat.dateTime(context, after))));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// 走势页的指标：常规五项 + 对方戒指有数据的血压 / 血糖；正在看参考范围的那项作为默认选中。
  void _openTrend(CallRingSnapshotRecord record) {
    final metrics = <RingTrendMetric>[
      ...RingTrendMetric.core,
      if (record.bloodPressure != null) RingTrendMetric.bloodPressure,
      if (record.metric('blood_sugar') != null) RingTrendMetric.bloodSugar,
    ];
    unawaited(Navigator.push(context, MaterialPageRoute<void>(
      builder: (context) => RingTrendScreen(
        service: widget.service,
        metrics: metrics,
        linkId: _owner.linkId,
        title: _owner.displayName,
        initialType: _selectedKey,
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, _owner.displayName, actions: [
        IconButton(
          tooltip: s.ringAlertRecords,
          icon: Stack(clipBehavior: Clip.none, children: [
            Icon(Icons.notifications_none, color: AppColors.k003f51),
            if (_owner.unreadCount > 0) Positioned(right: -6, top: -4, child: ringUnreadBadge(_owner.unreadCount, size: 15)),
          ]),
          onPressed: () => unawaited(_openAlerts()),
        ),
        IconButton(
          tooltip: s.ringAlertSettings,
          icon: Icon(Icons.tune, color: AppColors.k003f51),
          onPressed: () => unawaited(Navigator.push(context, MaterialPageRoute<void>(
            builder: (context) => RingAlertSettingsScreen(linkId: _owner.linkId, ownerName: _owner.displayName),
          ))),
        ),
      ]),
      body: RefreshIndicator(
        color: AppColors.k0cbcc5,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: _children(context),
        ),
      ),
    );
  }

  List<Widget> _children(BuildContext context) {
    final s = S.of(context);
    if (!_loaded) {
      if (_failed) {
        return [
          const SizedBox(height: 80),
          Icon(Icons.cloud_off, color: AppColors.kb1b1b1, size: 40),
          const SizedBox(height: 12),
          Text(s.ringFamilyLoadFailed, textAlign: TextAlign.center,
              style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13)),
          const SizedBox(height: 16),
          Center(child: SizedBox(width: 160, child: familyOutlinedButton(s.retry, onPressed: () {
            setState(() => _failed = false);
            unawaited(_load());
          }))),
        ];
      }
      return [
        const SizedBox(height: 120),
        Center(child: CircularProgressIndicator(color: AppColors.k0cbcc5)),
      ];
    }

    final record = _record;
    if (record == null) {
      return [
        _header(context, null),
        const SizedBox(height: 16),
        familyCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
          child: Column(children: [
            Icon(Icons.donut_large, color: AppColors.kb1b1b1, size: 36),
            const SizedBox(height: 12),
            Text(s.ringFamilyNoDataYet,
                style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(s.ringFamilyNoDataDesc, textAlign: TextAlign.center,
                style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5, height: 1.4)),
          ]),
        ),
      ];
    }

    final vitals = ringRecordVitalTiles(context, record);
    final activity = ringRecordActivityTiles(context, record);
    RingShareTile? selectedIn(List<RingShareTile> tiles) {
      for (final t in tiles) {
        if (t.key == _selectedKey) return t;
      }
      return null;
    }

    Widget section(String title, List<RingShareTile> tiles) {
      final selected = selectedIn(tiles);
      return familyCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ringSectionTitle(title),
            const SizedBox(height: 8),
            ringTileGrid(tiles, selectedKey: selected?.key,
                onTap: (t) => setState(() => _selectedKey = _selectedKey == t.key ? null : t.key)),
            if (selected != null) ...[
              const SizedBox(height: 8),
              ringRangeBar(context, selected),
            ],
          ],
        ),
      );
    }

    final latest = _owner.latestAlert;
    return [
      _header(context, record),
      const SizedBox(height: 12),
      if (latest != null && latest.active) ...[
        ringAlertStrip(context, latest, ownerName: null, onTap: () => unawaited(_openAlerts(initialAlertId: latest.id))),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(child: familyOutlinedButton(
          _refreshing ? s.ringFamilyRefreshing : s.ringFamilyRefresh,
          icon: Icons.sync,
          onPressed: _refreshing ? null : () => unawaited(_refreshLatest()),
        )),
        const SizedBox(width: 10),
        Expanded(child: familyOutlinedButton(s.ringTrendView, icon: Icons.show_chart, onPressed: () => _openTrend(record))),
      ]),
      const SizedBox(height: 12),
      if (vitals.isNotEmpty) section(s.smartRingVitals, vitals),
      if (vitals.isNotEmpty && activity.isNotEmpty) const SizedBox(height: 12),
      if (activity.isNotEmpty) section(s.smartRingSleepActivity, activity),
      if (vitals.isEmpty && activity.isEmpty)
        familyCard(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(s.smartRingNoData, textAlign: TextAlign.center,
              style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13)),
        ),
      const SizedBox(height: 14),
      Text(s.smartRingDisclaimer, textAlign: TextAlign.center,
          style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11)),
    ];
  }

  /// 渐变头卡：谁、哪只戒指、电量、数据更新时间。
  Widget _header(BuildContext context, CallRingSnapshotRecord? record) {
    final s = S.of(context);
    final updated = record?.capturedAt ?? record?.createdAt ?? _owner.snapshotAt;
    final battery = record?.battery ?? _owner.battery;
    // 起了称呼时把账号姓名放在副标题，方便确认是谁
    final realName = _owner.alias != null && _owner.alias!.isNotEmpty && _owner.name.isNotEmpty ? _owner.name : null;
    final subtitle = <String>[
      if (realName != null) realName,
      if (record != null) record.displayName,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [AppColors.k0cbcc5, AppColors.k003f51.withOpacity(0.88)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: AppColors.k0cbcc5.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
              child: Text(
                _owner.displayName.isEmpty ? '?' : _owner.displayName.characters.first.toUpperCase(),
                style: GoogleFonts.rubik(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_owner.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rubik(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.85), fontSize: 11.5)),
                ],
              ],
            )),
            if (battery != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.battery_std, color: Colors.white, size: 14),
                  const SizedBox(width: 3),
                  Text('$battery%', style: GoogleFonts.rubik(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.schedule, color: Colors.white.withOpacity(0.8), size: 13),
            const SizedBox(width: 5),
            Expanded(child: Text(
              updated == null ? s.ringFamilyNoDataYet : s.ringFamilyUpdatedAt(SmartRingFormat.dateTime(context, updated)),
              style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.85), fontSize: 11.5),
            )),
          ]),
        ],
      ),
    );
  }
}
