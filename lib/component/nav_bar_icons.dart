import 'package:flutter/material.dart'
    show
        Alignment,
        AssetImage,
        Colors,
        Container,
        Image,
        InkWell,
        Material,
        Widget;
import 'package:flutter/widgets.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

Widget navBarIcon({
  required String iconAssetName,
  double width = 25,
  double height = 25,
  Future<void> Function()? onTap,
}) {
  return Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    child: Stack(
      children: <Widget>[
        Image(
          image: AssetImage('assets/images/NavBar/$iconAssetName'),
          width: width,
          height: height,
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: TapDebouncer(
              onTap: onTap,
              builder: (BuildContext context, onTap) => InkWell(
                onTap: onTap,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
