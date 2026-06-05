import 'dart:core';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

part 'forgot_password_store.g.dart';

@injectable
class ForgotPasswordStore = _ForgotPasswordStore with _$ForgotPasswordStore;

abstract class _ForgotPasswordStore with Store {

  @observable
  AutovalidateMode? autovalidateMode;
}
