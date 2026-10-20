import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/marketing_payment_service.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

/// marketing 商品的支付方式弹窗：刷卡 + Apple Pay。
///
/// 结构和 Apple Pay 的展示/确认规则与 payment_bottom_sheet.dart（旅行套餐、其他服务）
/// 保持一致；因为 marketing 走 miaid_mispace 的下单接口、返回结构不同，这里没有直接复用
/// PaymentBottomSheet，而是把 Stripe 调用放在 [MarketingPaymentService] 里。
/// 点击某个方式后先关闭本弹窗，再用 [parentContext] 走支付流程，避免弹窗 context 失效。
class MarketingPaymentBottomSheet extends StatelessWidget {
  const MarketingPaymentBottomSheet({
    super.key,
    required this.parentContext,
    required this.products,
    required this.companyId,
    this.points,
    this.service,
  });

  final BuildContext parentContext;
  final dynamic products;
  final String companyId;
  final String? points;
  /// 便于测试替换；默认用单例
  final MarketingPaymentService? service;

  MarketingPaymentService get _service => service ?? MarketingPaymentService.instance;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 15),
            child: Text(S.of(context).chooseAPayment, style: GoogleFonts.rubik(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppColors.k010101,
            ),),
          ),
          Divider(color: Colors.grey[300], height: 0),
          _buildMethodRow(
            context,
            leading: const Image(image: AssetImage('assets/images/ic_payment_card.png')),
            title: S.of(context).creditOrDebit,
            onTap: () => _service.payWithCard(
              context: parentContext,
              products: products,
              companyId: companyId,
              points: points,
            ),
          ),
          // Apple Pay 走 Stripe Platform Pay，仅 iOS 且 Wallet 已添加受支持的卡时展示
          if (Platform.isIOS) _buildApplePayRow(context),
        ],
      ),
    );
  }

  Widget _buildApplePayRow(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isApplePaySupported(),
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          // isPlatformPaySupported 只检查 Wallet 里是否已添加 Visa/Mastercard/Amex 等
          // Stripe 支持的卡（银联不算），debug 构建把原因显示出来方便真机排查
          if (kDebugMode && snapshot.connectionState == ConnectionState.done) {
            return Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Apple Pay 不可用：Wallet 未添加 Visa/Mastercard/Amex 卡'
                '（isPlatformPaySupported=${snapshot.data}）',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        return _buildMethodRow(
          context,
          leading: const Icon(Icons.apple, color: Colors.black, size: 30),
          title: S.of(context).applePay,
          onTap: () => _service.payWithApplePay(
            context: parentContext,
            products: products,
            companyId: companyId,
            points: points,
          ),
        );
      },
    );
  }

  /// 查询失败（插件异常等）按不支持处理，不让弹窗整个报错
  Future<bool> _isApplePaySupported() async {
    try {
      return await Stripe.instance.isPlatformPaySupported();
    } catch (e) {
      debugPrint('[MarketingPayment] isPlatformPaySupported failed: $e');
      return false;
    }
  }

  /// 一行支付方式：先关弹窗再发起支付，TapDebouncer 防止连点重复下单
  Widget _buildMethodRow(
    BuildContext context, {
    required Widget leading,
    required String title,
    required Future<bool> Function() onTap,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: TapDebouncer(
            onTap: () async {
              Navigator.pop(context);
              await onTap();
            },
            builder: (context, debouncedTap) => ListTile(
              leading: leading,
              title: Text(title, style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 14,
              )),
              dense: true,
              onTap: debouncedTap,
            ),
          ),
        ),
        Divider(color: Colors.grey[300], height: 0),
      ],
    );
  }
}
