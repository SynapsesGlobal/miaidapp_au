import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/view/marketing/product_detail.dart';
import '../../api_utils/api_provider.dart';
import '../../api_utils/consts.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import '../../services/marketing_payment_service.dart';
import '../../utils/configure_dependencies.dart';
import 'company_products.dart';
import 'package:http/http.dart' as http;

class Checkout extends StatefulWidget {
  final List products;
  final dynamic company;
  final Map<int, int> quantities;

  const Checkout({
    super.key,
    required this.products,
    required this.company,
    required this.quantities
  });

  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
  var loading = true;
  late int credits = 0;
  late String point_money_ratio;
  late String max_deduction_ratio;
  final TextEditingController _quantityController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<Widget> productListView;

  @override
  void initState() {
    _getCreditPoints();
    super.initState();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getCreditPoints() async {
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
      final url = Uri.parse(Consts.marketingApiHost+'/credits/total').replace(queryParameters: {
        'userId': api.userProvider.user!.id.toString(),
        'currency': widget.products[0]['currency']
      });
      final response = await http.get(url, headers: headers);

      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        print(responseData);
        setState(() {
          point_money_ratio = responseData['point_money_ratio'].toString();
          max_deduction_ratio = responseData['max_deduct_ratio'].toString();
          credits = int.parse(responseData['credit'].toString());
          loading = false;
        });
      } else {
        await EasyLoading.dismiss();
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      print(e.toString());
      await EasyLoading.dismiss();
    }
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
        title: Text(S.of(context).checkout, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () => Navigator.pop(context),
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: loading ? Offstage() : Padding(
        padding: EdgeInsets.all(15),
        child: SingleChildScrollView(child: Column(
          children: [
            _buildProductView(),
            _buildCreditPointView(),
            _buildActionView()
          ],
        ),),
      ),
    );
  }

  Widget _buildCreditPointView() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              Text(S.of(context).available_credit, style: GoogleFonts.rubik(
                color: AppColors.k0cbcc5,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),),
              Text(credits.toString(), style: GoogleFonts.rubik(
                color: AppColors.k0cbcc5,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),),
            ],),
            Divider(color: Colors.black12,),
            SizedBox(height: 10,),
            TextField(
              controller: _quantityController,
              decoration: InputDecoration(
                hintText: S.of(context).point_deduct_number,
                hintStyle: TextStyle(
                  color: AppColors.kb1b1b1,
                  fontSize: 14,
                ),
                contentPadding: EdgeInsets.only(left: 16, top: 5, bottom: 5,),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.k010101,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.kb1b1b1,
                    width: 0.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.kfa0020,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.kfa0020,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.confirmation_num, color: Colors.grey, size: 16,)
              ),
              textInputAction: TextInputAction.done,
              // 关键2：点击“完成”时收起键盘
              onEditingComplete: () {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            ),
            SizedBox(height: 10,),
            Divider(color: Colors.black12,),
            Text(S.of(context).point_usage_rule, style: GoogleFonts.rubik(
              color: AppColors.k0cbcc5,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),),
            SizedBox(height: 4,),

            Text('1.'+S.of(context).point_money_ratio("${widget.products[0]['currency']} $point_money_ratio"), style: GoogleFonts.rubik(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),),
            SizedBox(height: 4,),
            Text('2.'+S.of(context).max_deduct_ratio('$max_deduction_ratio%'), style: GoogleFonts.rubik(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),),
          ],
        ),
      ),
    );
  }

  Widget _buildProductView() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(children: [
          InkWell(
            onTap: ()=> Navigator.push(context, MaterialPageRoute<void>(
              builder: (context) => CompanyProducts(company: widget.company),
            ),),
            child: Row(children: [
              ClipOval(child: CachedNetworkImage(
                height: 30,
                width: 30,
                fit: BoxFit.cover,
                imageUrl: widget.company['image'],
              ),),
              SizedBox(width: 5,),
              Text(widget.company['name'], style: GoogleFonts.rubik(color: AppColors.k0cbcc5))
            ],),
          ),
          Divider(color: Colors.black12),
          ...List.generate(widget.products.length, (pIndex) {
            final product = widget.products[pIndex];
            return Column(children: [
              InkWell(
                onTap: ()=> Navigator.push(context, MaterialPageRoute<void>(
                  builder: (context) => ProductDetail(
                    product: product,
                    company: widget.company,
                  ),
                ),),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        height: 120,
                        width: 120,
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
                        )),
                        SizedBox(height: 2),
                        Text(
                          product['description'],
                          style: GoogleFonts.rubik(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text('${product['currency']}', style: GoogleFonts.rubik(
                              color: AppColors.k0cbcc5,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            )),
                            SizedBox(width: 2,),
                            Text('${product['discount_price']}', style: GoogleFonts.rubik(
                              color: AppColors.k0cbcc5,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            )),
                            SizedBox(width: 5,),
                            product['price'] != product['discount_price'] ? Text('${product['price']}', style: GoogleFonts.rubik(
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
                            child: Icon(CupertinoIcons.minus_square_fill, color: int.parse(widget.quantities[product['productId']].toString()) > 1 ? AppColors.k0cbcc5 : Colors.grey[400], size: 30,),
                            onTap: () {
                              var quantity = int.parse(widget.quantities[product['productId']].toString() ?? '1');
                              if (quantity > 1) {
                                quantity = quantity-1;
                                setState(() => widget.quantities[product['productId']] = quantity);
                              }
                            },
                          ),
                          SizedBox(width: 5,),
                          Text(widget.quantities[product['productId']].toString() ?? '1', style: GoogleFonts.rubik(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w500
                          )),
                          SizedBox(width: 5,),
                          InkWell(
                            onTap: () {
                              var quantity = int.parse(widget.quantities[product['productId']].toString() ?? '1');
                              quantity = quantity+1;
                              setState(() => widget.quantities[product['productId']] = quantity);
                            },
                            child: Icon(CupertinoIcons.plus_square_fill, color: AppColors.k0cbcc5, size: 30,),
                          )
                        ],)
                      ],
                    ),),
                  ],
                ),
              ),
              pIndex == widget.products.length-1 ? Offstage() : SizedBox(height: 8,),
              pIndex == widget.products.length-1 ? Offstage() : Divider(color: Colors.black12),
              pIndex == widget.products.length-1 ? Offstage() : SizedBox(height: 8,),
            ],);
          }),
        ],),
      ),
    );;
  }

  Widget _buildActionView() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: MaterialButton(
          padding: EdgeInsets.symmetric(vertical: 10),
          onPressed: () async {
            var purchaseProducts = [];
            for (var p in widget.products) {
              int pid = p['productId'];
              purchaseProducts.add({'productId': pid, 'quantity': widget.quantities[pid] ?? 1,});
            }
            await MarketingPaymentService.instance.handlePurchase(
              context: context,
              companyId: widget.company['companyId'].toString(),
              points: _quantityController.text.isNotEmpty ? _quantityController.text : '0',
              products: purchaseProducts,
            );
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: AppColors.k0cbcc5,
          child: Text(S.of(context).purchase_now, style: GoogleFonts.rubik(color: Colors.white),),
        )),
        SizedBox(width: 10,),
        Expanded(child: MaterialButton(
          padding: EdgeInsets.symmetric(vertical: 10),
          onPressed: () => Navigator.of(context).pop(),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: Colors.grey,
          child: Text(S.of(context).cancel, style: GoogleFonts.rubik(color: Colors.white),),
        ))
      ],
    );
  }
}
