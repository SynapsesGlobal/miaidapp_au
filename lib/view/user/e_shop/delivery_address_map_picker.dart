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
    this.initialZoom = 16,
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
  final double initialZoom;

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
    double initialZoom = 16,
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
          initialZoom: initialZoom,
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

  @override
  void initState() {
    super.initState();
    _center = LatLng(widget.initialLatitude, widget.initialLongitude);
    _scheduleReverse();
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
