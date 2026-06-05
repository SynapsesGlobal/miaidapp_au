import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

Random random = Random();
int get randomNumber => random.nextInt(9000) + 1000;

class Utils {
  static void launschURL(String url) async =>
      await canLaunch(url) ? await launch(url) : throw 'Could not launch $url';

  static bool isValidEmail(String email) {
    final emailRegExp = RegExp(
      r'^[\w\.-]+@[\w\.-]+\.\w{2,}$',
    );
    return emailRegExp.hasMatch(email);
  }

  static bool isLessThan24HoursAgo(DateTime targetTime) {
    final now = DateTime.now();
    final difference = now.difference(targetTime);
    return difference.inHours < 24;
  }

  static bool isPad(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }
}
