import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/miaid_card.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rwfit_ble/rwfit_ble.dart';

/// 戒指配对页：申请蓝牙权限 → 扫描附近戒指 → 选择一台连接，就绪后进入健康看板。
class SmartRingPairScreen extends StatefulWidget {
  const SmartRingPairScreen({Key? key}) : super(key: key);

  @override
  State<SmartRingPairScreen> createState() => _SmartRingPairScreenState();
}

class _SmartRingPairScreenState extends State<SmartRingPairScreen> with SingleTickerProviderStateMixin {
  final SmartRingService _ring = SmartRingService.instance;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

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
        iconTheme: IconThemeData(color: AppColors.k010101),
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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                _radar(scanning),
                const SizedBox(height: 24),
                Text(
                  _permissionDenied
                      ? s.smartRingBluetoothPermission
                      : scanning
                          ? s.smartRingScanning
                          : s.smartRingScanFinished,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  !_permissionDenied && !scanning && devices.isEmpty ? s.smartRingNoDevices : s.smartRingScanHint,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13),
                ),
                const SizedBox(height: 28),
                for (final device in devices) ...[
                  _deviceTile(context, device),
                  const SizedBox(height: 12),
                ],
                if (!scanning && _connectingId == null) ...[
                  const SizedBox(height: 8),
                  if (_permissionDenied)
                    _outlinedButton(s.smartRingOpenSettings, Icons.settings, () {
                      unawaited(openAppSettings());
                    }),
                  const SizedBox(height: 12),
                  _outlinedButton(s.smartRingRescan, Icons.refresh, () => unawaited(_startScan())),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _radar(bool scanning) {
    return SizedBox(
      height: 180,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          // 扫描中三层光环按相位呼吸，结束后静止
          final t = scanning ? _pulse.value : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: [180.0, 136.0, 96.0][i] + (scanning ? 8 * ((t + i / 3) % 1) : 0),
                  height: [180.0, 136.0, 96.0][i] + (scanning ? 8 * ((t + i / 3) % 1) : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.k0cbcc5.withOpacity(i == 2 ? 0.18 : 0.07),
                  ),
                ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.k0cbcc5),
                child: const Icon(Icons.donut_large, color: Colors.white, size: 32),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _deviceTile(BuildContext context, BleDevice device) {
    final s = S.of(context);
    final strong = device.rssi >= -70;
    final connecting = _connectingId == _id(device);
    final name = device.name.isNotEmpty ? device.name : 'RWFIT Ring';
    final subtitle = device.mac.isNotEmpty ? device.mac : (device.uuid ?? '');
    return miAidCard(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.donut_large, color: AppColors.k0cbcc5, size: 28),
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
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(
            strong ? Icons.signal_cellular_alt : Icons.signal_cellular_alt_2_bar,
            color: strong ? AppColors.k25d000 : AppColors.kb1b1b1,
            size: 18,
          ),
          const SizedBox(width: 12),
          MaterialButton(
            onPressed: _connectingId == null ? () => unawaited(_connect(device)) : null,
            color: AppColors.k0cbcc5,
            disabledColor: AppColors.k0cbcc5.withOpacity(0.5),
            elevation: 0,
            height: 34,
            minWidth: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            child: connecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(s.smartRingConnectButton, style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
          ),
        ],
      ),
    ));
  }

  Widget _outlinedButton(String label, IconData icon, VoidCallback onPressed) {
    return MaterialButton(
      onPressed: onPressed,
      elevation: 0,
      height: 44,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
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
