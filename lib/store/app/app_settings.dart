import 'dart:core';
import 'dart:ui';

import 'package:injectable/injectable.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

@preResolve
@singleton
class AppSettings {
  static const String _kLang = 'languageCode';

  AppSettings(this.sharedPreferences);

  final SharedPreferences sharedPreferences;

  @factoryMethod
  static Future<AppSettings> create(SharedPreferences sharedPreferences) async {
    final appSettings = AppSettings(sharedPreferences);
    await appSettings._init();
    return appSettings;
  }

  Future<void> _init() async {
    await S.load(locale);
  }

  Future<void> setLocale(Locale locale) async {
    await sharedPreferences.setString(_kLang, locale.languageCode);
    await S.load(locale);
  }

  Locale get locale => Locale(sharedPreferences.getString(_kLang) ?? 'en');

  // en: English, cn: Chinese
  String get languageFull {
    if (locale.languageCode == 'zh') return 'Chinese';
    if (locale.languageCode == 'en') return 'English';
    if (locale.languageCode == 'kor') return 'Korean';
    if (locale.languageCode == 'ido') return 'Indonesia';
    return 'English';
  }
}
