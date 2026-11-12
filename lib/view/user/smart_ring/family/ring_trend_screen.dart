import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/ring_family_service.dart';
import 'package:miaid/view/user/smart_ring/family/ring_trend_chart.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';

/// 走势页可选的指标。[type] 是后端的指标名。
class RingTrendMetric {
  const RingTrendMetric._(this.type, this.unit, this.icon, this.decimals);

  final String type;
  final String unit;
  final IconData icon;
  final int decimals;

  static const heartRate = RingTrendMetric._('heart_rate', 'bpm', Icons.favorite, 0);
  static const bloodOxygen = RingTrendMetric._('blood_oxygen', '%', Icons.water_drop, 0);
  static const hrv = RingTrendMetric._('hrv', 'ms', Icons.monitor_heart, 0);
  static const stress = RingTrendMetric._('stress', '', Icons.psychology, 0);
  static const steps = RingTrendMetric._('steps', '', Icons.directions_walk, 0);
  static const bloodPressure = RingTrendMetric._('blood_pressure', 'mmHg', Icons.speed, 0);
  static const bloodSugar = RingTrendMetric._('blood_sugar', 'mmol/L', Icons.bloodtype, 1);

  /// 所有戒指都有的五项。体温不做走势（戒指测的是体表温度，波动大、参考意义有限）。
  static const core = <RingTrendMetric>[heartRate, bloodOxygen, hrv, stress, steps];

  bool get isBloodPressure => type == 'blood_pressure';

  /// 步数是每日累计值：只按天看（柱状图、固定最近 7 天），不分 24 小时 / 7 天。
  bool get isSteps => type == 'steps';

  /// 折线颜色，沿用看板上各指标的颜色；血压的收缩压用红、舒张压用靛蓝（已按色觉障碍可分辨校验）。
  Color get color {
    switch (type) {
      case 'heart_rate':
      case 'blood_pressure':
      case 'blood_sugar':
        return AppColors.ke63030;
      case 'blood_oxygen':
        return AppColors.k30bee6;
      case 'hrv':
        return AppColors.k5251f7;
      case 'steps':
        return AppColors.k25d000;
      default:
        return AppColors.ke68c30;
    }
  }

  Color? get color2 => isBloodPressure ? AppColors.k5251f7 : null;

  String label(BuildContext context) {
    final s = S.of(context);
    switch (type) {
      case 'heart_rate':
        return s.smartRingHeartRate;
      case 'blood_oxygen':
        return s.smartRingBloodOxygen;
      case 'hrv':
        return s.smartRingHrv;
      case 'stress':
        return s.smartRingStress;
      case 'steps':
        return s.smartRingSteps;
      case 'blood_pressure':
        return s.smartRingBloodPressure;
      default:
        return s.smartRingBloodSugar;
    }
  }
}

/// 最近走势：一次只看一项指标的一张大折线图。顶部选指标和 24 小时 / 7 天，
/// 下面是最新值、折线图和最低 / 平均 / 最高。
///
/// [linkId] 为空看自己的数据，否则看该绑定对应的家人（[title] 传对方称呼）。
/// [initialType] 是进入时默认选中的指标。
class RingTrendScreen extends StatefulWidget {
  const RingTrendScreen({
    Key? key,
    required this.service,
    required this.metrics,
    this.linkId,
    this.title,
    this.initialType,
  }) : super(key: key);

  final RingFamilyService service;
  final List<RingTrendMetric> metrics;
  final int? linkId;
  final String? title;
  final String? initialType;

  @override
  State<RingTrendScreen> createState() => _RingTrendScreenState();
}

class _RingTrendScreenState extends State<RingTrendScreen> {
  static const _ranges = ['24h', '7d'];

  late RingTrendMetric _metric = widget.metrics.firstWhere(
    (m) => m.type == widget.initialType,
    orElse: () => widget.metrics.first,
  );
  String _range = _ranges.first;

  /// 当前这张图的卡片；换指标时换一个 key，卡片状态随之重建。
  GlobalKey<_TrendCardState> _cardKey = GlobalKey<_TrendCardState>();

  void _pickMetric(RingTrendMetric metric) {
    if (metric.type == _metric.type) return;
    setState(() {
      _metric = metric;
      _cardKey = GlobalKey<_TrendCardState>();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelectedChip());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final title = widget.title == null || widget.title!.isEmpty ? s.ringTrend : '${widget.title} · ${s.ringTrend}';
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, title),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Column(children: [
            _metricChips(context),
            // 步数是每日累计值，只有按天的走势，不提供 24 小时
            if (!_metric.isSteps) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _rangeToggle(context),
              ),
            ],
          ]),
        ),
        Expanded(child: RefreshIndicator(
          color: AppColors.k0cbcc5,
          onRefresh: () => _cardKey.currentState?.reload() ?? Future<void>.value(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              _TrendCard(
                key: _cardKey,
                service: widget.service,
                linkId: widget.linkId,
                metric: _metric,
                range: _metric.isSteps ? '7d' : _range,
              ),
              const SizedBox(height: 14),
              Text(s.smartRingDisclaimer, textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11)),
            ],
          ),
        )),
      ]),
    );
  }

  late final Map<String, GlobalKey> _chipKeys = {for (final m in widget.metrics) m.type: GlobalKey()};

  @override
  void initState() {
    super.initState();
    // 默认选中的指标可能排在后面，进入时把它滑到可见位置
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelectedChip());
  }

  void _revealSelectedChip() {
    final chipContext = _chipKeys[_metric.type]?.currentContext;
    if (chipContext == null) return;
    unawaited(Scrollable.ensureVisible(chipContext, alignment: 0.5, duration: const Duration(milliseconds: 200)));
  }

  /// 横向可滑动的指标选择。指标不多，用 Row 一次建好，才能在进入时滚到选中的那个。
  Widget _metricChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        for (var i = 0; i < widget.metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _chip(context, widget.metrics[i]),
        ],
      ]),
    );
  }

  Widget _chip(BuildContext context, RingTrendMetric m) {
    final selected = m.type == _metric.type;
    return GestureDetector(
      key: _chipKeys[m.type],
      onTap: () => _pickMetric(m),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.k003f51 : AppColors.kf4f4f4,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(m.icon, size: 14, color: selected ? Colors.white : m.color),
          const SizedBox(width: 5),
          Text(m.label(context), style: GoogleFonts.rubik(
            color: selected ? Colors.white : AppColors.k5e5e5e,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          )),
        ]),
      ),
    );
  }

  /// 通栏分段开关。
  Widget _rangeToggle(BuildContext context) {
    final s = S.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        for (final r in _ranges)
          Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (r != _range) setState(() => _range = r);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: r == _range ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                boxShadow: r == _range
                    ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Text(r == '7d' ? s.ringTrendRange7d : s.ringTrendRange24h, style: GoogleFonts.rubik(
                color: r == _range ? AppColors.k010101 : AppColors.k8f8e94,
                fontSize: 13,
                fontWeight: r == _range ? FontWeight.w600 : FontWeight.w400,
              )),
            ),
          )),
      ]),
    );
  }
}

/// 当前指标的走势卡片（一张大折线图），自己加载数据。
///
/// 标题区右侧的大数字平时是最新读数；在图上点选某个点后换成那个点的数值和时间，松手几秒后恢复。
class _TrendCard extends StatefulWidget {
  const _TrendCard({
    Key? key,
    required this.service,
    required this.metric,
    required this.range,
    this.linkId,
  }) : super(key: key);

  final RingFamilyService service;
  final RingTrendMetric metric;
  final String range;
  final int? linkId;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  /// 已加载的结果，键为范围；切回看过的范围时先显示旧数据再静默刷新。
  final Map<String, RingTrend> _cache = <String, RingTrend>{};
  bool _failed = false;
  RingTrendPoint? _selected;

  RingTrendMetric get _metric => widget.metric;

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  @override
  void didUpdateWidget(_TrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range) {
      _selected = null;
      unawaited(reload());
    }
  }

  Future<void> reload() async {
    final range = widget.range;
    if (_failed) setState(() => _failed = false);
    try {
      final trend = await widget.service.fetchTrend(type: _metric.type, range: range, linkId: widget.linkId);
      if (!mounted) return;
      setState(() => _cache[range] = _metric.isSteps ? _lastSevenDays(trend) : trend);
    } on RingFamilyException {
      if (!mounted) return;
      if (range == widget.range) setState(() => _failed = !_cache.containsKey(range));
    }
  }

  /// 步数：每天一个点（时间为当天 0 点），窗口对齐到最近 7 个自然日（含今天），点正好落在日期刻度上。
  static RingTrend _lastSevenDays(RingTrend trend) {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day, 12);
    final from = DateTime(now.year, now.month, now.day - 6).subtract(const Duration(hours: 12));
    return RingTrend(
      from: from,
      to: to,
      points: trend.points.where((p) => p.time.isAfter(from) && p.time.isBefore(to)).toList(),
    );
  }

  String _fmt(double v) => _metric.isSteps
      ? SmartRingFormat.thousands(v.round())
      : _metric.decimals == 0 ? v.round().toString() : v.toStringAsFixed(_metric.decimals);

  String _pair(double v, double? v2) => v2 == null ? _fmt(v) : '${_fmt(v)}/${_fmt(v2)}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final trend = _cache[widget.range];
    final seven = widget.range == '7d';

    return familyCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, trend),
          if (trend == null) ...[
            const SizedBox(height: 12),
            SizedBox(height: 260, child: Center(child: _failed
                ? GestureDetector(
                    onTap: () => unawaited(reload()),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.refresh, color: AppColors.k0cbcc5, size: 16),
                      const SizedBox(width: 6),
                      Text('${s.ringFamilyLoadFailed} ${s.retry}',
                          style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5)),
                    ]),
                  )
                : SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.k0cbcc5)))),
          ] else if (!trend.isEmpty) ...[
            if (_metric.isBloodPressure) ...[
              const SizedBox(height: 10),
              Row(children: [
                _legend(_metric.color, s.ringTrendSystolic),
                const SizedBox(width: 14),
                _legend(_metric.color2!, s.ringTrendDiastolic),
              ]),
            ],
            const SizedBox(height: 12),
            RingTrendChart(
              points: trend.points,
              from: trend.from,
              to: trend.to,
              color: _metric.color,
              color2: _metric.color2,
              unit: _metric.unit,
              decimals: _metric.decimals,
              // 定时监测一般 30–60 分钟一条；24 小时视图超过 3 小时、7 天视图超过 12 小时没读数就断线。
              // 步数每天一个点，隔了一天以上没数据才断
              gap: _metric.isSteps
                  ? const Duration(hours: 36)
                  : seven ? const Duration(hours: 12) : const Duration(hours: 3),
              dayTicks: seven,
              height: 260,
              onSelected: (p) => setState(() => _selected = p),
            ),
            const SizedBox(height: 12),
            _stats(context, trend),
          ],
        ],
      ),
    );
  }

  /// 左：图标 + 指标名 + 一行说明；右：大数字（最新值，或图上选中的那个点）。
  Widget _header(BuildContext context, RingTrend? trend) {
    final s = S.of(context);
    final hasData = trend != null && !trend.isEmpty;
    final shown = hasData ? (_selected ?? trend.points.last) : null;

    String subtitle;
    if (trend == null) {
      subtitle = _metric.isSteps ? s.ringTrendRange7d : '';
    } else if (!hasData) {
      subtitle = s.ringTrendEmpty;
    } else if (_metric.isSteps) {
      // 步数的点是「某一天」，只显示日期
      final date = DateFormat.MMMEd(Localizations.localeOf(context).toLanguageTag()).format(shown!.time);
      subtitle = _selected != null ? date : '${s.ringTrendRange7d} · $date';
    } else {
      final time = SmartRingFormat.dateTime(context, shown!.time);
      subtitle = _selected != null ? time : '${s.ringTrendLatest} · $time';
    }

    return Row(children: [
      familyIconTile(_metric.icon, hasData || trend == null ? _metric.color : AppColors.kb1b1b1, size: 38),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_metric.label(context), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: FontWeight.w600)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11.5)),
          ],
        ],
      )),
      if (shown != null) ...[
        const SizedBox(width: 8),
        Text.rich(TextSpan(children: [
          TextSpan(text: _pair(shown.value, shown.value2), style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.1,
          )),
          if (_metric.unit.isNotEmpty)
            TextSpan(text: ' ${_metric.unit}', style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11.5)),
        ])),
      ],
    ]);
  }

  Widget _legend(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 14, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 11.5)),
    ]);
  }

  /// 最低 / 平均 / 最高三格；血压按「收缩压/舒张压」成对显示。
  Widget _stats(BuildContext context, RingTrend trend) {
    final s = S.of(context);
    final values = trend.points.map((p) => p.value).toList();
    final values2 = trend.points.where((p) => p.value2 != null).map((p) => p.value2!).toList();
    double min(List<double> l) => l.reduce((a, b) => a < b ? a : b);
    double max(List<double> l) => l.reduce((a, b) => a > b ? a : b);
    double avg(List<double> l) => l.reduce((a, b) => a + b) / l.length;
    final has2 = values2.isNotEmpty;

    Widget cell(String label, String value) => Expanded(child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(label, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 10.5)),
          ]),
        ));

    return Row(children: [
      cell(s.ringTrendMin, _pair(min(values), has2 ? min(values2) : null)),
      const SizedBox(width: 8),
      cell(s.ringTrendAvg, _pair(avg(values), has2 ? avg(values2) : null)),
      const SizedBox(width: 8),
      cell(s.ringTrendMax, _pair(max(values), has2 ? max(values2) : null)),
    ]);
  }
}
