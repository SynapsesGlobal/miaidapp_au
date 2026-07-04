import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/payment/e_shop_payment_bottom_sheet.dart';
import 'package:miaid/store/e_shop/purchases_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/purchase_view_receipt.dart';
import 'package:miaid/view/user/e_shop/refund_flow.dart';

/// 订单详情页：数据由列表页直接传入，不额外请求详情接口
class PurchaseDetail extends StatefulWidget {
  const PurchaseDetail({
    Key? key,
    required this.order,
    required this.api,
    required this.store,
    this.refund,
  }) : super(key: key);

  final Order order;
  final ApiProvider api;
  final PurchasesStore store;

  /// 订单的退款申请信息（status/reason/reject_reason），无退款申请时为 null
  final Map<String, dynamic>? refund;

  @override
  _PurchaseDetailState createState() => _PurchaseDetailState();
}

class _PurchaseDetailState extends State<PurchaseDetail> {
  // 与后端 Order.order_status 保持一致
  static const int _statusConfirming = 1;
  static const int _statusReadyForCollection = 3;
  static const int _statusRefundRequested = 5;
  static const int _statusRefunded = 6;
  // 与后端 OrderRefund.status 保持一致
  static const int _refundRejected = 3;

  Order get order => widget.order;

  // 本页发生过影响列表的操作（退款申请/再次购买）时，返回列表页触发刷新
  bool _changed = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.kf4f4f4,
        appBar: _appBar(),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _headerCard(),
            const SizedBox(height: 12),
            _productsCard(),
            const SizedBox(height: 12),
            _summaryCard(),
          ],
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: InkWell(
        onTap: () => Navigator.pop(context, _changed),
        child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
      ),
      centerTitle: true,
      title: Text(
        S.of(context).order_detail,
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

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
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 药房 + 状态 + 订单信息
  // ---------------------------------------------------------------------------

  Widget _headerCard() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.k0cbcc5.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_pharmacy_outlined,
                    color: AppColors.k0cbcc5,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order.pharmacy?.name ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _orderStatusBadge(),
              ],
            ),
            const SizedBox(height: 14),
            _metaLine(S.of(context).orderNumber, order.id?.toString() ?? ''),
            const SizedBox(height: 6),
            _metaLine(S.of(context).orderDate, _formatDate(order.createdAt)),
            _refundRejectedBanner(),
          ],
        ),
      ),
    );
  }

  // 订单状态徽章：默认已支付；退款流程中显示 退款中/已退款/已拒绝
  Widget _orderStatusBadge() {
    final status = order.orderStatus ?? 0;
    final refund = widget.refund;

    String label;
    Color color;
    if (status == _statusRefundRequested) {
      label = S.of(context).refunding;
      color = AppColors.ke68c30;
    } else if (status == _statusRefunded) {
      label = S.of(context).refunded;
      color = AppColors.k8f8f8f;
    } else if (refund != null && refund['status'] == _refundRejected) {
      label = S.of(context).refused;
      color = AppColors.ke63030;
    } else {
      label = S.of(context).paid;
      color = AppColors.k0cbcc5;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.rubik(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 退款被拒绝提示：展示药店填写的拒绝原因（此时可再次申请退款）
  Widget _refundRejectedBanner() {
    final status = order.orderStatus ?? 0;
    final refund = widget.refund;
    if (refund == null ||
        refund['status'] != _refundRejected ||
        status > _statusReadyForCollection) {
      return const SizedBox.shrink();
    }
    final rejectReason = (refund['reject_reason'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.ke63030.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.ke63030),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rejectReason.isEmpty
                  ? S.of(context).refundRequestRejected
                  : '${S.of(context).refundRequestRejected}: $rejectReason',
              style: GoogleFonts.rubik(
                color: AppColors.ke63030,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 13),
        children: [
          TextSpan(text: '$label:  '),
          TextSpan(
            text: value,
            style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return DateFormat('dd MMM yyyy hh:mm aaa').format(DateTime.parse(raw));
  }

  // ---------------------------------------------------------------------------
  // 商品列表
  // ---------------------------------------------------------------------------

  Widget _productsCard() {
    final products = order.products ?? [];
    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (var i = 0; i < products.length; i++) ...[
              if (i > 0) divider(),
              _productRow(products[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _productRow(Product prod) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _productImage(prod),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prod.name ?? '',
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${order.pharmacyCurrency} ${prod.unitPrice}',
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '×${prod.pivot?.qty ?? 0}',
                      style: GoogleFonts.rubik(
                        color: AppColors.k5e5e5e,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productImage(Product prod) {
    final images = prod.productImages;
    final url = (images != null && images.isNotEmpty) ? images.first.image : null;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: 64,
          width: 64,
          fit: BoxFit.cover,
          errorBuilder: (context, exception, stackTrace) => _imageFallback(),
        ),
      );
    }
    return _placeholderBox(Icon(Icons.local_pharmacy, size: 36));
  }

  Widget _imageFallback() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/default_shop_image.png',
        height: 64,
        width: 64,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _placeholderBox(Widget child) {
    return Container(
      height: 64,
      width: 64,
      decoration: BoxDecoration(
        color: AppColors.kf4f4f4,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: child),
    );
  }

  // ---------------------------------------------------------------------------
  // 金额汇总
  // ---------------------------------------------------------------------------

  Widget _summaryCard() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow(
              S.of(context).subTotal,
              '${order.pharmacyCurrency} ${order.subTotal}',
            ),
            const SizedBox(height: 6),
            _summaryRow(
              S.of(context).deliveryFees,
              '${order.pharmacyCurrency} ${order.deliveryFee}',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Colors.black12,),
            ),
            _summaryRow(
              S.of(context).orderTotal,
              '${order.pharmacyCurrency} ${order.orderTotal}',
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.rubik(
            color: emphasize ? AppColors.k010101 : AppColors.k5e5e5e,
            fontSize: emphasize ? 14 : 13,
            fontWeight: emphasize ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.rubik(
            color: emphasize ? AppColors.k0cbcc5 : AppColors.k010101,
            fontSize: emphasize ? 16 : 13,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 底部操作栏
  // ---------------------------------------------------------------------------

  Widget _bottomBar() {
    return Container(
      color: AppColors.kffffff,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: _actionButtons(),
      ),
    );
  }

  Widget _actionButtons() {
    final refundSlot = _refundSlot();
    return Row(
      children: [
        if (refundSlot != null) ...[
          Expanded(child: refundSlot),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.k0cbcc5,
              side: BorderSide(color: AppColors.k0cbcc5),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _viewReceipt,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                S.of(context).viewReceipt,
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.k0cbcc5,
              foregroundColor: AppColors.kffffff,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _orderAgain,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                S.of(context).orderAgain,
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 退款操作位：待取货前且未申请过退款时显示申请按钮；
  // 退款中/已退款/已拒绝显示状态；已取货不显示
  Widget? _refundSlot() {
    final status = order.orderStatus ?? 0;
    if (status == _statusRefundRequested) {
      return _refundStatusChip(S.of(context).refunding, AppColors.ke68c30);
    }
    if (status == _statusRefunded) {
      return _refundStatusChip(S.of(context).refunded, AppColors.k8f8f8f);
    }
    // 已有退款申请（含被拒绝）的订单不允许再次申请
    final refund = widget.refund;
    if (refund != null && refund['status'] == _refundRejected) {
      return _refundStatusChip(S.of(context).refused, AppColors.ke63030);
    }
    if (status >= _statusConfirming && status <= _statusReadyForCollection) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ke63030,
          side: BorderSide(color: AppColors.ke63030.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _requestRefund,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            S.of(context).requestRefund,
            style: GoogleFonts.rubik(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return null;
  }

  Widget _refundStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      // 不能用 Container.alignment：在 bottomNavigationBar 的无界高度下会撑满全屏
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.rubik(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 退款流程（共享实现见 refund_flow.dart）
  // ---------------------------------------------------------------------------

  Future<void> _requestRefund() async {
    final ok = await showRefundFlow(context, order: order, api: widget.api);
    if (ok && mounted) {
      Navigator.pop(context, true);
    }
  }

  // ---------------------------------------------------------------------------
  // 其他操作
  // ---------------------------------------------------------------------------

  void _viewReceipt() {
    widget.store.orderId = order.id ?? 0;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => getIt<PurchaseViewReceipt>(
          param1: PurchaseViewReceiptParams(
            widget.store.orderId,
            order.pharmacyCurrency ?? '',
          ),
        ),
      ),
    );
  }

  Future<void> _orderAgain() async {
    final reOrdered = await widget.store.reOrder(order, widget.api);
    if (!reOrdered) return;
    await showModalBottomSheet<void>(
      backgroundColor: Colors.white,
      context: context,
      isDismissible: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) => getIt<EShopPaymentBottomSheet>(
        param1: EShopPaymentBottomSheetParams(order: order),
      ),
    );
    _changed = true;
  }

  Widget divider() {
    return Container(height: 0.5, color: Colors.black12);
  }
}
