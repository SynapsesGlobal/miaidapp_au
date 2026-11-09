import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/miaid_card.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';
import 'package:rwfit_ble/rwfit_ble.dart';

/// 全天监测设置：按项目开关戒指的定时自动测量，心率/体温可选 30 或 60 分钟间隔，
/// 其余固定 60 分钟（SDK 限制）。进入时从戒指读取当前配置，改动即写回戒指。
///
/// 布局：顶部渐变概览卡（已开启数量 + 说明）→ 每个项目一张卡（彩色图标、状态、开关，
/// 开启后展开间隔分段选择）→ 底部耗电提示。
class SmartRingMonitoringScreen extends StatefulWidget {
  const SmartRingMonitoringScreen({Key? key}) : super(key: key);

  @override
  State<SmartRingMonitoringScreen> createState() => _SmartRingMonitoringScreenState();
}

class _SmartRingMonitoringScreenState extends State<SmartRingMonitoringScreen> {
  static final _items = <_MonitorItem>[
    _MonitorItem(RealtimeMetric.hr, Icons.favorite, AppColors.ke63030),
    _MonitorItem(RealtimeMetric.bloodOxy, Icons.water_drop, AppColors.k30bee6),
    _MonitorItem(RealtimeMetric.temperature, Icons.thermostat, AppColors.ke68c30),
    _MonitorItem(RealtimeMetric.hrv, Icons.monitor_heart, AppColors.k5251f7),
    _MonitorItem(RealtimeMetric.pressure, Icons.self_improvement, AppColors.k0CC58F),
    _MonitorItem(RealtimeMetric.bloodPressure, Icons.bloodtype, AppColors.ke63030),
    _MonitorItem(RealtimeMetric.bloodSugar, Icons.bubble_chart, AppColors.k0cbcc5),
  ];

  final SmartRingService _ring = SmartRingService.instance;
  final Map<RealtimeMetric, TimedConfig> _configs = {};
  final Set<RealtimeMetric> _saving = {};
  bool _loading = true;
  bool _loadFailed = false;

  List<_MonitorItem> get _supportedItems =>
      _items.where((item) => _ring.capabilities.supportsTimed(item.metric)).toList();

  int get _enabledCount => _supportedItems.where((i) => _configs[i.metric]?.isOpen ?? false).length;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      // 逐项读取：SDK 内部按队列串行执行，顺序读取便于定位哪一项失败
      for (final item in _supportedItems) {
        final config = await _ring.getTimedConfig(item.metric);
        if (!mounted) return;
        setState(() => _configs[item.metric] = config);
      }
    } catch (e) {
      debugPrint('SmartRing: load timed config failed: $e');
      if (!mounted) return;
      setState(() => _loadFailed = true);
      unawaited(HttpExceptionNotifyUser.showInfo(
        _ring.isConnected ? S.of(context).smartRingSettingsLoadFailed : S.of(context).smartRingConnectFailed,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply(RealtimeMetric metric, {required bool enabled, required int interval}) async {
    final previous = _configs[metric];
    setState(() {
      _saving.add(metric);
      // 先乐观更新，失败再回滚
      _configs[metric] = (previous ?? const TimedConfig(isOpen: false)).copyWith(isOpen: enabled, duration: interval);
    });
    try {
      await _ring.setTimedConfig(metric, enabled: enabled, intervalMinutes: interval);
    } catch (e) {
      debugPrint('SmartRing: set timed config failed: $e');
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          _configs.remove(metric);
        } else {
          _configs[metric] = previous;
        }
      });
      unawaited(HttpExceptionNotifyUser.showInfo(
        _ring.isConnected ? S.of(context).smartRingSettingFailed : S.of(context).smartRingConnectFailed,
      ));
    } finally {
      if (mounted) setState(() => _saving.remove(metric));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
        ),
        title: Text(s.smartRingAllDayMonitoring, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        )),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _loading ? AppColors.kb1b1b1 : AppColors.k010101),
            onPressed: _loading ? null : () => unawaited(_load()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _ring,
        builder: (context, _) {
          final items = _supportedItems;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _overviewCard(context, items.length),
                const SizedBox(height: 20),
                if (_loading && _configs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(children: [
                      CircularProgressIndicator(color: AppColors.k0cbcc5),
                      const SizedBox(height: 14),
                      Text(s.smartRingReadingSettings,
                          style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
                    ]),
                  )
                else ...[
                  for (final item in items) ...[
                    _itemCard(context, item),
                    const SizedBox(height: 12),
                  ],
                  if (_loadFailed || !_ring.isConnected)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.bluetooth_disabled, size: 14, color: AppColors.ke68c30),
                        const SizedBox(width: 6),
                        Flexible(child: Text(
                          _ring.isConnected ? s.smartRingSettingsLoadFailed : s.smartRingNotConnectedHint,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12),
                        )),
                      ]),
                    ),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.battery_alert, size: 14, color: AppColors.kb1b1b1),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s.smartRingBatteryNote,
                        style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 11, height: 1.4))),
                  ]),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 顶部渐变概览卡：时钟图标、已开启 n/m、说明文字。
  Widget _overviewCard(BuildContext context, int total) {
    final s = S.of(context);
    final enabled = _enabledCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [AppColors.k0cbcc5, AppColors.k003f51.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: AppColors.k0cbcc5.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.schedule, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.smartRingAllDayMonitoring, style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 2),
                  Text(
                    _loading && _configs.isEmpty ? s.smartRingReadingSettings : s.smartRingEnabledCount(enabled, total),
                    style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.85), fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!(_loading && _configs.isEmpty))
              Text('$enabled', style: GoogleFonts.rubik(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                height: 1,
              )),
          ]),
          const SizedBox(height: 14),
          Text(s.smartRingAllDayHint, style: GoogleFonts.rubik(
            color: Colors.white.withOpacity(0.85),
            fontSize: 12,
            height: 1.4,
          )),
        ],
      ),
    );
  }

  Widget _itemCard(BuildContext context, _MonitorItem item) {
    final s = S.of(context);
    final config = _configs[item.metric];
    final saving = _saving.contains(item.metric);
    final enabled = config?.isOpen ?? false;
    final interval = config?.duration == 30 ? 30 : 60;
    final canChoose = SmartRingService.supportsInterval30(item.metric);
    final interactive = config != null && !saving && !_loading;

    return miAidCard(Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.color.withOpacity(enabled ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: enabled ? item.color : item.color.withOpacity(0.55), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(SmartRingFormat.metricLabel(context, item.metric), style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: config == null ? AppColors.kb1b1b1 : (enabled ? AppColors.k25d000 : AppColors.kb1b1b1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      config == null
                          ? '--'
                          : enabled
                              ? s.smartRingEveryMinutes(interval)
                              : s.smartRingOff,
                      style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12),
                    ),
                  ]),
                ],
              ),
            ),
            if (saving)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: item.color)),
              ),
            Switch.adaptive(
              value: enabled,
              activeColor: AppColors.k0cbcc5,
              onChanged: interactive
                  ? (value) => unawaited(_apply(item.metric, enabled: value, interval: interval))
                  : null,
            ),
          ]),
          if (enabled) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(height: 1, color: AppColors.kf4f4f4),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(children: [
                Text(s.smartRingInterval, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
                const Spacer(),
                if (canChoose)
                  _segmented(
                    options: const [30, 60],
                    selected: interval,
                    color: item.color,
                    enabled: interactive,
                    label: (m) => s.smartRingEveryMinutes(m),
                    onChanged: (m) => unawaited(_apply(item.metric, enabled: true, interval: m)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(8)),
                    child: Text(s.smartRingIntervalFixed, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11)),
                  ),
              ]),
            ),
          ],
        ],
      ),
    ));
  }

  /// 分段选择器（30 / 60 分钟），选中项填充该项目的主题色。
  Widget _segmented({
    required List<int> options,
    required int selected,
    required Color color,
    required bool enabled,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.kf4f4f4, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final option in options)
          GestureDetector(
            onTap: enabled && option != selected ? () => onChanged(option) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: option == selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: option == selected
                    ? [BoxShadow(color: AppColors.k003f51.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Text(label(option), style: GoogleFonts.rubik(
                color: option == selected ? color : AppColors.k8f8e94,
                fontSize: 12,
                fontWeight: option == selected ? FontWeight.w600 : FontWeight.w400,
              )),
            ),
          ),
      ]),
    );
  }
}

class _MonitorItem {
  const _MonitorItem(this.metric, this.icon, this.color);

  final RealtimeMetric metric;
  final IconData icon;
  final Color color;
}
