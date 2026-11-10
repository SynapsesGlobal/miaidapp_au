import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rwfit_ble/rwfit_ble.dart';

/// 戒指配对页：申请蓝牙权限 → 扫描附近戒指 → 选择一台连接，就绪后进入健康看板。
///
/// 布局：顶部渐变「雷达卡」显示扫描状态；下方「附近的戒指」列表，每台带信号强弱与连接按钮；
/// 权限被拒 / 未找到设备时用独立的状态卡替代列表；底部是「配对须知」三条提示。
class SmartRingPairScreen extends StatefulWidget {
  const SmartRingPairScreen({Key? key}) : super(key: key);

  @override
  State<SmartRingPairScreen> createState() => _SmartRingPairScreenState();
}

class _SmartRingPairScreenState extends State<SmartRingPairScreen> with SingleTickerProviderStateMixin {
  final SmartRingService _ring = SmartRingService.instance;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  bool _permissionDenied = false;

  /// 正在连接的设备标识（uuid 或 mac），用于只在对应行显示进度。
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    unawaited(_startScan());
  }

  @override
  void dispose() {
    _pulse.dispose();
    unawaited(_ring.stopScan());
    super.dispose();
  }

  Future<void> _startScan() async {
    final granted = await _ring.requestPermissions();
    if (!mounted) return;
    if (!granted) {
      setState(() => _permissionDenied = true);
      return;
    }
    setState(() => _permissionDenied = false);
    try {
      await _ring.startScan();
    } catch (e) {
      debugPrint('SmartRing: startScan failed: $e');
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(S.of(context).smartRingConnectFailed));
    }
  }

  Future<void> _connect(BleDevice device) async {
    if (_connectingId != null) return;
    setState(() => _connectingId = _id(device));
    try {
      await _ring.connect(device);
      if (!mounted) return;
      await Navigator.pushReplacement(context, MaterialPageRoute<void>(
        builder: (context) => const SmartRingScreen(),
      ));
    } catch (e) {
      debugPrint('SmartRing: connect failed: $e');
      if (mounted) unawaited(HttpExceptionNotifyUser.showInfo(S.of(context).smartRingConnectFailed));
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  static String _id(BleDevice d) => (d.uuid?.isNotEmpty ?? false) ? d.uuid! : d.mac;

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
        title: Text(s.smartRing, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        )),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: _ring,
        builder: (context, _) {
          final scanning = _ring.scanning;
          final devices = _ring.scanResults;
          final idle = !scanning && _connectingId == null;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heroCard(context, scanning: scanning, found: devices.length),
                const SizedBox(height: 20),
                if (_permissionDenied)
                  _stateCard(
                    context,
                    icon: Icons.bluetooth_disabled,
                    color: AppColors.ke63030,
                    title: s.smartRingPermissionTitle,
                    body: s.smartRingBluetoothPermission,
                    primary: _filledButton(s.smartRingOpenSettings, Icons.settings, () => unawaited(openAppSettings())),
                    secondary: _outlinedButton(s.smartRingRescan, Icons.refresh, () => unawaited(_startScan())),
                  )
                else if (devices.isEmpty && !scanning)
                  _stateCard(
                    context,
                    icon: Icons.bluetooth_searching,
                    color: AppColors.ke68c30,
                    title: s.smartRingNoDevicesTitle,
                    body: s.smartRingNoDevices,
                    primary: _filledButton(s.smartRingRescan, Icons.refresh, () => unawaited(_startScan())),
                  )
                else ...[
                  _sectionHeader(context, scanning: scanning, found: devices.length),
                  const SizedBox(height: 10),
                  for (final device in devices) ...[
                    _deviceTile(context, device),
                    const SizedBox(height: 10),
                  ],
                  if (scanning && devices.isEmpty) _scanningPlaceholder(context),
                  if (idle) ...[
                    const SizedBox(height: 6),
                    _outlinedButton(s.smartRingRescan, Icons.refresh, () => unawaited(_startScan())),
                  ],
                ],
                const SizedBox(height: 20),
                _tipsCard(context),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- 顶部雷达卡 ----------------

  Widget _heroCard(BuildContext context, {required bool scanning, required int found}) {
    final s = S.of(context);
    String title;
    String subtitle;
    if (_permissionDenied) {
      title = s.smartRingPermissionTitle;
      subtitle = s.smartRingBluetoothPermission;
    } else if (scanning) {
      title = s.smartRingScanning;
      subtitle = s.smartRingScanHint;
    } else {
      title = s.smartRingScanFinished;
      subtitle = found == 0 ? s.smartRingNoDevices : s.smartRingFoundCount(found);
    }
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      child: Column(
        children: [
          _radar(scanning && !_permissionDenied),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.rubik(
            color: Colors.white.withOpacity(0.82),
            fontSize: 12.5,
            height: 1.4,
          )),
        ],
      ),
    );
  }

  Widget _radar(bool scanning) {
    return SizedBox(
      height: 150,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // 扫描中：两圈波纹从中心向外扩散并淡出；结束后只留静止的浅色底环
              if (scanning)
                for (var i = 0; i < 2; i++)
                  Builder(builder: (context) {
                    final p = (t + i / 2) % 1;
                    final size = 72 + 78 * p;
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.55 * (1 - p)), width: 1.5),
                      ),
                    );
                  })
              else
                for (final size in [150.0, 110.0])
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.07)),
                  ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Icon(Icons.donut_large, color: AppColors.k0cbcc5, size: 34),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- 设备列表 ----------------

  Widget _sectionHeader(BuildContext context, {required bool scanning, required int found}) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [
        Expanded(child: Text(s.smartRingNearbyDevices, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ))),
        if (found > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.k0cbcc5.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(s.smartRingFoundCount(found), style: GoogleFonts.rubik(
              color: AppColors.k0cbcc5,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            )),
          ),
      ]),
    );
  }

  /// 扫描刚开始、还没有结果时的占位，避免标题下方空空一片。
  Widget _scanningPlaceholder(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.k0cbcc5.withOpacity(0.25)),
      ),
      child: Row(children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.k0cbcc5)),
        const SizedBox(width: 12),
        Expanded(child: Text(s.smartRingScanning, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13))),
      ]),
    );
  }

  Widget _deviceTile(BuildContext context, BleDevice device) {
    final s = S.of(context);
    final connecting = _connectingId == _id(device);
    final name = device.name.isNotEmpty ? device.name : 'RWFIT Ring';
    final address = device.mac.isNotEmpty ? device.mac : (device.uuid ?? '');
    final level = _signalLevel(device.rssi);
    final signalColor = level == 3 ? AppColors.k25d000 : (level == 2 ? AppColors.ke68c30 : AppColors.kb1b1b1);
    final signalText = level == 3 ? s.smartRingSignalStrong : (level == 2 ? s.smartRingSignalMedium : s.smartRingSignalWeak);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: connecting ? Border.all(color: AppColors.k0cbcc5, width: 1.2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.k0cbcc5.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.donut_large, color: AppColors.k0cbcc5, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                if (address.isNotEmpty)
                  Text(address, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11.5),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(children: [
                  _signalBars(level, signalColor),
                  const SizedBox(width: 5),
                  Text(signalText, style: GoogleFonts.rubik(color: signalColor, fontSize: 11, fontWeight: FontWeight.w500)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _connectButton(context, device, connecting: connecting),
        ],
      ),
    );
  }

  Widget _connectButton(BuildContext context, BleDevice device, {required bool connecting}) {
    final s = S.of(context);
    final enabled = _connectingId == null;
    return MaterialButton(
      onPressed: enabled ? () => unawaited(_connect(device)) : null,
      color: AppColors.k0cbcc5,
      disabledColor: AppColors.k0cbcc5.withOpacity(connecting ? 1 : 0.4),
      elevation: 0,
      height: 36,
      minWidth: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: connecting
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 8),
              Text(s.smartRingConnecting, style: GoogleFonts.rubik(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ])
          : Text(s.smartRingConnectButton, style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
    );
  }

  /// RSSI → 1..3 档信号。
  static int _signalLevel(int rssi) {
    if (rssi >= -65) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  Widget _signalBars(int level, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: 3.5,
            height: 5.0 + i * 3,
            decoration: BoxDecoration(
              color: i < level ? color : AppColors.kb1b1b1.withOpacity(0.35),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------- 状态卡（权限被拒 / 未找到） ----------------

  Widget _stateCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required Widget primary,
    Widget? secondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: GoogleFonts.rubik(
            color: AppColors.k8f8e94,
            fontSize: 13,
            height: 1.45,
          )),
          const SizedBox(height: 18),
          primary,
          if (secondary != null) ...[
            const SizedBox(height: 10),
            secondary,
          ],
        ],
      ),
    );
  }

  // ---------------- 配对须知 ----------------

  Widget _tipsCard(BuildContext context) {
    final s = S.of(context);
    final tips = [s.smartRingPairTip1, s.smartRingPairTip2, s.smartRingPairTip3];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb_outline, color: AppColors.k0cbcc5, size: 18),
            const SizedBox(width: 6),
            Text(s.smartRingPairTips, style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
          ]),
          const SizedBox(height: 12),
          for (var i = 0; i < tips.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.k0cbcc5.withOpacity(0.12), shape: BoxShape.circle),
                    child: Text('${i + 1}', style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    )),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(tips[i], style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 13, height: 1.4)),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- 按钮 ----------------

  Widget _filledButton(String label, IconData icon, VoidCallback onPressed) {
    return MaterialButton(
      onPressed: onPressed,
      elevation: 0,
      height: 46,
      minWidth: double.infinity,
      color: AppColors.k0cbcc5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _outlinedButton(String label, IconData icon, VoidCallback onPressed) {
    return MaterialButton(
      onPressed: onPressed,
      elevation: 0,
      height: 46,
      minWidth: double.infinity,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(23),
        side: BorderSide(color: AppColors.k0cbcc5, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.k0cbcc5, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: GoogleFonts.rubik(
            color: AppColors.k0cbcc5,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
