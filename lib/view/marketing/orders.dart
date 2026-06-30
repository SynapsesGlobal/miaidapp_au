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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: ()=> Navigator.push(context, MaterialPageRoute(
                      builder: (context) => CompanyProducts(company: company),
                    )),
                    child: Row(children: [
                      ClipOval(child: CachedNetworkImage(
                        height: 30,
                        width: 30,
                        fit: BoxFit.cover,
                        imageUrl: company['image'],
                      ),),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          company['name'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.rubik(color: AppColors.k0cbcc5),
                        ),
                      ),
                    ],),
                  ),
                ),
                const SizedBox(width: 8),
                Text(order['orderNbr'], style: GoogleFonts.rubik(fontSize: 14, color: Colors.black,)),
              ],
            ),
            const Divider(color: Color(0xFFF4F5F7)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildOrderStatus(order['status'].toString()),
                Text(order['created_at'], style: GoogleFonts.rubik(color: Colors.grey, fontSize: 14,)),
              ],
            ),
            const Divider(color: Color(0xFFF4F5F7)),
            ...List.generate(order['products'].length, (pIndex) => _buildOrderItemLayout(order['products'][pIndex])),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.credit_card, size: 18, color: Colors.grey),
                  SizedBox(width: 5,),
                  Text(S.of(context).credit_card, style:GoogleFonts.rubik(color: Colors.grey)),
                  SizedBox(width: 2,),
                  order['last_four_digits'] != null ?
                  Text('(***${order['last_four_digits'].toString()})', style:GoogleFonts.rubik(color: Colors.grey)) :
                  Offstage()
                ]),
                Row(children: [
                  Text(order['currency'], style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(width: 4),
                  Text(order['amount'].toString(), style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
                ]),
              ],
            ),
            order['can_cancel'] ? const Divider(color: Color(0xFFF4F5F7)) : Offstage(),
            order['can_cancel'] ? MaterialButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                final _reasonController = TextEditingController();
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,  // 允许弹窗撑满屏幕高度
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (context) {
                    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                    return Padding(
                      padding: EdgeInsets.only(bottom: bottomInset),
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: 100,
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(order['orderNbr'], style: GoogleFonts.rubik(
                                  color: AppColors.k010101,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),),),
                                InkWell(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: const Icon(Icons.close, color: Colors.grey),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            Divider(color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            TextField(
                              maxLines: 3,
                              controller: _reasonController,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                hintText: 'Please enter cancel reason',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.k0cbcc5, width: 1),
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            SizedBox(height: 10,),
                            MaterialButton(
                              onPressed: () {
                                var reason = _reasonController.text;
                                if (reason.isNotEmpty) {
                                  Navigator.of(context).pop();
                                  _cancelOrder(order['orderId'].toString(), reason);
                                }
                              },
                              minWidth: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              color: AppColors.k0cbcc5,
                              child: Text(
                                S.of(context).confirm,
                                style: GoogleFonts.rubik(color: Colors.white),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              minWidth: MediaQuery.of(context).size.width * 0.3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              color: AppColors.k0cbcc5,
              child: Text('Cancel order', style: GoogleFonts.rubik(color: Colors.white),),
            ) : Offstage()
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemLayout(dynamic product) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF4F5F7)))),
    child: Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          height: 100,
          width: 100,
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
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
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
                color: AppColors.k0cbcc5,
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
