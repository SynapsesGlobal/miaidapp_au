import 'dart:core';
import 'dart:math';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/main.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/home/user_info_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/widget/custom_dialog.dart';
import 'package:mobx/mobx.dart';

import 'home_screen_store.dart';

part 'active_subscription_store.g.dart';

class RemainingConsultations {
  RemainingConsultations({
    required this.callCount,
    required this.totalConsultations,
    required this.type,
  });

  final int callCount;
  final int totalConsultations;
  final String type;

  int get total => totalConsultations;
  String get consultationType => type;
  int get remainingConsultations => max(totalConsultations - callCount, 0);
}

@singleton
class ActiveSubscriptionStore = _ActiveSubscriptionStore
    with _$ActiveSubscriptionStore;

abstract class _ActiveSubscriptionStore with Store {
  _ActiveSubscriptionStore(this.user, this.appSettings, this.api);

  final UserProvider user;
  final AppSettings appSettings;
  final ApiProvider api;

  @observable
  RemainingConsultations? remainingConsultations;

  @observable
  RemainingConsultations? totalConsultations;

  @observable
  SubscriptionDetail? activeCustomerSubscriptionDetail;

  @observable
  List<SubscriptionDetail?>? activeCompanySubscriptionDetails;

  @observable
  bool hasActiveSubscription = false;

  @action
  Future<void> fetchActiveSubscription() async {
    final countryCode = await getCountryCode();

    try {
      final response = await api.apiClient.profileGetMyProfile(
        with_subscription_details: true,
        country_code: countryCode,
      );

      if (ApiSuccessParser.isSuccessfulWithPayload(response)) {
        final userInfoStore = getIt<UserInfoStore>();
        userInfoStore.setFirstName(response.body?.payload?.firstName ?? '');

        totalConsultations = RemainingConsultations(
          callCount: response.body?.payload?.customer?.callsPlaced ?? 0,
          totalConsultations: response.body?.payload?.customer?.callsTotal ?? 0,
          type: 'total',
        );

        if (totalConsultations!.remainingConsultations > 0) {
          remainingConsultations = totalConsultations;
        } else {
          remainingConsultations = RemainingConsultations(
            callCount: 0,
            totalConsultations: 0,
            type: 'total',
          );
        }

        activeCustomerSubscriptionDetail =
            response.body?.payload?.customer?.activeCustomerSubscriptionDetail;
        activeCompanySubscriptionDetails = response
            .body?.payload?.customer?.activeCompanySubscriptionDetailList;
        hasActiveSubscription =
            response.body?.payload?.customer?.hasActiveSubscription ?? false;
      } else {
        if (response.statusCode == 401) {
          HttpExceptionNotifyUser.showInfo(
            S
                .of(
                  navigatorKey.currentContext!,
                )
                .relogin,
          );
        } else {
          HttpExceptionNotifyUser.showInfo(
            S
                .of(
                  navigatorKey.currentContext!,
                )
                .noAvailableConsultation,
          );
        }

        resetActiveSubscription();
      }
    } catch (e) {
      HttpExceptionNotifyUser.showInfo(
        S
            .of(
              navigatorKey.currentContext!,
            )
            .noAvailableConsultation,
      );
      resetActiveSubscription();
    }
  }

  Future<bool> isPaymentPaid(int paymentId) async {
    final response =
        await api.apiClient.subscriptionsGetShowPayment(payment_id: paymentId);
    if (ApiSuccessParser.isSuccessfulWithPayload(response)) {
      return (response.body?.payload?.status ?? 0) == 1;
    }
    return false;
  }

  @action
  void resetActiveSubscription() {
    remainingConsultations = null;
    totalConsultations = null;
    activeCustomerSubscriptionDetail = null;
    activeCompanySubscriptionDetails = null;
    hasActiveSubscription = false;
  }
}
