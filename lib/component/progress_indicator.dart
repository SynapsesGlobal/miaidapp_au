import 'package:flutter/material.dart';
import 'package:miaid/config/app_colors.dart';

Widget progressIndicator() {
  return CircularProgressIndicator(

      valueColor: AlwaysStoppedAnimation<Color>(AppColors.k0cbcc5));
}
