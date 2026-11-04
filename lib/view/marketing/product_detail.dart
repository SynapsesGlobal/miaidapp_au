import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/widget/count_down.dart';
import '../../api_utils/api_provider.dart';
import '../../api_utils/http_exception.dart';
import '../../generated/l10n.dart';
import '../../services/marketing_payment_service.dart';
import '../../utils/configure_dependencies.dart';
import '../../config/app_colors.dart';
import '../../component/nav_bar_icons.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/services/marketing_api.dart';
import 'package:miaid/widget/contact_shop_sheet.dart';
import 'package:miaid/widget/product_media_gallery.dart';

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
    final headers = MarketingApi.headers();

    try {
      await EasyLoading.show(
        status: S.current.loading,
        maskType: EasyLoadingMaskType.black,
      );

      final api = getIt<ApiProvider>();
      final url = Uri.parse(getIt<ApiSettings>().marketingApiHost + '/product/detail').replace(queryParameters: {
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
    final headers = MarketingApi.headers();

    try {
      await EasyLoading.show(
        status: S.current.loading,
        maskType: EasyLoadingMaskType.black,
      );

      final api = getIt<ApiProvider>();
      final url = Uri.parse('${getIt<ApiSettings>().marketingApiHost}/product/wish');

      final body = jsonEncode({
        'productId': widget.productId,
        'userId': api.userProvider.user!.id,
        'companyId': widget.companyId,
        'source': 'au',
      });

      final response = await http.post(url, headers: headers, body: body);

      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        await HttpExceptionNotifyUser.showInfo(S.current.addedToWishList);
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
    final headers = MarketingApi.headers();

    try {
      await EasyLoading.show(
        status: S.current.loading,
        maskType: EasyLoadingMaskType.black,
      );

      final api = getIt<ApiProvider>();
      final url = Uri.parse('${getIt<ApiSettings>().marketingApiHost}/product/remove/wish');

      final body = jsonEncode({
        'productId': widget.productId,
        'userId': api.userProvider.user!.id,
        'companyId': widget.companyId,
        'source': 'au',
      });
      final response = await http.post(url, headers: headers, body: body);

      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        await HttpExceptionNotifyUser.showInfo(S.current.removedFromWishList);
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
    final headers = MarketingApi.headers();

    try {
      final api = getIt<ApiProvider>();
      final url = Uri.parse(getIt<ApiSettings>().marketingApiHost + '/credits/product').replace(queryParameters: {
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
              // 商品相册：视频（若有）+ 多张图片，可滑动
              ProductMediaGallery.fromProduct(detail),

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
                      tabs: [
                        Tab(text: S.of(context).productDescription),
                        Tab(text: S.of(context).productInstructions),
                        Tab(text: S.of(context).productEligibility),
                        Tab(text: S.of(context).location),
                        Tab(text: S.of(context).companyInfo),
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
                    final company = detail['company'];
                    ContactShopSheet.show(context, company is Map ? Map<String, dynamic>.from(company) : null);
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
      return Text(detail['description']?.toString() ?? S.of(context).noMoreInformation, style: GoogleFonts.rubik(
        color: Colors.grey,
        height: 1.4,
      ),);
    }

    if (_tabIndex == 1) {
      return Text(detail['instruction']?.toString() ?? S.of(context).noMoreInformation, style: GoogleFonts.rubik(
        color: Colors.grey,
        height: 1.4,
      ),);
    }

    if (_tabIndex == 2) {
      return Text(detail['eligibility']?.toString() ?? S.of(context).noMoreInformation, style: GoogleFonts.rubik(
        color: Colors.grey,
        height: 1.4,
      ),);
    }

    if (_tabIndex == 3) {
      return Text(detail['locations']?.toString() ?? S.of(context).noMoreInformation, style: GoogleFonts.rubik(
        color: Colors.grey,
        height: 1.4,
      ),);
    }

    if (_tabIndex == 4) {
      return Text(detail['companyInfo']?.toString() ?? S.of(context).noMoreInformation, style: GoogleFonts.rubik(
        color: Colors.grey,
        height: 1.4,
      ),);
    }

    return Offstage();
  }
}