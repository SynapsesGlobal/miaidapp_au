import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

part 'change_password_store.g.dart';

@injectable
class ChangePasswordStore = _ChangePasswordStore with _$ChangePasswordStore;

abstract class _ChangePasswordStore with Store {

  @observable
  bool obscurePasswordText = true;

  @observable
  bool obscureConfirmPasswordText = true;

  @observable
  bool obscureCurrentPasswordText = true;
}
