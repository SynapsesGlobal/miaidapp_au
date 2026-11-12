import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alert_demo_data.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alert_widgets.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alerts_screen.dart';

/// 父母端「家人提醒」设置页（演示版，静态数据）：
/// 总开关 → 已绑定的家人 + 邀请码 → 异常阈值 → 提醒规则 → 预览家人端。
class FamilyAlertSettingsScreen extends StatefulWidget {
  const FamilyAlertSettingsScreen({Key? key}) : super(key: key);

  @override
  State<FamilyAlertSettingsScreen> createState() => _FamilyAlertSettingsScreenState();
}

class _FamilyAlertSettingsScreenState extends State<FamilyAlertSettingsScreen> {
  bool _enabled = true;
  bool _quietHours = true;
  TimeOfDay _quietStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);
  bool _recovery = true;
  bool _noData = true;
  final int _noDataHours = 12;
  final List<DemoMember> _members = List.of(FamilyAlertDemoData.members);
  final List<DemoThreshold> _thresholds = FamilyAlertDemoData.thresholds;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, s.familyAlerts),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heroCard(context),
            const SizedBox(height: 20),
            AnimatedOpacity(
              opacity: _enabled ? 1 : 0.45,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_enabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    familySectionTitle(s.familyAlertMembers),
                    _membersCard(context),
                    const SizedBox(height: 20),
                    familySectionTitle(s.familyAlertThresholds, subtitle: s.familyAlertThresholdsDesc),
                    _thresholdsCard(context),
                    const SizedBox(height: 20),
                    familySectionTitle(s.familyAlertRules),
                    _rulesCard(context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            familyOutlinedButton(s.familyAlertPreviewFamily, icon: Icons.visibility_outlined, onPressed: () {
              unawaited(Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => const FamilyAlertsScreen(),
              )));
            }),
            familyDemoNote(context),
          ],
        ),
      ),
    );
  }

  // ---------------- 总开关 ----------------

  Widget _heroCard(BuildContext context) {
    final s = S.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [AppColors.k0cbcc5, AppColors.k003f51.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: AppColors.k0cbcc5.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.family_restroom, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.familyAlertEnable, style: GoogleFonts.rubik(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(s.familyAlertEnableDesc, style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.82), fontSize: 12, height: 1.35)),
          ],
        )),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: _enabled,
          activeColor: Colors.white,
          activeTrackColor: Colors.white.withOpacity(0.45),
          onChanged: (v) => setState(() => _enabled = v),
        ),
      ]),
    );
  }

  // ---------------- 家人 ----------------

  Widget _membersCard(BuildContext context) {
    final s = S.of(context);
    return familyCard(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Column(children: [
        if (_members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(s.familyAlertNoMembers, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13)),
          ),
        for (var i = 0; i < _members.length; i++) ...[
          _memberRow(context, _members[i]),
          if (i < _members.length - 1) Divider(height: 1, color: AppColors.kf4f4f4),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: () => unawaited(_showInvite(context)),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.k0cbcc5.withOpacity(0.5), width: 1.2),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.person_add_alt_1, color: AppColors.k0cbcc5, size: 18),
              const SizedBox(width: 8),
              Text(s.familyAlertInvite, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _memberRow(BuildContext context, DemoMember m) {
    final s = S.of(context);
    final pending = m.status == DemoMemberStatus.pending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        familyAvatar(m.name, pending ? AppColors.k8f8e94 : AppColors.k0cbcc5),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(m.name, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              familyChip(m.relation, AppColors.k0cbcc5),
            ]),
            if (pending) ...[
              const SizedBox(height: 3),
              Text(s.familyAlertPending, style: GoogleFonts.rubik(color: AppColors.ke68c30, fontSize: 12)),
            ],
          ],
        )),
        IconButton(
          icon: Icon(Icons.link_off, color: AppColors.kb1b1b1, size: 20),
          onPressed: () => unawaited(_confirmRemove(context, m)),
        ),
      ]),
    );
  }

  Future<void> _confirmRemove(BuildContext context, DemoMember m) async {
    final s = S.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _sheet(context, children: [
        familyIconTile(Icons.link_off, AppColors.ke63030, size: 60),
        const SizedBox(height: 14),
        Text(s.familyAlertRemove, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(s.familyAlertRemoveConfirm(m.name), textAlign: TextAlign.center,
            style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13, height: 1.45)),
        const SizedBox(height: 22),
        familyFilledButton(s.familyAlertRemove, color: AppColors.ke63030, onPressed: () => Navigator.pop(context, true)),
        const SizedBox(height: 10),
        _greyButton(s.cancel, () => Navigator.pop(context, false)),
      ]),
    );
    if (ok == true && mounted) setState(() => _members.remove(m));
  }

  Future<void> _showInvite(BuildContext context) async {
    final s = S.of(context);
    const code = '482 931';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _sheet(context, children: [
        familyIconTile(Icons.qr_code_2, AppColors.k0cbcc5, size: 60),
        const SizedBox(height: 14),
        Text(s.familyAlertInviteCode, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(16)),
          child: Text(code, style: GoogleFonts.rubik(
            color: AppColors.k003f51,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          )),
        ),
        const SizedBox(height: 12),
        Text(s.familyAlertInviteHint, textAlign: TextAlign.center,
            style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5, height: 1.45)),
        const SizedBox(height: 22),
        familyFilledButton(s.familyAlertCopy, icon: Icons.copy, onPressed: () async {
          await Clipboard.setData(const ClipboardData(text: '482931'));
          unawaited(HttpExceptionNotifyUser.showInfo(s.familyAlertCopied));
        }),
      ]),
    );
  }

  // ---------------- 阈值 ----------------

  Widget _thresholdsCard(BuildContext context) {
    final s = S.of(context);
    return familyCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(children: [
        for (var i = 0; i < _thresholds.length; i++) ...[
          _thresholdRow(context, _thresholds[i], s),
          if (i < _thresholds.length - 1) Divider(height: 1, color: AppColors.kf4f4f4),
        ],
      ]),
    );
  }

  Widget _thresholdRow(BuildContext context, DemoThreshold t, S s) {
    final isOxy = t.metric == DemoMetric.bloodOxygen;
    final summary = isOxy
        ? '${s.familyAlertLow} ${t.fmt(t.low)} ${t.unit}'
        : '${s.familyAlertLow} ${t.fmt(t.low)} · ${s.familyAlertHigh} ${t.fmt(t.high)} ${t.unit}';
    return InkWell(
      onTap: () => unawaited(_editThreshold(context, t)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          familyIconTile(t.metric.icon, t.metric.color, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.metric.label(context), style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(summary, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
            ],
          )),
          Icon(Icons.chevron_right, color: AppColors.kb1b1b1, size: 20),
        ]),
      ),
    );
  }

  Future<void> _editThreshold(BuildContext context, DemoThreshold t) async {
    final s = S.of(context);
    var range = RangeValues(t.low, t.high);
    var consecutive = t.consecutive;
    final isOxy = t.metric == DemoMetric.bloodOxygen;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        return _sheet(context, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            familyIconTile(t.metric.icon, t.metric.color, size: 44),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.metric.label(context), style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(s.familyAlertThresholdsDesc, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5)),
              ],
            )),
          ]),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _bigValue(s.familyAlertLow, t.fmt(range.start), t.unit, t.metric.color),
            if (!isOxy) _bigValue(s.familyAlertHigh, t.fmt(range.end), t.unit, t.metric.color, alignEnd: true),
          ]),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: t.metric.color,
              inactiveTrackColor: t.metric.color.withOpacity(0.15),
              thumbColor: t.metric.color,
              overlayColor: t.metric.color.withOpacity(0.15),
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: isOxy
                ? Slider(
                    value: range.start,
                    min: t.min,
                    max: t.max,
                    onChanged: (v) => setSheet(() => range = RangeValues(v, t.max)),
                  )
                : RangeSlider(
                    values: range,
                    min: t.min,
                    max: t.max,
                    onChanged: (v) => setSheet(() => range = v),
                  ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(child: Text(s.familyAlertConsecutive(consecutive),
                  style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 13))),
              _stepButton(Icons.remove, consecutive > 1 ? () => setSheet(() => consecutive--) : null),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('$consecutive', style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              _stepButton(Icons.add, consecutive < 5 ? () => setSheet(() => consecutive++) : null),
            ]),
          ),
          const SizedBox(height: 22),
          familyFilledButton(s.confirm, onPressed: () => Navigator.pop(context, true)),
          const SizedBox(height: 10),
          _greyButton(s.cancel, () => Navigator.pop(context, false)),
        ]);
      }),
    );
    if (saved == true && mounted) {
      setState(() {
        t.low = range.start;
        t.high = range.end;
        t.consecutive = consecutive;
      });
    }
  }

  Widget _bigValue(String label, String value, String unit, Color color, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
        const SizedBox(height: 2),
        Text.rich(TextSpan(children: [
          TextSpan(text: value, style: GoogleFonts.rubik(color: color, fontSize: 26, fontWeight: FontWeight.w700)),
          TextSpan(text: ' $unit', style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
        ])),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, size: 16, color: onTap == null ? AppColors.kb1b1b1 : AppColors.k0cbcc5),
      ),
    );
  }

  // ---------------- 规则 ----------------

  Widget _rulesCard(BuildContext context) {
    final s = S.of(context);
    String fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return familyCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(children: [
        _ruleRow(
          icon: Icons.bedtime_outlined,
          color: AppColors.k5251f7,
          title: s.familyAlertQuietHours,
          subtitle: s.familyAlertQuietHoursDesc(fmt(_quietStart), fmt(_quietEnd)),
          value: _quietHours,
          onChanged: (v) => setState(() => _quietHours = v),
          onTap: _quietHours ? () => unawaited(_pickQuietHours(context)) : null,
        ),
        Divider(height: 1, color: AppColors.kf4f4f4),
        _ruleRow(
          icon: Icons.check_circle_outline,
          color: AppColors.k25d000,
          title: s.familyAlertRecovery,
          subtitle: s.familyAlertRecoveryDesc,
          value: _recovery,
          onChanged: (v) => setState(() => _recovery = v),
        ),
        Divider(height: 1, color: AppColors.kf4f4f4),
        _ruleRow(
          icon: Icons.bluetooth_disabled,
          color: AppColors.k8f8e94,
          title: s.familyAlertNoData,
          subtitle: s.familyAlertNoDataDesc(_noDataHours),
          value: _noData,
          onChanged: (v) => setState(() => _noData = v),
        ),
      ]),
    );
  }

  Widget _ruleRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          familyIconTile(icon, color, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(subtitle, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
            ],
          )),
          Switch.adaptive(value: value, activeColor: AppColors.k0cbcc5, onChanged: onChanged),
        ]),
      ),
    );
  }

  Future<void> _pickQuietHours(BuildContext context) async {
    final start = await showTimePicker(context: context, initialTime: _quietStart);
    if (start == null || !mounted) return;
    final end = await showTimePicker(context: context, initialTime: _quietEnd);
    if (end == null || !mounted) return;
    setState(() {
      _quietStart = start;
      _quietEnd = end;
    });
  }

  // ---------------- 通用 ----------------

  Widget _sheet(BuildContext context, {required List<Widget> children, CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center}) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Center(child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.kb1b1b1.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _greyButton(String label, VoidCallback onPressed) {
    return MaterialButton(
      onPressed: onPressed,
      elevation: 0,
      height: 46,
      minWidth: double.infinity,
      color: AppColors.kf4f4f4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
      child: Text(label, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}
