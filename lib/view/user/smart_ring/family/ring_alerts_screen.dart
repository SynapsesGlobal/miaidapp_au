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
import 'package:miaid/view/user/smart_ring/family/ring_alert_widgets.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';

/// 提醒记录：家人端看某位长辈（传 [linkId]）或我关注的所有人；戴戒指的人自己看自己的（[mine]，只看不标已读）。
///
/// 按日期分组的列表，每天一张白卡、每条提醒一行，
/// 滚到底自动加载更多；打开即把加载到的未读标为已读。没有详情页，每条就是一行。[initialAlertId] 仅保留给推送跳转，不做定位。
class RingAlertsScreen extends StatefulWidget {
  const RingAlertsScreen({Key? key, this.linkId, this.title, this.initialAlertId, this.mine = false}) : super(key: key);

  final int? linkId;
  final bool mine;
  final String? title;
  final int? initialAlertId;

  @override
  State<RingAlertsScreen> createState() => _RingAlertsScreenState();
}

class _RingAlertsScreenState extends State<RingAlertsScreen> {
  static const _pageSize = 50;

  late final RingAlertService _service = RingAlertService(RingFamilyService(getIt<ApiProvider>()));
  final _scroll = ScrollController();

  List<RingAlertItem>? _alerts;
  bool _failed = false;
  bool _loadingMore = false;
  bool _hasMore = true;

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
      final alerts = widget.mine
          ? await _service.fetchMine(limit: _pageSize)
          : await _service.fetchAlerts(linkId: widget.linkId, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _failed = false;
        _hasMore = alerts.length >= _pageSize;
      });
      if (!widget.mine) unawaited(_markSeen(alerts));
    } on RingFamilyException {
      if (mounted) setState(() => _failed = _alerts == null);
    }
  }

  Future<void> _loadMore() async {
    final current = _alerts;
    if (_loadingMore || !_hasMore || current == null || current.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final more = widget.mine
          ? await _service.fetchMine(beforeId: current.last.id, limit: _pageSize)
          : await _service.fetchAlerts(linkId: widget.linkId, beforeId: current.last.id, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _alerts = [...current, ...more];
        _hasMore = more.length >= _pageSize;
      });
      if (!widget.mine) unawaited(_markSeen(more));
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

  // ---------------- 页面 ----------------

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, widget.title ?? (widget.mine ? s.ringAlertMyRecords : s.ringAlertRecords)),
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

    final groups = _groupByDay(alerts);

    return RefreshIndicator(
      color: AppColors.k0cbcc5,
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (alerts.isEmpty) _emptyCard(context, s.familyAlertNoAlerts),
          for (final g in groups) ...[
            _dayHeader(context, g.day),
            familyCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(children: [
                for (var i = 0; i < g.items.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 52, color: AppColors.kf4f4f4),
                  _row(context, g.items[i]),
                ],
              ]),
            ),
            const SizedBox(height: 16),
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

  Widget _dayHeader(BuildContext context, DateTime day) {
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
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(label, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }

  /// 一行：指标图标、「妈妈 · 心率偏低」+ 时间、右侧读数；未读加粗并带小红点。
  Widget _row(BuildContext context, RingAlertItem a) {
    final accent = ringAlertMetricColor(a.type);
    final unread = a.seen == false;
    final name = a.ownerAlias;
    final title = widget.linkId == null && name != null && name.isNotEmpty
        ? '$name · ${ringAlertTitle(context, a)}'
        : ringAlertTitle(context, a);
    final time = a.measuredAt ?? a.createdAt;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: accent.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
              child: Icon(ringAlertMetricIcon(a.type), color: accent, size: 19),
            ),
            if (unread)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.ke63030, border: Border.all(color: Colors.white, width: 1.5)),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: unread ? FontWeight.w600 : FontWeight.w500)),
              if (time != null) ...[
                const SizedBox(height: 2),
                Text(DateFormat.Hm().format(time), style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
              ],
            ],
          )),
          const SizedBox(width: 10),
          if (a.valueText.isNotEmpty)
            Text.rich(TextSpan(children: [
              TextSpan(text: a.valueText, style: GoogleFonts.rubik(color: accent, fontSize: 20, fontWeight: FontWeight.w700)),
              TextSpan(text: ' ${a.unit}', style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11)),
            ])),
        ]),
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
