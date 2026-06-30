import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/view/marketing/order_detail.dart';

import '../../api_utils/api_provider.dart';
import '../../api_utils/consts.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import '../../utils/configure_dependencies.dart';
import 'package:http/http.dart' as http;

import 'company_products.dart';

class Orders extends StatefulWidget {
  const Orders({super.key});

  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  List historyOrders = [];

  // ★ 分页变量
  int page = 1;
  int pageSize = 6;
  bool isLoading = false;
  bool hasMore = true;
  final ScrollController _scrollController = ScrollController();

  Future<void> _getHistoryOrders() async {
    if (isLoading || !hasMore) return;

    setState(() => isLoading = true);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    if (page == 1) {
      await EasyLoading.show(
        status: 'Loading',
        maskType: EasyLoadingMaskType.black,
      );
    }

    try {
      final api = getIt<ApiProvider>();

      final url = Uri.parse('${Consts.marketingApiHost}/orders').replace(
        queryParameters: {
          'userId': api.userProvider.user?.id.toString(),
          'source': 'au',
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        },
      );

      final response = await http.get(url, headers: headers);

      if (page == 1) await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List newOrders = json['orders'];

        setState(() {
          historyOrders.addAll(newOrders);
          page++;
          hasMore = newOrders.isNotEmpty;
        });
      } else {
        if (page == 1) await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      if (page == 1) await EasyLoading.dismiss();
    }

    setState(() => isLoading = false);
  }

  Future<void> _cancelOrder(String orderId, String reason) async {
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    try {
      final url = Uri.parse('${Consts.marketingApiHost}/order/refund');

      final body = jsonEncode({
        'orderId': orderId,
        'reason': reason,
      });
      final response = await http.post(url, headers: headers, body: body);

      var responseData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(responseData['message'])),
      );

      if (response.statusCode == 200) {
        setState(() {
          page = 1;
          isLoading = false;
          hasMore = true;
          historyOrders = [];
        });
        await _getHistoryOrders();
      }
    } catch (e) {
      print('程序报错：${e}');
      await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
    }
  }

  @override
  void initState() {
    super.initState();
    _getHistoryOrders();

    // ★ 监听滚动到底部
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        _getHistoryOrders();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).history_orders,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () => Navigator.pop(context),
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),

      // ★ 没有订单时展示空状态
      body: (historyOrders.isEmpty && !isLoading)
          ? _emptyOrders()
          // ★ 使用 ListView.builder + 分页 footer
          : ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: historyOrders.length + 1,
        itemBuilder: (context, index) {
          if (index < historyOrders.length) {
            return InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetail(
                orderId: historyOrders[index]['orderId'].toString(),
              ),),),
              child: _buildOrderCard(historyOrders[index]),
            );
          }

          // ★ 底部加载区域
          if (isLoading && page > 1) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CupertinoActivityIndicator()),
            );
          }

          if (!hasMore) {
            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
              child: Center(child: Text('—— ${S.of(context).no_more_orders} ——', style: GoogleFonts.rubik(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ))),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _emptyOrders() {
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

  Widget _buildOrderCard(dynamic order) {
    var company = order['company'];
    final canCancel = order['can_cancel'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 店铺名称 + 订单状态
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => CompanyProducts(company: company),
                    )),
                    child: Row(children: [
                      ClipOval(child: CachedNetworkImage(
                        height: 24,
                        width: 24,
                        fit: BoxFit.cover,
                        imageUrl: company['image'],
                      ),),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          company['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.rubik(
                            color: AppColors.k010101,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                    ],),
                  ),
                ),
                const SizedBox(width: 8),
                _buildOrderStatus(order['status'].toString()),
              ],
            ),
            const SizedBox(height: 6),
            // 订单号 + 下单时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order['orderNbr'], style: GoogleFonts.rubik(color: Colors.grey, fontSize: 12,)),
                Text(order['created_at'], style: GoogleFonts.rubik(color: Colors.grey, fontSize: 12,)),
              ],
            ),
            const Divider(color: Color(0xFFF4F5F7)),
            // 商品预览（京东风格）
            _buildProductsPreview(order),
            const Divider(color: Color(0xFFF4F5F7)),
            // 支付方式 + 实付金额
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  order['payment_method'] == 'alipay'
                      ? Image.asset('assets/images/ic_payment_alipay.png', width: 18, height: 18)
                      : Image.asset('assets/images/ic_payment_wechatpay.png', width: 18, height: 18),
                  const SizedBox(width: 5),
                  Text(order['payment_method'] == 'alipay' ? S.of(context).alipay : S.of(context).wechatPay, style: GoogleFonts.rubik(color: Colors.grey, fontSize: 13)),
                ]),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text('${S.of(context).orderTotal}  ', style: GoogleFonts.rubik(color: Colors.grey, fontSize: 13)),
                  Text(order['currency'], style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(width: 2),
                  Text(order['amount'].toString(), style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  )),
                ]),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(color: Color(0xFFF4F5F7)),
            const SizedBox(height: 6),
            // 底部操作按钮：删除订单 / 取消订单
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _orderActionButton(
                  label: S.of(context).deleteOrder,
                  onTap: () => _confirmDeleteOrder(order['orderId'].toString()),
                ),
                if (canCancel) const SizedBox(width: 10),
                if (canCancel)
                  _orderActionButton(
                    label: S.of(context).cancelOrder,
                    primary: true,
                    onTap: () => _showCancelOrderSheet(order),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 商品图片预览：单件显示详情，多件横排缩略图（最多 3 张，自适应宽度防溢出）
  Widget _buildProductsPreview(dynamic order) {
    final products = order['products'] as List;
    if (products.isEmpty) return const SizedBox.shrink();
    if (products.length == 1) return _buildOrderItemLayout(products[0]);

    final totalQty = products.fold<int>(
      0,
      (sum, p) => sum + (int.tryParse(p['quantity'].toString()) ?? 0),
    );
    final shownCount = products.length > 3 ? 3 : products.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          const countWidth = 70.0;
          final available = constraints.maxWidth - countWidth - spacing;
          var size = (available - spacing * 2) / 3;
          size = size.clamp(48.0, 84.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < shownCount; i++) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    height: size,
                    width: size,
                    fit: BoxFit.cover,
                    imageUrl: products[i]['image'],
                  ),
                ),
                if (i != shownCount - 1) const SizedBox(width: spacing),
              ],
              const Spacer(),
              SizedBox(
                width: countWidth,
                child: Text(
                  S.of(context).totalItems(totalQty),
                  textAlign: TextAlign.end,
                  style: GoogleFonts.rubik(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 底部操作按钮（圆角描边）
  Widget _orderActionButton({
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final borderColor = primary ? AppColors.k0cbcc5 : const Color(0xFFD9D9D9);
    final textColor = primary ? AppColors.k0cbcc5 : Colors.grey[700];
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: GoogleFonts.rubik(fontSize: 13, color: textColor)),
    );
  }

  // 删除订单确认框（统一风格，参考购物车删除商品确认框；后端接口开发中）
  Future<void> _confirmDeleteOrder(String orderId) async {
    final okButton = Padding(
      padding: const EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
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
                  offset: const Offset(0.0, 4),
                ),
              ],
            ),
            child: TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                S.of(context).no,
                style: GoogleFonts.rubik(
                  color: AppColors.kffffff,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                _deleteOrder(orderId);
              },
              child: Text(
                S.of(context).deleteOrder,
                style: GoogleFonts.rubik(
                  color: AppColors.k0cbcc5,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        title: Text(
          S.of(context).deleteOrder,
          textAlign: TextAlign.center,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          S.of(context).deleteOrderConfirm,
          textAlign: TextAlign.center,
          style: GoogleFonts.rubik(fontSize: 13),
        ),
        actions: [okButton],
      ),
    );
  }

  Future<void> _deleteOrder(String orderId) async {
    // TODO: 后端删除订单接口开发中，待接入后替换为真实请求
    await HttpExceptionNotifyUser.showInfo(S.of(context).featureInDevelopment);
  }

  // 取消订单弹框
  Future<void> _showCancelOrderSheet(dynamic order) async {
    final _reasonController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
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
                            S.of(context).cancelOrder,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order['orderNbr'],
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
                        child: Icon(Icons.close, color: Colors.grey, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  S.of(context).cancelReason,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: TextField(
                  maxLines: 4,
                  controller: _reasonController,
                  keyboardType: TextInputType.text,
                  style: GoogleFonts.rubik(fontSize: 14, color: AppColors.k010101),
                  decoration: InputDecoration(
                    hintText: S.of(context).enterCancelReason,
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    contentPadding: const EdgeInsets.all(12),
                    filled: true,
                    fillColor: AppColors.kf4f4f4,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.k0cbcc5, width: 1),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: MaterialButton(
                  onPressed: () {
                    var reason = _reasonController.text;
                    if (reason.isNotEmpty) {
                      Navigator.of(context).pop();
                      _cancelOrder(order['orderId'].toString(), reason);
                    }
                  },
                  minWidth: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: AppColors.k0cbcc5,
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
        );
      },
    );
  }

  Widget _buildOrderItemLayout(dynamic product) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          height: 84,
          width: 84,
          fit: BoxFit.cover,
          imageUrl: product['image'],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product['title'], style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          )),
          const SizedBox(height: 4),
          Text(
            product['description'],
            style: GoogleFonts.rubik(
              color: Colors.grey[600],
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(product['currency'], style: GoogleFonts.rubik(
                  color: AppColors.k0cbcc5,
                  fontSize: 14,
                )),
                const SizedBox(width: 3),
                Text(product['price'].toString(), style: GoogleFonts.rubik(
                  color: AppColors.k0cbcc5,
                  fontSize: 14,
                )),
              ]),
              Text('x ${product['quantity']}', style: GoogleFonts.rubik(
                color: Colors.grey,
                fontSize: 14,
              )),
            ],
          ),
        ],
      ),),
    ],),
  );

  Widget _buildOrderStatus(String status) {
    if (status == '1') return Text(S.of(context).paid, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 14,));
    if (status == '2') return Text(S.of(context).refunding, style: GoogleFonts.rubik(color: AppColors.k0CC58F, fontSize: 14,));
    if (status == '3') return Text(S.of(context).refunded, style: GoogleFonts.rubik(color: AppColors.k5251f7, fontSize: 14,));
    if (status == '4') return Text(S.of(context).refused, style: GoogleFonts.rubik(color: AppColors.ke63030, fontSize: 14,));
    return Offstage();
  }
}
