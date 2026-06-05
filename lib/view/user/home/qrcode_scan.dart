import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../api_utils/consts.dart';
import '../../../component/nav_bar_icons.dart';
import '../../../config/app_colors.dart';
import '../../../generated/l10n.dart';

/// 相机权限/初始化的状态机，用来决定页面展示什么，
/// 避免权限被拒或相机初始化失败时停在永久黑屏（部分三星机型表现为「扫码没反应」）。
enum _CameraState { checking, ready, denied, error }

class QrCodeScan extends StatefulWidget {
  const QrCodeScan({super.key});

  @override
  State<QrCodeScan> createState() => _QrCodeScanState();
}

class _QrCodeScanState extends State<QrCodeScan> {
  bool _hasScanned = false;
  _CameraState _state = _CameraState.checking;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _ensureCameraPermission();
  }

  /// 先在 App 层显式申请相机权限，再决定是否渲染相机预览。
  /// flutter_zxing 的 ReaderWidget 依赖 camera 插件在 initialize() 时隐式弹框，
  /// 一旦权限被「禁止后不再询问」（One UI 上很常见），就只会黑屏且无任何提示。
  Future<void> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    setState(() {
      if (status.isGranted) {
        _state = _CameraState.ready;
      } else {
        _state = _CameraState.denied;
        _permanentlyDenied = status.isPermanentlyDenied || status.isRestricted;
      }
    });
  }

  Future<void> _onScan(Code result) async {
    if (_hasScanned) return;

    if (result.isValid && result.text != null && _validateQRFormat(result.text!)) {
      final data = jsonDecode(result.text!);
      _hasScanned = true;
      Navigator.pop(context, {
        'hospital_name': data['hospital_name'],
        'hospital_id': data['hospital_id'],
        'type': data['type'],
      });
    } else {
      Navigator.pop(context, '');
    }
  }

  bool _validateQRFormat(String qrContent) {
    // 扫到的二维码不一定是合法 JSON，jsonDecode 会抛异常；
    // 此前未捕获时异常会被 ReaderWidget 的图像流静默吞掉，表现为扫了没反应。
    try {
      final data = jsonDecode(qrContent);
      if (data is! Map) return false;
      final token = data['token']?.toString() ?? '';
      return token.isNotEmpty && token == Consts.QrCodeToken;
    } catch (_) {
      return false;
    }
  }

  /// 相机初始化失败（如被系统/其他 App 占用、权限在中途被回收）时回调，
  /// 切到错误态而不是停在黑屏。
  void _onControllerCreated(CameraController? controller, Exception? error) {
    if (error == null || !mounted) return;
    setState(() => _state = _CameraState.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text('扫码', style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _CameraState.checking:
        return const ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator()),
        );
      case _CameraState.ready:
        return ReaderWidget(
          codeFormat: Format.qrCode,
          onScan: _onScan,
          onControllerCreated: _onControllerCreated,
          onScanFailure: (Code result) {
            debugPrint(result.toString());
            debugPrint('扫码失败');
          },
          showScannerOverlay: true,
          showFlashlight: true,
          showGallery: true,
          scanDelay: const Duration(milliseconds: 500),
        );
      case _CameraState.denied:
      case _CameraState.error:
        return _buildPermissionHint();
    }
  }

  Widget _buildPermissionHint() {
    final isDenied = _state == _CameraState.denied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography_outlined, size: 48, color: AppColors.k010101),
            const SizedBox(height: 16),
            Text(
              isDenied
                  ? '${S.of(context).camera}: please allow camera access to scan QR codes.'
                  : 'Camera is unavailable. Please close other camera apps and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
              onPressed: () async {
                if (isDenied && _permanentlyDenied) {
                  // 已被永久拒绝，系统不再弹框，只能引导去设置页开启。
                  await openAppSettings();
                } else {
                  setState(() => _state = _CameraState.checking);
                  await _ensureCameraPermission();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  isDenied && _permanentlyDenied ? 'Open Settings' : S.of(context).okay,
                  style: GoogleFonts.rubik(color: AppColors.kffffff, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}