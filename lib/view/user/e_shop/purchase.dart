import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/payment/e_shop_payment_bottom_sheet.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/purchases_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/purchase_detail.dart';
import 'package:miaid/view/user/e_shop/refund_flow.dart';

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
  // 与后端 Order.order_status 保持一致
  static const int _statusConfirming = 1;
  static const int _statusReadyForCollection = 3;
  static const int _statusRefundRequested = 5;
  static const int _statusRefunded = 6;
  // 与后端 OrderRefund.status 保持一致
  static const int _refundRejected = 3;

  // 分页订单列表；退款申请信息（status/reason/reject_reason）来自
  // 同一接口原始 JSON 的 refund 关联（生成的 Order 模型不包含该字段）
  final List<Order> _orders = [];
  Map<int, Map<String, dynamic>> _refundByOrderId = {};

  // ★ 分页变量
  static const int _pageSize = 10;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50) {
        _fetchOrders();
      }
    });
    _fetchOrders();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _page = 1;
    _hasMore = true;
    _orders.clear();
    _refundByOrderId = {};
    await _fetchOrders();
  }

  // 分页拉取订单：GET /orders?per_page=N&page=N，
  // 一次请求同时获得订单数据与退款申请信息
  Future<void> _fetchOrders() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final api = widget.services.api;
    final endpoint = api.apiSettings.endpointSub;
    try {
      final response = await http.get(
        Uri.parse('$endpoint/orders?per_page=$_pageSize&page=$_page'),
        headers: {
          'x-api-key': api.apiKey,
          'x-access-token': api.userProvider.user?.accessToken ?? '',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final payload = json['payload'];
        final newOrders = <Order>[];
        if (payload is List) {
          for (final item in payload) {
            if (item is! Map<String, dynamic>) continue;
            newOrders.add(Order.fromJson(item));
            if (item['id'] is int && item['refund'] is Map<String, dynamic>) {
              _refundByOrderId[item['id'] as int] =
                  item['refund'] as Map<String, dynamic>;
            }
          }
        }
        // paginator 判断是否还有下一页，异常时按本页数量兜底
        final paginator = json['paginator'];
        var hasMore = newOrders.length >= _pageSize;
        if (paginator is Map<String, dynamic> &&
            paginator['current_page'] is int &&
            paginator['last_page'] is int) {
          hasMore = (paginator['current_page'] as int) <
              (paginator['last_page'] as int);
        }
        if (!mounted) return;
        setState(() {
          _orders.addAll(newOrders);
          _page++;
          _hasMore = hasMore;
        });
      } else if (_page == 1 && mounted) {
        await HttpExceptionNotifyUser.showInfo(
          S.of(context).somethingWentWrong,
        );
      }
    } catch (_) {
      if (_page == 1 && mounted) {
        await HttpExceptionNotifyUser.showInfo(
          S.of(context).somethingWentWrong,
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: _appBar(),
      body: _orders.isNotEmpty
          ? _purchasesList()
          : _isLoading
              ? Center(child: progressIndicator())
              : _emptyState(),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: InkWell(
        onTap: () => Navigator.pop(context),
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
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _orders.length + 1,
        itemBuilder: (context, index) {
          if (index < _orders.length) {
            return _orderCard(index);
          }
          // ★ 底部加载区域
          if (_isLoading && _page > 1) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CupertinoActivityIndicator()),
            );
          }
          if (!_hasMore) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Center(
                child: Text(
                  '—— ${S.of(context).no_more_orders} ——',
                  style: GoogleFonts.rubik(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // 点击卡片进入订单详情页，详情页发生退款申请等操作后返回并刷新列表
  Future<void> _openDetail(Order order) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseDetail(
          order: order,
          refund: _refundByOrderId[order.id],
          api: widget.services.api,
          store: widget.services.store,
        ),
      ),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  // 订单卡片（参考京东订单列表样式）：
  // 药房 + 状态 / 订单号 + 时间 / 商品预览 / 合计 / 操作按钮
  Widget _orderCard(int index) {
    return Builder(
      builder: (context) {
        final order = _orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: AppColors.kffffff,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openDetail(order),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 药房名称 + 订单状态
                  Row(
                    children: [
                      Container(
                        height: 24,
                        width: 24,
                        decoration: BoxDecoration(
                          color: AppColors.k0cbcc5.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_pharmacy_outlined,
                          color: AppColors.k0cbcc5,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.pharmacy?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.rubik(
                            color: AppColors.k010101,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _orderStatusText(order),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 订单号 + 下单时间
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${S.of(context).orderNumber}: ${order.id ?? ''}',
                        style: GoogleFonts.rubik(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDate(order.createdAt),
                        style: GoogleFonts.rubik(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFF4F5F7)),
                  // 商品预览（京东风格）
                  _productsPreview(order),
                  const Divider(color: Color(0xFFF4F5F7)),
                  // 件数 + 订单总计
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        S.of(context).totalItems(_totalQty(order)),
                        style: GoogleFonts.rubik(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${S.of(context).orderTotal}  ',
                            style: GoogleFonts.rubik(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            order.pharmacyCurrency ?? '',
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${order.orderTotal}',
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: Color(0xFFF4F5F7)),
                  const SizedBox(height: 6),
                  // 底部操作按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_canRequestRefund(order)) ...[
                        _orderActionButton(
                          label: S.of(context).requestRefund,
                          color: AppColors.ke63030,
                          onTap: () => _requestRefund(order),
                        ),
                        const SizedBox(width: 10),
                      ],
                      _orderActionButton(
                        label: S.of(context).orderAgain,
                        color: AppColors.k0cbcc5,
                        onTap: () => _orderAgain(order),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _totalQty(Order order) {
    var count = 0;
    for (final prod in order.products ?? <Product>[]) {
      count += (prod.pivot?.qty ?? 0).toInt();
    }
    return count;
  }

  bool _canRequestRefund(Order order) {
    final status = order.orderStatus ?? 0;
    if (status < _statusConfirming || status > _statusReadyForCollection) {
      return false;
    }
    // 已有退款申请（含被拒绝）的订单不允许再次申请
    return _refundByOrderId[order.id] == null;
  }

  // 商品预览：单件显示详情行，多件横排缩略图（最多 3 张，自适应宽度）
  Widget _productsPreview(Order order) {
    final products = order.products ?? [];
    if (products.isEmpty) return const SizedBox.shrink();
    if (products.length == 1) {
      return _singleProductRow(order, products.first);
    }

    final shownCount = products.length > 3 ? 3 : products.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          var size = (constraints.maxWidth - spacing * 2) / 3;
          size = size.clamp(48.0, 84.0);
          return Row(
            children: [
              for (var i = 0; i < shownCount; i++) ...[
                _productImage(products[i], size),
                if (i != shownCount - 1) const SizedBox(width: spacing),
              ],
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: AppColors.kb1b1b1,
                size: 18,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _singleProductRow(Order order, Product prod) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _productImage(prod, 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prod.name ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${order.pharmacyCurrency} ${prod.unitPrice}',
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '×${(prod.pivot?.qty ?? 0).toInt()}',
                      style: GoogleFonts.rubik(
                        color: AppColors.k5e5e5e,
                        fontSize: 13,
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

  Widget _productImage(Product prod, double size) {
    final images = prod.productImages;
    final url = (images != null && images.isNotEmpty) ? images.first.image : null;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (context, exception, stackTrace) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/default_shop_image.png',
              height: size,
              width: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.kf4f4f4,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(Icons.local_pharmacy, size: size / 2),
      ),
    );
  }

  // 底部操作按钮（圆角描边胶囊）
  Widget _orderActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.rubik(fontSize: 13, color: color),
      ),
    );
  }

  // 申请退款（共享流程），提交成功后刷新列表
  Future<void> _requestRefund(Order order) async {
    final ok = await showRefundFlow(
      context,
      order: order,
      api: widget.services.api,
    );
    if (ok) {
      await _refresh();
    }
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
    await _refresh();
  }

  // 订单状态文字：默认已支付；退款流程中显示 退款中/已退款/已拒绝
  Widget _orderStatusText(Order order) {
    final status = order.orderStatus ?? 0;
    final refund = _refundByOrderId[order.id];

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

    return Text(
      label,
      style: GoogleFonts.rubik(color: color, fontSize: 14),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return DateFormat('dd MMM yyyy hh:mm aaa').format(DateTime.parse(raw));
  }

  Widget divider() {
    return Container(height: 0.5, color: AppColors.k5e5e5e.withOpacity(0.15));
  }
}
