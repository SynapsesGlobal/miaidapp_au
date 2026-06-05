import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

part 'sign_up_store.g.dart';

@injectable
class SignUpStore = _SignUpStore with _$SignUpStore;

abstract class _SignUpStore with Store {
  _SignUpStore();

  @observable
  AutovalidateMode? autovalidateMode;

  @observable
  bool obscurePasswordText = true;

  @observable
  bool obscureConfirmPasswordText = true;

  @observable
  bool showIndividualUserTab = true;

  @observable
  CountryCode? selectedCountry;
}
