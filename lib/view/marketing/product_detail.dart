import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/widget/count_down.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api_utils/api_provider.dart';
import '../../api_utils/consts.dart';
import '../../api_utils/http_exception.dart';
import '../../generated/l10n.dart';
import '../../utils/configure_dependencies.dart';
import '../../config/app_colors.dart';
import '../../component/nav_bar_icons.dart';
import 'package:map_launcher/map_launcher.dart' as ml;

import 'checkout.dart';

class ProductDetail extends StatefulWidget {
  final dynamic product;
  final dynamic company;

  const ProductDetail({
    super.key,
    required this.product,
    required this.company,
  });

  @override
  State<ProductDetail> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> with SingleTickerProviderStateMixin {
  Map<String, dynamic> detail = {};
  bool collected = false;
  bool loading = true;
  late TabController _tabController;
  int _tabIndex = 0;
  int _quantity = 1;
  var _showCountDown = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _getProductDtl();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getProductDtl() async {
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    try {
      await EasyLoading.show(
        status: 'Loading',
        maskType: EasyLoadingMaskType.black,
      );

      final api = getIt<ApiProvider>();
      final url = Uri.parse(Consts.marketingApiHost + '/product/detail').replace(queryParameters: {
        'productId': widget.product['productId'].toString(),
        'userId': api.userProvider.user!.id.toString(),
        'source': 'au'
      });

      final response = await http.get(url, headers: headers);
      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body)['product'];
        setState(() {
          detail = responseData ?? {};
          collected = detail['collected'] ?? false;
          loading = false;
        });
      } else {
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      print(e);
      await EasyLoading.dismiss();
      await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
    }
  }

  Future<void> _addToWishlist() async {
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    try {
      await EasyLoading.show(
        status: 'Loading',
        maskType: EasyLoadingMaskType.black,
      );

      final api = getIt<ApiProvider>();
      final url = Uri.parse('${Consts.marketingApiHost}/product/wish');

      final body = jsonEncode({
        'productId': widget.product['productId'],
        'userId': api.userProvider.user!.id,
        'companyId': widget.company['companyId'],
        'source': 'au',
      });

      final response = await http.post(url, headers: headers, body: body);

      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        await HttpExceptionNotifyUser.showInfo('Added to wish list.');
      } else {
        await HttpExceptionNotifyUser.showInfo(
          S.of(context).somethingWentWrong,
        );
      }
    } catch (e) {
      print('add error: $e');
      await EasyLoading.dismiss();
      await HttpExceptionNotifyUser.showInfo(
        S.of(context).somethingWentWrong,
      );
    }
  }

  Future<void> _removeFromWishlist() async {
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    try {
      await EasyLoading.show(
        status: 'Loading',
        maskType: EasyLoadingMaskType.black,
      );

      final api = getIt<ApiProvider>();
      final url = Uri.parse('${Consts.marketingApiHost}/product/remove/wish');

      final body = jsonEncode({
        'productId': widget.product['productId'],
        'userId': api.userProvider.user!.id,
        'companyId': widget.company['companyId'],
        'source': 'au',
      });
      final response = await http.post(url, headers: headers, body: body);

      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        await HttpExceptionNotifyUser.showInfo('Removed from wish list.');
      } else {
        await HttpExceptionNotifyUser.showInfo(
          S.of(context).somethingWentWrong,
        );
      }
    } catch (e) {
      print('remove: $e');
      await EasyLoading.dismiss();
      await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
    }
  }

  Future<void> _getCreditRewards() async {
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    try {
      final api = getIt<ApiProvider>();
      final url = Uri.parse(Consts.marketingApiHost + '/credits/product').replace(queryParameters: {
        'productId': widget.product['productId'].toString(),
        'userId': api.userProvider.user!.id.toString(),
        'source': 'au'
      });

      final response = await http.post(url, headers: headers);
      if (response.statusCode != 200) {
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      print(e);
      await EasyLoading.dismiss();
      await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    String imageURL = detail['image'] ?? '';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          widget.product['title'],
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.favorite, color: collected ? AppColors.k0cbcc5 : Colors.black26,),
            onPressed: () {
              setState(() => collected = !collected);
              collected ? _addToWishlist() : _removeFromWishlist();
            },
          ),
        ],
      ),
      body: loading ? Text('') : SingleChildScrollView(
        child: Stack(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 商品图片
              imageURL.isNotEmpty ? Image.network(
                imageURL,
                width: double.infinity,
                height: 400,
                fit: BoxFit.cover,
              ) : Container(
                height: 400,
                color: Colors.grey[200],
                child: Center(child: Text('No Image')),
              ),

              // 内容详情
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail['title'] ?? '', style: GoogleFonts.rubik(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text('${detail['currency']}', style: GoogleFonts.rubik(
                              color: AppColors.k0cbcc5,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            )),
                            SizedBox(width: 2,),
                            Text('${detail['discount_price']}', style: GoogleFonts.rubik(
                              color: AppColors.k0cbcc5,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            )),
                            SizedBox(width: 5,),
                            detail['price'] != detail['discount_price'] ? Text('${detail['currency']} ${detail['price']}', style: GoogleFonts.rubik(
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
                            child: Icon(CupertinoIcons.minus_square_fill, color: _quantity > 1 ? AppColors.k0cbcc5 : Colors.grey[400], size: 30,),
                            onTap: () {
                              if (_quantity > 1) setState(() => _quantity -= 1);
                            },
                          ),
                          SizedBox(width: 5,),
                          Text(_quantity.toString(), style: GoogleFonts.rubik(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500
                          )),
                          SizedBox(width: 5,),
                          InkWell(
                            onTap: () => setState(() => _quantity += 1),
                            child: Icon(CupertinoIcons.plus_square_fill, color: AppColors.k0cbcc5, size: 30,),
                          )
                        ],)
                      ],
                    ),

                    SizedBox(height: 10),
                    Divider(color: Colors.grey[200],),
                    TabBar(
                      tabAlignment: TabAlignment.start,
                      onTap: (index)=> setState(() => _tabIndex = index),
                      controller: _tabController,
                      labelColor: AppColors.k0cbcc5,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppColors.k0cbcc5,
                      labelStyle: GoogleFonts.rubik(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      isScrollable: true,
                      indicatorSize: TabBarIndicatorSize.tab,
                      padding: EdgeInsets.zero,
                      labelPadding: EdgeInsets.only(right: 25),
                      indicatorPadding: EdgeInsets.zero,
                      tabs: const [
                        Tab(text: 'Description'),
                        Tab(text: 'Instructions'),
                        Tab(text: 'Eligibility'),
                        Tab(text: 'Location'),
                        Tab(text: 'Company Info'),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildTabContent(_tabIndex)
                  ],
                ),
              ),
            ],
          ),
          _showCountDown && !detail['rewarded'] ? Positioned(right:20, top: 20, child: Countdown(
            onFinished: () {
              setState(() => _showCountDown = false);
              _getCreditRewards();
            },
            size: 40,
            seconds: int.parse(detail['threshold']),
          )) : Offstage()
        ],),
      ),

      // 底部按钮
      bottomNavigationBar: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: MaterialButton(
              padding: EdgeInsets.symmetric(vertical: 12),
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute<void>(
                  builder: (context) => Checkout(
                    products: [widget.product],
                    company: widget.company,
                    quantities: {widget.product['productId']: _quantity},
                  ),
                ),);
              },
              color: AppColors.k0cbcc5,
              child: Text('${S.of(context).purchase_now}', style: GoogleFonts.rubik(color: Colors.white),),
            )),
            SizedBox(width: 10,),
            Expanded(child: MaterialButton(
              padding: EdgeInsets.symmetric(vertical: 12),
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () {
                var company = detail['company'];
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (BuildContext context) => Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: ()=> Navigator.of(context).pop(),
                            child: Icon(Icons.close, color: Colors.grey,),
                          ),
                        ),
                        SizedBox(height: 5,),
                        Divider(color: Colors.grey[200],),
                        SizedBox(height: 5,),
                        Row(children: [
                          ClipOval(child: CachedNetworkImage(
                            height:  MediaQuery.of(context).size.width*0.25,
                            width: MediaQuery.of(context).size.width*0.25,
                            fit: BoxFit.cover,
                            imageUrl: company['image'],
                          ),),
                          SizedBox(width: 10,),
                          SizedBox(
                            width: MediaQuery.of(context).size.width*0.60,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(company['name'], style: GoogleFonts.rubik(
                                  color: AppColors.k010101,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),),
                                Text("${company['area_code']} ${company['phone']}", style: GoogleFonts.rubik(
                                  color: AppColors.k010101,
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                ),),
                                SizedBox(height: 8),
                                Text(company['address'], style: GoogleFonts.rubik(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                ),),
                              ],
                            ),
                          )
                        ],),
                        Divider(color: Colors.grey[200],),
                        Row(
                          children: [
                            Expanded(flex: 3, child: MaterialButton(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onPressed: () async {
                                final availableMaps = await ml.MapLauncher.installedMaps;
                                if (availableMaps.isNotEmpty) {
                                  await availableMaps.first.showMarker(
                                    coords: ml.Coords(double.parse(company['latitude']), double.parse(company['longitude'])),
                                    title: company['name'],
                                    description: company['address']
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(S.of(context).installMap),),
                                  );
                                }
                              },
                              color: AppColors.k0cbcc5,
                              child: Text(S.of(context).getDirection, style: GoogleFonts.rubik(color: Colors.white),),
                            )),
                            SizedBox(width: 10,),
                            Expanded(flex: 2, child: MaterialButton(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onPressed: () {
                                if (company['phone'] != null) {
                                  launch('tel://${company['area_code']}${company['phone']}');
                                }
                              },
                              color: AppColors.k0cbcc5,
                              child: Text(S.of(context).dial_phone, style: GoogleFonts.rubik(color: Colors.white),),
                            )),
                            widget.company['attachment'].toString().isNotEmpty ? SizedBox(width: 10,) : Offstage(),
                            widget.company['attachment'].toString().isNotEmpty ? Expanded(flex: 4, child: MaterialButton(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onPressed: () async {
                                if (await canLaunchUrl(Uri.parse(widget.company['attachment']))) {
                                  await launchUrl(Uri.parse(widget.company['attachment']));
                                }
                              },
                              color: AppColors.k0cbcc5,
                              child: Text(
                                S.of(context).product_usage_instruction,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.rubik(color: Colors.white),
                              ),
                            )) : Offstage()
                          ],
                        ),
                        SizedBox(height: 10,),
                        Text(S.of(context).direction_caption, style: GoogleFonts.rubik(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),),
                      ],
                    ),
                  ),
                );
              },
              color: AppColors.k0CC58F,
              child: Text('${S.of(context).contact_shop}', style: GoogleFonts.rubik(color: Colors.white),),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(int _tabIndex) {
    if (_tabIndex == 0) {
      return Text(detail['description']?.toString() ?? 'No more information.', style: GoogleFonts.rubik(
        color: Colors.grey,
        height: 1.4,
      ),);
    }

    if (_tabIndex == 1) {
      return Text(detail['instruction']?.toString() ?? 'No more information.', style: GoogleFonts.rubik(
        color: Colors.grey,
        height: 1.4,
      ),);
    }

    if (_tabIndex == 2) {
      return Text(detail['eligibility']?.toString() ?? 'No more information.', style: GoogleFonts.rubik(
        color: Colors.grey,
        height: 1.4,
      ),);
    }

    if (_tabIndex == 3) {
      return Text(detail['locations']?.toString() ?? 'No more information.', style: GoogleFonts.rubik(
        color: Colors.grey,
        height: 1.4,
      ),);
    }

    if (_tabIndex == 4) {
      return Text(detail['companyInfo']?.toString() ?? 'No more information.', style: GoogleFonts.rubik(
        color: Colors.grey,
        height: 1.4,
      ),);
    }

    return Offstage();
  }
}