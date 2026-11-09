import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_pair_screen.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_screen.dart';
import 'package:rwfit_ble/rwfit_ble.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

/// 首页的智能戒指入口卡片，放在四个服务卡片下方。
///
/// 已绑定：渐变「设备卡」，头部是戒指名、连接状态与电量，下方三格最近读数
/// （按能力表从心率、血氧、睡眠、步数、体温里取前三项），底部一行上次同步时间。
/// 未绑定：白色引导卡，渐变圆形戒指图标 + 文案 + 「去连接」胶囊按钮。
/// 数据来自 [SmartRingService] 的最近快照，冷启动也能显示上次同步结果。
class SmartRingHomeCard extends StatelessWidget {
  const SmartRingHomeCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ring = SmartRingService.instance;
    return ListenableBuilder(
      listenable: ring,
      builder: (context, _) {
        final bound = ring.isBound;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TapDebouncer(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => bound ? const SmartRingScreen() : const SmartRingPairScreen(),
              ));
            },
            builder: (context, onTap) => GestureDetector(
              onTap: onTap,
              child: bound ? _boundCard(context, ring) : _connectCard(context),
            ),
          ),
        );
      },
    );
  }

  // ---------------- 已绑定 ----------------

  Widget _boundCard(BuildContext context, SmartRingService ring) {
    final s = S.of(context);
    final snap = ring.snapshot;
    final battery = ring.battery;

    String status;
    Color dot;
    if (ring.measuring != null) {
      status = s.smartRingLive;
      dot = AppColors.k25d000;
    } else if (ring.isConnected) {
      status = s.smartRingConnected;
      dot = AppColors.k25d000;
    } else if (ring.isConnecting) {
      status = s.smartRingConnecting;
      dot = AppColors.ke68c30;
    } else {
      status = s.smartRingDisconnected;
      dot = Colors.white.withOpacity(0.6);
    }
    final lastSync = snap.lastSyncAt;
    final syncText = lastSync == null ? s.smartRingNotSynced : s.smartRingLastSync(SmartRingFormat.dateTime(context, lastSync));
    final tiles = _statTiles(context, ring).take(3).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [AppColors.k0cbcc5, AppColors.k003f51.withOpacity(0.88)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: AppColors.k0cbcc5.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.donut_large, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ring.displayName, style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
                    const SizedBox(width: 5),
                    Flexible(child: Text(status, style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.85), fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
            if (battery != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_batteryIcon(battery), color: Colors.white, size: 14),
                  const SizedBox(width: 3),
                  Text('$battery%', style: GoogleFonts.rubik(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.8), size: 20),
          ]),
          if (tiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: tiles[i]),
              ],
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.sync, color: Colors.white.withOpacity(0.7), size: 12),
            const SizedBox(width: 4),
            Expanded(child: Text(syncText, style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.7), fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ),
    );
  }

  /// 候选读数格，按能力表过滤；调用方取前三个。
  List<Widget> _statTiles(BuildContext context, SmartRingService ring) {
    final s = S.of(context);
    final snap = ring.snapshot;
    final caps = ring.capabilities;
    final sleep = snap.sleep;
    final steps = snap.steps;
    return [
      if (caps.heartRate)
        _statTile(
          icon: Icons.favorite,
          label: s.smartRingHeartRate,
          value: SmartRingFormat.metric(snap.heartRate),
          unit: 'bpm',
          hasValue: snap.heartRate != null,
          pulsing: ring.measuring == RealtimeMetric.hr,
        ),
      if (caps.bloodOxygen)
        _statTile(
          icon: Icons.water_drop,
          label: s.smartRingSpo2,
          value: SmartRingFormat.metric(snap.bloodOxygen),
          unit: '%',
          hasValue: snap.bloodOxygen != null,
          pulsing: ring.measuring == RealtimeMetric.bloodOxy,
        ),
      if (caps.sleep)
        _statTile(
          icon: Icons.bedtime,
          label: s.smartRingSleep,
          value: sleep == null ? '--' : SmartRingFormat.hoursMinutes(sleep.totalMinutes),
          unit: '',
          hasValue: sleep != null,
        ),
      if (caps.steps)
        _statTile(
          icon: Icons.directions_walk,
          label: s.smartRingSteps,
          value: steps == null ? '--' : SmartRingFormat.thousands(steps.steps),
          unit: '',
          hasValue: steps != null,
        ),
      if (caps.temperature)
        _statTile(
          icon: Icons.thermostat,
          label: s.smartRingTemperature,
          value: SmartRingFormat.metric(snap.temperature, decimals: 1),
          unit: '°C',
          hasValue: snap.temperature != null,
          pulsing: ring.measuring == RealtimeMetric.temperature,
        ),
    ];
  }

  Widget _statTile({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required bool hasValue,
    bool pulsing = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 13),
            const SizedBox(width: 4),
            Expanded(child: Text(label, style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.8), fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (pulsing)
              const SizedBox(width: 9, height: 9, child: CircularProgressIndicator(strokeWidth: 1.2, color: Colors.white)),
          ]),
          const SizedBox(height: 5),
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(children: [
              TextSpan(text: value, style: GoogleFonts.rubik(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                height: 1,
              )),
              if (hasValue && unit.isNotEmpty)
                TextSpan(text: ' $unit', style: GoogleFonts.rubik(color: Colors.white.withOpacity(0.75), fontSize: 10)),
            ]),
          ),
        ],
      ),
    );
  }

  static IconData _batteryIcon(int level) {
    if (level >= 90) return Icons.battery_full;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 30) return Icons.battery_3_bar;
    if (level >= 15) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  // ---------------- 未绑定 ----------------

  Widget _connectCard(BuildContext context) {
    final s = S.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.k003f51.withOpacity(0.12), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.k0cbcc5, AppColors.k0CC58F],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: AppColors.k0cbcc5.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.donut_large, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.smartRing, style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: 3),
                Text(s.smartRingHomeHint, style: GoogleFonts.rubik(
                  color: AppColors.k8f8e94,
                  fontSize: 11,
                  height: 1.3,
                ), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: AppColors.k0cbcc5, borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(s.smartRingConnect, style: GoogleFonts.rubik(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, color: Colors.white, size: 16),
            ]),
          ),
        ],
      ),
    );
  }
}
