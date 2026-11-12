import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alert_demo_data.dart';

export 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';

/// 「家人提醒」演示页专用的小组件；通用的卡片 / 按钮 / 头像等在 family/ring_family_widgets.dart，这里转出口。

/// 页面底部「演示数据」说明。
Widget familyDemoNote(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.science_outlined, color: AppColors.kb1b1b1, size: 13),
      const SizedBox(width: 4),
      Text(S.of(context).familyAlertDemoNote, style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11)),
    ]),
  );
}

Color familyLevelColor(DemoAlertLevel level) {
  switch (level) {
    case DemoAlertLevel.high:
      return AppColors.ke63030;
    case DemoAlertLevel.warn:
      return AppColors.ke68c30;
    case DemoAlertLevel.recovered:
      return AppColors.k25d000;
    case DemoAlertLevel.noData:
      return AppColors.k8f8e94;
  }
}

String familyLevelText(BuildContext context, DemoAlertLevel level) {
  final s = S.of(context);
  switch (level) {
    case DemoAlertLevel.high:
      return s.familyAlertLevelHigh;
    case DemoAlertLevel.warn:
      return s.familyAlertLevelWarn;
    case DemoAlertLevel.recovered:
      return s.familyAlertLevelRecovered;
    case DemoAlertLevel.noData:
      return s.familyAlertStatusNoData;
  }
}

Color familyElderStatusColor(DemoElderStatus status) {
  switch (status) {
    case DemoElderStatus.normal:
      return AppColors.k25d000;
    case DemoElderStatus.abnormal:
      return AppColors.ke63030;
    case DemoElderStatus.noData:
      return AppColors.k8f8e94;
  }
}

String familyElderStatusText(BuildContext context, DemoElderStatus status) {
  final s = S.of(context);
  switch (status) {
    case DemoElderStatus.normal:
      return s.familyAlertStatusNormal;
    case DemoElderStatus.abnormal:
      return s.familyAlertStatusAbnormal;
    case DemoElderStatus.noData:
      return s.familyAlertStatusNoData;
  }
}
