import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/services/marketing_payment_service.dart';
import 'package:miaid/view/marketing/product_detail.dart';

import '../../api_utils/api_provider.dart';
import '../../api_utils/consts.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import 'package:http/http.dart' as http;

import '../../generated/l10n.dart';
import '../../utils/configure_dependencies.dart';
import '../../widget/quantity_dialog.dart';

class CompanyProducts extends StatefulWidget {
  final dynamic company;
  const CompanyProducts({super.key, required this.company});

  @override
  State<CompanyProducts> createState() => _CompanyProductsState();
}

class _CompanyProductsState extends State<CompanyProducts> with SingleTickerProviderStateMixin {
  int page = 1;
  int pageSize = 10;
  bool isLoading = false;
  bool hasMore = true;
  late TabController _tabController;
  List categories = [];
  bool isGridView = false;
  String no_data = '';
  late int currentCateId = 0;
  String keywords = '';
  final TextEditingController _kwController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _getCompanyProducts(0, widget.company['companyId']);

    categories = widget.company['categories'];
    _tabController = TabController(length: categories.length, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      var cateId = categories[_tabController.index]['cateId'];
      setState(() {
        currentCateId = cateId;
        page = 1;
        company_products = [];
        isLoading = false;
        hasMore = true;
      });
      var companyId = widget.company['companyId'];
      _getCompanyProducts(cateId, companyId, keywords: keywords);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        _getCompanyProducts(currentCateId, widget.company['companyId'], keywords: keywords);
      }
    });
  }

  @override
  void dispose() {
    _kwController.dispose();
    _qtyController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List company_products = [];
  final api = getIt<ApiProvider>();
  Future<void> _getCompanyProducts(int cateId, int companyId, {String keywords=''}) async {
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
      final url = Uri.parse(Consts.marketingApiHost+'/company/products').replace(queryParameters: {
        'cateId': cateId.toString(),
        'companyId': companyId.toString(),
        'keywords': keywords,
        'gender': api.userProvider.user?.customer?.gender?.name,
        'birthday': api.userProvider.user?.customer?.dob,
        'page': page.toString(),
        'pageSize': pageSize.toString()
      });
      final response = await http.get(url, headers: headers);

      if (page == 1) await EasyLoading.dismiss();

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
      if (page == 1) await EasyLoading.dismiss();
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.view_list, color: isGridView ? Colors.black : AppColors.k0cbcc5),
            onPressed: () => setState(() => isGridView = !isGridView),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.grid_view, color: isGridView ? AppColors.k0cbcc5 : Colors.black),
            onPressed: () => setState(() => isGridView = !isGridView),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSearch(),
            _buildCategoryTab()
          ];
        },

        body: company_products.isNotEmpty ? TabBarView(
          controller: _tabController,
          children: categories.map((category) =>  isGridView ? _buildGridView() : _buildListView()).toList(),
        ) : Center(child: Text(no_data, style: GoogleFonts.rubik(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        )),),
      ),
    );
  }

  /// Search widget
  Widget _buildSearch() {
    return SliverToBoxAdapter(child: Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: _kwController,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(2),
          hintText: S.of(context).keywords,
          hintStyle: TextStyle(fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.k0cbcc5,),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.black12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.k0cbcc5, width: 1),
          ),
          suffixIcon: _kwController.text.isNotEmpty ? InkWell(
            onTap: (){
              _kwController.text = '';
              setState(() {
                keywords = '';
                page = 1;
                company_products = [];
                isLoading = false;
                hasMore = true;
              });
              _getCompanyProducts(currentCateId,  widget.company['companyId']);
            },
            child: Icon(Icons.close, size: 20, color: Colors.grey,),
          ) : null
        ),
        onChanged: (value) => setState(() => keywords = value),
        textInputAction: TextInputAction.search,
        keyboardType: TextInputType.text,
        onSubmitted: (value) {
          setState(() {
            keywords = value;
            page = 1;
            company_products = [];
            isLoading = false;
            hasMore = true;
          });
          _getCompanyProducts(currentCateId, widget.company['companyId'], keywords: value);
        },
      ),
    ),);
  }

  ///Category tab widget
  Widget _buildCategoryTab() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          padding: EdgeInsets.zero,
          tabAlignment: TabAlignment.start,
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AppColors.k0cbcc5,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          tabs: categories.map((category) => Tab(text: category['cateName'])).toList(),
          dividerColor: Colors.transparent,
        )
      ),
    );
  }

  /// Listview layout
  Widget _buildListView() {
    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.all(10),
      itemBuilder: (context, int index) {
        if (index < company_products.length) {
          return InkWell(
            onTap: (){
              Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => ProductDetail(
                  product: company_products[index],
                  company: widget.company,
                ),
              ),);
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    imageUrl: company_products[index]['image'],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company_products[index]['title'],
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      company_products[index]['description'],
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
                        Text('${company_products[index]['currency']}', style: GoogleFonts.rubik(
                          color: AppColors.k0cbcc5,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        )),
                        SizedBox(width: 2,),
                        Text('${company_products[index]['discount_price']}', style: GoogleFonts.rubik(
                          color: AppColors.k0cbcc5,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        )),
                        SizedBox(width: 5,),
                        company_products[index]['price'] != company_products[index]['discount_price'] ? Text('${company_products[index]['currency']} ${company_products[index]['price']}', style: GoogleFonts.rubik(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.red
                        )) : Offstage(),
                      ],
                    ),
                    MaterialButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        var product = company_products[index];
                        var productId = product['productId'].toString();
                        var companyId = widget.company['companyId'].toString();
                        await showQuantityDialog(
                          context: context,
                          title: product['title'],
                          currency: product['currency']?.toString(),
                          unitPrice: num.tryParse(
                              product['discount_price'].toString()),
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
                      minWidth: MediaQuery.of(context).size.width * 0.3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      color: AppColors.k0cbcc5,
                      child: Text(S.of(context).purchase_now, style: GoogleFonts.rubik(color: Colors.white),),
                    )
                  ],
                ),),
              ],
            ),
          );
        }

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
      },
      separatorBuilder: (context, index) => Divider(color: Colors.grey[200]),
      itemCount: company_products.length+1
    );
  }

  /// Gridview layout
  Widget _buildGridView() => MasonryGridView.builder(
    gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,             // 每行2列
    ),
    padding: EdgeInsets.all(10),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    controller: _scrollController,
    itemCount: company_products.length+1,
    itemBuilder: (context, index) {
      if (index < company_products.length) {
        return InkWell(
          onTap: ()=> Navigator.push(context, MaterialPageRoute<void>(
            builder: (context) => ProductDetail(
              product: company_products[index],
              company: widget.company,
            ),
          ),),
          child: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5, spreadRadius: 2),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CachedNetworkImage(
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  imageUrl: company_products[index]['image'],
                ),
                SizedBox(height: 6),
                Text(
                  company_products[index]['title'],
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  company_products[index]['description'],
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
                    Text('${company_products[index]['currency']}', style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    )),
                    SizedBox(width: 5,),
                    Text('${company_products[index]['discount_price']}', style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    )),
                    SizedBox(width: 5,),
                    company_products[index]['price'] != company_products[index]['discount_price'] ? Text('${company_products[index]['currency']} ${company_products[index]['price']}', style: GoogleFonts.rubik(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.red
                    )) : Offstage(),
                  ],
                ),
                MaterialButton(
                  onPressed: () async {
                    var product = company_products[index];
                    var productId = product['productId'].toString();
                    var companyId = widget.company['companyId'].toString();
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
                  minWidth: MediaQuery.of(context).size.width,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  color: AppColors.k0cbcc5,
                  child: Text('Purchase', style: GoogleFonts.rubik(color: Colors.white),),
                )
              ],
            ),
          ),
        );
      }

      return const SizedBox.shrink();
    },
  );
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_) => false;
}