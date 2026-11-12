import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/ring_alert_center.dart';
import 'package:miaid/services/ring_alert_service.dart';
import 'package:miaid/services/ring_family_service.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alert_detail_screen.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alert_widgets.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';

/// 家人端提醒记录：某位长辈（传 [linkId]）或我关注的所有人。
///
/// 顶部概览卡（待处理数 / 今日数 / 高危数），下面「全部 / 待处理 / 高危」筛选，按日期分组列表，
/// 滚到底自动加载更多；打开即把加载到的未读标为已读。[initialAlertId]：从推送点进来时直接打开这一条。
class RingAlertsScreen extends StatefulWidget {
  const RingAlertsScreen({Key? key, this.linkId, this.title, this.initialAlertId}) : super(key: key);

  final int? linkId;
  final String? title;
  final int? initialAlertId;

  @override
  State<RingAlertsScreen> createState() => _RingAlertsScreenState();
}

enum _Filter { all, active, critical }

class _RingAlertsScreenState extends State<RingAlertsScreen> {
  static const _pageSize = 50;

  late final RingAlertService _service = RingAlertService(RingFamilyService(getIt<ApiProvider>()));
  final _scroll = ScrollController();

  List<RingAlertItem>? _alerts;
  bool _failed = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _openedInitial = false;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) unawaited(_loadMore());
  }

  Future<void> _load() async {
    try {
      final alerts = await _service.fetchAlerts(linkId: widget.linkId, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _failed = false;
        _hasMore = alerts.length >= _pageSize;
      });
      unawaited(_markSeen(alerts));
      _openInitial(alerts);
    } on RingFamilyException {
      if (mounted) setState(() => _failed = _alerts == null);
    }
  }

  Future<void> _loadMore() async {
    final current = _alerts;
    if (_loadingMore || !_hasMore || current == null || current.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _service.fetchAlerts(linkId: widget.linkId, beforeId: current.last.id, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _alerts = [...current, ...more];
        _hasMore = more.length >= _pageSize;
      });
      unawaited(_markSeen(more));
    } on RingFamilyException {
      // 保留已有内容
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markSeen(List<RingAlertItem> alerts) async {
    final unseen = alerts.where((a) => a.seen == false).map((a) => a.id).toList();
    if (unseen.isEmpty) return;
    await RingAlertCenter.instance.markSeen(ids: unseen);
    if (!mounted) return;
    setState(() {
      _alerts = _alerts?.map((a) => unseen.contains(a.id) ? a.copyWith(seen: true) : a).toList();
    });
  }

  void _openInitial(List<RingAlertItem> alerts) {
    final id = widget.initialAlertId;
    if (_openedInitial || id == null) return;
    _openedInitial = true;
    for (final a in alerts) {
      if (a.id == id) {
        WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_openDetail(a)));
        return;
      }
    }
  }

  Future<void> _openDetail(RingAlertItem a) async {
    final updated = await Navigator.push<RingAlertItem>(context, MaterialPageRoute<RingAlertItem>(
      builder: (context) => RingAlertDetailScreen(alert: a),
    ));
    if (!mounted) return;
    if (updated != null) {
      setState(() => _alerts = _alerts?.map((x) => x.id == updated.id ? updated : x).toList());
    }
  }

  // ---------------- 页面 ----------------

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, widget.title ?? s.ringAlertRecords),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final s = S.of(context);
    final alerts = _alerts;
    if (alerts == null) {
      if (_failed) return ringAlertFailed(context, () => unawaited(_load()));
      return Center(child: CircularProgressIndicator(color: AppColors.k0cbcc5));
    }

    final visible = alerts.where((a) {
      switch (_filter) {
        case _Filter.active:
          return a.active;
        case _Filter.critical:
          return a.isCritical;
        case _Filter.all:
          return true;
      }
    }).toList();
    final groups = _groupByDay(visible);

    return RefreshIndicator(
      color: AppColors.k0cbcc5,
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _summaryCard(context, alerts),
          const SizedBox(height: 14),
          _filterBar(context, alerts),
          const SizedBox(height: 14),
          if (visible.isEmpty) _emptyCard(context, alerts.isEmpty ? s.familyAlertNoAlerts : s.ringAlertNoMatch),
          for (final g in groups) ...[
            _dayHeader(context, g.day, g.items.length),
            for (final a in g.items) ...[_alertCard(context, a), const SizedBox(height: 10)],
            const SizedBox(height: 6),
          ],
          if (_hasMore && alerts.isNotEmpty)
            Center(child: _loadingMore
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.k0cbcc5)),
                  )
                : TextButton(
                    onPressed: () => unawaited(_loadMore()),
                    child: Text(s.ringAlertLoadMore, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 13)),
                  )),
          const SizedBox(height: 8),
          Text(s.smartRingDisclaimer, textAlign: TextAlign.center,
              style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// 顶部概览：有待处理时红 / 橙渐变显示数量和人，否则青色「当前没有待处理的提醒」。
  Widget _summaryCard(BuildContext context, List<RingAlertItem> alerts) {
    final s = S.of(context);
    final active = alerts.where((a) => a.active).toList();
    final hasCritical = active.any((a) => a.isCritical);
    final now = DateTime.now();
    final todayCount = alerts.where((a) => _sameDay(a.measuredAt ?? a.createdAt, now)).length;
    final criticalCount = alerts.where((a) => a.isCritical).length;
    final color = active.isEmpty ? AppColors.k0cbcc5 : (hasCritical ? AppColors.ke63030 : AppColors.ke68c30);
    final colorEnd = active.isEmpty ? AppColors.k003f51.withOpacity(0.88) : color.withOpacity(0.72);
    final names = active.map((a) => a.ownerAlias).whereType<String>().where((n) => n.isNotEmpty).toSet().join('、');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [color, colorEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
              child: Icon(active.isEmpty ? Icons.verified_outlined : Icons.notifications_active, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active.isEmpty ? s.ringAlertAllClear : s.ringAlertActiveCount(active.length),
                    style: GoogleFonts.rubik(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                if (names.isNotEmpty && widget.linkId == null) ...[
                  const SizedBox(height: 2),
                  Text(names, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.85), fontSize: 12.5)),
                ],
              ],
            )),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _statPill(s.ringAlertTodayCount(todayCount)),
            const SizedBox(width: 8),
            _statPill('${s.familyAlertLevelHigh} $criticalCount'),
          ]),
        ],
      ),
    );
  }

  Widget _statPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: GoogleFonts.rubik(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }

  /// 分段筛选：全部 / 待处理 / 高危，带数量。
  Widget _filterBar(BuildContext context, List<RingAlertItem> alerts) {
    final s = S.of(context);
    final items = <(_Filter, String, int)>[
      (_Filter.all, s.ringAlertFilterAll, alerts.length),
      (_Filter.active, s.ringAlertFilterActive, alerts.where((a) => a.active).length),
      (_Filter.critical, s.ringAlertFilterCritical, alerts.where((a) => a.isCritical).length),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.k0cbcc5.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final item in items)
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _filter = item.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _filter == item.$1 ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                boxShadow: _filter == item.$1
                    ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Text('${item.$2} ${item.$3}', style: GoogleFonts.rubik(
                color: _filter == item.$1 ? AppColors.k010101 : AppColors.k8f8e94,
                fontSize: 13,
                fontWeight: _filter == item.$1 ? FontWeight.w600 : FontWeight.w400,
              )),
            ),
          )),
      ]),
    );
  }

  Widget _dayHeader(BuildContext context, DateTime day, int count) {
    final s = S.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String label;
    if (day == today) {
      label = s.smartRingToday;
    } else if (day == today.subtract(const Duration(days: 1))) {
      label = s.ringAlertYesterday;
    } else {
      label = DateFormat.MMMd().format(day);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
      child: Row(children: [
        Text(label, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Text('$count', style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 12)),
      ]),
    );
  }

  /// 一条提醒：左侧级别色条、图标、标题、时间与状态标签、右侧数值。
  Widget _alertCard(BuildContext context, RingAlertItem a) {
    final s = S.of(context);
    final color = ringAlertLevelColor(a);
    final unread = a.seen == false;
    final name = a.ownerAlias;
    final title = widget.linkId == null && name != null && name.isNotEmpty
        ? '$name · ${ringAlertTitle(context, a)}'
        : ringAlertTitle(context, a);
    final time = a.measuredAt ?? a.createdAt;
    final tags = <Widget>[
      if (a.isCritical && !a.isRecovered) familyChip(s.familyAlertLevelHigh, AppColors.ke63030),
      if (a.isRecovered) familyChip(s.familyAlertLevelRecovered, AppColors.k25d000),
      if (a.isHandled) familyChip(s.familyAlertHandled, AppColors.k0cbcc5),
    ];

    return InkWell(
      onTap: () => unawaited(_openDetail(a)),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Row(children: [
            Container(width: 5, height: 78, color: a.active ? color : color.withOpacity(0.35)),
            const SizedBox(width: 11),
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
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: unread ? FontWeight.w700 : FontWeight.w600)),
                  const SizedBox(height: 5),
                  Row(children: [
                    if (time != null)
                      Text(DateFormat.Hm().format(time), style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
                    for (final t in tags) ...[const SizedBox(width: 6), t],
                  ]),
                ],
              ),
            )),
            const SizedBox(width: 8),
            if (a.valueText.isNotEmpty)
              Text.rich(TextSpan(children: [
                TextSpan(text: a.valueText, style: GoogleFonts.rubik(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
                TextSpan(text: ' ${a.unit}', style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11)),
              ])),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: AppColors.kb1b1b1, size: 20),
            const SizedBox(width: 6),
          ]),
        ),
      ),
    );
  }

  Widget _emptyCard(BuildContext context, String text) {
    return familyCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: AppColors.k0cbcc5.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.notifications_none, color: AppColors.k0cbcc5, size: 28),
        ),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13)),
      ]),
    );
  }

  // ---------------- 工具 ----------------

  static bool _sameDay(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  static List<_DayGroup> _groupByDay(List<RingAlertItem> alerts) {
    final groups = <_DayGroup>[];
    for (final a in alerts) {
      final t = a.measuredAt ?? a.createdAt ?? DateTime.now();
      final day = DateTime(t.year, t.month, t.day);
      if (groups.isNotEmpty && groups.last.day == day) {
        groups.last.items.add(a);
      } else {
        groups.add(_DayGroup(day, [a]));
      }
    }
    return groups;
  }
}

class _DayGroup {
  _DayGroup(this.day, this.items);

  final DateTime day;
  final List<RingAlertItem> items;
}
