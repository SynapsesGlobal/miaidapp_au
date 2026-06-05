import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

part 'user_info_store.g.dart';

// this is a temporary fix for the issue where the user name is not reactive in the drawer
// and home page due to the user_provider not being reactive
@singleton
class UserInfoStore = _UserInfoStore with _$UserInfoStore;

abstract class _UserInfoStore with Store {
  @observable
  String firstName = '';

  @observable
  bool isLoggedIn = false;

  @action
  void setFirstName(String value) {
    firstName = value;
  }

  @action
  void setIsLoggedIn(bool value) {
    isLoggedIn = value;
  }
}
