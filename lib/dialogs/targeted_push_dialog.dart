import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/targeted_push_service.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/marketing/product_detail.dart';

/// 商品定向推送弹框：打开 App 到首页后，用当前位置向 mispace 查一次命中的商品，
/// 有则弹出卡片轮播（多个商品自动轮播、可左右滑动）。
///
/// - 右上角 ♡ → 加入心愿单（已收藏时提示并显示实心），弹框不关闭；
/// - 点「查看商品」→ 关闭弹框并进入商品详情页，不做任何记录；
/// - 点「不再显示此商品」→ 记录该商品当前推送轮次的 pushKey，从轮播中移走，没有剩余时
///   自动关闭；后台把推送关掉再开启会换一轮 key，于是会再次提醒；
/// - 只有点 ×、「不再显示」或「查看商品」才会关闭，点遮罩和系统返回键都不关闭；
/// - 仅关闭弹框不做任何记录。
///
/// 触发时机见 [TargetedPushTrigger]：App 启动后第一次进入首页、登录成功后进入首页。
/// 抽屉里点「首页」、从其他页面返回首页、从后台恢复都不弹。
class TargetedPushDialog {
  TargetedPushDialog._();

  static bool _isShowing = false;

  /// 多个商品时的自动轮播间隔。
  static const autoPlayInterval = Duration(seconds: 4);

  static Future<void> showOnHomeEntry(BuildContext context) async {
    final user = getIt<UserProvider>();
    // 商品详情页需要登录用户 id，未登录/非顾客不查；也不消费触发开关，等登录后再弹。
    if (!user.isLoggedIn || !user.isCustomer) return;

    if (!TargetedPushTrigger.consume()) return;

    // 同一时间只弹一个
    if (_isShowing) return;
    _isShowing = true;
    try {
      if (getIt<OngoingCallStore>().hasOngoingCall) return;

      List<TargetedProduct> products;
      try {
        products = await TargetedPushService.fetchForCurrentUser();
      } catch (_) {
        return;
      }

      final history = await TargetedPushHistory.load();
      final toShow = history.visible(products);
      if (toShow.isEmpty || !context.mounted) return;

      await show(context, toShow, history);
    } finally {
      _isShowing = false;
    }
  }

  /// 弹出轮播；若用户选择了商品则跳转详情页。
  static Future<void> show(
    BuildContext context,
    List<TargetedProduct> products,
    TargetedPushHistory history,
  ) async {
    final selected = await showDialog<TargetedProduct>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TargetedPushCarousel(
        products: products,
        history: history,
        onWish: TargetedPushService.addToWishlist,
      ),
    );

    if (selected != null && context.mounted) {
      await Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => ProductDetail(
          productId: selected.productId,
          title: selected.title,
          companyId: selected.companyId,
        ),
      ));
    }
  }
}

/// 弹框内容：卡片轮播 + 指示点 + 按钮。以 `Navigator.pop(product)` 返回用户点开的商品。
class TargetedPushCarousel extends StatefulWidget {
  final List<TargetedProduct> products;
  final TargetedPushHistory history;

  /// 「收藏」动作；为 null 时不显示收藏按钮。
  final Future<WishResult> Function(TargetedProduct product)? onWish;

  const TargetedPushCarousel({
    super.key,
    required this.products,
    required this.history,
    this.onWish,
  });

  @override
  State<TargetedPushCarousel> createState() => _TargetedPushCarouselState();
}

class _TargetedPushCarouselState extends State<TargetedPushCarousel> {
  late final List<TargetedProduct> _items = List.of(widget.products);
  final PageController _controller = PageController();
  Timer? _autoPlay;
  int _index = 0;
  /// 本次弹框里已收藏（或本来就在心愿单里）的商品 id。
  final Set<String> _wished = {};
  bool _wishing = false;

  @override
  void initState() {
    super.initState();
    // 接口已告知哪些商品在心愿单里，一开始就显示实心
    _wished.addAll(widget.products.where((p) => p.collected).map((p) => p.productId));
    _restartAutoPlay();
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartAutoPlay() {
    _autoPlay?.cancel();
    if (_items.length < 2) return;
    _autoPlay = Timer.periodic(TargetedPushDialog.autoPlayInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % _items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  /// 查看商品：带着当前商品关闭弹框，由调用方跳转详情页；不做任何记录。
  void _viewCurrent() => Navigator.pop(context, _items[_index]);

  /// 收藏当前商品：成功或已收藏都标为实心，弹框保持打开。
  Future<void> _wishCurrent() async {
    final onWish = widget.onWish;
    if (onWish == null || _wishing) return;
    final product = _items[_index];
    if (_wished.contains(product.productId)) {
      _toast(S.of(context).targetedPushAlreadyInWishList);
      return;
    }
    setState(() => _wishing = true);
    final result = await onWish(product);
    if (!mounted) return;
    setState(() {
      _wishing = false;
      if (result != WishResult.failed) _wished.add(product.productId);
    });
    _toast(switch (result) {
      WishResult.added => S.of(context).addedToWishList,
      WishResult.exists => S.of(context).targetedPushAlreadyInWishList,
      WishResult.failed => S.of(context).somethingWentWrong,
    });
  }

  void _toast(String message) {
    // 测试环境没有原生插件，提示失败不影响功能
    HttpExceptionNotifyUser.showInfo(message).catchError((_) {});
  }

  Future<void> _hideCurrent() async {
    final product = _items[_index];
    await widget.history.hide(product);
    if (!mounted) return;

    if (_items.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _items.removeAt(_index);
      if (_index >= _items.length) _index = _items.length - 1;
    });
    if (_controller.hasClients) _controller.jumpToPage(_index);
    _restartAutoPlay();
  }

  @override
  Widget build(BuildContext context) {
    // 卡片区高度随屏幕自适应：矮屏/横屏时压缩图片高度，避免弹框整体溢出
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = (screenHeight - 48 - 210).clamp(240.0, 372.0);
    final imageHeight = (cardHeight - 202).clamp(80.0, 170.0);
    // canPop=false 只拦系统返回键/手势，按钮里的 Navigator.pop 不受影响
    return PopScope(
      canPop: false,
      child: Dialog(
      backgroundColor: Colors.white,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          SizedBox(
            height: cardHeight,
            child: PageView.builder(
              controller: _controller,
              itemCount: _items.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                _restartAutoPlay();
              },
              itemBuilder: (_, i) => _ProductCard(product: _items[i], imageHeight: imageHeight),
            ),
          ),
          if (_items.length > 1) _buildDots(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('targeted_push_view_product'),
                onPressed: _viewCurrent,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  backgroundColor: AppColors.k0cbcc5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  S.of(context).targetedPushViewProduct,
                  style: GoogleFonts.rubik(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            key: const Key('targeted_push_hide_product'),
            onPressed: _hideCurrent,
            child: Text(
              S.of(context).targetedPushDontShowAgain,
              style: GoogleFonts.rubik(
                fontSize: 13,
                color: AppColors.k8f8e94,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 20, color: AppColors.k0cbcc5),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              S.of(context).targetedPushTitle.toUpperCase(),
              style: GoogleFonts.rubik(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.k010101,
              ),
            ),
          ),
          if (widget.onWish != null)
            IconButton(
              key: const Key('targeted_push_wish'),
              tooltip: S.of(context).targetedPushAddToWishlist,
              icon: Icon(
                _wished.contains(_items[_index].productId) ? Icons.favorite : Icons.favorite_border,
                color: _wished.contains(_items[_index].productId) ? AppColors.ke63030 : AppColors.k8f8e94,
              ),
              onPressed: _wishing ? null : _wishCurrent,
            ),
          IconButton(
            key: const Key('targeted_push_close'),
            icon: Icon(Icons.close, color: AppColors.k8f8e94),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_items.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.k0cbcc5 : AppColors.kb1b1b1,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final TargetedProduct product;
  final double imageHeight;

  const _ProductCard({required this.product, required this.imageHeight});

  @override
  Widget build(BuildContext context) {
    final company = (product.companyName ?? '').trim();
    // 地点 · 距离，如 "Guangzhou · 6.7 km away"
    final where = <String>[
      if ((product.location ?? '').trim().isNotEmpty) product.location!.trim(),
      if (product.distance != null)
        S.of(context).targetedPushDistance(product.distance!.toStringAsFixed(1)),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              height: imageHeight,
              width: double.infinity,
              fit: BoxFit.cover,
              imageUrl: product.image,
              placeholder: (_, __) => Container(
                height: imageHeight,
                color: const Color(0xFFEDEFF2),
                child: Icon(Icons.image_outlined, size: 32, color: Colors.grey.shade400),
              ),
              errorWidget: (_, __, ___) => Container(
                height: imageHeight,
                color: const Color(0xFFEDEFF2),
                child: Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.rubik(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.k010101,
              height: 1.3,
            ),
          ),
          if (company.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              company,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.rubik(fontSize: 12, color: AppColors.k8f8e94),
            ),
          ],
          if (where.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.place_outlined, size: 13, color: AppColors.k8f8e94),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  where,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rubik(fontSize: 12, color: AppColors.k8f8e94),
                ),
              ),
            ]),
          ],
          if ((product.instruction ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            // 使用说明：最多两行，超出省略
            Text(
              product.instruction!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.rubik(
                fontSize: 12,
                color: AppColors.k5e5e5e,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${product.currency} ', style: GoogleFonts.rubik(
                color: AppColors.k0cbcc5,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
              Text(product.discountPrice, style: GoogleFonts.rubik(
                color: AppColors.k0cbcc5,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              )),
              if (product.hasDiscount) ...[
                const SizedBox(width: 6),
                Text('${product.currency} ${product.price}', style: GoogleFonts.rubik(
                  color: Colors.grey,
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.grey,
                )),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
