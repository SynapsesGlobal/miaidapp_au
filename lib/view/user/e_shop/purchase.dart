import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/payment/e_shop_payment_bottom_sheet.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/purchases_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/purchase_view_receipt.dart';

class PurchaseItemParams {
  const PurchaseItemParams(this.key);

  final Key key;
}

@injectable
class PurchaseItemServices {
  PurchaseItemServices(this.api, this.store, this.appSettings);

  final ApiProvider api;
  final PurchasesStore store;
  final AppSettings appSettings;
}

@injectable
class PurchaseItem extends StatefulWidget {
  PurchaseItem({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final PurchaseItemParams? params;
  final PurchaseItemServices services;

  @override
  _PurchaseItemState createState() => _PurchaseItemState();
}

class _PurchaseItemState extends State<PurchaseItem> {
  late final PurchasesStore purchasesStore = widget.services.store;

  @override
  void initState() {
    super.initState();
    purchasesStore.getOrders(widget.services.api);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: _appBar(),
      body: Observer(
        builder: (context) {
          if (purchasesStore.orderList.isNotEmpty) {
            return _purchasesList();
          }
          if (purchasesStore.isLoading) {
            return Center(child: progressIndicator());
          }
          return _emptyState();
        },
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: InkWell(
        onTap: () {
          purchasesStore.unExpandEveryItem();
          Navigator.pop(context);
        },
        child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
      ),
      centerTitle: true,
      title: Text(
        S.of(context).purchases,
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: AppColors.kb1b1b1,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context).noPastPurchases,
              style: GoogleFonts.rubik(
                color: AppColors.k808080,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // List
  // ---------------------------------------------------------------------------

  Widget _purchasesList() {
    return RefreshIndicator(
      color: AppColors.k0cbcc5,
      onRefresh: () => purchasesStore.getOrders(widget.services.api),
      child: Observer(
        builder: (context) {
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: purchasesStore.orderList.length,
            itemBuilder: (context, index) => _orderCard(index),
          );
        },
      ),
    );
  }

  Widget _orderCard(int index) {
    return Observer(
      builder: (context) {
        final order = purchasesStore.orderList[index];
        final expanded = purchasesStore.isExpandedList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
            child: Column(
              children: [
                _cardHeader(order, expanded, index),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: expanded
                      ? _cardBody(order)
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Header (always visible, tap to toggle)
  // ---------------------------------------------------------------------------

  Widget _cardHeader(Order order, bool expanded, int index) {
    return InkWell(
      onTap: () => purchasesStore.updateExpansion(index, !expanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.pharmacy?.name ?? '',
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _metaLine(
                    S.of(context).orderNumber,
                    order.id?.toString() ?? '',
                  ),
                  const SizedBox(height: 4),
                  _metaLine(
                    S.of(context).orderDate,
                    _formatDate(order.createdAt),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${order.pharmacyCurrency} ${order.orderTotal}',
                  style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.k5e5e5e,
                  ),
                ),
              ],
            ),
          ],
        ),
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
  // Body (products + summary + actions)
  // ---------------------------------------------------------------------------

  Widget _cardBody(Order order) {
    final products = order.products ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < products.length; i++) ...[
                if (i > 0) divider(),
                _productRow(order, products[i]),
              ],
            ],
          ),
        ),
        _summary(order),
      ],
    );
  }

  Widget _productRow(Order order, Product prod) {
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
    if (images != null && images.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          images.first.image!,
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
  // Summary + actions
  // ---------------------------------------------------------------------------

  Widget _summary(Order order) {
    return Container(
      color: AppColors.k0cbcc5.withOpacity(0.06),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
            child: Divider(height: 1),
          ),
          _summaryRow(
            S.of(context).orderTotal,
            '${order.pharmacyCurrency} ${order.orderTotal}',
            emphasize: true,
          ),
          const SizedBox(height: 16),
          _actionButtons(order),
        ],
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

  Widget _actionButtons(Order order) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.k0cbcc5,
              side: BorderSide(color: AppColors.k0cbcc5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _viewReceipt(order),
            child: Text(
              S.of(context).viewReceipt,
              style: GoogleFonts.rubik(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.k0cbcc5,
              foregroundColor: AppColors.kffffff,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _orderAgain(order),
            child: Text(
              S.of(context).orderAgain,
              style: GoogleFonts.rubik(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _viewReceipt(Order order) {
    purchasesStore.orderId = order.id ?? 0;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => getIt<PurchaseViewReceipt>(
          param1: PurchaseViewReceiptParams(
            purchasesStore.orderId,
            order.pharmacyCurrency!,
          ),
        ),
      ),
    );
  }

  Future<void> _orderAgain(Order order) async {
    final reOrdered =
        await widget.services.store.reOrder(order, widget.services.api);
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
    await purchasesStore.getOrders(widget.services.api);
  }

  Widget divider() {
    return Container(height: 0.5, color: AppColors.k5e5e5e.withOpacity(0.15));
  }
}
