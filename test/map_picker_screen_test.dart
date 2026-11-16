import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:taxi_app/localization/app_language.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/models/map_picker_result.dart';
import 'package:taxi_app/screens/map_picker_screen.dart';
import 'package:taxi_app/services/backend_reverse_geocode_service.dart';

import 'ride_request_screen_test.dart' show RecordingGoogleMapsPlatform;

class _ReverseGeocoder implements ReverseGeocodeService {
  final List<LatLng> requested = [];
  Future<String?> Function(LatLng point)? handler;

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    final point = LatLng(latitude, longitude);
    requested.add(point);
    return handler?.call(point) ?? Future.value('Recognized address');
  }
}

class _PickerHost extends StatefulWidget {
  const _PickerHost({required this.service});

  final ReverseGeocodeService service;

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  MapPickerResult? result;

  Future<void> _open() async {
    final selected = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute<MapPickerResult>(
        builder: (context) => MapPickerScreen(
          purpose: MapPickerPurpose.destination,
          initialCameraTarget: const LatLng(42.6977, 23.3219),
          reverseGeocodeService: widget.service,
          reverseGeocodeDebounce: Duration.zero,
        ),
      ),
    );
    if (mounted) setState(() => result = selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(onPressed: _open, child: const Text('Open map')),
        if (result != null)
          Text('${result!.address}|${result!.latitude},${result!.longitude}'),
      ],
    ),
  );
}

void main() {
  late RecordingGoogleMapsPlatform mapsPlatform;
  late GoogleMapsFlutterPlatform originalMapsPlatform;

  setUp(() {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
    originalMapsPlatform = GoogleMapsFlutterPlatform.instance;
    mapsPlatform = RecordingGoogleMapsPlatform();
    GoogleMapsFlutterPlatform.instance = mapsPlatform;
  });

  tearDown(() async {
    await mapsPlatform.close();
    GoogleMapsFlutterPlatform.instance = originalMapsPlatform;
  });

  testWidgets('map tap resolves one address and confirms exact coordinates', (
    tester,
  ) async {
    final service = _ReverseGeocoder();
    await tester.pumpWidget(MaterialApp(home: _PickerHost(service: service)));
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();

    expect(find.text('Изберете крайна точка'), findsOneWidget);
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    map.onTap!(const LatLng(42.7012, 23.3321));
    await tester.pump();
    expect(find.text('42.70120, 23.33210'), findsOneWidget);
    expect(service.requested, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(service.requested, [const LatLng(42.7012, 23.3321)]);
    await tester.pump();
    expect(find.text('Recognized address'), findsOneWidget);

    await tester.tap(find.text('Потвърди'));
    await tester.pumpAndSettle();
    expect(find.text('Recognized address|42.7012,23.3321'), findsOneWidget);
  });

  testWidgets('old address is hidden on marker drag and reverse lookup waits', (
    tester,
  ) async {
    final service = _ReverseGeocoder();
    await tester.pumpWidget(MaterialApp(home: _PickerHost(service: service)));
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    map.onTap!(const LatLng(42.70, 23.32));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump();
    expect(find.text('Recognized address'), findsOneWidget);

    var marker = tester
        .widget<GoogleMap>(find.byType(GoogleMap))
        .markers
        .single;
    marker.onDragStart!(const LatLng(42.71, 23.33));
    await tester.pump();
    expect(find.text('Recognized address'), findsNothing);
    expect(find.text('42.71000, 23.33000'), findsOneWidget);
    expect(service.requested, hasLength(1));

    marker = tester.widget<GoogleMap>(find.byType(GoogleMap)).markers.single;
    marker.onDrag!(const LatLng(42.715, 23.335));
    await tester.pump();
    expect(find.text('42.71500, 23.33500'), findsOneWidget);
    expect(service.requested, hasLength(1));
    marker = tester.widget<GoogleMap>(find.byType(GoogleMap)).markers.single;
    marker.onDragEnd!(const LatLng(42.71, 23.33));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(service.requested, hasLength(2));
  });

  testWidgets('late reverse response cannot replace newer selection', (
    tester,
  ) async {
    final service = _ReverseGeocoder();
    final first = Completer<String?>();
    final second = Completer<String?>();
    service.handler = (point) =>
        point.latitude < 42.71 ? first.future : second.future;

    await tester.pumpWidget(MaterialApp(home: _PickerHost(service: service)));
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    var map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    map.onTap!(const LatLng(42.70, 23.32));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(service.requested, hasLength(1));

    map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    map.onTap!(const LatLng(42.72, 23.34));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(service.requested, hasLength(2));

    second.complete('New address');
    await tester.pump();
    first.complete('Stale address');
    await tester.pump();
    expect(find.text('New address'), findsOneWidget);
    expect(find.text('Stale address'), findsNothing);
  });

  testWidgets('unavailable reverse lookup keeps a coordinate fallback', (
    tester,
  ) async {
    final service = _ReverseGeocoder()..handler = (_) async => null;
    await tester.pumpWidget(MaterialApp(home: _PickerHost(service: service)));
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    tester.widget<GoogleMap>(find.byType(GoogleMap)).onTap!(
      const LatLng(42.69, 23.31),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump();
    expect(find.text('42.69000, 23.31000'), findsOneWidget);

    await tester.tap(find.text('Потвърди'));
    await tester.pumpAndSettle();
    expect(find.text('42.69000, 23.31000|42.69,23.31'), findsOneWidget);
  });

  testWidgets('reverse-geocode error keeps the selected point confirmable', (
    tester,
  ) async {
    final service = _ReverseGeocoder()
      ..handler = (_) async => throw TimeoutException('temporary timeout');
    await tester.pumpWidget(MaterialApp(home: _PickerHost(service: service)));
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    tester.widget<GoogleMap>(find.byType(GoogleMap)).onTap!(
      const LatLng(42.69, 23.31),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump();
    expect(find.text('42.69000, 23.31000'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Потвърди'));
    await tester.pumpAndSettle();
    expect(find.text('42.69000, 23.31000|42.69,23.31'), findsOneWidget);
  });

  testWidgets('back cancels and English labels fit a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppTranslations.currentLanguage = AppLanguage.english;
    final service = _ReverseGeocoder();
    await tester.pumpWidget(MaterialApp(home: _PickerHost(service: service)));
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    expect(find.text('Choose destination'), findsOneWidget);
    expect(find.text('Confirm location'), findsOneWidget);
    tester.widget<GoogleMap>(find.byType(GoogleMap)).onTap!(
      const LatLng(42.7, 23.3),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    Navigator.of(tester.element(find.byType(MapPickerScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('|42.7,23.3'), findsNothing);
  });
}
