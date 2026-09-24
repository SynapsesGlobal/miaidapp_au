import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class ImageWidget extends StatelessWidget {
  String imageUrl;
  Widget? errorWidget;
  double? height;
  double? width;
  /// 图片裁切方式；默认 cover 与原行为一致，商品详情等需要完整展示的地方传 contain
  BoxFit fit;
  ImageWidget(
      {required this.imageUrl,
      this.errorWidget,
      this.height,
      this.width,
      this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      height: height,
      width: width,
      errorWidget: (context, url, error) =>
          errorWidget ?? Image.asset('assets/images/default_shop_image.png'),
      fit: fit,
      imageUrl: imageUrl,
    );
  }
}
