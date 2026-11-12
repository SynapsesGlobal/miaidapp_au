import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alert_demo_data.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alert_detail_screen.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alert_join_screen.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alert_widgets.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';

/// 家人端「家人提醒」列表页（演示版）：我关注的长辈 + 最近提醒。
class FamilyAlertsScreen extends StatefulWidget {
  const FamilyAlertsScreen({Key? key}) : super(key: key);

  @override
  State<FamilyAlertsScreen> createState() => _FamilyAlertsScreenState();
}

class _FamilyAlertsScreenState extends State<FamilyAlertsScreen> {
  final List<DemoAlert> _alerts = FamilyAlertDemoData.alerts;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final now = DateTime.now();
    final today = _alerts.where((a) => _sameDay(a.time, now)).toList();
    final earlier = _alerts.where((a) => !_sameDay(a.time, now)).toList();
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, s.familyAlerts, actions: [
        IconButton(
          icon: Icon(Icons.person_add_alt_1, color: AppColors.k003f51),
          onPressed: () => unawaited(Navigator.push(context, MaterialPageRoute<void>(
            builder: (context) => const FamilyAlertJoinScreen(),
          ))),
        ),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            familySectionTitle(s.familyAlertWatching),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: FamilyAlertDemoData.elders.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _elderCard(context, FamilyAlertDemoData.elders[i]),
              ),
            ),
            const SizedBox(height: 22),
            familySectionTitle(s.familyAlertRecent),
            if (_alerts.isEmpty)
              familyCard(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(s.familyAlertNoAlerts, textAlign: TextAlign.center,
                    style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13)),
              )),
            for (final a in today) ...[_alertTile(context, a), const SizedBox(height: 10)],
            if (earlier.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                child: Text(s.familyAlertEarlier, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              for (final a in earlier) ...[_alertTile(context, a), const SizedBox(height: 10)],
            ],
            familyDemoNote(context),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _elderCard(BuildContext context, DemoElder e) {
    final s = S.of(context);
    final abnormal = e.status == DemoElderStatus.abnormal;
    final statusColor = familyElderStatusColor(e.status);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: abnormal
            ? LinearGradient(
                colors: [AppColors.ke63030.withOpacity(0.92), AppColors.ke68c30.withOpacity(0.9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [AppColors.k0cbcc5, AppColors.k003f51.withOpacity(0.88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [BoxShadow(color: (abnormal ? AppColors.ke63030 : AppColors.k0cbcc5).withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)),
              child: Text(e.name.characters.first, style: GoogleFonts.rubik(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: GoogleFonts.rubik(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                Text(e.relation, style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.8), fontSize: 11)),
              ],
            )),
          ]),
          const Spacer(),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: abnormal ? Colors.white : statusColor)),
                const SizedBox(width: 5),
                Text(familyElderStatusText(context, e.status), style: GoogleFonts.rubik(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            Icon(Icons.battery_std, color: Colors.white.withOpacity(0.85), size: 13),
            Text('${e.battery}%', style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.85), fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          Text(s.familyAlertLastReading(SmartRingFormat.dateTime(context, e.lastReading)),
              style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.75), fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _alertTile(BuildContext context, DemoAlert a) {
    final s = S.of(context);
    final color = familyLevelColor(a.level);
    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute<void>(
          builder: (context) => FamilyAlertDetailScreen(alert: a),
        ));
        if (mounted) setState(() {});
      },
      borderRadius: BorderRadius.circular(18),
      child: familyCard(
        child: Row(children: [
          familyIconTile(a.level == DemoAlertLevel.noData ? Icons.bluetooth_disabled : a.metric.icon, color, size: 42),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text('${a.elder.name} · ${a.title(context)}',
                    style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                familyChip(familyLevelText(context, a.level), color),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text(SmartRingFormat.dateTime(context, a.time), style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
                if (a.handled) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, color: AppColors.k25d000, size: 13),
                  const SizedBox(width: 2),
                  Text(s.familyAlertHandled, style: GoogleFonts.rubik(color: AppColors.k25d000, fontSize: 11.5)),
                ],
              ]),
            ],
          )),
          const SizedBox(width: 8),
          if (a.level != DemoAlertLevel.noData)
            Text.rich(TextSpan(children: [
              TextSpan(text: a.value, style: GoogleFonts.rubik(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
              TextSpan(text: ' ${a.unit}', style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11)),
            ])),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: AppColors.kb1b1b1, size: 20),
        ]),
      ),
    );
  }
}
