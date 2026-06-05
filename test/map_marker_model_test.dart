import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/model/map_marker.dart';
import 'package:latlong2/latlong.dart';

void main() {
  late MapMarker mapMarker;
  setUpAll(() {
    mapMarker = MapMarker(
        id: 'testLocation',
        marker: Marker(
            point: LatLng(30, 30),
            builder: (context) {
              return Icon(Icons.location_on_rounded,
                  size: 100, color: Colors.blue);
            }));
  });

  group('MapMarker', () {
    test('Values', () {
      expect(mapMarker.id, 'testLocation');
      expect(mapMarker.marker.point, LatLng(30, 30));
    });
  });
  testWidgets('map marker model test', (WidgetTester tester) async {});
}
