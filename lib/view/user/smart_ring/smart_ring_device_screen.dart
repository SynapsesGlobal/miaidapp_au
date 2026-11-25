import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/ring_device_sync.dart';
import 'package:miaid/services/smart_ring_models.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_alarms_screen.dart';
import 'package:rwfit_ble/rwfit_ble.dart';

/// 戒指设置：把 SDK 里对老人看护有用的设备功能集中到一页。
///
/// 一张卡片按顺序列出：跌倒检测、来电提醒、戒指端震动报警、用药闹钟、久坐、喝水、佩戴手、震动、LED、
/// 亮屏、抬腕、震动测试、查找戒指、心率校正、固件更新。不支持的项目按功能表隐藏，不分组。
/// 进入时逐项从戒指读取当前值，改动即写回。
class SmartRingDeviceScreen extends StatefulWidget {
  const SmartRingDeviceScreen({Key? key}) : super(key: key);

  @override
  State<SmartRingDeviceScreen> createState() => _SmartRingDeviceScreenState();
}

class _SmartRingDeviceScreenState extends State<SmartRingDeviceScreen> {
  final SmartRingService _ring = SmartRingService.instance;

  bool? _fallDetect;
  ReminderConfig? _sedentary;
  ReminderConfig? _drink;
  bool? _rightHand;
  VibrationConfig? _vibration;
  LedLevel? _led;
  int? _screenSeconds;
  ScheduleToggle? _raise;

  bool _loading = true;
  final Set<String> _saving = {};
  bool _checkingFirmware = false;

  RingCapabilities get _caps => _ring.capabilities;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// 逐项读取（SDK 内部串行），某一项失败不影响其它项，保持 null 显示「--」。
  Future<void> _load() async {
    setState(() => _loading = true);
    Future<void> read(String name, bool supported, Future<void> Function() action) async {
      if (!supported) return;
      try {
        await action();
      } catch (e) {
        debugPrint('SmartRing: read $name failed: $e');
      }
      if (mounted) setState(() {});
    }

    try {
      await read('fallDetect', _caps.fallDetect, () async => _fallDetect = await _ring.getFallDetect());
      await read('sedentary', _caps.sedentary, () async => _sedentary = await _ring.getSedentaryReminder());
      await read('drink', _caps.drink, () async => _drink = await _ring.getDrinkReminder());
      await read('wearHand', _caps.wearDirection, () async => _rightHand = await _ring.getWearRightHand());
      // 震动次数 / 强度走的是「马达等级」命令，没有 isSupportMotoVibrationLevel 的戒指读写都会被拒（错误 3 / 6）
      await read('vibration', _caps.vibrationLevel, () async => _vibration = await _ring.getVibration());
      await read('led', _caps.ledLight, () async => _led = await _ring.getLed());
      await read('screenTime', _caps.brightScreenTime, () async => _screenSeconds = await _ring.getBrightScreenSeconds());
      await read('raise', _caps.raiseBrightScreen, () async => _raise = await _ring.getRaiseBrightScreen());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 写回一项：先乐观更新，失败回滚并提示。
  Future<void> _apply(String key, Future<void> Function() write, {required VoidCallback rollback}) async {
    setState(() => _saving.add(key));
    try {
      await write();
    } catch (e) {
      debugPrint('SmartRing: set $key failed: $e');
      if (!mounted) return;
      setState(rollback);
      unawaited(HttpExceptionNotifyUser.showInfo(
        _ring.isConnected ? S.of(context).smartRingSettingFailed : S.of(context).smartRingConnectFailed,
      ));
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, s.smartRingDeviceSettings, actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: _loading ? AppColors.kb1b1b1 : AppColors.k010101),
          onPressed: _loading ? null : () => unawaited(_load()),
        ),
      ]),
      body: ListenableBuilder(
        listenable: _ring,
        builder: (context, _) => Stack(children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_ring.isConnected) ...[
                  _notConnectedHint(context),
                  const SizedBox(height: 12),
                ],
                _card([
                  if (_caps.fallDetect)
                    _switchRow(
                      icon: Icons.personal_injury,
                      color: AppColors.ke63030,
                      title: s.smartRingFallDetect,
                      subtitle: s.smartRingFallDetectDesc,
                      value: _fallDetect,
                      saving: _saving.contains('fall'),
                      onChanged: (v) {
                        final prev = _fallDetect;
                        setState(() => _fallDetect = v);
                        unawaited(_apply('fall', () => _ring.setFallDetect(v), rollback: () => _fallDetect = prev));
                      },
                    ),
                  _switchRow(
                    icon: Icons.phone_in_talk,
                    color: AppColors.k0cbcc5,
                    title: s.smartRingCallAlert,
                    subtitle: s.smartRingCallAlertDesc,
                    value: _ring.callAlertEnabled,
                    saving: _saving.contains('call'),
                    onChanged: (v) => unawaited(_apply('call', () => _ring.setCallAlertEnabled(v), rollback: () {})),
                  ),
                  if (_caps.heartRateAlert || _caps.bloodOxygenAlert) _ringAlarmRow(context),

                  if (_caps.alarm)
                    _navRow(
                      icon: Icons.alarm,
                      color: AppColors.k5251f7,
                      title: s.smartRingAlarms,
                      subtitle: s.smartRingAlarmsDesc,
                      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (context) => const SmartRingAlarmsScreen())),
                    ),
                  if (_caps.sedentary)
                    _navRow(
                      icon: Icons.airline_seat_recline_normal,
                      color: AppColors.ke68c30,
                      title: s.smartRingSedentary,
                      subtitle: _reminderSummary(context, _sedentary),
                      saving: _saving.contains('sedentary'),
                      onTap: () => unawaited(_editReminder(context, 'sedentary', s.smartRingSedentary, s.smartRingSedentaryDesc, _sedentary,
                          (c) => _ring.setSedentaryReminder(c), (c) => _sedentary = c)),
                    ),
                  if (_caps.drink)
                    _navRow(
                      icon: Icons.local_drink,
                      color: AppColors.k30bee6,
                      title: s.smartRingDrink,
                      subtitle: _reminderSummary(context, _drink),
                      saving: _saving.contains('drink'),
                      onTap: () => unawaited(_editReminder(context, 'drink', s.smartRingDrink, s.smartRingDrinkDesc, _drink,
                          (c) => _ring.setDrinkReminder(c), (c) => _drink = c)),
                    ),

                  if (_caps.wearDirection) _wearHandRow(context),
                  if (_caps.vibrationLevel)
                    _navRow(
                      icon: Icons.vibration,
                      color: AppColors.ke68c30,
                      title: s.smartRingVibration,
                      subtitle: _vibration == null
                          ? '--'
                          : (_vibration!.count == 0 ? s.smartRingOff : '${_vibrationLevelText(context, _vibration!.level)} · ×${_vibration!.count}'),
                      saving: _saving.contains('vibration'),
                      onTap: () => unawaited(_editVibration(context)),
                    ),
                  if (_caps.ledLight)
                    _navRow(
                      icon: Icons.light_mode,
                      color: AppColors.ke68c30,
                      title: s.smartRingLed,
                      subtitle: _led == null ? '--' : (_led!.isOpen ? _ledLevelText(context, _led!.lcdLevel) : s.smartRingOff),
                      saving: _saving.contains('led'),
                      onTap: () => unawaited(_editLed(context)),
                    ),
                  if (_caps.brightScreenTime)
                    _navRow(
                      icon: Icons.timer_outlined,
                      color: AppColors.k0cbcc5,
                      title: s.smartRingScreenTime,
                      subtitle: _screenSeconds == null ? '--' : s.smartRingSeconds(_screenSeconds!),
                      saving: _saving.contains('screen'),
                      onTap: () => unawaited(_editScreenTime(context)),
                    ),
                  if (_caps.raiseBrightScreen)
                    _switchRow(
                      icon: Icons.front_hand,
                      color: AppColors.k5251f7,
                      title: s.smartRingRaiseWake,
                      subtitle: null,
                      value: _raise?.isOpen,
                      saving: _saving.contains('raise'),
                      onChanged: (v) {
                        final prev = _raise;
                        final base = prev ?? const ScheduleToggle(isOpen: false);
                        final next = ScheduleToggle(
                          isOpen: v,
                          startHour: base.startHour,
                          startMin: base.startMin,
                          endHour: base.endHour,
                          endMin: base.endMin,
                        );
                        setState(() => _raise = next);
                        unawaited(_apply('raise', () => _ring.setRaiseBrightScreen(next), rollback: () => _raise = prev));
                      },
                    ),

                  _navRow(
                    icon: Icons.vibration,
                    color: AppColors.ke68c30,
                    title: s.smartRingVibrateTest,
                    subtitle: s.smartRingVibrateTestDesc,
                    saving: _saving.contains('vibrate'),
                    onTap: () => unawaited(_apply('vibrate', () async {
                      final reason = await _ring.vibrate(count: 3, strength: 3);
                      final text = reason == null
                          ? s.smartRingVibrateSent
                          : reason == 'unsupported'
                              ? s.smartRingVibrateUnsupported
                              : reason == 'disconnected'
                                  ? s.smartRingConnectFailed
                                  : s.smartRingVibrateFailed(reason);
                      unawaited(HttpExceptionNotifyUser.showInfo(text));
                    }, rollback: () {})),
                  ),
                  if (_caps.findDevice)
                    _navRow(
                      icon: Icons.search,
                      color: AppColors.k25d000,
                      title: s.smartRingFindDevice,
                      subtitle: s.smartRingFindDeviceDesc,
                      saving: _saving.contains('find'),
                      onTap: () => unawaited(_apply('find', () async {
                        await _ring.findDevice();
                        unawaited(HttpExceptionNotifyUser.showInfo(s.smartRingFindDeviceSent));
                      }, rollback: () {})),
                    ),
                  _navRow(
                    icon: Icons.favorite_border,
                    color: AppColors.ke63030,
                    title: s.smartRingCalibrate,
                    subtitle: _ring.calibrating ? s.smartRingCalibrating : s.smartRingCalibrateDesc,
                    saving: _ring.calibrating,
                    onTap: () => unawaited(_calibrate(context)),
                  ),
                  _navRow(
                    icon: Icons.system_update,
                    color: AppColors.k5251f7,
                    title: s.smartRingFirmware,
                    subtitle: _firmwareSubtitle(context),
                    saving: _checkingFirmware || _ring.otaProgress != null,
                    onTap: () => unawaited(_checkFirmware(context)),
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (_loading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2, color: AppColors.k0cbcc5, backgroundColor: Colors.transparent),
            ),
        ]),
      ),
    );
  }

  // ---------------- 行组件 ----------------

  Widget _card(List<Widget> rows) {
    final visible = rows.where((w) => w is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return familyCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 50, color: AppColors.kf4f4f4),
          visible[i],
        ],
      ]),
    );
  }

  Widget _rowShell({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required Widget trailing,
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
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12, height: 1.3)),
              ],
            ],
          )),
          const SizedBox(width: 8),
          trailing,
        ]),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required Color color,
    required String title,
    required String? subtitle,
    required bool? value,
    required bool saving,
    required ValueChanged<bool> onChanged,
  }) {
    return _rowShell(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (saving) _spinner(color),
        Switch.adaptive(
          value: value ?? false,
          activeColor: AppColors.k0cbcc5,
          onChanged: value == null || saving ? null : onChanged,
        ),
      ]),
    );
  }

  Widget _navRow({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    bool saving = false,
    required VoidCallback onTap,
  }) {
    return _rowShell(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      onTap: saving ? null : onTap,
      trailing: saving ? _spinner(color) : Icon(Icons.chevron_right, color: AppColors.kb1b1b1, size: 20),
    );
  }

  Widget _spinner(Color color) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
      );

  Widget _notConnectedHint(BuildContext context) {
    final s = S.of(context);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.bluetooth_disabled, size: 14, color: AppColors.ke68c30),
      const SizedBox(width: 6),
      Flexible(child: Text(s.smartRingNotConnectedHint, textAlign: TextAlign.center,
          style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12))),
    ]);
  }

  /// 戒指端震动报警：显示已写进戒指的阈值，可手动再同步一次。
  Widget _ringAlarmRow(BuildContext context) {
    final s = S.of(context);
    final cfg = _ring.alertConfig;
    final subtitle = cfg == null || !cfg.enabled
        ? s.smartRingRingAlarmNotSynced
        : s.smartRingRingAlarmSynced('${cfg.hrLow ?? '--'}', '${cfg.hrHigh ?? '--'}', '${cfg.spo2Low ?? '--'}');
    return _rowShell(
      icon: Icons.notifications_active_outlined,
      color: AppColors.ke68c30,
      title: s.smartRingRingAlarm,
      subtitle: '${s.smartRingRingAlarmDesc}\n$subtitle',
      trailing: _saving.contains('alarmSync')
          ? _spinner(AppColors.ke68c30)
          : TextButton(
              onPressed: () => unawaited(_apply('alarmSync', () async {
                await RingDeviceSync.instance.sync();
                final c = _ring.alertConfig;
                if (c != null) await _ring.applyAlertConfig(c, force: true);
              }, rollback: () {})),
              child: Text(s.smartRingSyncNow, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 12.5)),
            ),
    );
  }

  Widget _wearHandRow(BuildContext context) {
    final s = S.of(context);
    final right = _rightHand;
    return _rowShell(
      icon: Icons.back_hand,
      color: AppColors.k0cbcc5,
      title: s.smartRingWearHand,
      trailing: _saving.contains('hand')
          ? _spinner(AppColors.k0cbcc5)
          : _segmented<bool>(
              options: const [false, true],
              selected: right,
              label: (v) => v ? s.smartRingRightHand : s.smartRingLeftHand,
              onChanged: (v) {
                final prev = _rightHand;
                setState(() => _rightHand = v);
                unawaited(_apply('hand', () => _ring.setWearRightHand(v), rollback: () => _rightHand = prev));
              },
            ),
    );
  }

  Widget _segmented<T>({
    required List<T> options,
    required T? selected,
    required String Function(T) label,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final o in options)
          GestureDetector(
            onTap: o == selected ? null : () => onChanged(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: o == selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: o == selected
                    ? [BoxShadow(color: AppColors.k003f51.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Text(label(o), style: GoogleFonts.rubik(
                color: o == selected ? AppColors.k0cbcc5 : AppColors.k8f8e94,
                fontSize: 12,
                fontWeight: o == selected ? FontWeight.w600 : FontWeight.w400,
              )),
            ),
          ),
      ]),
    );
  }

  // ---------------- 文案 ----------------

  String _reminderSummary(BuildContext context, ReminderConfig? c) {
    final s = S.of(context);
    if (c == null) return '--';
    if (!c.isOpen) return s.smartRingOff;
    return '${s.smartRingEveryMinutes(c.intervalMinutes)} · ${_hm(c.startHour, c.startMin)}–${_hm(c.endHour, c.endMin)}';
  }

  static String _hm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  String _vibrationLevelText(BuildContext context, int level) {
    final s = S.of(context);
    switch (level) {
      case 0:
        return s.smartRingOff;
      case 1:
        return s.smartRingVibrationLow;
      case 2:
        return s.smartRingVibrationMedium;
      default:
        return s.smartRingVibrationHigh;
    }
  }

  String _ledLevelText(BuildContext context, int level) {
    final s = S.of(context);
    switch (level) {
      case 1:
        return s.smartRingLedLow;
      case 2:
        return s.smartRingLedMedium;
      default:
        return s.smartRingLedHigh;
    }
  }

  String _firmwareSubtitle(BuildContext context) {
    final s = S.of(context);
    final progress = _ring.otaProgress;
    if (progress != null) return s.smartRingFirmwareInstalling((progress * 100).round());
    if (_checkingFirmware) return s.smartRingFirmwareChecking;
    final fw = _ring.firmware;
    return fw == null || fw.deviceNo.isEmpty ? s.smartRingFirmwareDesc : s.smartRingFirmwareCurrent(fw.deviceNo);
  }

  // ---------------- 弹层 ----------------

  Widget _sheetShell(BuildContext context, {required IconData icon, required Color color, required String title, String? desc, required List<Widget> children}) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
          familyIconTile(icon, color, size: 44),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 17, fontWeight: FontWeight.w600)),
            if (desc != null) ...[
              const SizedBox(height: 2),
              Text(desc, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5, height: 1.3)),
            ],
          ])),
        ]),
        const SizedBox(height: 16),
        Flexible(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))),
      ]),
    );
  }

  Widget _chips<T>({
    required List<T> options,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
    Color? color,
  }) {
    final c = color ?? AppColors.k0cbcc5;
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final o in options)
        ChoiceChip(
          label: Text(label(o)),
          selected: o == selected,
          selectedColor: c.withOpacity(0.15),
          backgroundColor: AppColors.kf4f4f4,
          labelStyle: GoogleFonts.rubik(
            color: o == selected ? c : AppColors.k5e5e5e,
            fontSize: 13,
            fontWeight: o == selected ? FontWeight.w600 : FontWeight.w400,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: BorderSide.none,
          onSelected: (_) => onSelected(o),
        ),
    ]);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 6),
        child: Text(text, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 12.5)),
      );

  /// 久坐 / 喝水：开关 + 间隔 + 时段。
  Future<void> _editReminder(
    BuildContext context,
    String key,
    String title,
    String desc,
    ReminderConfig? current,
    Future<void> Function(ReminderConfig) write,
    void Function(ReminderConfig) assign,
  ) async {
    final s = S.of(context);
    var cfg = current ?? const ReminderConfig(isOpen: false, intervalMinutes: 60, startHour: 9, startMin: 0, endHour: 18, endMin: 0);
    final result = await showModalBottomSheet<ReminderConfig>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        Future<void> pick(bool start) async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: start ? cfg.startHour : cfg.endHour, minute: start ? cfg.startMin : cfg.endMin),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child ?? const SizedBox.shrink(),
            ),
          );
          if (picked == null) return;
          setSheet(() => cfg = start
              ? cfg.copyWith(startHour: picked.hour, startMin: picked.minute)
              : cfg.copyWith(endHour: picked.hour, endMin: picked.minute));
        }

        return _sheetShell(context, icon: key == 'drink' ? Icons.local_drink : Icons.airline_seat_recline_normal,
            color: key == 'drink' ? AppColors.k30bee6 : AppColors.ke68c30, title: title, desc: desc, children: [
          Row(children: [
            Expanded(child: Text(s.familyAlertEnable, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14))),
            Switch.adaptive(value: cfg.isOpen, activeColor: AppColors.k0cbcc5, onChanged: (v) => setSheet(() => cfg = cfg.copyWith(isOpen: v))),
          ]),
          _label(s.smartRingReminderInterval),
          _chips<int>(
            options: const [30, 45, 60, 90, 120],
            selected: cfg.intervalMinutes,
            label: (m) => s.smartRingEveryMinutes(m),
            onSelected: (m) => setSheet(() => cfg = cfg.copyWith(intervalMinutes: m)),
          ),
          _label(s.smartRingReminderPeriod),
          Row(children: [
            Expanded(child: _timeButton(_hm(cfg.startHour, cfg.startMin), () => unawaited(pick(true)))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('–', style: GoogleFonts.rubik(color: AppColors.k8f8e94))),
            Expanded(child: _timeButton(_hm(cfg.endHour, cfg.endMin), () => unawaited(pick(false)))),
          ]),
          const SizedBox(height: 20),
          familyFilledButton(s.confirm, onPressed: () => Navigator.pop(context, cfg)),
          const SizedBox(height: 10),
          familyOutlinedButton(s.cancel, onPressed: () => Navigator.pop(context)),
        ]);
      }),
    );
    if (result == null || !mounted) return;
    final prev = current;
    setState(() => assign(result));
    await _apply(key, () => write(result), rollback: () {
      if (prev != null) assign(prev);
    });
  }

  Widget _timeButton(String text, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _editVibration(BuildContext context) async {
    final s = S.of(context);
    var cfg = _vibration ?? const VibrationConfig(count: 3, level: 2);
    final result = await showModalBottomSheet<VibrationConfig>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        return _sheetShell(context, icon: Icons.vibration, color: AppColors.ke68c30, title: s.smartRingVibration, children: [
          _label(s.smartRingVibration),
          _chips<int>(
            options: const [0, 1, 2, 3],
            selected: cfg.level,
            label: (l) => _vibrationLevelText(context, l),
            onSelected: (l) => setSheet(() => cfg = VibrationConfig(count: cfg.count, level: l)),
            color: AppColors.ke68c30,
          ),
          _label(s.smartRingVibrationCount),
          _chips<int>(
            options: const [0, 1, 2, 3, 4, 5, 6],
            selected: cfg.count,
            label: (n) => n == 0 ? s.smartRingOff : '×$n',
            onSelected: (n) => setSheet(() => cfg = VibrationConfig(count: n, level: cfg.level)),
            color: AppColors.ke68c30,
          ),
          const SizedBox(height: 20),
          familyFilledButton(s.confirm, onPressed: () => Navigator.pop(context, cfg)),
          const SizedBox(height: 10),
          familyOutlinedButton(s.cancel, onPressed: () => Navigator.pop(context)),
        ]);
      }),
    );
    if (result == null || !mounted) return;
    final prev = _vibration;
    setState(() => _vibration = result);
    await _apply('vibration', () => _ring.setVibration(result), rollback: () => _vibration = prev);
  }

  Future<void> _editLed(BuildContext context) async {
    final s = S.of(context);
    var cfg = _led ?? const LedLevel(isOpen: true, lcdLevel: 2);
    final result = await showModalBottomSheet<LedLevel>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        return _sheetShell(context, icon: Icons.light_mode, color: AppColors.ke68c30, title: s.smartRingLed, children: [
          Row(children: [
            Expanded(child: Text(s.familyAlertEnable, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14))),
            Switch.adaptive(value: cfg.isOpen, activeColor: AppColors.k0cbcc5, onChanged: (v) => setSheet(() => cfg = LedLevel(isOpen: v, lcdLevel: cfg.lcdLevel))),
          ]),
          _label(s.smartRingLed),
          _chips<int>(
            options: const [1, 2, 3],
            selected: cfg.lcdLevel,
            label: (l) => _ledLevelText(context, l),
            onSelected: (l) => setSheet(() => cfg = LedLevel(isOpen: cfg.isOpen, lcdLevel: l)),
            color: AppColors.ke68c30,
          ),
          const SizedBox(height: 20),
          familyFilledButton(s.confirm, onPressed: () => Navigator.pop(context, cfg)),
          const SizedBox(height: 10),
          familyOutlinedButton(s.cancel, onPressed: () => Navigator.pop(context)),
        ]);
      }),
    );
    if (result == null || !mounted) return;
    final prev = _led;
    setState(() => _led = result);
    await _apply('led', () => _ring.setLed(result), rollback: () => _led = prev);
  }

  Future<void> _editScreenTime(BuildContext context) async {
    final s = S.of(context);
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _sheetShell(context, icon: Icons.timer_outlined, color: AppColors.k0cbcc5, title: s.smartRingScreenTime, children: [
        _chips<int>(
          options: const [5, 10, 15, 20, 30],
          selected: _screenSeconds ?? -1,
          label: (sec) => s.smartRingSeconds(sec),
          onSelected: (sec) => Navigator.pop(context, sec),
        ),
        const SizedBox(height: 16),
        familyOutlinedButton(s.cancel, onPressed: () => Navigator.pop(context)),
      ]),
    );
    if (result == null || !mounted) return;
    final prev = _screenSeconds;
    setState(() => _screenSeconds = result);
    await _apply('screen', () => _ring.setBrightScreenSeconds(result), rollback: () => _screenSeconds = prev);
  }

  Future<void> _calibrate(BuildContext context) async {
    final s = S.of(context);
    try {
      await _ring.calibrateHeartRate();
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(s.smartRingCalibrateDone));
    } catch (e) {
      debugPrint('SmartRing: calibration failed: $e');
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(_ring.isConnected ? s.smartRingCalibrateFailed : s.smartRingConnectFailed));
    }
  }

  /// 固件：先查厂商接口；有新版本弹确认，确认后下载并升级，进度显示在行副标题里。
  Future<void> _checkFirmware(BuildContext context) async {
    final s = S.of(context);
    if (_ring.otaProgress != null) return;
    setState(() => _checkingFirmware = true);
    RingFirmwareUpdate? update;
    try {
      update = await _ring.checkFirmwareUpdate();
    } catch (e) {
      debugPrint('SmartRing: firmware check failed: $e');
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(s.smartRingFirmwareCheckFailed));
      if (mounted) setState(() => _checkingFirmware = false);
      return;
    }
    if (!mounted) return;
    setState(() => _checkingFirmware = false);
    if (update == null) {
      unawaited(HttpExceptionNotifyUser.showInfo(s.smartRingFirmwareLatest));
      return;
    }
    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _sheetShell(context, icon: Icons.system_update, color: AppColors.k5251f7,
          title: s.smartRingFirmwareAvailable(update!.version), desc: s.smartRingFirmwareInstallHint, children: [
        familyFilledButton(s.smartRingFirmwareInstall, onPressed: () => Navigator.pop(context, true)),
        const SizedBox(height: 10),
        familyOutlinedButton(s.cancel, onPressed: () => Navigator.pop(context, false)),
      ]),
    );
    if (go != true || !mounted) return;
    try {
      final ok = await _ring.installFirmware(update);
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(ok ? s.smartRingFirmwareDone : s.smartRingFirmwareFailed));
    } catch (e) {
      debugPrint('SmartRing: ota failed: $e');
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(s.smartRingFirmwareFailed));
    }
  }
}
