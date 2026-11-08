import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/miaid_card.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';
import 'package:rwfit_ble/rwfit_ble.dart';

/// 全天监测设置：按项目开关戒指的定时自动测量，心率/体温可选 30 或 60 分钟间隔，
/// 其余固定 60 分钟（SDK 限制）。进入时从戒指读取当前配置，改动即写回戒指。
class SmartRingMonitoringScreen extends StatefulWidget {
  const SmartRingMonitoringScreen({Key? key}) : super(key: key);

  @override
  State<SmartRingMonitoringScreen> createState() => _SmartRingMonitoringScreenState();
}

class _SmartRingMonitoringScreenState extends State<SmartRingMonitoringScreen> {
  static const _items = <_MonitorItem>[
    _MonitorItem(RealtimeMetric.hr, Icons.favorite),
    _MonitorItem(RealtimeMetric.bloodOxy, Icons.water_drop),
    _MonitorItem(RealtimeMetric.temperature, Icons.thermostat),
    _MonitorItem(RealtimeMetric.hrv, Icons.monitor_heart),
  ];

  final SmartRingService _ring = SmartRingService.instance;
  final Map<RealtimeMetric, TimedConfig> _configs = {};
  final Set<RealtimeMetric> _saving = {};
  bool _loading = true;
  bool _loadFailed = false;

  List<_MonitorItem> get _supportedItems =>
      _items.where((item) => _ring.capabilities.supportsRealtime(item.metric)).toList();

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
        iconTheme: IconThemeData(color: AppColors.k010101),
        title: Text(s.smartRingAllDayMonitoring, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        )),
        centerTitle: true,
        actions: [
          if (!_loading)
            IconButton(
              icon: Icon(Icons.refresh, color: AppColors.k010101),
              onPressed: () => unawaited(_load()),
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
                Text(s.smartRingAllDayHint, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
                const SizedBox(height: 16),
                if (_loading && _configs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  for (final item in items) ...[
                    _itemCard(context, item),
                    const SizedBox(height: 12),
                  ],
                  if (_loadFailed || !_ring.isConnected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _ring.isConnected ? s.smartRingSettingsLoadFailed : s.smartRingNotConnectedHint,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          Row(children: [
            Icon(item.icon, color: AppColors.k0cbcc5, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(SmartRingFormat.metricLabel(context, item.metric), style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 2),
                  Text(
                    config == null
                        ? '--'
                        : enabled
                            ? s.smartRingEveryMinutes(interval)
                            : s.smartRingOff,
                    style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (saving)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            Switch(
              value: enabled,
              activeColor: AppColors.k0cbcc5,
              onChanged: interactive
                  ? (value) => unawaited(_apply(item.metric, enabled: value, interval: interval))
                  : null,
            ),
          ]),
          if (enabled && canChoose) ...[
            Divider(height: 1, color: AppColors.kf4f4f4),
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 30),
              for (final minutes in const [30, 60]) ...[
                ChoiceChip(
                  label: Text(s.smartRingEveryMinutes(minutes), style: GoogleFonts.rubik(
                    fontSize: 12,
                    color: interval == minutes ? Colors.white : AppColors.k010101,
                  )),
                  selected: interval == minutes,
                  selectedColor: AppColors.k0cbcc5,
                  backgroundColor: AppColors.kf4f4f4,
                  onSelected: interactive && interval != minutes
                      ? (_) => unawaited(_apply(item.metric, enabled: true, interval: minutes))
                      : null,
                ),
                const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 4),
          ],
        ],
      ),
    ));
  }
}

class _MonitorItem {
  const _MonitorItem(this.metric, this.icon);

  final RealtimeMetric metric;
  final IconData icon;
}
