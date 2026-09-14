import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';

/// 订单列表 / 详情共用的到店自取订单操作。
/// 生成的 Order 模型不含 pay_on_pickup / cancelled_at，两处都从接口原始 JSON 读取。

/// 后端 Order.order_status：到店自取订单被用户或药店取消
const int orderStatusCancelled = 7;

/// 原始订单 JSON 是否为到店自取（到店付款）订单；后端返回 bool，兼容 0/1
bool isPayOnPickupJson(Map<String, dynamic> json) {
  final value = json['pay_on_pickup'];
  return value == true || value == 1 || value == '1';
}

/// 取消到店自取订单：POST /orders/{order_id}/cancel。
/// 成功返回 null；失败返回后端 message（没有则返回空串），由调用方兜底提示。
Future<String?> cancelPickupOrder(ApiProvider api, int orderId) async {
  final endpoint = api.apiSettings.endpointSub;
  final response = await http.post(
    Uri.parse('$endpoint/orders/$orderId/cancel'),
    headers: {
      'x-api-key': api.apiKey,
      'x-access-token': api.userProvider.user?.accessToken ?? '',
      'Accept': 'application/json',
    },
  );
  if (response.statusCode == 200) return null;
  try {
    return (jsonDecode(response.body)['message'] as String?) ?? '';
  } catch (_) {
    return '';
  }
}

/// 取消自取订单确认框（风格与删除订单确认框一致）：主按钮保留订单，文字链确认取消
Future<bool> confirmCancelPickupOrder(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).cancelOrder,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        S.of(context).cancelPickupOrderConfirm,
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
                    S.of(context).keepOrder,
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
                    S.of(context).cancelOrder,
                    style: GoogleFonts.rubik(
                      color: AppColors.ke63030,
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
  return confirmed == true;
}

/// "到店自取 · 到店付款" 小标签，列表与详情共用
Widget pickupPayInStoreChip(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.ke68c30.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.storefront_outlined, size: 12, color: AppColors.ke68c30),
        const SizedBox(width: 4),
        Text(
          S.of(context).pickupPayInStore,
          style: GoogleFonts.rubik(
            color: AppColors.ke68c30,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
