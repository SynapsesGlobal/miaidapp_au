import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

part 'reset_password_store.g.dart';

@injectable
class ResetPasswordStore = _ResetPasswordStore with _$ResetPasswordStore;

abstract class _ResetPasswordStore with Store {

  @observable
  bool obscurePasswordText = true;

  @observable
  bool obscureConfirmPasswordText = true;
}
