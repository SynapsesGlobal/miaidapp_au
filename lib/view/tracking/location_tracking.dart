import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api_utils/api_provider.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import '../../services/location_upload_service.dart';
import '../../store/home/home_screen_store.dart';
import '../../utils/configure_dependencies.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationTracking extends StatefulWidget {
  const LocationTracking({super.key});

  @override
  State<LocationTracking> createState() => _LocationTrackingState();
}

class _LocationTrackingState extends State<LocationTracking> {
  bool _open = false;
  final TextEditingController _controller = TextEditingController();
  // 默认每 3 小时（后端频率值 5）
  int _frequency = 5;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _getPositionSetting();
  }

  Future<void> _getPositionSetting() async {
    final api = getIt<ApiProvider>();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-user-id': api.userProvider.user!.id.toString(),
      'x-api-key': api.apiKey,
    };

    await EasyLoading.show(
      status: 'Loading...',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final url = Uri.parse(api.baseUrl+'/api/v1/position/index');
      final response = await http.post(url, headers: headers,);
      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body)['payload'];
        var opened = LocationUploadService.isTrackingOpen(responseData['open_position_tracking']);
        // 缓存后端开关值，供 App 重启时恢复定位上传服务用。
        var sharedPreferences = await SharedPreferences.getInstance();
        await sharedPreferences.setBool('open_position_tracking', opened);
        setState(() {
          _open = opened;
          _controller.text = opened ? responseData['tracking_email'] : '';
          _frequency = opened ? int.parse(responseData['tracking_frequency']) : 5;
        });
      } else {
        await EasyLoading.dismiss();
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      await EasyLoading.dismiss();
    }
  }

  Future<void> _submit() async {
    if (_open && !formKey.currentState!.validate()) {
      return;
    }

    final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
    final api = getIt<ApiProvider>();

    final data = <String, dynamic>{
      'tracking_email':_open ? _controller.text : '',
      'open_position_tracking': _open ? 1 : 0,
      'tracking_frequency': _open ? _frequency : 0,
      'latitude': position.latitude,
      'longitude': position.longitude,
    };

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-access-token': api.userProvider.user!.accessToken!,
      'x-user-id': api.userProvider.user!.id.toString(),
      'x-api-key': api.apiKey,
    };

    await EasyLoading.show(
      status: 'Submitting',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final url = Uri.parse(api.baseUrl+'/api/v1/position/setting');
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );
      await EasyLoading.dismiss();

      if (response.statusCode == 200 ) {
        // 缓存开关值，供 App 重启时恢复定位上传服务用。
        var sharedPreferences = await SharedPreferences.getInstance();
        await sharedPreferences.setBool('open_position_tracking', _open);
        // 设置保存成功后立即启动/停止追踪服务，不用等下次冷启动。
        // （服务启动时会立即上传一次，替代原先的单次 sendPositionToBackend。）
        if (_open) {
          await LocationUploadService.start();
        } else if (await LocationUploadService.isRunning) {
          await LocationUploadService.stop();
        }
        await HttpExceptionNotifyUser.showInfo(S.of(context).setup_success);
      } else {
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      await EasyLoading.dismiss();
      await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(S.of(context).positionTracking, style: GoogleFonts.rubik(
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 开关卡片
            _card(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.k0cbcc5.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.location_on, color: AppColors.k0cbcc5, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(S.of(context).open_location_tracking, style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),),
                  ),
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: _open,
                      activeColor: AppColors.k0cbcc5,
                      inactiveTrackColor: Colors.grey[200],
                      onChanged: (value) => setState(() {
                        _open = value;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            if (_open) ...[
              const SizedBox(height: 16),
              // 接收邮箱卡片
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(Icons.mail_outline, S.of(context).email_receive_location),
                    const SizedBox(height: 12),
                    Form(
                      key: formKey,
                      child: TextFormField(
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (_open && (_controller.text.isEmpty || !Utils.isValidEmail(_controller.text))) {
                            return S.of(context).entEmail;
                          } else {
                            return null;
                          }
                        },
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'yourname@example.com',
                          hintStyle: TextStyle(
                            color: AppColors.kb1b1b1,
                            fontSize: 14,
                          ),
                          contentPadding: EdgeInsets.only(
                            left: 16,
                            top: 5,
                            bottom: 5,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.k010101,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.kfa0020,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppColors.kb1b1b1,
                              width: 0.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red,),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 发送频率卡片
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(Icons.schedule, S.of(context).email_frequency),
                    const SizedBox(height: 4),
                    // 5 对应后端 frequencyHours 映射的每 3 小时（1/2/3/4 已被 6h/12h/天/周占用）
                    _frequencyOption(5, S.of(context).every_three_hours),
                    Divider(color: Colors.black12, height: 1,),
                    _frequencyOption(1, S.of(context).every_six_hours),
                    Divider(color: Colors.black12, height: 1,),
                    _frequencyOption(2, S.of(context).every_twelve_hours),
                    Divider(color: Colors.black12, height: 1,),
                    _frequencyOption(3, S.of(context).every_day),
                    Divider(color: Colors.black12, height: 1,),
                    _frequencyOption(4, S.of(context).every_week),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 发送说明
              _noticeBox(
                icon: Icons.info_outline,
                iconColor: AppColors.k0cbcc5,
                background: AppColors.k0cbcc5.withOpacity(0.08),
                text: S.of(context).tracking_instruction,
              ),
            ],
            const SizedBox(height: 24),
            // 渐变确认按钮
            Container(
              width: MediaQuery.of(context).size.width,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF12CCD6), AppColors.k0cbcc5],
                ),
                borderRadius: BorderRadius.circular(23),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.k0cbcc5.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.transparent),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  S.of(context).confirm,
                  style: GoogleFonts.rubik(
                    color: AppColors.kffffff,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 底部提示：完全关闭 App 后追踪停止、不再发送位置邮件
            _noticeBox(
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFE8A23D),
              background: const Color(0xFFFDF3E3),
              text: S.of(context).tracking_app_closed_notice,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // 白色圆角分区卡
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.k010101.withOpacity(0.04),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.k0cbcc5),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: GoogleFonts.rubik(
            color: AppColors.k5e5e5e,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),),
        ),
      ],
    );
  }

  // 整行可点的频率选项
  Widget _frequencyOption(int value, String label) {
    return InkWell(
      onTap: () => setState(() {
        _frequency = value;
      }),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),),
          Radio<int>(
            value: value,
            activeColor: AppColors.k0cbcc5,
            groupValue: _frequency,
            onChanged: (value) => setState(() {
              _frequency = value ?? _frequency;
            }),
          ),
        ],
      ),
    );
  }

  Widget _noticeBox({
    required IconData icon,
    required Color iconColor,
    required Color background,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.rubik(
              color: AppColors.k5e5e5e,
              fontSize: 13,
              height: 1.5,
            ),),
          ),
        ],
      ),
    );
  }
}
