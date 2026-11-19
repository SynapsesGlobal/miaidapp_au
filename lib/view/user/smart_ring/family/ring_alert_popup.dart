import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/ring_alert_center.dart';
import 'package:miaid/services/ring_alert_service.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alert_widgets.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';

/// 家人端「新提醒」弹框：拉到还没看过的提醒时弹一次（同一条只弹一次）。
///
/// 居中小卡片，全部居中排版、只留必要信息：
/// 顶部圆形指标图标 → 是谁 → 什么异常 → 大号读数 → 测量时间 → （其他未读，最多 3 条）→ 「知道了」。
/// 关闭即把这些提醒标为已读。
Future<void> showRingAlertPopup(BuildContext context, List<RingAlertItem> alerts) async {
  if (alerts.isEmpty) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'ring-alert',
    barrierColor: Colors.black.withOpacity(0.4),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, __) => _RingAlertDialog(alerts: alerts),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1).animate(curved), child: child),
      );
    },
  );
  unawaited(RingAlertCenter.instance.markSeen(ids: alerts.map((a) => a.id).toList()));
}

class _RingAlertDialog extends StatelessWidget {
  const _RingAlertDialog({required this.alerts});

  final List<RingAlertItem> alerts;

  static String _nameOf(RingAlertItem a) {
    final alias = a.ownerAlias;
    if (alias != null && alias.isNotEmpty) return alias;
    return RingAlertCenter.instance.ownerStatus(a.linkId ?? -1)?.name ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final first = alerts.first;
    final others = alerts.skip(1).take(3).toList();
    final extra = alerts.length - 1 - others.length;
    final accent = ringAlertMetricColor(first.type);
    final time = first.measuredAt ?? first.createdAt;
    final name = _nameOf(first);

    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 296,
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 56),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 28, offset: const Offset(0, 10))],
            ),
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 指标图标
                Center(child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: accent.withOpacity(0.10), shape: BoxShape.circle),
                  child: Icon(ringAlertMetricIcon(first.type), color: accent, size: 26),
                )),
                const SizedBox(height: 14),
                // 是谁
                Text(name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                // 什么异常
                Text(ringAlertTitle(context, first), textAlign: TextAlign.center,
                    style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 14)),
                // 读数
                if (first.valueText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: first.valueText, style: GoogleFonts.rubik(color: accent, fontSize: 44, fontWeight: FontWeight.w700, height: 1)),
                      TextSpan(text: '  ${first.unit}', style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 14)),
                    ]),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (time != null) ...[
                  const SizedBox(height: 8),
                  Text(SmartRingFormat.dateTime(context, time), textAlign: TextAlign.center,
                      style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 12)),
                ],
                // 其他未读
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      for (var i = 0; i < others.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: Colors.white),
                        _otherRow(context, others[i]),
                      ],
                      if (extra > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(s.ringAlertMoreCount(extra), style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11.5)),
                        ),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                MaterialButton(
                  onPressed: () => Navigator.pop(context),
                  elevation: 0,
                  height: 44,
                  minWidth: double.infinity,
                  color: AppColors.k0cbcc5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  child: Text(s.ringAlertGotIt, style: GoogleFonts.rubik(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _otherRow(BuildContext context, RingAlertItem a) {
    final accent = ringAlertMetricColor(a.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(ringAlertMetricIcon(a.type), color: accent, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text('${_nameOf(a)} · ${ringAlertTitle(context, a)}', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 12.5))),
        if (a.valueText.isNotEmpty)
          Text('${a.valueText} ${a.unit}', style: GoogleFonts.rubik(color: accent, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
