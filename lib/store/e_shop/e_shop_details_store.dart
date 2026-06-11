import 'package:chopper/chopper.dart' as chopper;
import 'package:flutter/material.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'e_shop_details_store.g.dart';

@injectable
class EShopDetailsStore = _EShopDetailsStore with _$EShopDetailsStore;

abstract class _EShopDetailsStore with Store {
  String categoryName = '';
  String pharmacyName = '';

  @observable
  bool isProductByCategoryLoading = false;
  int categoryIndex = 1;
  TextEditingController searchController = TextEditingController();

  @observable
  Pharmacy? pharmacyDetails;

  @observable
  bool isLoading = false;

  @observable
  List<ProductCategory> productCategoryList = [];

  @observable
  List<Product> products = [];

  @observable
  int page = 1;

  @observable
  bool has_more = true;

  @observable
  int currentCategoryId = -1;

  @observable
  int pageSize = 10;

  @observable
  double scrollPosition = 0.0;

  @observable
  bool showHeader = true;

  @action
  dynamic fetchShopDetails(ApiProvider apiProvider, int pharmacyId) async {
    try {
      isLoading = true;
      final currentTimeZone = await FlutterNativeTimezone.getLocalTimezone();

      var pharmacyDetailsResponse = await apiProvider.apiClient.eShopLocationsGetPharmacyShow(
        pharmacy_id: pharmacyId, timezone: currentTimeZone
      );

      if (pharmacyDetailsResponse.statusCode == 200) {
        pharmacyDetails = pharmacyDetailsResponse.body!.payload;
      }
      isLoading = false;
    } catch (e) {
      rethrow;
    }
  }

  @action
  dynamic getProductsByCategoryIds(ApiProvider apiProvider, int? productCategoryId, int locationId, int eShopId) async {
    try {
      isProductByCategoryLoading = true;
      currentCategoryId = productCategoryId!;
      chopper.Response<EShopProductsProductsResponse>productByCategoryIdsResponse;

      final appSettings = getIt<AppSettings>();
      final language = appSettings.languageFull;

      if (productCategoryId == -1) {
        productByCategoryIdsResponse = await apiProvider.apiClient.eShopProductsGetProducts(
          location_id: locationId,
          pharmacy_id: eShopId,
          lang: language,
          page: page,
        );
      } else {
        productByCategoryIdsResponse = await apiProvider.apiClient.eShopProductsGetProducts(
          category_id: productCategoryId,
          location_id: locationId,
          pharmacy_id: eShopId,
          lang: language,
          page: page,
        );
      }
      page++;

      if (productByCategoryIdsResponse.statusCode == 200) {
        var pageProducts = productByCategoryIdsResponse.body?.payload as Iterable<Product>;
        if (pageProducts.isEmpty || pageProducts.length < pageSize) {
          has_more = false;
        }

        if (pageProducts.isNotEmpty) {
          products.addAll(pageProducts);
        }
        //products = productByCategoryIdsResponse.body?.payload ?? [];
      }

      isProductByCategoryLoading = false;
    } catch (e) {
      rethrow;
    } finally {
      isProductByCategoryLoading = false;
    }
  }

  @action
  dynamic getProductCategories(ApiProvider apiProvider, int eShopId, int locationId) async {
    try {
      final appSettings = getIt<AppSettings>();
      final language = appSettings.languageFull;
      var categoryDetailsResponse = await apiProvider.apiClient.eShopProductCategoryGetProductCategoryList(lang: language);

      if (categoryDetailsResponse.statusCode == 200) {
        var sharedPreferences = await SharedPreferences.getInstance();
        var language = sharedPreferences.getString('languageCode') ?? 'zh';
        var allCategory = 'All Categories';
        if (language == 'zh') {
          allCategory = '所有类别';
        } else if (language == 'id') {
          allCategory = 'Semua Kategori';
        } else if (language == 'ko') {
          allCategory = '모든 카테고리';
        } else {}

        productCategoryList = categoryDetailsResponse.body?.payload ?? [];
        productCategoryList.insert(0, ProductCategory(id: -1, name: allCategory));

        categoryIndex = productCategoryList[0].id!;
        categoryName = productCategoryList.first.name ?? '';
        isLoading = false;

        await getProductsByCategoryIds(apiProvider, productCategoryList.first.id ?? 0, locationId, eShopId);
      }
    } catch (e) {
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  @action
  dynamic searchShop(ApiProvider apiProvider, int shopId, int locationId) async {
    await getProductsByCategoryIds(apiProvider, -1, locationId, shopId);
    products = products.where((value) => value.name?.toLowerCase().contains(searchController.text.toLowerCase()) ?? false).toList();
  }
}
