import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alert_demo_data.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alert_widgets.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';

/// 家人端提醒详情（演示版）：异常值 + 参考范围 + 24 小时折线 + 长辈信息 + 一键打电话。
class FamilyAlertDetailScreen extends StatefulWidget {
  const FamilyAlertDetailScreen({Key? key, required this.alert}) : super(key: key);

  final DemoAlert alert;

  @override
  State<FamilyAlertDetailScreen> createState() => _FamilyAlertDetailScreenState();
}

class _FamilyAlertDetailScreenState extends State<FamilyAlertDetailScreen> {
  DemoAlert get a => widget.alert;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, s.familyAlertDetail),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heroCard(context),
            if (a.points.isNotEmpty) ...[
              const SizedBox(height: 16),
              _chartCard(context),
            ],
            const SizedBox(height: 16),
            _elderCard(context),
            const SizedBox(height: 20),
            familyFilledButton(s.familyAlertPhone, icon: Icons.call, onPressed: () => _demoAction(context)),
            const SizedBox(height: 10),
            if (!a.handled)
              TextButton.icon(
                onPressed: () => setState(() => a.handled = true),
                icon: Icon(Icons.check_circle_outline, color: AppColors.k8f8e94, size: 18),
                label: Text(s.familyAlertMarkHandled, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13.5)),
              )
            else
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle, color: AppColors.k25d000, size: 18),
                const SizedBox(width: 6),
                Text(s.familyAlertHandled, style: GoogleFonts.rubik(color: AppColors.k25d000, fontSize: 13.5, fontWeight: FontWeight.w500)),
              ]),
            familyDemoNote(context),
          ],
        ),
      ),
    );
  }

  void _demoAction(BuildContext context) {
    unawaited(HttpExceptionNotifyUser.showInfo(S.of(context).familyAlertDemoAction));
  }

  Widget _heroCard(BuildContext context) {
    final s = S.of(context);
    final color = familyLevelColor(a.level);
    final noData = a.level == DemoAlertLevel.noData;
    final t = FamilyAlertDemoData.thresholds.firstWhere((t) => t.metric == a.metric);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.95), color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
              child: Text(familyLevelText(context, a.level), style: GoogleFonts.rubik(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            Icon(noData ? Icons.bluetooth_disabled : a.metric.icon, color: Colors.white.withOpacity(0.9), size: 22),
          ]),
          const SizedBox(height: 14),
          Text('${a.elder.name} · ${a.title(context)}', style: GoogleFonts.rubik(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          if (!noData) ...[
            const SizedBox(height: 10),
            Text.rich(TextSpan(children: [
              TextSpan(text: a.value, style: GoogleFonts.rubik(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w700, height: 1)),
              TextSpan(text: '  ${a.unit}', style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.85), fontSize: 16)),
            ])),
            const SizedBox(height: 10),
            Text(s.familyAlertRangeLine(t.fmt(a.low), t.fmt(a.high), a.unit),
                style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.85), fontSize: 12.5)),
          ],
          const SizedBox(height: 4),
          Text(s.familyAlertMeasuredAt(SmartRingFormat.dateTime(context, a.time)),
              style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.75), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _chartCard(BuildContext context) {
    final s = S.of(context);
    final end = a.time;
    final start = end.subtract(const Duration(hours: 23));
    final color = a.metric.color;
    return familyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(s.familyAlertLast24h, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.k25d000.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text(s.smartRingReferenceRange, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _TrendPainter(points: a.points, low: a.low, high: a.high, color: color),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(DateFormat.Hm().format(start), style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 10.5)),
            Text(DateFormat.Hm().format(end), style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 10.5)),
          ]),
        ],
      ),
    );
  }

  Widget _elderCard(BuildContext context) {
    final s = S.of(context);
    final e = a.elder;
    return familyCard(
      child: Row(children: [
        familyAvatar(e.name, AppColors.k0cbcc5, size: 44),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(e.name, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(e.relation, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
            ]),
            const SizedBox(height: 3),
            Text('${e.ringName} · ${e.battery}% · ${s.familyAlertLastReading(SmartRingFormat.dateTime(context, e.lastReading))}',
                style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        )),
        const SizedBox(width: 8),
        Text(e.phone, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

/// 最近 24 小时折线：浅绿参考范围带 + 折线 + 末点高亮；超出范围的点标红。
class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.points, required this.low, required this.high, required this.color});

  final List<double> points;
  final double low;
  final double high;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minV = [points.reduce((a, b) => a < b ? a : b), low].reduce((a, b) => a < b ? a : b);
    final maxV = [points.reduce((a, b) => a > b ? a : b), high].reduce((a, b) => a > b ? a : b);
    final pad = (maxV - minV) * 0.12 + 0.1;
    final lo = minV - pad;
    final hi = maxV + pad;
    double y(double v) => size.height - (v - lo) / (hi - lo) * size.height;
    double x(int i) => i / (points.length - 1) * size.width;

    // 参考范围带
    final band = Rect.fromLTRB(0, y(high), size.width, y(low));
    canvas.drawRRect(RRect.fromRectAndRadius(band, const Radius.circular(4)), Paint()..color = AppColors.k25d000.withOpacity(0.12));
    final dash = Paint()
      ..color = AppColors.k25d000.withOpacity(0.5)
      ..strokeWidth = 1;
    for (final v in [low, high]) {
      for (var dx = 0.0; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, y(v)), Offset(dx + 4, y(v)), dash);
      }
    }

    // 折线 + 渐变填充
    final path = Path()..moveTo(x(0), y(points[0]));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(x(i), y(points[i]));
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.22), color.withOpacity(0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // 超范围的点
    final outPaint = Paint()..color = AppColors.ke63030;
    for (var i = 0; i < points.length; i++) {
      final v = points[i];
      if (v < low || v > high) canvas.drawCircle(Offset(x(i), y(v)), 2.6, outPaint);
    }
    // 末点高亮
    final last = Offset(x(points.length - 1), y(points.last));
    canvas.drawCircle(last, 6, Paint()..color = color.withOpacity(0.25));
    canvas.drawCircle(last, 3.5, Paint()..color = color);
    canvas.drawCircle(last, 3.5, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.points != points || old.low != low || old.high != high || old.color != color;
}
