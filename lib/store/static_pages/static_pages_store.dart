import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:mobx/mobx.dart';

part 'static_pages_store.g.dart';

@singleton
class StaticPageStore = _StaticPageStore with _$StaticPageStore;

abstract class _StaticPageStore with Store {
  _StaticPageStore(this.api);

  final ApiProvider api;

  @observable
  ObservableList<Setting> pages = ObservableList<Setting>();

  @observable
  bool isLoading = false;

  @action
  Future<void> fetchStaticPages() async {
    try {
      isLoading = true;
      final response = await api.apiClient.settingsGetGetSettings();

      final payload =
          await ApiSuccessParser.payloadOrThrowWithMessage(response);
      pages.clear();
      pages.addAll(payload);
    } finally {
      isLoading = false;
    }
  }
}
