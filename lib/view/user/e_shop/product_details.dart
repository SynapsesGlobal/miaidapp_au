import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/cart_store.dart';
import 'package:miaid/store/product/product_details_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:miaid/widget/custom_dialog.dart';
import 'package:miaid/widget/image_widget.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class ProductDetailsParams {
  final int productId;
  final int locationId;
  final String currency;
  ProductDetailsParams(this.productId, this.currency, this.locationId);
}

@injectable
class ProductDetailsServices {
  ProductDetailsServices(this.api, this.store, this.appSettings);

  final ApiProvider api;
  final ProductDetailsStore store;
  final AppSettings appSettings;
}

@injectable
class ProductDetails extends StatefulWidget {
  ProductDetails({
    @factoryParam this.params,
    required this.services,
  }) : super();

  final ProductDetailsParams? params;
  final ProductDetailsServices services;

  @override
  _ProductDetailsState createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  late ProductDetailsStore productDetailsStore;
  final PageController _imagePageController = PageController();

  @override
  void initState() {
    super.initState();
    productDetailsStore = widget.services.store;

    productDetailsStore.getProductDetails(
      widget.services.api,
      widget.params!.productId,
      widget.params!.locationId,
      widget.params!.currency,
    );
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.kffffff,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.kffffff,
          centerTitle: true,
          title: Text(
            S.of(context).viewDetails,
            style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          leading: Builder(
            builder: (BuildContext context) {
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
              );
            },
          ),
        ),
        body: _body(),
        bottomNavigationBar: _bottomActionBar(),
      ),
    );
  }

  Widget _body() {
    return Observer(builder: (context) {
      if (productDetailsStore.isLoading) {
        return Center(child: progressIndicator());
      }

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            _imageCarousel(),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productDetailsStore.productDetails?.name ?? '',
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (productDetailsStore.productDetails?.pharmacy?.name !=
                      null) ...[
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 15,
                          color: AppColors.k5e5e5e,
                        ),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            productDetailsStore
                                .productDetails!.pharmacy!.name!,
                            style: GoogleFonts.rubik(
                              color: AppColors.k5e5e5e,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${widget.params?.currency} ',
                        style: GoogleFonts.rubik(
                          color: AppColors.k5e5e5e,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        productDetailsStore.productDetails?.unitPrice
                                .toString() ??
                            '',
                        style: GoogleFonts.rubik(
                          color: AppColors.k0cbcc5,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            _tabBar(context),
            IndexedStack(
              index: productDetailsStore.tabindex,
              children: [
                generalTab(),
                warningTab(),
                ingredientTab(),
                directionTab(),
              ],
            ),
            SizedBox(height: 24),
          ],
        ),
      );
    });
  }

  // ── 图片轮播：滑动翻页 + 指示点（替代旧版左右箭头按钮） ──────────────────
  Widget _imageCarousel() {
    final images = productDetailsStore.productDetails?.productImages;
    final hasImages = images != null && images.isNotEmpty;

    return Column(
      children: [
        Container(
          height: 260,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: !hasImages
              ? Image.asset(
                  'assets/images/default_shop_image.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                )
              : PageView.builder(
                  controller: _imagePageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    productDetailsStore.currentImageIndex = index;
                  },
                  itemBuilder: (context, index) => ImageWidget(
                    imageUrl: images[index].image ?? '',
                  ),
                ),
        ),
        if (hasImages && images.length > 1) ...[
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 7,
                width:
                    productDetailsStore.currentImageIndex == index ? 18 : 7,
                decoration: BoxDecoration(
                  color: productDetailsStore.currentImageIndex == index
                      ? AppColors.k0cbcc5
                      : AppColors.k5e5e5e.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── 分段式 Tab：选中项为主题色圆角胶囊 ─────────────────────────────────
  Widget _tabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        onTap: (index) {
          productDetailsStore.tabindex = index;
        },
        indicator: BoxDecoration(
          color: AppColors.k0cbcc5,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.kffffff,
        unselectedLabelColor: AppColors.k5e5e5e,
        labelStyle: GoogleFonts.rubik(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: EdgeInsets.zero,
        tabs: [
          Tab(
            text: S.of(context).general,
          ),
          Tab(
            text: S.of(context).warning,
          ),
          Tab(
            text: S.of(context).ingredient,
          ),
          Tab(
            text: S.of(context).direction,
          ),
        ],
      ),
    );
  }

  // ── 底部吸底操作栏：加购 / 立即购买（替代旧版滚动内容里的按钮行） ────────
  Widget _bottomActionBar() {
    return Observer(builder: (context) {
      if (productDetailsStore.isLoading ||
          productDetailsStore.productDetails == null) {
        return SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.kffffff,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: TapDebouncer(
                  onTap: () async {
                    if (!widget.services.api.userProvider.isLoggedIn) {
                      showAlertDialog(context);

                      return;
                    }

                    var cartEShopStore = getIt<CartEShopStore>();

                    setState(() {
                      cartEShopStore.addItem(
                        productDetailsStore.productDetails!,
                        curr: widget.params?.currency,
                        quantity: productDetailsStore.quantity,
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.k0cbcc5,
                        content: Text(
                          'Item added to Cart.',
                        ),
                      ),
                    );
                  },
                  builder: (context, onTap) => InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          width: 1.2,
                          color: AppColors.k0cbcc5,
                        ),
                      ),
                      child: Text(
                        S.of(context).addToCart,
                        style: GoogleFonts.rubik(
                          color: AppColors.k0cbcc5,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (!widget.services.api.userProvider.isLoggedIn) {
                      showAlertDialog(context);

                      return;
                    }

                    var cartEShopStore = getIt<CartEShopStore>();
                    setState(() {
                      cartEShopStore.addItem(
                        productDetailsStore.productDetails!,
                        curr: widget.params?.currency,
                        quantity: productDetailsStore.quantity,
                      );
                    });

                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => getIt<CartEShop>(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.k0cbcc5,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      S.of(context).buyNow,
                      style: GoogleFonts.rubik(
                        color: AppColors.kffffff,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// 后台商品说明两种格式混存：富文本编辑器存的是 HTML，也有直接粘贴的纯文本
  /// （靠换行和 "-"/"•" 排版）。纯文本走 HTML 渲染时换行会被折叠成空格，
  /// 段落全糊成一团；这里对无标签内容按纯文本转义并把换行转成 <br> 保留排版。
  String _asRenderableHtml(String? data) {
    final text = data ?? '';
    if (RegExp(r'<[a-zA-Z!/]').hasMatch(text)) return text;
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('\r\n', '\n')
        .replaceAll('\n', '<br>');
  }

  Widget generalTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 19,
      ),
      child: Column(
        children: [
          Html(
            data: _asRenderableHtml(
                productDetailsStore.productDetails?.generalInformation),
          ),
          SizedBox(
            height: 10,
          ),
        ],
      ),
    );
  }

  Widget warningTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 19,
      ),
      child: Column(
        children: [
          Html(
            data: _asRenderableHtml(productDetailsStore.productDetails?.warnings),
          ),
          SizedBox(
            height: 10,
          ),
        ],
      ),
    );
  }

  Widget ingredientTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 19,
      ),
      child: Column(
        children: [
          Html(
            data:
                _asRenderableHtml(productDetailsStore.productDetails?.ingredients),
          ),
          SizedBox(
            height: 5,
          ),
        ],
      ),
    );
  }

  Widget directionTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 19,
      ),
      child: Column(
        children: [
          Html(
            data:
                _asRenderableHtml(productDetailsStore.productDetails?.directions),
          ),
          SizedBox(
            height: 5,
          ),
        ],
      ),
    );
  }

  void showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomDialog(
          title: S.of(context).alert,
          content: S.of(context).pleaseSignInFirst,
          buttonText: S.of(context).signIn,
          showCancel: false,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => getIt<SignIn>(),
              ),
            );
          },
        );
      },
    );
  }
}
