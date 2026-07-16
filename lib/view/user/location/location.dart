import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/location_details_store.dart';
import 'package:miaid/utils/geolocation.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

import '../../../generated/l10n.dart';

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
                      _countryDropDown(),
                    ],
                    if (locationDetailsStore.showNoLocationsInCountryError) ...[
                      const SizedBox(height: 12),
                      _errorCard(S.of(context).noLocationsInCountry),
                    ],
                    if (locationDetailsStore.countrySelected != null) ...[
                      const SizedBox(height: 20),
                      _fieldLabel(S.of(context).city),
                      const SizedBox(height: 8),
                      _cityDropDown(),
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
                  image: const AssetImage('assets/images/ic_pharmacy_currentlocation.png'),
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

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: AppColors.kf4f4f4.withOpacity(0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(width: 0.5, color: AppColors.kb1b1b1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(width: 0.5, color: AppColors.kb1b1b1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(width: 1.5, color: AppColors.k0cbcc5),
      ),
    );
  }

  DropdownButtonFormField<String> _cityDropDown() {
    var cityList = locationDetailsStore.listLocationFilters[0].cities!;
    return DropdownButtonFormField<String>(
      hint: Text(
        S.of(context).selectCity,
        style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 14),
      ),
      isExpanded: true,
      value: locationDetailsStore.citySelected,
      icon: Image.asset('assets/images/ic_support_dropdown_arrow_active.png'),
      elevation: 4,
      dropdownColor: AppColors.kffffff,
      style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14),
      onChanged: (String? newValue) {
        if (newValue != null) {
          locationDetailsStore.changeSelectedCity(newValue);
          Navigator.pop(context);
        }
      },
      decoration: _dropdownDecoration(),
      items: cityList.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  DropdownButtonFormField<String> _stateDropDown() {
    return DropdownButtonFormField<String>(
      hint: Text(
        S.of(context).selectState,
        style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 14),
      ),
      isExpanded: true,
      value: locationDetailsStore.stateSelected,
      icon: Image.asset('assets/images/ic_support_dropdown_arrow_active.png'),
      elevation: 4,
      dropdownColor: AppColors.kffffff,
      style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14),
      onChanged: (String? newValue) {
        if (newValue != null) {
          locationDetailsStore.changeSelectedState(newValue);
        }
      },
      decoration: _dropdownDecoration(),
      items: locationDetailsStore.listLocationFilters
          .map((e) => e.state.toString())
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  DropdownButtonFormField<String> _countryDropDown() {
    return DropdownButtonFormField<String>(
      hint: Text(
        S.of(context).selectCountry,
        style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 14),
      ),
      isExpanded: true,
      value: locationDetailsStore.countrySelected,
      icon: Image.asset('assets/images/ic_support_dropdown_arrow_active.png'),
      elevation: 4,
      dropdownColor: AppColors.kffffff,
      style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14),
      onChanged: (String? newValue) {
        if (newValue != null) {
          final countryId = locationDetailsStore.countryList
              .firstWhere((e) => e.name == newValue, orElse: () => Country())
              .id;
          locationDetailsStore.changeSelectedCountry(newValue, countryId: countryId);
          locationDetailsStore.changeSelectedState('miaid');
          locationDetailsStore.fetchLocations(widget.services.api, newValue, countryId: countryId);
        }
      },
      decoration: _dropdownDecoration(),
      items: locationDetailsStore.countryList
          .map((e) => e.name.toString())
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }
}
