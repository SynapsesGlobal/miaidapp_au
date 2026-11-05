import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/alipay_service.dart';
import 'package:miaid/services/marketing_payment_service.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

/// marketing 商品的支付方式弹窗：刷卡 + Apple Pay，人民币计价的商品另有支付宝。
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
    this.currency,
    this.service,
  });

  final BuildContext parentContext;
  final dynamic products;
  final String companyId;
  final String? points;
  /// 商品币种；为 CNY / RMB 时展示支付宝入口
  final String? currency;
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
          // 支付宝 App 支付：境内商户号、人民币结算，不经过 Stripe。规则与药房 / 套餐弹窗一致：
          // 只要商品以人民币计价就展示；设备未安装支付宝时不隐藏，行下方提示并在点击时 toast
          if (MarketingPaymentService.isRmb(currency)) _buildAlipayRow(context),
        ],
      ),
    );
  }

  Widget _buildAlipayRow(BuildContext context) {
    return FutureBuilder<bool>(
      future: AlipayService().isInstalled,
      builder: (context, snapshot) {
        // 检测未完成前按已安装展示，避免入口闪一下；真正发起支付时 AlipayService 会再查一次
        final installed = snapshot.data ?? true;
        return _buildMethodRow(
          context,
          leading: const Image(image: AssetImage('assets/images/ic_payment_alipay.png')),
          title: S.of(context).alipay,
          // 未安装时提示先装支付宝；已安装时告知境外卡单笔超 200 元支付宝收 3%，避免被理解为平台多收费
          subtitle: Text(
            installed ? S.of(context).alipayOverseasCardFeeNotice : S.of(context).alipayNotInstalled,
            style: GoogleFonts.rubik(
              color: installed ? Colors.grey : Colors.redAccent,
              fontSize: 11,
            ),
          ),
          dismissSheet: installed,
          onTap: () async {
            if (!installed) {
              await HttpExceptionNotifyUser.showInfo(S.of(context).alipayNotInstalled);
              return false;
            }
            return _service.payWithAlipay(
              context: parentContext,
              products: products,
              companyId: companyId,
              points: points,
            );
          },
        );
      },
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

  /// 一行支付方式：先关弹窗再发起支付（[dismissSheet] 为 false 时留在弹窗，用于只弹提示的情况），
  /// TapDebouncer 防止连点重复下单
  Widget _buildMethodRow(
    BuildContext context, {
    required Widget leading,
    required String title,
    required Future<bool> Function() onTap,
    Widget? subtitle,
    bool dismissSheet = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: TapDebouncer(
            onTap: () async {
              if (dismissSheet) Navigator.pop(context);
              await onTap();
            },
            builder: (context, debouncedTap) => ListTile(
              leading: leading,
              title: Text(title, style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 14,
              )),
              subtitle: subtitle,
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
