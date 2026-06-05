import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:mobx/mobx.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:injectable/injectable.dart';

part 'notification_screen_store.g.dart';

@injectable
class NotificationScreenStore = _NotificationScreenStore
    with _$NotificationScreenStore;

abstract class _NotificationScreenStore with Store {
  _NotificationScreenStore(this.api, this.user);

  final ApiProvider api;
  final UserProvider user;

  @observable
  ObservableList<MiaidNotification> notifications =
      <MiaidNotification>[].asObservable();

  @action
  Future<void> fetchNotificationList() async {
    notifications.clear();
    final response = await api.apiClient.notificationGetNotificationList();
    final notificationResponse =
        await ApiSuccessParser.payloadOrThrowWithMessage(response);
    notifications.addAll(notificationResponse);
  }

  @action
  Future<void> markNotificationAsRead(int notificationId) async {
    final response = await api.apiClient
        .notificationUpdateNotificationStatusToRead(
            notification_id: notificationId);

    final updatedNotification =
        await ApiSuccessParser.payloadOrThrowWithMessage(response);

    final index =
        notifications.indexWhere((element) => element.id == notificationId);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
    }
  }
}
