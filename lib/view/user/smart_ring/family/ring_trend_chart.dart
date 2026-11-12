import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/services/ring_family_service.dart';

/// 单项指标的走势图（自绘，不引第三方图表库）：默认折线，[bars] 为 true 时是按天的柱状图（步数）。
///
/// 横轴固定为查询的时间窗 [from]–[to]（不是首尾读数），所以数据稀疏时能看出哪段没有读数；
/// 相邻读数间隔超过 [gap] 时折线断开，不把长时间没数据的两头连成一条线。
/// 纵轴只有一个刻度；血压的收缩压 / 舒张压同单位，画在同一坐标里（[color2] 为舒张压）。
/// 点按或横向拖动选中离手指最近的读数，通过 [onSelected] 交给外层显示；松手几秒后自动取消选中。
class RingTrendChart extends StatefulWidget {
  const RingTrendChart({
    Key? key,
    required this.points,
    required this.from,
    required this.to,
    required this.color,
    required this.unit,
    required this.gap,
    required this.dayTicks,
    this.color2,
    this.decimals = 0,
    this.bars = false,
    this.height = 260,
    this.onSelected,
  }) : super(key: key);

  final List<RingTrendPoint> points;
  final DateTime from;
  final DateTime to;
  final Color color;

  /// 第二条线（血压的舒张压）的颜色；为空表示单线。
  final Color? color2;
  final String unit;
  final int decimals;

  /// 相邻两点超过这个间隔就断线。
  final Duration gap;

  /// true：横轴按天标（7 天）；false：按 6 小时标（24 小时）。
  final bool dayTicks;

  /// true：每个点是一天的累计值（步数），画成按天居中的柱子，纵轴从 0 起；[from]/[to] 需对齐到整天。
  final bool bars;
  final double height;

  /// 选中的读数变化时回调；取消选中时为 null。
  final ValueChanged<RingTrendPoint?>? onSelected;

  @override
  State<RingTrendChart> createState() => _RingTrendChartState();
}

class _RingTrendChartState extends State<RingTrendChart> {
  /// 松手后选中状态保留多久。
  static const _holdSelection = Duration(seconds: 4);

  int? _selected;
  Timer? _clearTimer;

  @override
  void didUpdateWidget(RingTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points) && _selected != null) {
      _clearTimer?.cancel();
      _selected = null;
      // 数据换了（切范围 / 刷新），原来选中的点已不存在；build 期间不能直接回调外层 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSelected?.call(null);
      });
    }
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }

  void _select(Offset local, double width) {
    final points = widget.points;
    if (points.isEmpty) return;
    _clearTimer?.cancel();
    final geometry = _Geometry(Size(width, widget.height), widget.from, widget.to);
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = (geometry.x(_markTime(points[i].time, widget.bars)) - local.dx).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    if (best != _selected) {
      setState(() => _selected = best);
      widget.onSelected?.call(points[best]);
    }
  }

  void _release() {
    _clearTimer?.cancel();
    _clearTimer = Timer(_holdSelection, () {
      if (!mounted || _selected == null) return;
      setState(() => _selected = null);
      widget.onSelected?.call(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _select(d.localPosition, width),
        onHorizontalDragStart: (d) => _select(d.localPosition, width),
        onHorizontalDragUpdate: (d) => _select(d.localPosition, width),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onHorizontalDragEnd: (_) => _release(),
        onHorizontalDragCancel: _release,
        child: CustomPaint(
          size: Size(width, widget.height),
          painter: _TrendPainter(
            points: widget.points,
            from: widget.from,
            to: widget.to,
            color: widget.color,
            color2: widget.color2,
            unit: widget.unit,
            decimals: widget.decimals,
            gap: widget.gap,
            dayTicks: widget.dayTicks,
            bars: widget.bars,
            selected: _selected,
            locale: Localizations.localeOf(context).toLanguageTag(),
          ),
        ),
      );
    });
  }
}

/// 一个读数在横轴上的时间：柱状图里每天的值画在当天正中。
DateTime _markTime(DateTime t, bool bars) => bars ? t.add(const Duration(hours: 12)) : t;

/// 绘图区的位置与时间 → 横坐标的换算，绘制和点击命中共用。
class _Geometry {
  _Geometry(Size size, this.from, this.to)
      : plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

  static const double left = 36;
  static const double right = 10;
  static const double top = 10;
  static const double bottom = 22;

  final Rect plot;
  final DateTime from;
  final DateTime to;

  double x(DateTime t) {
    final span = math.max(1, to.difference(from).inSeconds);
    final ratio = t.difference(from).inSeconds / span;
    return plot.left + plot.width * ratio.clamp(0.0, 1.0);
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.from,
    required this.to,
    required this.color,
    required this.color2,
    required this.unit,
    required this.decimals,
    required this.gap,
    required this.dayTicks,
    required this.bars,
    required this.selected,
    required this.locale,
  });

  final List<RingTrendPoint> points;
  final DateTime from;
  final DateTime to;
  final Color color;
  final Color? color2;
  final String unit;
  final int decimals;
  final Duration gap;
  final bool dayTicks;
  final bool bars;
  final int? selected;
  final String locale;

  static final Color _grid = const Color(0xFFECECEC);
  static final Color _axisText = AppColors.k8f8e94;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geometry(size, from, to);
    final plot = g.plot;

    // ---- 纵轴范围：读数上下各留一点余量，取整到好读的刻度 ----
    var lo = double.infinity;
    var hi = -double.infinity;
    for (final p in points) {
      lo = math.min(lo, math.min(p.value, p.value2 ?? p.value));
      hi = math.max(hi, math.max(p.value, p.value2 ?? p.value));
    }
    if (points.isEmpty) {
      lo = 0;
      hi = 1;
    }
    final minSpan = decimals > 0 ? 1.0 : 10.0;
    var span = math.max(hi - lo, minSpan);
    final step = _niceStep(span / 3);
    var axisLo = ((lo - span * 0.1) / step).floorToDouble() * step;
    if (bars || (lo >= 0 && axisLo < 0)) axisLo = 0;
    var axisHi = ((hi + span * 0.1) / step).ceilToDouble() * step;
    if (axisHi <= axisLo) axisHi = axisLo + step;
    span = axisHi - axisLo;
    double y(double v) => plot.bottom - plot.height * ((v - axisLo) / span);

    // ---- 网格与纵轴刻度 ----
    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    final tickDecimals = step < 1 ? 1 : 0;
    for (var v = axisLo; v <= axisHi + step * 0.001; v += step) {
      final yy = y(v);
      canvas.drawLine(Offset(plot.left, yy), Offset(plot.right, yy), gridPaint);
      final tp = _text(_tickLabel(v, tickDecimals), _axisText, 10);
      tp.paint(canvas, Offset(plot.left - 6 - tp.width, yy - tp.height / 2));
    }

    // ---- 横轴刻度 ----
    var lastLabelRight = double.negativeInfinity;
    for (final tick in _timeTicks()) {
      // 柱状图的日期标在当天柱子正下方，折线图标在 0 点的位置
      final xx = g.x(_markTime(tick, bars));
      final label = dayTicks ? DateFormat.Md(locale).format(tick) : DateFormat.Hm(locale).format(tick);
      final tp = _text(label, _axisText, 10);
      final dx = (xx - tp.width / 2).clamp(plot.left - 4, size.width - tp.width).toDouble();
      // 窄屏或长日期格式下标签会挤在一起，和上一个重叠的就不画
      if (dx < lastLabelRight + 6) continue;
      tp.paint(canvas, Offset(dx, plot.bottom + 6));
      lastLabelRight = dx + tp.width;
    }

    if (points.isEmpty) return;

    // ---- 柱子 / 折线 ----
    if (bars) {
      _drawBars(canvas, g, y);
    } else {
      _drawSeries(canvas, g, y, color, (p) => p.value);
      if (color2 != null) _drawSeries(canvas, g, y, color2!, (p) => p.value2);
    }

    // ---- 选中的读数：竖线 + 圆点（数值由外层卡片的标题区显示，图上不画气泡） ----
    final index = selected;
    if (index == null || index < 0 || index >= points.length) return;
    final p = points[index];
    final px = g.x(_markTime(p.time, bars));
    // 柱状图靠其余柱子变淡来标出选中项，不需要竖线
    if (!bars) {
      canvas.drawLine(
        Offset(px, plot.top),
        Offset(px, plot.bottom),
        Paint()
          ..color = AppColors.kb1b1b1
          ..strokeWidth = 1,
      );
    }
    void marker(double value, Color c) {
      final center = Offset(px, y(value));
      canvas.drawCircle(center, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(center, 4.5, Paint()..color = c);
    }

    if (!bars) {
      marker(p.value, color);
      if (color2 != null && p.value2 != null) marker(p.value2!, color2!);
    }
  }

  void _drawSeries(
    Canvas canvas,
    _Geometry g,
    double Function(double) y,
    Color c,
    double? Function(RingTrendPoint) valueOf,
  ) {
    final line = Paint()
      ..color = c
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = c;
    // 点不多时每个读数画一个小点；点多了只给前后都断开的孤立读数画点，否则它没有线段、会看不见
    final showAllDots = points.length <= 40;

    final path = Path();
    DateTime? previous;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final v = valueOf(p);
      if (v == null) continue;
      final offset = Offset(g.x(p.time), y(v));
      final joined = previous != null && p.time.difference(previous) <= gap;
      if (joined) {
        path.lineTo(offset.dx, offset.dy);
      } else {
        path.moveTo(offset.dx, offset.dy);
      }
      final nextJoined = i + 1 < points.length && points[i + 1].time.difference(p.time) <= gap;
      if (showAllDots || (!joined && !nextJoined)) canvas.drawCircle(offset, 2.5, dot);
      previous = p.time;
    }
    canvas.drawPath(path, line);
  }

  /// 每天一根柱子：宽度不超过一天所占宽度的一半，顶部圆角、底部贴基线；选中的那根保持原色，其余略淡。
  void _drawBars(Canvas canvas, _Geometry g, double Function(double) y) {
    final days = math.max(1, to.difference(from).inHours / 24);
    final width = math.min(22.0, g.plot.width / days * 0.5);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = g.x(_markTime(p.time, true));
      final top = math.min(y(p.value), g.plot.bottom - 2);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - width / 2, top, cx + width / 2, g.plot.bottom),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      final dimmed = selected != null && selected != i;
      canvas.drawRRect(rect, Paint()..color = dimmed ? color.withOpacity(0.45) : color);
    }
  }

  /// 纵轴刻度文字：上千的写成 2k / 2.5k，省出宽度。
  String _tickLabel(double v, int tickDecimals) {
    if (v >= 1000) {
      final k = v / 1000;
      return '${k == k.roundToDouble() ? k.round().toString() : k.toStringAsFixed(1)}k';
    }
    return v.toStringAsFixed(tickDecimals);
  }

  /// 24 小时：整 6 点（0/6/12/18 时）；7 天：每天 0 点。
  List<DateTime> _timeTicks() {
    final ticks = <DateTime>[];
    if (dayTicks) {
      // 柱状图每天都要有日期（含第一天、不含窗口结束的那个 0 点）；折线图只标窗口内的 0 点
      var t = bars ? from : DateTime(from.year, from.month, from.day).add(const Duration(days: 1));
      while (bars ? t.isBefore(to) : !t.isAfter(to)) {
        ticks.add(t);
        t = DateTime(t.year, t.month, t.day + 1);
      }
    } else {
      var t = DateTime(from.year, from.month, from.day, (from.hour ~/ 6) * 6);
      while (!t.isAfter(to)) {
        if (!t.isBefore(from)) ticks.add(t);
        t = t.add(const Duration(hours: 6));
      }
    }
    return ticks;
  }

  static double _niceStep(double raw) {
    if (raw <= 0) return 1;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    final nice = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
    return nice * magnitude;
  }

  TextPainter _text(String text, Color color, double size) {
    return TextPainter(
      text: TextSpan(text: text, style: GoogleFonts.rubik(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      !identical(old.points, points) ||
      old.selected != selected ||
      old.from != from ||
      old.to != to ||
      old.color != color ||
      old.color2 != color2 ||
      old.bars != bars ||
      old.locale != locale;
}
