import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:mobx/mobx.dart';

part 'purchases_store.g.dart';

@singleton
class PurchasesStore = _PurchasesStore with _$PurchasesStore;

abstract class _PurchasesStore with Store {
  int orderId = 0;

  @observable
  Order? orderDetails;

  @observable
  bool isLoading = false;

  @observable
  List<Order> orderList = [];

  @observable
  List<bool> isExpandedList = [];

  @action
  Future<void> getOrders(ApiProvider apiProvider) async {
    try {
      isLoading = true;

      var userOrderListResponse =
          await apiProvider.apiClient.eShopOrdersGetUserOrders();

      if (userOrderListResponse.statusCode == 200) {
        isExpandedList.clear();
        orderList = List.generate(
          userOrderListResponse.body!.payload!.length,
          (index) => Order.fromJson(
            userOrderListResponse.body!.payload![index].toJson(),
          ),
        );
        orderList.forEach((_) {
          isExpandedList.add(false);
        });
        // print('orders: ${orderList.length}');
        orderList.forEach((o) {
          // print('order: ${o.products?.length}');
          o.products?.forEach((p) {});
        });
        // print('All User Purchase Listed Success');
      }
    } catch (e) {
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  @action
  void unExpandEveryItem() {
    if (isExpandedList.isNotEmpty) {
      isExpandedList.forEach((element) {
        element = false;
      });
      isExpandedList = isExpandedList;
    }
  }

  Future<void> getOrderData(ApiProvider apiProvider, int orderId) async {
    try {
      isLoading = true;

      var orderDataResponse = await apiProvider.apiClient
          .eShopOrdersGetOrderDetails(order_id: orderId);

      if (orderDataResponse.statusCode == 200) {
        orderDetails = orderDataResponse.body!.payload!;

        // print(
        // 'Purchase View Receipt Success order details: ${orderDetails?.products?.length}');
        // print(orderDataResponse.bodyString);
        // print(orderDetails!.products.toString());
      }
    } catch (e) {
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  @action
  void updateExpansion(int i, bool b) {
    isExpandedList[i] = b;
    isExpandedList = isExpandedList;
  }

  @action
  Future<bool> reOrder(Order order, ApiProvider apiProvider) async {
    // print('ordering again with order id : ${order.id}');
    var response = await apiProvider.apiClient
        .eShopOrdersPostCreateAOrderAgain(order_id: order.id);
    if (ApiSuccessParser.isSuccessfulWithPayload(response)) {
      return true;
    } else {
      ApiSuccessParser.isSuccessfulOrThrowWithMessage(response);
      return false;
    }
  }
}
