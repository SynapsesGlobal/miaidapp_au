import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/device_location_service.dart';
import 'package:miaid/services/mapbox_geocoding_service.dart';

/// 地图选点的结果：坐标以图钉为准，[address] 是反查出的文本，可能为空
class DeliveryMapPickerResult {
  const DeliveryMapPickerResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;
}

/// 收货地址地图选点页：图钉固定在屏幕中央，拖动地图把图钉放到收货地址上，
/// 底部实时显示反查出的地址和到药店的距离，超出寄送半径时不能确认。
///
/// 给地址联想找不到的用户兜底（新小区、拼写不全等），产出和联想一样的坐标，
/// 购物车页的半径校验与后端下单逻辑不变。地图瓦片沿用「附近急诊」页的 Mapbox 样式。
class DeliveryAddressMapPicker extends StatefulWidget {
  const DeliveryAddressMapPicker({
    Key? key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.pharmacyLatitude,
    required this.pharmacyLongitude,
    required this.radiusMeters,
    required this.radiusLabel,
    this.pharmacyName,
    this.languageTag,
    this.countryCode,
    this.initialZoom = 16,
    this.autofocusSearch = false,
  }) : super(key: key);

  final double initialLatitude;
  final double initialLongitude;
  final double pharmacyLatitude;
  final double pharmacyLongitude;
  final double radiusMeters;
  final String radiusLabel;

  /// 药店名称，挂在药店图标下方，帮用户辨认方位；为空只画图标
  final String? pharmacyName;
  final String? languageTag;

  /// 地图内搜索限定的国家（ISO 3166-1 alpha-2），和购物车页联想保持一致
  final String? countryCode;
  final double initialZoom;

  /// 打开时直接聚焦搜索框弹键盘：从空白地址栏进来时用户多半想先搜
  final bool autofocusSearch;

  /// 全屏打开选点页；用户取消返回 null
  static Future<DeliveryMapPickerResult?> show(
    BuildContext context, {
    required double initialLatitude,
    required double initialLongitude,
    required double pharmacyLatitude,
    required double pharmacyLongitude,
    required double radiusMeters,
    required String radiusLabel,
    String? pharmacyName,
    String? languageTag,
    String? countryCode,
    double initialZoom = 16,
    bool autofocusSearch = false,
  }) {
    return Navigator.push<DeliveryMapPickerResult>(
      context,
      MaterialPageRoute<DeliveryMapPickerResult>(
        fullscreenDialog: true,
        builder: (_) => DeliveryAddressMapPicker(
          initialLatitude: initialLatitude,
          initialLongitude: initialLongitude,
          pharmacyLatitude: pharmacyLatitude,
          pharmacyLongitude: pharmacyLongitude,
          radiusMeters: radiusMeters,
          radiusLabel: radiusLabel,
          pharmacyName: pharmacyName,
          languageTag: languageTag,
          countryCode: countryCode,
          initialZoom: initialZoom,
          autofocusSearch: autofocusSearch,
        ),
      ),
    );
  }

  @override
  State<DeliveryAddressMapPicker> createState() => _DeliveryAddressMapPickerState();
}

class _DeliveryAddressMapPickerState extends State<DeliveryAddressMapPicker> {
  final MapController _mapController = MapController();
  final MapboxGeocodingService _geocoding = MapboxGeocodingService();

  late LatLng _center;
  String? _address;
  bool _resolving = false;
  bool _locating = false;
  Timer? _debounce;
  int _seq = 0;

  // ---- 地图内搜索：输入后联想，选中把地图中心移过去，之后走和拖动一样的反查 ----
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  int _searchSeq = 0;
  List<MapboxPlace> _suggestions = const [];
  bool _searching = false;
  bool _searchFailed = false;
  String _lastQuery = '';
  /// 选中联想项回填输入框时置 true，避免 onChanged 再触发一次搜索
  bool _suppressSearch = false;

  @override
  void initState() {
    super.initState();
    _center = LatLng(widget.initialLatitude, widget.initialLongitude);
    // 焦点变化要重建：失焦收起联想面板，重新聚焦再展开
    _searchFocus.addListener(_onSearchFocusChanged);
    _scheduleReverse();
    if (widget.autofocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchFocus.dispose();
    super.dispose();
  }

  double get _distanceMeters => Geolocator.distanceBetween(
        widget.pharmacyLatitude,
        widget.pharmacyLongitude,
        _center.latitude,
        _center.longitude,
      );

  bool get _inRange => _distanceMeters <= widget.radiusMeters;

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    final center = position.center;
    if (center == null) return;
    if (center.latitude == _center.latitude && center.longitude == _center.longitude) return;
    setState(() {
      _center = center;
      _address = null;
      _resolving = true;
    });
    _scheduleReverse();
  }

  /// 地图停下 500ms 后再反查，拖动过程中不发请求；旧请求的结果按序号丢弃
  void _scheduleReverse() {
    _debounce?.cancel();
    _resolving = true;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final seq = ++_seq;
      final target = _center;
      final place = await _geocoding.reverse(
        target.latitude,
        target.longitude,
        language: widget.languageTag,
      );
      if (!mounted || seq != _seq) return;
      setState(() {
        _address = place?.placeName;
        _resolving = false;
      });
    });
  }

  Future<void> _moveToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final result = await DeviceLocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    final position = result.position;
    if (result.isOk && position != null) {
      _mapController.move(LatLng(position.latitude, position.longitude), 17);
      return;
    }
    final l10n = S.of(context);
    String message;
    switch (result.status) {
      case DeviceLocationStatus.serviceDisabled:
        message = l10n.locationServiceDisabled;
        break;
      case DeviceLocationStatus.permissionDenied:
      case DeviceLocationStatus.permissionDeniedForever:
        message = l10n.locationPermissionDenied;
        break;
      default:
        message = l10n.locatingFailed;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  double _metersToPharmacy(double latitude, double longitude) => Geolocator.distanceBetween(
        widget.pharmacyLatitude,
        widget.pharmacyLongitude,
        latitude,
        longitude,
      );

  /// 输入框有焦点且输入够 3 个字符时才挂联想面板（加载中 / 失败 / 无结果 / 列表）
  bool get _showSuggestionPanel => _searchFocus.hasFocus && _lastQuery.length >= 3;

  void _onSearchChanged(String value) {
    if (_suppressSearch) return;
    final query = value.trim();
    _searchDebounce?.cancel();
    if (query.length < 3) {
      setState(() {
        _lastQuery = query;
        _suggestions = const [];
        _searching = false;
        _searchFailed = false;
      });
      return;
    }
    setState(() {
      _lastQuery = query;
      _searching = true;
      _searchFailed = false;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _runSearch(query));
  }

  /// proximity 用当前地图中心：用户正在看的区域优先，比固定用药店坐标更贴近意图
  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq;
    final center = _center;
    final result = await _geocoding.search(
      query,
      proximityLatitude: center.latitude,
      proximityLongitude: center.longitude,
      countryCode: widget.countryCode,
      language: widget.languageTag,
    );
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _suggestions = result.places;
      _searchFailed = result.failed;
      _searching = false;
    });
  }

  void _retrySearch() {
    if (_lastQuery.length < 3) return;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    _runSearch(_lastQuery);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchSeq++;
    _suppressSearch = true;
    _searchController.clear();
    _suppressSearch = false;
    setState(() {
      _lastQuery = '';
      _suggestions = const [];
      _searching = false;
      _searchFailed = false;
    });
  }

  /// 选中联想项：输入框回填名称、收起列表，地图移到该点；onPositionChanged 会接着反查地址
  void _selectSuggestion(MapboxPlace place) {
    _searchDebounce?.cancel();
    _searchSeq++;
    _suppressSearch = true;
    _searchController.value = TextEditingValue(
      text: place.placeName,
      selection: TextSelection.collapsed(offset: place.placeName.length),
    );
    _suppressSearch = false;
    _searchFocus.unfocus();
    setState(() {
      _suggestions = const [];
      _searching = false;
      _searchFailed = false;
    });
    _mapController.move(LatLng(place.latitude, place.longitude), 17);
  }

  void _confirm() {
    Navigator.pop(
      context,
      DeliveryMapPickerResult(
        latitude: _center.latitude,
        longitude: _center.longitude,
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final pharmacy = LatLng(widget.pharmacyLatitude, widget.pharmacyLongitude);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.k010101),
        title: Text(
          l10n.mapPickerTitle,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _center,
                    zoom: widget.initialZoom,
                    maxZoom: 18.0,
                    onPositionChanged: _onPositionChanged,
                    // 点地图收起搜索列表和键盘
                    onTap: (_, __) => _searchFocus.unfocus(),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://api.mapbox.com/styles/v1/abdullahriaz95/ckrx2pafw27bh17ryrlaoy65r/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                      additionalOptions: {
                        'accessToken': dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '',
                      },
                    ),
                    // 寄送范围圈，让用户一眼看到图钉能放到哪
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: pharmacy,
                          radius: widget.radiusMeters,
                          useRadiusInMeter: true,
                          color: AppColors.k0cbcc5.withOpacity(0.08),
                          borderColor: AppColors.k0cbcc5.withOpacity(0.6),
                          borderStrokeWidth: 1,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [_pharmacyMarker(pharmacy)],
                    ),
                  ],
                ),
                // 固定在屏幕中央的图钉：图标底部尖端对准地图中心，所以整体上移半个图标高
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 40,
                        color: _inRange ? Colors.red : AppColors.kb1b1b1,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _searchOverlay(l10n),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'delivery_map_my_location',
                    backgroundColor: Colors.white,
                    onPressed: _moveToMyLocation,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          _bottomPanel(context, l10n),
        ],
      ),
    );
  }

  /// 地图上方的搜索框，下面按需挂联想列表 / 失败重试 / 无结果提示
  Widget _searchOverlay(S l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          elevation: 3,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14),
            decoration: InputDecoration(
              hintText: l10n.searchOnMap,
              hintStyle: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: AppColors.k8f8e94),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close, color: AppColors.k8f8e94, size: 20),
                          onPressed: _clearSearch,
                        )),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
        if (_showSuggestionPanel) ...[
          const SizedBox(height: 6),
          Material(
            color: Colors.white,
            elevation: 3,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: _suggestionPanelBody(l10n),
            ),
          ),
        ],
      ],
    );
  }

  Widget _suggestionPanelBody(S l10n) {
    if (_searchFailed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.addressServiceUnavailable,
                style: GoogleFonts.rubik(color: Colors.red, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _retrySearch,
              child: Text(l10n.retry, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 13)),
            ),
          ],
        ),
      );
    }
    if (_searching && _suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(l10n.loading, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13)),
      );
    }
    if (_suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(l10n.noAddressFound, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13)),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.kf4f4f4),
      itemBuilder: (_, index) => _suggestionTile(l10n, _suggestions[index]),
    );
  }

  /// 联想项：第一段逗号前做标题，其余做副标题；右侧标到药店距离，超出半径标红
  Widget _suggestionTile(S l10n, MapboxPlace place) {
    final comma = place.placeName.indexOf(',');
    final title = comma > 0 ? place.placeName.substring(0, comma).trim() : place.placeName;
    final subtitle = comma > 0 ? place.placeName.substring(comma + 1).trim() : '';
    final meters = _metersToPharmacy(place.latitude, place.longitude);
    final inRange = meters <= widget.radiusMeters;
    final km = (meters / 1000).toStringAsFixed(1);
    return InkWell(
      onTap: () => _selectSuggestion(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.place_outlined, size: 18, color: inRange ? AppColors.k0cbcc5 : AppColors.kb1b1b1),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rubik(
                      color: inRange ? AppColors.k010101 : AppColors.k8f8e94,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              inRange ? '$km km' : l10n.outsideDeliveryRadius(widget.radiusLabel),
              maxLines: 1,
              style: GoogleFonts.rubik(
                color: inRange ? AppColors.k0cbcc5 : Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 药店标记：图标 + 名称标签。Marker 默认以中心对准坐标，所以标签上方留同样高度的
  /// 空白，让图标中心正好落在药店坐标上，名称挂在图标正下方
  Marker _pharmacyMarker(LatLng point) {
    const iconSize = 28.0;
    const labelHeight = 22.0;
    final name = widget.pharmacyName?.trim() ?? '';
    final hasName = name.isNotEmpty;
    return Marker(
      point: point,
      width: hasName ? 180 : iconSize + 4,
      height: hasName ? iconSize + labelHeight * 2 : iconSize + 4,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasName) const SizedBox(height: labelHeight),
          Icon(Icons.local_pharmacy_rounded, color: AppColors.k0cbcc5, size: iconSize),
          if (hasName)
            Container(
              height: labelHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(labelHeight / 2),
                border: Border.all(color: AppColors.k0cbcc5, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomPanel(BuildContext context, S l10n) {
    final distanceKm = (_distanceMeters / 1000).toStringAsFixed(1);
    final inRange = _inRange;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.mapPickerHint,
              style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, size: 18, color: AppColors.k8f8e94),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _resolving
                        ? l10n.findingAddress
                        : (_address ?? l10n.addressUnknownAtPin),
                    style: GoogleFonts.rubik(
                      color: _resolving ? AppColors.k8f8e94 : AppColors.k010101,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              inRange
                  ? l10n.distanceFromPharmacy(distanceKm)
                  : l10n.outsideDeliveryRadius(widget.radiusLabel),
              style: GoogleFonts.rubik(
                color: inRange ? AppColors.k0cbcc5 : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.k0cbcc5,
                  disabledBackgroundColor: AppColors.kb1b1b1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                // 反查未结束也允许确认（文本可以回去手填），超出范围才禁用
                onPressed: inRange ? _confirm : null,
                child: Text(
                  l10n.confirmLocation,
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
