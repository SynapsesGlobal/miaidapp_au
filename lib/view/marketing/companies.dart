import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/view/marketing/company_products.dart';

import '../../api_utils/consts.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import 'package:http/http.dart' as http;

import '../../generated/l10n.dart';
import '../../store/home/home_screen_store.dart';

class Companies extends StatefulWidget {
  final int categoryId;
  final String category;
  const Companies({super.key, required this.categoryId, required this.category});

  @override
  State<Companies> createState() => _CompaniesState();
}

class _CompaniesState extends State<Companies> {
  List companies = [];
  String no_data = '';
  String keywords = '';
  Position? _position;
  Timer? _searchDebounce;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  Future<void> _getCompanies({bool showLoading = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    if (showLoading) {
      await EasyLoading.show(
        status: 'Loading',
        maskType: EasyLoadingMaskType.black,
      );
    }

    try {
      final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
      _position = position;
      final url = Uri.parse(Consts.marketingApiHost+'/companies').replace(queryParameters: {
        'mainCateId': widget.categoryId.toString(),
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
        'keywords': keywords
      });
      final response = await http.get(url, headers: headers);

      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body)['companies'];
        setState(() {
          companies = responseData;
          no_data = responseData.length > 0 ? '' : 'No data available.';
        });
      } else {
        await EasyLoading.dismiss();
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      print(e.toString());
      await EasyLoading.dismiss();
    }
  }

  @override
  void initState() {
    super.initState();
    _getCompanies();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// 输入停顿 450ms 后自动搜索，避免每敲一个字都请求一次
  void _onKeywordsChanged(String value) {
    setState(() => keywords = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _getCompanies(showLoading: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(widget.category, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () => Navigator.pop(context),
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: Column(children: [
        _buildSearch(),
        Expanded(child: _buildListView())
      ],),
    );
  }

  /// Distance from the user to a company, e.g. "1.2 km" (null when unknown).
  String? _distanceLabel(Map company) {
    final lat = double.tryParse(company['latitude']?.toString() ?? '');
    final lng = double.tryParse(company['longitude']?.toString() ?? '');
    if (_position == null || lat == null || lng == null) return null;

    final meters = Geolocator.distanceBetween(
      _position!.latitude, _position!.longitude, lat, lng);
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Widget _buildListView() {
    if (companies.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: AppColors.k0cbcc5,
      onRefresh: () => _getCompanies(showLoading: false),
      child: MasonryGridView.count(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: companies.length,
        itemBuilder: (context, index) => _buildCompanyCard(companies[index]),
      ),
    );
  }

  Widget _buildCompanyCard(Map company) {
    final distance = _distanceLabel(company);
    final phone = company['phone']?.toString() ?? '';
    final address = company['address']?.toString() ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (context) => CompanyProducts(company: company),
        ),),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: CachedNetworkImage(
                    fit: BoxFit.cover,
                    imageUrl: company['image'] ?? '',
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFEDEFF2),
                      child: Icon(Icons.storefront_outlined,
                          size: 32, color: Colors.grey.shade400),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFEDEFF2),
                      child: Icon(Icons.storefront_outlined,
                          size: 32, color: Colors.grey.shade400),
                    ),
                  ),
                ),
                // 底部渐变压暗，保证图上的商家名可读
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.55, 1.0],
                        colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10, right: 10, bottom: 8,
                  child: Text(
                    company['name']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (distance != null)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(distance, style: GoogleFonts.rubik(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(address, maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rubik(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              height: 1.3,
                            ),),
                        ),
                      ],
                    ),
                  if (address.isNotEmpty && phone.isNotEmpty)
                    const SizedBox(height: 5),
                  if (phone.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 14, color: AppColors.k0cbcc5),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(phone, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 12,
                            ),),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (no_data.isNotEmpty) ...[
            Icon(Icons.storefront_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
          ],
          Text(no_data, style: GoogleFonts.rubik(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          )),
        ],
      ),
    );
  }

  /// Search widget
  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: _controller,
          focusNode: _searchFocus,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            hintText: S.of(context).keywords,
            hintStyle: GoogleFonts.rubik(fontSize: 14, color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search, size: 20, color: AppColors.k0cbcc5,),
            filled: true,
            fillColor: const Color(0xFFF2F3F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(21),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(21),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(21),
              borderSide: BorderSide(color: AppColors.k0cbcc5, width: 1),
            ),
            suffixIcon: _controller.text.isNotEmpty ? InkWell(
              customBorder: const CircleBorder(),
              onTap: (){
                _controller.clear();
                _searchDebounce?.cancel();
                setState(() => keywords = '');
                _getCompanies(showLoading: false);
              },
              child: Icon(Icons.cancel, size: 18, color: Colors.grey.shade400,),
            ) : null,
          ),
          style: GoogleFonts.rubik(fontSize: 14, color: AppColors.k010101),
          onChanged: _onKeywordsChanged,
          textInputAction: TextInputAction.search,
          keyboardType: TextInputType.text,
          onSubmitted: (value) {
            _searchDebounce?.cancel();
            setState(() => keywords = value);
            _getCompanies();
          },
        ),
      ),
    );
  }
}
