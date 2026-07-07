import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../api_utils/api_provider.dart';
import '../../api_utils/consts.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import '../../services/marketing_payment_service.dart';
import '../../utils/configure_dependencies.dart';
import 'company_products.dart';

class Wishes extends StatefulWidget {
  const Wishes({super.key});

  @override
  State<Wishes> createState() => _WishesState();
}

class _WishesState extends State<Wishes> {
  List wishes = [];
  List selectedProducts = [];
  Map<int, bool> selectedCompanies = {};
  Map<int, int> quantities = {}; // ⭐ 产品数量
  String no_data = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _getWishes();
  }

  Future<void> _getWishes() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    await EasyLoading.show(
      status: 'Loading',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final api = getIt<ApiProvider>();
      final url = Uri.parse(Consts.marketingApiHost + '/product/wishes')
          .replace(queryParameters: {
        'userId': api.userProvider.user!.id.toString(),
        'source': 'au'
      });

      final response = await http.get(url, headers: headers);
      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body)['wishes'];

        setState(() {
          wishes = responseData;
          selectedProducts.clear();
          quantities.clear();

          for (var w in wishes) {
            int companyId = w['companyId'];
            selectedCompanies[companyId] = true;

            for (var p in w['products']) {
              int pid = p['productId'];

              selectedProducts.add(pid);
              quantities[pid] = 1; // ⭐ 默认数量
            }
          }

          no_data = responseData.isNotEmpty ? '' : 'No data available.';
          isLoading = false;
        });
      } else {
        await EasyLoading.dismiss();
        setState(() => isLoading = false);
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      await EasyLoading.dismiss();
      setState(() => isLoading = false);
    }
  }

  Future<void> _removeFromWishlist(String companyId) async {
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    var companyProductIds = [];

    for (var w in wishes) {
      if (w['companyId'].toString() != companyId.toString()) continue;
      companyProductIds = (w['products'] as List).map((item) => item['productId']).toList();
    }

    var deleteProductIds = [];

    for (var pid in selectedProducts) {
      if (companyProductIds.contains(pid)) deleteProductIds.add(pid);
    }

    if (deleteProductIds.isEmpty) {
      await HttpExceptionNotifyUser.showInfo('please select one product at least.');
      return;
    }

    try {
      await EasyLoading.show(status: 'Loading');

      final api = getIt<ApiProvider>();
      final url = Uri.parse('${Consts.marketingApiHost}/product/batch/remove/wish');

      final body = jsonEncode({
        'productIds': deleteProductIds,
        'userId': api.userProvider.user!.id,
        'companyId': companyId,
        'source': 'au',
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        await _getWishes();
        await HttpExceptionNotifyUser.showInfo('Removed from wish list.');
      } else {
        await EasyLoading.dismiss();
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      await EasyLoading.dismiss();
      await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
    }
  }

  Future<void> _purchase(String companyId) async {
    var purchaseProducts = <Map<String, dynamic>>[];

    for (var w in wishes) {
      if (w['companyId'].toString() != companyId.toString()) continue;

      for (var p in w['products']) {
        int pid = p['productId'];

        if (!selectedProducts.contains(pid)) continue;
        purchaseProducts.add({'productId': pid, 'quantity': quantities[pid] ?? 1,});
      }
    }

    if (purchaseProducts.isEmpty) {
      await HttpExceptionNotifyUser.showInfo('please select one product at least.');
      return;
    }

    await MarketingPaymentService.instance.handlePurchase(
      context: context,
      companyId: companyId,
      products: purchaseProducts,
    );
  }

  void _toggleCompanySelection(int companyId, bool? selected) {
    setState(() {
      selectedCompanies[companyId] = selected ?? false;

      var companyProductIds = <int>[];
      for (var w in wishes) {
        if (w['companyId'] != companyId) continue;
        companyProductIds = (w['products']).map<int>((dynamic p) => int.parse(p['productId'].toString())).toList();
      }

      if (selected == true) {
        selectedProducts.addAll(companyProductIds);
      } else {
        selectedProducts.removeWhere((id) => companyProductIds.contains(id));
      }
    });
  }

  void _toggleProductSelect(int productId, bool? selected) {
    setState(() {
      if (selected == true) {
        if (!selectedProducts.contains(productId)) {
          selectedProducts.add(productId);
        }
      } else {
        selectedProducts.remove(productId);
      }
    });
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
          '我的收藏',
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
      body: isLoading ? const SizedBox.shrink() : wishes.isNotEmpty ? ListView.builder(
        padding: EdgeInsets.all(10),
        itemCount: wishes.length,
        itemBuilder: (context, index) => Card(
          elevation: 0,
          margin: EdgeInsets.only(bottom: 16),
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /*Text(
                  wishes[index]['companyName'],
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),*/
                InkWell(
                  onTap: ()=> Navigator.push(context, MaterialPageRoute<void>(
                    builder: (context) => CompanyProducts(company: wishes[index]['company']),
                  ),),
                  child: Row(children: [
                    ClipOval(
                      child: CachedNetworkImage(
                        height: 30,
                        width: 30,
                        fit: BoxFit.cover,
                        imageUrl: wishes[index]['company']['image'],
                      ),
                    ),
                    SizedBox(width: 5,),
                    Expanded(
                      child: Text(
                        wishes[index]['company']['name'],
                        softWrap: true,
                        style: GoogleFonts.rubik(color: AppColors.k0cbcc5),
                      ),
                    ),
                  ],),
                ),
                Divider(color: Colors.black12),
                ...List.generate(wishes[index]['products'].length, (pIndex) => _buildProducts(
                    wishes[index]['products'][pIndex],
                    wishes[index]['companyId'].toString()),
                ),
                Row(children: [
                  SizedBox(
                    width: 25,
                    height: 25,
                    child: Checkbox(
                      activeColor: AppColors.k0cbcc5,
                      value: selectedCompanies[wishes[index]['companyId']] ?? false,
                      onChanged: (selected) => _toggleCompanySelection(wishes[index]['companyId'], selected),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: MaterialButton(
                    onPressed: () => _purchase(wishes[index]['companyId'].toString()),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    color: AppColors.k0cbcc5,
                    child: Text('Purchase', style: GoogleFonts.rubik(color: Colors.white),),
                  ),),
                  SizedBox(width: 10),
                  Expanded(child: MaterialButton(
                    onPressed: () => _removeFromWishlist(wishes[index]['companyId'].toString()),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    color: AppColors.kfa0020,
                    child: Text('Delete', style: GoogleFonts.rubik(color: Colors.white),
                    ),
                  ),),
                ],),
              ],
            ),
          ),
        ),
      ) : _emptyWishes(),
    );
  }

  Widget _emptyWishes() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections,
              size: 40,
              color: AppColors.kb1b1b1,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context).noWishes,
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

  Widget _buildProducts(dynamic product, String companyId) {
    return Container(
      padding: EdgeInsets.only(bottom: 16),
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration:
      BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
      child: Row(children: [
        SizedBox(
          width: 25,
          height: 25,
          child: Checkbox(
            activeColor: AppColors.k0cbcc5,
            value: selectedProducts.contains(product['productId']),
            onChanged: (selected) => _toggleProductSelect(product['productId'], selected),
          ),
        ),
        SizedBox(width: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            height: 100,
            width: 100,
            fit: BoxFit.cover,
            imageUrl: product['image'],
          ),
        ),
        SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product['title'], style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),),
            SizedBox(height: 2),
            Text(
              product['description'],
              style: GoogleFonts.rubik(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(
                children: [
                  Text('${product['currency']} ${product['discount_price']}', style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 14,
                  ),),
                  product['price'] != product['discount_price'] ? Text('${product['currency']} ${product['price']}', style: GoogleFonts.rubik(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.red
                  )) : Offstage(),
                ],
              ),
              Row(children: [
                InkWell(
                  child: Icon(CupertinoIcons.minus_square_fill, color: int.parse(quantities[product['productId']].toString()) > 1 ? AppColors.k0cbcc5 : Colors.grey[400], size: 30,),
                  onTap: () {
                    var quantity = int.parse(quantities[product['productId']].toString() ?? '1');
                    if (quantity > 1) {
                      quantity = quantity-1;
                      setState(() => quantities[product['productId']] = quantity);
                    }
                  },
                ),
                SizedBox(width: 5,),
                Text(quantities[product['productId']].toString() ?? '1', style: GoogleFonts.rubik(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500
                )),
                SizedBox(width: 5,),
                InkWell(
                  onTap: () {
                    var quantity = int.parse(quantities[product['productId']].toString() ?? '1');
                    quantity = quantity+1;
                    setState(() => quantities[product['productId']] = quantity);
                  },
                  child: Icon(CupertinoIcons.plus_square_fill, color: AppColors.k0cbcc5, size: 30,),
                )
              ],)
            ],),
          ],
        ),),
      ],),
    );
  }
}
