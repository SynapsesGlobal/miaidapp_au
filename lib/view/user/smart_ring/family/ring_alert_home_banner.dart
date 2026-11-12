import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miaid/services/ring_alert_center.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alert_widgets.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alerts_screen.dart';

/// 首页顶部的家人异常横幅：有未处理的提醒时显示最严重的一条，点击进提醒列表；没有则不占位。
/// 数据来自 [RingAlertCenter]，推送丢了也能在这里看到。
class RingAlertHomeBanner extends StatelessWidget {
  const RingAlertHomeBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final center = RingAlertCenter.instance;
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        final alert = center.bannerAlert;
        if (alert == null) return const SizedBox.shrink();
        final owner = alert.linkId == null ? null : center.ownerStatus(alert.linkId!);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ringAlertStrip(
            context,
            alert,
            ownerName: owner?.displayName,
            extraCount: center.bannerExtraCount,
            onTap: () {
              unawaited(Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => RingAlertsScreen(initialAlertId: alert.id),
              )));
            },
          ),
        );
      },
    );
  }
}
