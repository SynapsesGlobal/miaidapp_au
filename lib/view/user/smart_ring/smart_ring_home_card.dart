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
/// 已绑定戒指时按三栏展示心率、血氧和昨晚睡眠（数据来自 [SmartRingService] 的最近快照，
/// 冷启动也能显示上次同步结果）；未绑定时显示一行引导去配对页。
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
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: TapDebouncer(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => bound ? const SmartRingScreen() : const SmartRingPairScreen(),
              ));
            },
            builder: (context, onTap) => InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.keefeff,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.k003f51.withOpacity(0.08),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: bound ? _metricsRow(context, ring) : _connectRow(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _metricsRow(BuildContext context, SmartRingService ring) {
    final s = S.of(context);
    final snap = ring.snapshot;

    // 心率栏下方显示连接状态；测量中显示「实时」
    String status;
    Color statusColor;
    if (ring.measuring == RealtimeMetric.hr) {
      status = s.smartRingLive;
      statusColor = AppColors.k25d000;
    } else if (ring.isConnected) {
      status = s.smartRingConnected;
      statusColor = AppColors.k25d000;
    } else if (ring.isConnecting) {
      status = s.smartRingConnecting;
      statusColor = AppColors.ke68c30;
    } else {
      status = s.smartRingDisconnected;
      statusColor = AppColors.k8f8e94;
    }

    final spo2 = snap.bloodOxygen;
    final sleep = snap.sleep;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _metricColumn(
            icon: Icons.monitor_heart,
            color: AppColors.ke63030,
            label: s.smartRingHeartRate,
            value: SmartRingFormat.metric(snap.heartRate),
            unit: snap.heartRate == null ? '' : 'bpm',
            statusIcon: Icons.circle,
            status: status,
            statusColor: statusColor,
          ),
          _divider(),
          _metricColumn(
            icon: Icons.water_drop,
            color: AppColors.k0cbcc5,
            label: s.smartRingSpo2,
            value: spo2 == null ? '--' : SmartRingFormat.metric(spo2) + '%',
            unit: '',
            statusIcon: Icons.schedule,
            status: spo2 == null ? s.smartRingNoData : SmartRingFormat.clock(spo2.time),
            statusColor: AppColors.k8f8e94,
          ),
          _divider(),
          _metricColumn(
            icon: Icons.nights_stay,
            color: AppColors.k5251f7,
            label: s.smartRingSleep,
            value: sleep == null ? '--' : SmartRingFormat.hoursMinutes(sleep.totalMinutes),
            unit: '',
            statusIcon: Icons.bedtime,
            status: sleep == null ? s.smartRingNoData : s.smartRingLastNight,
            statusColor: AppColors.k5251f7,
          ),
          Icon(Icons.chevron_right, color: AppColors.k8f8e94, size: 20),
        ],
      ),
    );
  }

  Widget _connectRow(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.k0cbcc5,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.donut_large, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.smartRing, style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 2),
              Text(s.smartRingHomeHint, style: GoogleFonts.rubik(
                color: AppColors.k8f8e94,
                fontSize: 11,
              ), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(s.smartRingConnect, style: GoogleFonts.rubik(
          color: AppColors.k0cbcc5,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        )),
        Icon(Icons.chevron_right, color: AppColors.k8f8e94, size: 20),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: AppColors.k0cbcc5.withOpacity(0.2),
    );
  }

  Widget _metricColumn({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String unit,
    required IconData statusIcon,
    required String status,
    required Color statusColor,
  }) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(children: [
                    TextSpan(text: value, style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    )),
                    if (unit.isNotEmpty)
                      TextSpan(text: ' ' + unit, style: GoogleFonts.rubik(
                        color: AppColors.k5e5e5e,
                        fontSize: 10,
                      )),
                  ]),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(statusIcon, color: statusColor, size: 7),
                  const SizedBox(width: 3),
                  Flexible(child: Text(status, style: GoogleFonts.rubik(color: statusColor, fontSize: 9),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
