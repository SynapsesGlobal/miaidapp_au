import 'dart:core';

import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:mobx/mobx.dart';

part 'call_history_store.g.dart';

@injectable
class CallHistoryStore = _CallHistoryStore with _$CallHistoryStore;

abstract class _CallHistoryStore with Store {
  _CallHistoryStore(this.api, this.user);

  final ApiProvider api;
  final UserProvider user;

  @observable
  ObservableList<Call> calls = <Call>[].asObservable();

  @observable
  DateTime? date;

  @action
  Future<void> fetchCallHistory() async {
    String? dateFormatted;
    if (date != null) {
      final formatter = DateFormat('yyyy-MM-dd');
      dateFormatted = formatter.format(date!);
    }
    calls.clear();
    final response =
        await api.apiClientMain.callsGetCallsHistory(date: dateFormatted);
    final callResponse = await ApiSuccessParser.payloadOrThrowWithMessage(response);
    calls.addAll(callResponse);
  }

  @action
  Future<void> setDateFilter(DateTime date) async {
    this.date = date;
    await fetchCallHistory();
  }
}
