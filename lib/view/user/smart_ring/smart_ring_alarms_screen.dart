import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';
import 'package:rwfit_ble/rwfit_ble.dart';

/// 用药闹钟：闹钟存在戒指里，到点戒指震动，不依赖手机。
///
/// 协议只能整批下发，所以每次增删改都是「改内存里的列表 → 整批写回」。最多 [_maxAlarms] 个。
class SmartRingAlarmsScreen extends StatefulWidget {
  const SmartRingAlarmsScreen({Key? key}) : super(key: key);

  @override
  State<SmartRingAlarmsScreen> createState() => _SmartRingAlarmsScreenState();
}

class _SmartRingAlarmsScreenState extends State<SmartRingAlarmsScreen> {
  static const _maxAlarms = 8;

  final SmartRingService _ring = SmartRingService.instance;
  List<Alarm>? _alarms;
  bool _failed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final alarms = await _ring.getAlarms();
      if (!mounted) return;
      setState(() => _alarms = alarms..sort(_byTime));
    } catch (e) {
      debugPrint('SmartRing: load alarms failed: $e');
      if (!mounted) return;
      setState(() => _failed = true);
      unawaited(HttpExceptionNotifyUser.showInfo(
        _ring.isConnected ? S.of(context).smartRingSettingsLoadFailed : S.of(context).smartRingConnectFailed,
      ));
    }
  }

  static int _byTime(Alarm a, Alarm b) => (a.startHour * 60 + a.startMin).compareTo(b.startHour * 60 + b.startMin);

  /// 整批写回；失败回滚到写之前的列表。
  Future<void> _commit(List<Alarm> next) async {
    final previous = _alarms;
    setState(() {
      _saving = true;
      _alarms = next..sort(_byTime);
    });
    try {
      await _ring.saveAlarms(next);
    } catch (e) {
      debugPrint('SmartRing: save alarms failed: $e');
      if (!mounted) return;
      setState(() => _alarms = previous);
      unawaited(HttpExceptionNotifyUser.showInfo(
        _ring.isConnected ? S.of(context).smartRingSettingFailed : S.of(context).smartRingConnectFailed,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    final s = S.of(context);
    final current = _alarms ?? const <Alarm>[];
    if (current.length >= _maxAlarms) {
      unawaited(HttpExceptionNotifyUser.showInfo(s.smartRingAlarmMax(_maxAlarms)));
      return;
    }
    final result = await _editSheet(null);
    if (result == null || !mounted) return;
    var id = 1;
    final used = current.map((a) => a.alarmId).toSet();
    while (used.contains(id)) {
      id++;
    }
    await _commit([...current, result.copyWith(alarmId: id)]);
  }

  Future<void> _edit(Alarm alarm) async {
    final result = await _editSheet(alarm);
    if (result == null || !mounted) return;
    final current = _alarms ?? const <Alarm>[];
    if (result.alarmId < 0) {
      await _commit(current.where((a) => a.alarmId != alarm.alarmId).toList());
    } else {
      await _commit([for (final a in current) a.alarmId == alarm.alarmId ? result : a]);
    }
  }

  Future<void> _toggle(Alarm alarm, bool on) async {
    final current = _alarms ?? const <Alarm>[];
    await _commit([for (final a in current) a.alarmId == alarm.alarmId ? a.copyWith(isOpen: on) : a]);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final alarms = _alarms;
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, s.smartRingAlarms, actions: [
        IconButton(
          icon: Icon(Icons.add, color: alarms == null || _saving ? AppColors.kb1b1b1 : AppColors.k010101),
          onPressed: alarms == null || _saving ? null : () => unawaited(_add()),
        ),
      ]),
      body: Stack(children: [
        if (alarms == null)
          Center(
            child: _failed
                ? TextButton(onPressed: () => unawaited(_load()), child: Text(s.retry, style: GoogleFonts.rubik(color: AppColors.k0cbcc5)))
                : CircularProgressIndicator(color: AppColors.k0cbcc5),
          )
        else
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (alarms.isEmpty)
                familyCard(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  child: Column(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: AppColors.k0cbcc5.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.alarm, color: AppColors.k0cbcc5, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(s.smartRingAlarmsNone, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13)),
                    const SizedBox(height: 14),
                    familyFilledButton(s.smartRingAddAlarm, icon: Icons.add, onPressed: _saving ? null : () => unawaited(_add())),
                  ]),
                )
              else
                familyCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: Column(children: [
                    for (var i = 0; i < alarms.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 4, color: AppColors.kf4f4f4),
                      _row(context, alarms[i]),
                    ],
                  ]),
                ),
              const SizedBox(height: 12),
              Text(s.smartRingAlarmHint, textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11)),
            ],
          ),
        if (_saving)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2, color: AppColors.k0cbcc5, backgroundColor: Colors.transparent),
          ),
      ]),
    );
  }

  Widget _row(BuildContext context, Alarm a) {
    final on = a.isOpen;
    return InkWell(
      onTap: _saving ? null : () => unawaited(_edit(a)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_timeText(a), style: GoogleFonts.rubik(
                color: on ? AppColors.k010101 : AppColors.kb1b1b1,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                height: 1.1,
              )),
              const SizedBox(height: 2),
              Text(repeatText(context, a.repeats), style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
            ],
          )),
          Switch.adaptive(
            value: on,
            activeColor: AppColors.k0cbcc5,
            onChanged: _saving ? null : (v) => unawaited(_toggle(a, v)),
          ),
        ]),
      ),
    );
  }

  static String _timeText(Alarm a) =>
      '${a.startHour.toString().padLeft(2, '0')}:${a.startMin.toString().padLeft(2, '0')}';

  /// 重复文案：全选「每天」、全不选「仅一次」、否则列出星期（本地化缩写，周日开头与 SDK 一致）。
  static String repeatText(BuildContext context, List<int> repeats) {
    final s = S.of(context);
    final on = [for (var i = 0; i < 7 && i < repeats.length; i++) if (repeats[i] == 1) i];
    if (on.isEmpty) return s.smartRingAlarmOnce;
    if (on.length == 7) return s.smartRingAlarmEveryDay;
    return on.map((i) => DateFormat.E().format(DateTime(2023, 1, 1 + i))).join(' ');
  }

  /// 新建 / 编辑弹层：时间 + 重复星期；编辑时可删除（返回 alarmId = -1 表示删除）。
  Future<Alarm?> _editSheet(Alarm? initial) {
    final s = S.of(context);
    var hour = initial?.startHour ?? TimeOfDay.now().hour;
    var minute = initial?.startMin ?? 0;
    final repeats = List<int>.from(initial?.repeats ?? const [1, 1, 1, 1, 1, 1, 1]);
    while (repeats.length < 7) {
      repeats.add(0);
    }
    return showModalBottomSheet<Alarm>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        final time = TimeOfDay(hour: hour, minute: minute);
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(context).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.kb1b1b1.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 18),
            Row(children: [
              familyIconTile(Icons.alarm, AppColors.k0cbcc5, size: 44),
              const SizedBox(width: 12),
              Expanded(child: Text(initial == null ? s.smartRingAddAlarm : s.smartRingAlarms,
                  style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 17, fontWeight: FontWeight.w600))),
              if (initial != null)
                TextButton(
                  onPressed: () => Navigator.pop(context, initial.copyWith(alarmId: -1)),
                  child: Text(s.smartRingDeleteAlarm, style: GoogleFonts.rubik(color: AppColors.ke63030, fontSize: 12.5)),
                ),
            ]),
            const SizedBox(height: 18),
            // 时间：点开系统时间选择器
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: time,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
                if (picked != null) {
                  setSheet(() {
                    hour = picked.hour;
                    minute = picked.minute;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Text('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 40, fontWeight: FontWeight.w600, height: 1)),
                  const SizedBox(height: 6),
                  Text(s.smartRingAlarmTime, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text(s.smartRingAlarmRepeat, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (var i = 0; i < 7; i++)
                GestureDetector(
                  onTap: () => setSheet(() => repeats[i] = repeats[i] == 1 ? 0 : 1),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: repeats[i] == 1 ? AppColors.k0cbcc5 : AppColors.kf4f4f4,
                    ),
                    child: Text(
                      DateFormat.E().format(DateTime(2023, 1, 1 + i)).substring(0, 1),
                      style: GoogleFonts.rubik(
                        color: repeats[i] == 1 ? Colors.white : AppColors.k5e5e5e,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 20),
            familyFilledButton(s.confirm, onPressed: () {
              Navigator.pop(context, Alarm(
                alarmId: initial?.alarmId ?? 0,
                startHour: hour,
                startMin: minute,
                isOpen: initial?.isOpen ?? true,
                repeats: List<int>.from(repeats),
              ));
            }),
            const SizedBox(height: 10),
            familyOutlinedButton(s.cancel, onPressed: () => Navigator.pop(context)),
          ]),
        );
      }),
    );
  }
}
