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
import '../../services/marketing_payment_service.dart';
import '../../utils/configure_dependencies.dart';
import '../../config/app_colors.dart';
import '../../component/nav_bar_icons.dart';
import 'package:map_launcher/map_launcher.dart' as ml;

class ProductDetail extends StatefulWidget {
  final String productId;
  final String title;
  final String companyId;

  const ProductDetail({
    super.key,
    required this.productId,
    required this.title,
    required this.companyId,
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
        'productId': widget.productId,
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
        'productId': widget.productId,
        'userId': api.userProvider.user!.id,
        'companyId': widget.companyId,
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
        'productId': widget.productId,
        'userId': api.userProvider.user!.id,
        'companyId': widget.companyId,
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
        'productId': widget.productId,
        'userId': api.userProvider.user!.id.toString(),
        'source': 'au'
      });

      final response = await http.post(url, headers: headers);
      if (response.statusCode != 200) {
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
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
          widget.title,
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
      body: loading
          ? const Center(child: CupertinoActivityIndicator(radius: 14))
          : SingleChildScrollView(
        child: Stack(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 商品图片
              _buildProductImage(imageURL),

              // 内容详情
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail['title'] ?? '', style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('${detail['currency']} ', style: GoogleFonts.rubik(
                                color: AppColors.k0cbcc5,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              )),
                              Text('${detail['discount_price']}', style: GoogleFonts.rubik(
                                color: AppColors.k0cbcc5,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              )),
                              SizedBox(width: 8,),
                              detail['price'] != detail['discount_price'] ? Text('${detail['currency']} ${detail['price']}', style: GoogleFonts.rubik(
                                color: Colors.grey,
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.grey,
                              )) : Offstage(),
                            ],
                          ),
                        ),
                        _buildQuantityStepper(),
                      ],
                    ),

                    SizedBox(height: 16),
                    Divider(color: Colors.grey[200], height: 1,),
                    SizedBox(height: 4),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: MaterialButton(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onPressed: () async {
                    await MarketingPaymentService.instance.handlePurchase(
                      context: context,
                      companyId: widget.companyId,
                      products: [{'productId': widget.productId, 'quantity': _quantity,}],
                    );
                  },
                  color: AppColors.k0cbcc5,
                  child: Text('${S.of(context).purchase_now}', style: GoogleFonts.rubik(color: Colors.white),),
                )),
                SizedBox(width: 10,),
                Expanded(child: MaterialButton(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onPressed: () {
                    var company = detail['company'];
                    showModalBottomSheet(
                      context: context,
                      isDismissible: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (BuildContext context) => Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        height: 320,
                        child: Column(
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
                                    Text(company['phone'], style: GoogleFonts.rubik(
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
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(child: MaterialButton(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  shape:
                                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  onPressed: () async {
                                    final availableMaps = await ml.MapLauncher.installedMaps;
                                    if (availableMaps.isNotEmpty) {
                                      await availableMaps.first.showMarker(
                                          coords: ml.Coords(company['latitude'], company['longitude']),
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
                                Expanded(child: MaterialButton(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  shape:
                                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  onPressed: () {
                                    if (company['phone'] != null) {
                                      launch('tel://${company['phone']}');
                                    }
                                  },
                                  color: AppColors.k0cbcc5,
                                  child: Text('拨打电话', style: GoogleFonts.rubik(color: Colors.white),),
                                ))
                              ],
                            ),
                            SizedBox(height: 10,),
                            Text('注意： 想要获取路线请首先在您的手机上安装导航工具，比如苹果地图、谷歌地图、百度地图、高德地图等', style: GoogleFonts.rubik(
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
        ),
      ),
    );
  }

  Widget _buildProductImage(String imageURL) {
    if (imageURL.isEmpty) {
      return Container(
        height: 360,
        width: double.infinity,
        color: Colors.grey[200],
        child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: Colors.grey[400], size: 56),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageURL,
      width: double.infinity,
      height: 360,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 360,
        color: Colors.grey[100],
        child: const Center(child: CupertinoActivityIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        height: 360,
        color: Colors.grey[200],
        child: Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.grey[400], size: 56),
        ),
      ),
    );
  }

  Widget _buildQuantityStepper() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.kf4f4f4,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            child: Icon(CupertinoIcons.minus_circle_fill,
                color: _quantity > 1 ? AppColors.k0cbcc5 : Colors.grey[400],
                size: 28),
            onTap: () {
              if (_quantity > 1) setState(() => _quantity -= 1);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_quantity.toString(),
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                )),
          ),
          InkWell(
            onTap: () => setState(() => _quantity += 1),
            child: Icon(CupertinoIcons.plus_circle_fill,
                color: AppColors.k0cbcc5, size: 28),
          ),
        ],
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