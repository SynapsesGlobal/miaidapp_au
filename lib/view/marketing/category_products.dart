import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/services/marketing_api.dart';
import 'package:miaid/view/marketing/company_products.dart';
import 'package:miaid/view/marketing/product_detail.dart';
import 'package:miaid/widget/marketing_product_card.dart';

import '../../api_utils/api_provider.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import '../../store/home/home_screen_store.dart';
import '../../utils/configure_dependencies.dart';

/// 主分类下所有商家的商品列表（从分类页直接进入，跳过商家列表页）。
///
/// 数据来自 miaid_mispace `GET /category/products`：按商家离用户的距离排序
/// （拿不到定位时按商家 id），同一商家内新品在前。这里只有一个主分类，所以不显示
/// 子分类栏（商家商品页 [CompanyProducts] 才有）。每个商品带 `company` 对象
/// （与 /companies 一致），卡片底部的商家行点进去就是原来的商家商品列表。
class CategoryProducts extends StatefulWidget {
  final int categoryId;
  final String category;
  const CategoryProducts({super.key, required this.categoryId, required this.category});

  @override
  State<CategoryProducts> createState() => _CategoryProductsState();
}

class _CategoryProductsState extends State<CategoryProducts> {
  int page = 1;
  final int pageSize = 10;
  bool isLoading = false;
  bool hasMore = true;
  List products = [];
  String keywords = '';
  Position? _position;
  bool _positionResolved = false;
  Timer? _searchDebounce;
  final TextEditingController _kwController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final api = getIt<ApiProvider>();

  @override
  void initState() {
    super.initState();
    _getProducts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        _getProducts(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _kwController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 只在首次请求时定位一次；定位失败（无权限/未开启）不阻塞列表，后端按商家 id 排序。
  Future<void> _resolvePosition() async {
    if (_positionResolved) return;
    _positionResolved = true;
    try {
      _position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
    } catch (e) {
      _position = null;
    }
  }

  Future<void> _getProducts({bool showLoading = true}) async {
    if (isLoading || !hasMore) return;

    setState(() => isLoading = true);

    final showMask = page == 1 && showLoading;
    if (showMask) {
      await EasyLoading.show(
        status: 'Loading',
        maskType: EasyLoadingMaskType.black,
      );
    }

    try {
      await _resolvePosition();

      final query = <String, String>{
        'mainCateId': widget.categoryId.toString(),
        'keywords': keywords,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      final gender = api.userProvider.user?.customer?.gender?.name;
      final birthday = api.userProvider.user?.customer?.dob;
      if (gender != null) query['gender'] = gender;
      if (birthday != null) query['birthday'] = birthday;
      if (_position != null) {
        query['latitude'] = _position!.latitude.toString();
        query['longitude'] = _position!.longitude.toString();
      }

      final url = Uri.parse(getIt<ApiSettings>().marketingApiHost + '/category/products')
          .replace(queryParameters: query);
      final response = await http.get(url, headers: MarketingApi.headers());

      if (showMask) await EasyLoading.dismiss();

      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List newProducts = body['products'] ?? [];
        setState(() {
          products.addAll(newProducts);
          page++;
          hasMore = newProducts.length >= pageSize;
        });
      } else if (page == 1) {
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      print(e.toString());
      if (showMask) await EasyLoading.dismiss();
    }

    if (mounted) setState(() => isLoading = false);
  }

  /// 重置分页并按当前关键字重新拉取
  void _resetAndFetch({bool showLoading = true}) {
    setState(() {
      page = 1;
      products = [];
      isLoading = false;
      hasMore = true;
    });
    _getProducts(showLoading: showLoading);
  }

  /// 输入停顿 450ms 后自动搜索，避免每敲一个字都请求一次
  void _onKeywordsChanged(String value) {
    setState(() => keywords = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _resetAndFetch(showLoading: false);
    });
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

  /// 进入该商品所属商家的商品列表（原商家 → 商品流程）
  void _openCompany(Map company) {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (context) => CompanyProducts(company: company),
    ),);
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
        title: Text(widget.category, style: GoogleFonts.rubik(
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
      body: RefreshIndicator(
        color: AppColors.k0cbcc5,
        onRefresh: () async => _resetAndFetch(showLoading: false),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                height: 62,
                child: Container(
                  color: AppColors.kffffff,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSearch(),
                ),
              ),
            ),
            _buildProductSliverList(),
          ],
        ),
      ),
    );
  }

  /// Search widget（与 company_products.dart 一致）
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
              contentPadding: const EdgeInsets.only(left: 16, top: 5, bottom: 5),
              border: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.yellow),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.k010101),
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.kb1b1b1, width: 0.5),
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
          const SizedBox(width: 12,),
          InkWell(
            onTap: () {
              _searchDebounce?.cancel();
              _resetAndFetch();
            },
            child: const Image(
              height: 44,
              width: 44,
              image: AssetImage('assets/images/btn_search.png'),
            ),
          ),
        ],
      ),
    );
  }

  /// 商品列表：每张卡片价格下带商家属性行
  Widget _buildProductSliverList() {
    if (products.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: MarketingEmptyState(loading: isLoading),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= products.length) {
              return MarketingListFooter(loadingMore: isLoading && page > 1, hasMore: hasMore);
            }

            final Map product = products[index];
            final company = product['company'];
            return MarketingProductCard(
              product: product,
              onTap: () => _openProductDetail(product),
              company: company is Map
                  ? MarketingCompanyRow(company: company, onTap: () => _openCompany(company))
                  : null,
            );
          },
          childCount: products.length + 1,
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
