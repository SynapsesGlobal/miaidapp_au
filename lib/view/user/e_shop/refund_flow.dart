import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';

/// 退款凭证图片上限
const _maxRefundImages = 9;

/// 取消订单申请退款完整流程：确认弹窗 → 退款申请页（原因/说明/凭证）→ 提交后端。
/// 返回 true 表示退款申请已提交成功。
Future<bool> showRefundFlow(
  BuildContext context, {
  required Order order,
  required ApiProvider api,
}) async {
  final confirmed = await _showConfirmDialog(context);
  if (confirmed != true) return false;
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (context) => RefundRequestPage(order: order, api: api),
    ),
  );
  return ok == true;
}

// 确认弹窗（风格与购物车删除商品弹框一致）
Future<bool?> _showConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).cancelOrderRefund,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        S.of(context).cancelOrderRefundConfirm,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(fontSize: 13),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: MediaQuery.of(context).size.width,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.k0cbcc5.withOpacity(0.2),
                      blurRadius: 10.0,
                      spreadRadius: 0.0,
                      offset: Offset(0.0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(AppColors.k0cbcc5),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    S.of(context).notNow,
                    style: GoogleFonts.rubik(
                      color: AppColors.kffffff,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Text(
                    S.of(context).requestRefund,
                    style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 退款申请页：顶部订单基本信息，下方退款原因、详细说明（必填）、凭证图片（选填）。
/// 提交成功后 pop(true)。
class RefundRequestPage extends StatefulWidget {
  const RefundRequestPage({
    Key? key,
    required this.order,
    required this.api,
  }) : super(key: key);

  final Order order;
  final ApiProvider api;

  @override
  _RefundRequestPageState createState() => _RefundRequestPageState();
}

class _RefundRequestPageState extends State<RefundRequestPage> {
  int _selectedIndex = -1;
  final _detailController = TextEditingController();
  final _pickedImages = <XFile>[];
  bool _submitting = false;

  Order get order => widget.order;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  List<String> get _reasons => [
        S.of(context).refundReasonWrongMedication,
        S.of(context).refundReasonDamaged,
        S.of(context).refundReasonExpired,
        S.of(context).refundReasonQualityIssue,
        S.of(context).refundReasonDeliveryError,
      ];

  bool get _canSubmit => !_submitting && _selectedIndex >= 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: InkWell(
          onTap: () => Navigator.pop(context, false),
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
        ),
        centerTitle: true,
        title: Text(
          S.of(context).requestRefund,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _reasonCard(),
          const SizedBox(height: 12),
          _detailCard(),
          const SizedBox(height: 12),
          _photosCard(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: MaterialButton(
            onPressed: _canSubmit ? _submit : null,
            minWidth: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: AppColors.k0cbcc5,
            disabledColor: AppColors.kb1b1b1,
            child: Text(
              S.of(context).confirm,
              style: GoogleFonts.rubik(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 卡片
  // ---------------------------------------------------------------------------

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.kffffff,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.k010101.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.rubik(
        color: AppColors.k010101,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // 退款原因单选（必填）
  Widget _reasonCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(S.of(context).selectRefundReason),
          const SizedBox(height: 12),
          for (var i = 0; i < _reasons.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == _reasons.length - 1 ? 0 : 10,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedIndex == i
                        ? AppColors.keefeff
                        : AppColors.kf4f4f4,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedIndex == i
                          ? AppColors.k0cbcc5
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _reasons[i],
                          style: GoogleFonts.rubik(
                            color: AppColors.k010101,
                            fontSize: 14,
                            fontWeight: _selectedIndex == i
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Icon(
                        _selectedIndex == i
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _selectedIndex == i
                            ? AppColors.k0cbcc5
                            : AppColors.kb1b1b1,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 详细说明（选填）
  Widget _detailCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(S.of(context).refundDetailLabel),
          const SizedBox(height: 12),
          TextField(
            maxLines: 4,
            maxLength: 300,
            controller: _detailController,
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.rubik(
              fontSize: 14,
              color: AppColors.k010101,
            ),
            decoration: InputDecoration(
              hintText: S.of(context).pleaseDescribeReason,
              hintStyle: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.all(12),
              filled: true,
              fillColor: AppColors.kf4f4f4,
              counterStyle: GoogleFonts.rubik(
                color: AppColors.kb1b1b1,
                fontSize: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E0E0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E0E0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.k0cbcc5,
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 凭证图片（选填）
  Widget _photosCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(S.of(context).refundUploadPhotos),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _pickedImages.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        io.File(_pickedImages[i].path),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: InkWell(
                        onTap: () =>
                            setState(() => _pickedImages.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_pickedImages.length < _maxRefundImages)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final files = await ImagePicker().pickMultiImage(
                      maxWidth: 1600,
                      imageQuality: 85,
                    );
                    if (files.isEmpty) return;
                    setState(() {
                      _pickedImages.addAll(files.take(
                          _maxRefundImages - _pickedImages.length));
                    });
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.kf4f4f4,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.kb1b1b1,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 提交
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final detail = _detailController.text.trim();
    // 说明选填：填了拼在原因后面
    final reason = detail.isEmpty
        ? _reasons[_selectedIndex]
        : '${_reasons[_selectedIndex]}: $detail';
    setState(() => _submitting = true);
    final ok = await _submitRefundRequest(
      order,
      reason,
      _pickedImages,
      widget.api,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Navigator.pop(context, true);
  }
}

// 上传单张退款凭证图片，返回后端存储路径（复用处方图上传接口）
Future<String> _uploadRefundImage(
  ApiProvider api,
  String endpoint,
  XFile file,
) async {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$endpoint/order/uploadImage'),
  );
  request.files.add(await http.MultipartFile.fromPath('image', file.path));
  request.headers['x-access-token'] =
      api.userProvider.user?.accessToken ?? '';
  request.headers['x-api-key'] = api.apiKey;
  final response = await http.Response.fromStream(await request.send());
  if (response.statusCode != 200) {
    throw HttpException(response.statusCode, S.current.uploadFailed);
  }
  return json.decode(response.body)['payload']['path'] as String;
}

// 提交退款申请：先上传凭证图片，再 POST /orders/{order_id}/refund
Future<bool> _submitRefundRequest(
  Order order,
  String reason,
  List<XFile> images,
  ApiProvider api,
) async {
  final endpoint = api.apiSettings.endpointSub;
  try {
    await EasyLoading.show(maskType: EasyLoadingMaskType.black);
    final imagePaths = <String>[];
    for (final file in images) {
      imagePaths.add(await _uploadRefundImage(api, endpoint, file));
    }

    final response = await http.post(
      Uri.parse('$endpoint/orders/${order.id}/refund'),
      headers: {
        'x-api-key': api.apiKey,
        'x-access-token': api.userProvider.user?.accessToken ?? '',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reason': reason,
        if (imagePaths.isNotEmpty) 'images': imagePaths,
      }),
    );
    await EasyLoading.dismiss();

    if (response.statusCode == 200) {
      await HttpExceptionNotifyUser.showInfo(
        S.current.refundRequestSubmitted,
      );
      return true;
    }

    String? message;
    try {
      message = jsonDecode(response.body)['message'] as String?;
    } catch (_) {}
    await HttpExceptionNotifyUser.showInfo(
      message?.isNotEmpty == true ? message! : S.current.somethingWentWrong,
    );
  } catch (e) {
    await EasyLoading.dismiss();
    await HttpExceptionNotifyUser.showInfo(
      e is HttpException && (e.message?.isNotEmpty ?? false)
          ? e.message!
          : S.current.somethingWentWrong,
    );
  }
  return false;
}
