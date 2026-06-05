import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class ImageWidget extends StatelessWidget {
  String imageUrl;
  Widget? errorWidget;
  double? height;
  double? width;
  ImageWidget(
      {required this.imageUrl, this.errorWidget, this.height, this.width});
  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      height: height,
      width: width,
      errorWidget: (context, url, error) =>
          errorWidget ?? Image.asset('assets/images/default_shop_image.png'),
      fit: BoxFit.cover,
      imageUrl: imageUrl,
    );
  }
}
