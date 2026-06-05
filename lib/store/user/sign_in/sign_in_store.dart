import 'package:injectable/injectable.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:mobx/mobx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

part 'sign_in_store.g.dart';

@injectable
class SignInStore = _SignInStore with _$SignInStore;

abstract class _SignInStore with Store {
  _SignInStore(this.appSettings) : locale = appSettings.locale;

  final AppSettings appSettings;

  @observable
  AutovalidateMode? autovalidateMode;

  @observable
  bool signInFailed = false;

  @observable
  bool obscurePasswordText = true;

  @observable
  Locale locale;

  @observable
  String userType = 'customer';

  List<String> userTypes = ['customer', 'doctor', 'translator'];

  @action
  Future<void> setLocale(Locale locale) async {
    await appSettings.setLocale(locale);
    this.locale = locale;
  }
}
