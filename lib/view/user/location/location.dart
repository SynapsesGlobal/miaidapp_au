import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/location_details_store.dart';
import 'package:miaid/utils/geolocation.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class LocationsParams {
  const LocationsParams(this.key);

  final Key key;
}

@injectable
class LocationsServices {
  LocationsServices(this.api, this.locationDetailsStore, this.appSettings);

  final ApiProvider api;
  final AppSettings appSettings;
  final LocationDetailsStore locationDetailsStore;
}

@injectable
class Locations extends StatefulWidget {
  Locations({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final LocationsParams? params;
  final LocationsServices services;

  @override
  _LocationsState createState() => _LocationsState();
}

class _LocationsState extends State<Locations> {
  late LocationDetailsStore locationDetailsStore;
  GlobalKey<ScaffoldState> scaffoldState = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    locationDetailsStore = widget.services.locationDetailsStore;
    locationDetailsStore.fetchCountries(widget.services.api);
    MyGeoLocation().determinePosition(context);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldState,
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.kffffff,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).chooseLocation,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) {
            return InkWell(
              onTap: () async {
                Navigator.pop(context, true);
                locationDetailsStore.changeIsFilterSelected(false);
              },
              child: navBarIcon(iconAssetName: 'ic_nb_close.png'),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _currentLocationButton(context),
            const SizedBox(height: 28),
            _sectionDivider(context),
            const SizedBox(height: 24),
            Observer(builder: (context) {
              if (locationDetailsStore.isLoading) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: progressIndicator(),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (locationDetailsStore.countryList.isNotEmpty) ...[
                      _fieldLabel(S.of(context).country),
                      const SizedBox(height: 8),
                      _countryField(),
                    ],
                    if (locationDetailsStore.showNoLocationsInCountryError ||
                        (locationDetailsStore.countrySelected != null &&
                            locationDetailsStore.cityList.isEmpty)) ...[
                      const SizedBox(height: 12),
                      _errorCard(S.of(context).noLocationsInCountry),
                    ] else if (locationDetailsStore.countrySelected != null) ...[
                      const SizedBox(height: 20),
                      _fieldLabel(S.of(context).city),
                      const SizedBox(height: 8),
                      _cityField(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _currentLocationButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TapDebouncer(
        onTap: () async {
          await MyGeoLocation().determinePosition(context);
          Navigator.pop(context, true);
          locationDetailsStore.changeIsFilterSelected(false);
        },
        builder: (context, onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.k0cbcc5.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.k0cbcc5.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.k0cbcc5.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image(
                  image: const AssetImage(
                      'assets/images/ic_pharmacy_currentlocation.png'),
                  height: 20,
                  width: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  S.of(context).useCurrentLocation,
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.k0cbcc5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.kb1b1b1.withOpacity(0.4),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              S.of(context).selectNewAddress,
              style: GoogleFonts.rubik(
                color: AppColors.k8f8e94,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: AppColors.kb1b1b1.withOpacity(0.4),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.rubik(
        color: AppColors.k2e2e2e,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.ke63030.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.ke63030.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.ke63030, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.rubik(
                color: AppColors.ke63030,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 城市选择入口：点击打开底部单选弹窗
  Widget _cityField() {
    return _pickerField(
      value: locationDetailsStore.citySelected,
      hint: S.of(context).selectCity,
      onTap: _showCityPicker,
    );
  }

  Future<void> _showCityPicker() async {
    final cities = locationDetailsStore.cityList;
    if (cities.isEmpty) {
      return;
    }
    final index = await _showSingleSelectPicker(
      title: S.of(context).selectCity,
      options: cities.map((e) => e.name ?? '').toList(),
      selectedIndex: cities.indexWhere((e) => e.id != null
          ? e.id == locationDetailsStore.cityIdSelected
          : e.name == locationDetailsStore.citySelected),
    );
    if (index != null && mounted) {
      final city = cities[index];
      locationDetailsStore.changeSelectedCity(city.name ?? '', cityId: city.id);
      Navigator.pop(context);
    }
  }

  // 国家选择入口：点击打开底部单选弹窗
  Widget _countryField() {
    return _pickerField(
      value: locationDetailsStore.countrySelected,
      hint: S.of(context).selectCountry,
      onTap: _showCountryPicker,
    );
  }

  Future<void> _showCountryPicker() async {
    final countries = locationDetailsStore.countryList;
    final index = await _showSingleSelectPicker(
      title: S.of(context).selectCountry,
      options: countries.map((e) => e.name ?? '').toList(),
      selectedIndex: countries
          .indexWhere((e) => e.id == locationDetailsStore.countryIdSelected),
    );
    if (index != null) {
      final country = countries[index];
      final name = country.name ?? '';
      locationDetailsStore.changeSelectedCountry(name, countryId: country.id);
      locationDetailsStore.changeSelectedState('miaid');
      await locationDetailsStore.fetchLocations(widget.services.api, name,
          countryId: country.id);
    }
  }

  // 选择入口字段：展示已选值或占位提示，点击打开底部弹窗
  Widget _pickerField({
    required String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.kf4f4f4.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(width: 0.5, color: AppColors.kb1b1b1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: GoogleFonts.rubik(
                  color: value == null ? AppColors.k8f8e94 : AppColors.k010101,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.kb1b1b1,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // 单选底部弹窗：选项卡片式，点选即返回；内容多时可滚动，少时高度自适应
  // 返回选中项的下标而非文本，避免同名选项（不同 id）无法区分
  Future<int?> _showSingleSelectPicker({
    required String title,
    required List<String> options,
    required int selectedIndex,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // 最高不超过屏幕高度的 60%：选项少时高度自适应，选项多时列表内部滚动
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部拖拽指示条
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.rubik(
                          color: AppColors.k010101,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    children: [
                      for (var i = 0; i < options.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Builder(builder: (context) {
                            final isSelected = i == selectedIndex;
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(context).pop(i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.keefeff
                                      : AppColors.kf4f4f4,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.k0cbcc5
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        options[i],
                                        style: GoogleFonts.rubik(
                                          color: AppColors.k010101,
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? AppColors.k0cbcc5
                                          : AppColors.kb1b1b1,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
