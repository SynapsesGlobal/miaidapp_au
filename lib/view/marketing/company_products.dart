import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/services/marketing_payment_service.dart';
import 'package:miaid/view/marketing/product_detail.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api_utils/api_provider.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import 'package:http/http.dart' as http;

import '../../generated/l10n.dart';
import '../../utils/configure_dependencies.dart';
import '../../widget/quantity_dialog.dart';
import 'package:miaid/config/api_settings.dart';

class CompanyProducts extends StatefulWidget {
  final dynamic company;
  const CompanyProducts({super.key, required this.company});

  @override
  State<CompanyProducts> createState() => _CompanyProductsState();
}

class _CompanyProductsState extends State<CompanyProducts> {
  int page = 1;
  int pageSize = 10;
  bool isLoading = false;
  bool hasMore = true;
  List categories = [];
  late int currentCateId = 0;
  String keywords = '';
  Timer? _searchDebounce;
  final TextEditingController _kwController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _getCompanyProducts(0, widget.company['companyId']);

    categories = widget.company['categories'];

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        _getCompanyProducts(currentCateId, widget.company['companyId'], keywords: keywords);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _kwController.dispose();
    _qtyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List company_products = [];
  final api = getIt<ApiProvider>();
  Future<void> _getCompanyProducts(int cateId, int companyId, {String keywords='', bool showLoading=true}) async {
    if (isLoading || !hasMore) return;

    setState(() => isLoading = true);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': getIt<ApiSettings>().marketingApiKey,
    };

    final showMask = page == 1 && showLoading;
    if (showMask) {
      await EasyLoading.show(
        status: 'Loading',
        maskType: EasyLoadingMaskType.black,
      );
    }

    try {
      final url = Uri.parse(getIt<ApiSettings>().marketingApiHost+'/company/products').replace(queryParameters: {
        'cateId': cateId.toString(),
        'companyId': companyId.toString(),
        'keywords': keywords,
        'gender': api.userProvider.user?.customer?.gender?.name,
        'birthday': api.userProvider.user?.customer?.dob,
        'page': page.toString(),
        'pageSize': pageSize.toString()
      });
      final response = await http.get(url, headers: headers);

      if (showMask) await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        final List newProducts = jsonDecode(response.body)['products'];

        setState(() {
          company_products.addAll(newProducts);
          page++;
          hasMore = newProducts.isNotEmpty;
        });
      } else {
        if (page == 1) {
          await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
        }
      }
    } catch (e) {
      print(e.toString());
      if (showMask) await EasyLoading.dismiss();
    }

    setState(() => isLoading = false);
  }

  /// 重置分页并重新拉取当前分类的商品
  void _resetAndFetch({bool showLoading = true}) {
    setState(() {
      page = 1;
      company_products = [];
      isLoading = false;
      hasMore = true;
    });
    _getCompanyProducts(currentCateId, widget.company['companyId'],
        keywords: keywords, showLoading: showLoading);
  }

  /// 输入停顿 450ms 后自动搜索，避免每敲一个字都请求一次
  void _onKeywordsChanged(String value) {
    setState(() => keywords = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _resetAndFetch(showLoading: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(widget.company['name']+'-'+S.of(context).product_list, style: GoogleFonts.rubik(
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

      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          //SliverToBoxAdapter(child: _buildCompanyHeader()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              height: 110,
              child: Container(
                color: AppColors.kffffff,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSearch(),
                    _buildCategoryBar(),
                  ],
                ),
              ),
            ),
          ),
          _buildProductSliverList(),
        ],
      ),
    );
  }

  /// 商家基本信息（布局与 e_shop_details.dart 的药店信息一致）
  Widget _buildCompanyHeader() {
    final company = widget.company;
    final phone = company['phone']?.toString() ?? '';
    final website = company['website']?.toString() ?? '';
    final attachment = company['attachment']?.toString() ?? '';
    final imageUrl = company['image']?.toString() ?? '';

    return Container(
      padding: EdgeInsets.only(top: 10, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Color.fromRGBO(90, 177, 255, 0.1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10,),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(company['name']?.toString() ?? '', style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            )),
            Padding(
              padding: const EdgeInsets.only(top: 8,),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  imageUrl.isEmpty ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/default_shop_image.png',
                      height: 100,
                      width: 100,
                    ),
                  ) : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                      imageUrl: imageUrl,
                      errorWidget: (context, url, error) => Image.asset(
                        'assets/images/default_shop_image.png',
                        height: 100,
                        width: 100,
                      ),
                    ),
                  ),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(left: 15, right: 5,),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14,),
                          child: Text(
                            company['address']?.toString() ?? '',
                            style: GoogleFonts.rubik(
                              color: AppColors.k747474,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              phone,
                              style: GoogleFonts.rubik(
                                color: AppColors.k747474,
                                fontSize: 14,
                              ),
                            ),
                            Row(children: [
                              if (attachment.isNotEmpty)
                                InkWell(
                                  onTap: () async {
                                    if (await canLaunchUrl(Uri.parse(attachment))) {
                                      await launchUrl(Uri.parse(attachment));
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Icon(Icons.file_download_outlined,
                                        size: 26, color: AppColors.k0cbcc5),
                                  ),
                                ),
                              if (website.isNotEmpty)
                                InkWell(
                                  onTap: () async {
                                    try {
                                      var url = website.trim();
                                      if (!url.startsWith('http')) {
                                        url = 'https://' + url;
                                      }
                                      await launchUrl(Uri.parse(url));
                                    } catch (e) {}
                                  },
                                  child: Image(
                                    image: AssetImage('assets/images/btn_pharmacy_web.png'),
                                  ),
                                ),
                              if (phone.isNotEmpty)
                                InkWell(
                                  onTap: () => launchUrl(Uri.parse('tel:$phone')),
                                  child: Image(
                                    image: AssetImage('assets/images/btn_pharmacy_phone.png'),
                                  ),
                                ),
                            ],),
                          ],
                        )
                      ],
                    ),
                  ),)
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  /// Search widget（布局与 e_shop_details.dart 的搜索栏一致）
  Widget _buildSearch() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 50,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16,),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(child: TextField(
            autofocus: false,
            controller: _kwController,
            decoration: InputDecoration(
              hintText: S.of(context).keywords,
              hintStyle: GoogleFonts.rubik(
                color: AppColors.kb1b1b1,
                fontSize: 14,
              ),
              contentPadding: EdgeInsets.only(
                left: 16,
                top: 5,
                bottom: 5,
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.yellow),
              ),
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
            ),
            onChanged: _onKeywordsChanged,
            textInputAction: TextInputAction.search,
            keyboardType: TextInputType.text,
            onSubmitted: (value) {
              _searchDebounce?.cancel();
              setState(() => keywords = value);
              _resetAndFetch();
            },
          ),),
          SizedBox(width: 12,),
          InkWell(
            onTap: () {
              _searchDebounce?.cancel();
              _resetAndFetch();
            },
            child: Image(
              height: 44,
              width: 44,
              image: AssetImage('assets/images/btn_search.png'),
            ),
          ),
        ],
      ),
    );
  }

  /// 分类栏（布局与 e_shop_details.dart 的分类栏一致）
  Widget _buildCategoryBar() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 60,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 18, right: 18, top: 16, bottom: 10,),
        itemCount: categories.length,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: BouncingScrollPhysics(),
        itemBuilder: (BuildContext context, index) {
          final category = categories[index];
          final selected = currentCateId == category['cateId'];
          return Row(children: [
            InkWell(
              onTap: () {
                setState(() {
                  currentCateId = category['cateId'];
                  page = 1;
                  company_products = [];
                  isLoading = false;
                  hasMore = true;
                });
                _getCompanyProducts(category['cateId'], widget.company['companyId'], keywords: keywords);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? AppColors.k0cbcc5 : AppColors.kffffff,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      width: 0.5,
                      color: !selected ? AppColors.k0cbcc5 : Colors.transparent
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.k003f51.withOpacity(0.1),
                      offset: Offset(0, 4,),
                      blurRadius: 10,
                      spreadRadius: 0,
                    )
                  ],
                ),
                padding: const EdgeInsets.only(left: 10, right: 10,),
                alignment: Alignment.center,
                child: Text(
                  category['cateName']?.toString() ?? '',
                  style: GoogleFonts.rubik(
                    color: selected ? AppColors.kffffff : AppColors.k010101,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10,),
          ],);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    if (isLoading) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No data available.', style: GoogleFonts.rubik(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          )),
        ],
      ),
    );
  }

  Widget _buildProductImage(Map product, {double? height, double? width}) {
    return CachedNetworkImage(
      height: height,
      width: width,
      fit: BoxFit.cover,
      imageUrl: product['image']?.toString() ?? '',
      placeholder: (context, url) => Container(
        height: height,
        width: width,
        color: const Color(0xFFEDEFF2),
        child: Icon(Icons.image_outlined, size: 28, color: Colors.grey.shade400),
      ),
      errorWidget: (context, url, error) => Container(
        height: height,
        width: width,
        color: const Color(0xFFEDEFF2),
        child: Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildPriceRow(Map product, {double fontSize = 16}) {
    final hasDiscount = product['price'] != product['discount_price'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('${product['currency']} ', style: GoogleFonts.rubik(
          color: AppColors.k0cbcc5,
          fontSize: fontSize - 4,
          fontWeight: FontWeight.w500,
        )),
        Text('${product['discount_price']}', style: GoogleFonts.rubik(
          color: AppColors.k0cbcc5,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        )),
        if (hasDiscount) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text('${product['currency']} ${product['price']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rubik(
                  color: Colors.grey,
                  fontSize: fontSize - 4,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.grey,
                )),
          ),
        ],
      ],
    );
  }

  Widget _buildPurchaseButton(Map product, {bool fullWidth = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        var productId = product['productId'].toString();
        var companyId = product['companyId'].toString();
        await showQuantityDialog(
          context: context,
          title: product['title'],
          currency: product['currency']?.toString(),
          unitPrice: num.tryParse(product['discount_price'].toString()),
          imageUrl: product['image']?.toString(),
          onConfirm: (qty) async {
            await MarketingPaymentService.instance.handlePurchase(
              context: context,
              companyId: companyId,
              products: [{'productId': productId, 'quantity': qty,}],
            );
          },
        );
      },
      child: Container(
        width: fullWidth ? double.infinity : null,
        alignment: fullWidth ? Alignment.center : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.k0cbcc5,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(S.of(context).purchase_now, style: GoogleFonts.rubik(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),),
      ),
    );
  }

  void _openProductDetail(Map product) {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (context) => ProductDetail(
        productId: product['productId'].toString(),
        title: product['title'],
        companyId: product['companyId'].toString(),
      ),
    ),);
  }

  Widget _buildListFooter() {
    if (isLoading && page > 1) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
        child: Center(child: Text('—— ${S.of(context).no_more_products} ——', style: GoogleFonts.rubik(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ))),
      );
    }

    return const SizedBox.shrink();
  }

  /// 商品列表
  Widget _buildProductSliverList() {
    if (company_products.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            if (index >= company_products.length) return _buildListFooter();

            final Map product = company_products[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openProductDetail(product),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildProductImage(product, height: 104, width: 104),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['title'] ?? '',
                              style: GoogleFonts.rubik(
                                color: AppColors.k010101,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product['description'] ?? '',
                              style: GoogleFonts.rubik(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _buildPriceRow(product)),
                                const SizedBox(width: 8),
                                _buildPurchaseButton(product),
                              ],
                            ),
                          ],
                        ),),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: company_products.length + 1,
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) => true;
}
