import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';

/// 取消订单申请退款完整流程：确认弹窗 → 选择退款原因 → 提交后端。
/// 返回 true 表示退款申请已提交成功。
Future<bool> showRefundFlow(
  BuildContext context, {
  required Order order,
  required ApiProvider api,
}) async {
  final confirmed = await _showConfirmDialog(context);
  if (confirmed != true) return false;
  final reason = await _showReasonSheet(context, order);
  if (reason == null) return false;
  return _submitRefundRequest(context, order, reason, api);
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

// 退款原因选择弹窗，返回选中（或填写）的原因，取消返回 null
Future<String?> _showReasonSheet(BuildContext context, Order order) async {
  final reasons = [
    S.of(context).refundReasonNoLongerNeeded,
    S.of(context).refundReasonWrongItem,
    S.of(context).refundReasonWrongAddress,
    S.of(context).refundReasonDeliveryTooSlow,
    S.of(context).refundReasonOther,
  ];
  final otherIndex = reasons.length - 1;
  var selectedIndex = -1;
  final otherController = TextEditingController();

  final reason = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final canSubmit = selectedIndex >= 0 &&
              (selectedIndex != otherIndex ||
                  otherController.text.trim().isNotEmpty);
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部拖拽指示条
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.of(context).refundReason,
                                style: GoogleFonts.rubik(
                                  color: AppColors.k010101,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${S.of(context).orderNumber}: '
                                '${order.id?.toString() ?? ''}',
                                style: GoogleFonts.rubik(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      S.of(context).selectRefundReason,
                      style: GoogleFonts.rubik(
                        color: AppColors.k5e5e5e,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  for (var i = 0; i < reasons.length; i++)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setSheetState(() => selectedIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: selectedIndex == i
                                ? AppColors.keefeff
                                : AppColors.kf4f4f4,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedIndex == i
                                  ? AppColors.k0cbcc5
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  reasons[i],
                                  style: GoogleFonts.rubik(
                                    color: AppColors.k010101,
                                    fontSize: 14,
                                    fontWeight: selectedIndex == i
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Icon(
                                selectedIndex == i
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: selectedIndex == i
                                    ? AppColors.k0cbcc5
                                    : AppColors.kb1b1b1,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (selectedIndex == otherIndex)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: TextField(
                        maxLines: 3,
                        controller: otherController,
                        keyboardType: TextInputType.text,
                        onChanged: (_) => setSheetState(() {}),
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
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: MaterialButton(
                      onPressed: canSubmit
                          ? () {
                              final value = selectedIndex == otherIndex
                                  ? otherController.text.trim()
                                  : reasons[selectedIndex];
                              Navigator.of(context).pop(value);
                            }
                          : null,
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
                ],
              ),
            ),
          );
        },
      );
    },
  );
  otherController.dispose();
  return reason;
}

// 提交退款申请：POST /orders/{order_id}/refund
Future<bool> _submitRefundRequest(
  BuildContext context,
  Order order,
  String reason,
  ApiProvider api,
) async {
  final endpoint = api.apiSettings.endpointSub;
  try {
    final response = await http.post(
      Uri.parse('$endpoint/orders/${order.id}/refund'),
      headers: {
        'x-api-key': api.apiKey,
        'x-access-token': api.userProvider.user?.accessToken ?? '',
        'Accept': 'application/json',
      },
      body: {'reason': reason},
    );

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
    await HttpExceptionNotifyUser.showInfo(S.current.somethingWentWrong);
  }
  return false;
}
