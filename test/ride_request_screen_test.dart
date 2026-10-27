import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:taxi_app/models/place_suggestion.dart';
import 'package:taxi_app/services/backend_places_service.dart';
import 'package:taxi_app/localization/translations.dart';
import 'package:taxi_app/localization/app_language.dart';
import 'package:taxi_app/models/route_result.dart';
import 'package:taxi_app/screens/ride_request_screen.dart';
import 'package:taxi_app/services/route_service.dart';
import 'package:taxi_app/screens/ride_summary_screen.dart';
import 'package:taxi_app/models/ride.dart';
import 'package:taxi_app/models/ride_request_status.dart';
import 'package:taxi_app/screens/main_navigation_screen.dart';

class FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  Position currentPosition = _position(42.70, 23.32);
  int positionStreamRequestCount = 0;
  int currentPositionRequestCount = 0;
  int permissionRequestCount = 0;
  int activeStreamCount = 0;
  LocationSettings? lastLocationSettings;

  final List<StreamController<Position>> _positionControllers = [];

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequestCount++;
    permission = requestedPermission;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    currentPositionRequestCount++;
    return currentPosition;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    positionStreamRequestCount++;
    lastLocationSettings = locationSettings;

    late final StreamController<Position> controller;
    controller = StreamController<Position>(
      sync: true,
      onListen: () => activeStreamCount++,
      onCancel: () {
        activeStreamCount--;
      },
    );
    _positionControllers.add(controller);
    return controller.stream;
  }

  void emitPosition(Position position) {
    for (final controller in _positionControllers) {
      if (!controller.isClosed && controller.hasListener) {
        controller.add(position);
      }
    }
  }

  Future<void> close() async {
    for (final controller in _positionControllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }
}

class RecordingGoogleMapsPlatform extends GoogleMapsFlutterPlatform {
  final StreamController<MapEvent<dynamic>> _mapEvents =
      StreamController<MapEvent<dynamic>>.broadcast(sync: true);
  final List<CameraUpdate> cameraUpdates = [];
  final Set<int> _createdMapIds = {};
  Completer<void>? nextCameraAnimationCompleter;
  int? mapId;
  MapWidgetConfiguration? widgetConfiguration;

  @override
  Future<void> init(int mapId) async {}

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateMarkers(
    MarkerUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolygons(
    PolygonUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolylines(
    PolylineUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateCircles(
    CircleUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates updates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    cameraUpdates.add(cameraUpdate);
    final completer = nextCameraAnimationCompleter;
    nextCameraAnimationCompleter = null;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    mapId = creationId;
    this.widgetConfiguration = widgetConfiguration;
    if (_createdMapIds.add(creationId)) {
      onPlatformViewCreated(creationId);
    }
    return const ColoredBox(color: Colors.transparent);
  }

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) =>
      _mapEvents.stream
          .where((event) => event is CameraMoveStartedEvent)
          .cast();

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) =>
      _mapEvents.stream.where((event) => event is CameraMoveEvent).cast();

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) =>
      _mapEvents.stream.where((event) => event is CameraIdleEvent).cast();

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MapTapEvent> onTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      const Stream.empty();

  @override
  void dispose({required int mapId}) {}

  void emitCameraMoveStarted() {
    _mapEvents.add(CameraMoveStartedEvent(mapId!));
  }

  void emitCameraMove(CameraPosition position) {
    _mapEvents.add(CameraMoveEvent(mapId!, position));
  }

  void emitCameraIdle() {
    _mapEvents.add(CameraIdleEvent(mapId!));
  }

  Future<void> close() => _mapEvents.close();
}

Position _position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime(2026, 10, 20),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class FailingRouteService implements RouteService {
  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
    String? pickupPlaceId,
    String? destinationPlaceId,
    double? pickupLatitude,
    double? pickupLongitude,
  }) async {
    throw Exception('Route calculation failed');
  }
}

class SuccessfulRouteService implements RouteService {
  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
    String? pickupPlaceId,
    String? destinationPlaceId,
    double? pickupLatitude,
    double? pickupLongitude,
  }) async {
    return const RouteResult(
      distanceKm: 12.5,
      durationMinutes: 25,
      pickupLatitude: 42.70,
      pickupLongitude: 23.32,
    );
  }
}

class RecordingCoordinateRouteService implements RouteService {
  String? selectedPickupPlaceId;
  double? pickupLatitude;
  double? pickupLongitude;

  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
    String? pickupPlaceId,
    String? destinationPlaceId,
    double? pickupLatitude,
    double? pickupLongitude,
  }) async {
    selectedPickupPlaceId = pickupPlaceId;
    this.pickupLatitude = pickupLatitude;
    this.pickupLongitude = pickupLongitude;
    return const RouteResult(
      distanceKm: 12.5,
      durationMinutes: 25,
      pickupLatitude: 42.75,
      pickupLongitude: 23.40,
    );
  }
}

class NightIntercityRouteService implements RouteService {
  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
    String? pickupPlaceId,
    String? destinationPlaceId,
    double? pickupLatitude,
    double? pickupLongitude,
  }) async {
    return const RouteResult(
      distanceKm: 10,
      durationMinutes: 20,
      pickupLatitude: 42.70,
      pickupLongitude: 23.32,
    );
  }
}

class RecordingPlaceIdRouteService implements RouteService {
  String? pickupPlaceId;
  String? destinationPlaceId;

  @override
  Future<RouteResult> calculateRoute({
    required String pickup,
    required String destination,
    String? pickupPlaceId,
    String? destinationPlaceId,
    double? pickupLatitude,
    double? pickupLongitude,
  }) async {
    this.pickupPlaceId = pickupPlaceId;
    this.destinationPlaceId = destinationPlaceId;

    return const RouteResult(
      distanceKm: 10,
      durationMinutes: 20,
      pickupLatitude: 42.70,
      pickupLongitude: 23.32,
    );
  }
}

class FakePlacesService extends BackendPlacesService {
  const FakePlacesService();

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    String? sessionToken,
  }) async {
    return const [
      PlaceSuggestion(
        placeId: 'pickup-place-001',
        text: 'бул. „Витоша“, София, България',
      ),
      PlaceSuggestion(
        placeId: 'pickup-place-002',
        text: 'бул. „Витоша“ 100, София, България',
      ),
    ];
  }
}

Future<void> enableManualPickup(WidgetTester tester) async {
  final pickupField = find.byType(TextField).at(0);

  await tester.tap(pickupField);
  await tester.pumpAndSettle();

  final manualAddressOption = find.text('Въведи адрес');

  expect(manualAddressOption, findsOneWidget);

  await tester.tap(manualAddressOption);
  await tester.pumpAndSettle();
}

Future<void> pumpLocationUpdates(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 1)),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  late FakeGeolocatorPlatform geolocatorPlatform;
  late GeolocatorPlatform originalGeolocatorPlatform;
  late RecordingGoogleMapsPlatform mapsPlatform;
  late GoogleMapsFlutterPlatform originalMapsPlatform;

  setUp(() {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
    originalGeolocatorPlatform = GeolocatorPlatform.instance;
    originalMapsPlatform = GoogleMapsFlutterPlatform.instance;
    geolocatorPlatform = FakeGeolocatorPlatform();
    mapsPlatform = RecordingGoogleMapsPlatform();
    GeolocatorPlatform.instance = geolocatorPlatform;
    GoogleMapsFlutterPlatform.instance = mapsPlatform;
  });

  tearDown(() async {
    await geolocatorPlatform.close();
    await mapsPlatform.close();
    GeolocatorPlatform.instance = originalGeolocatorPlatform;
    GoogleMapsFlutterPlatform.instance = originalMapsPlatform;
  });

  testWidgets('request map is interactive and exposes a follow control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: RideRequestScreen()));
    await tester.pumpAndSettle();

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.liteModeEnabled, isFalse);
    expect(map.scrollGesturesEnabled, isTrue);
    expect(map.zoomGesturesEnabled, isTrue);
    expect(map.zoomControlsEnabled, isTrue);
    expect(map.myLocationButtonEnabled, isFalse);
    expect(
      map.gestureRecognizers.single.constructor(),
      isA<EagerGestureRecognizer>(),
    );
    expect(find.byTooltip(AppTranslations.myLocation), findsOneWidget);
    expect(geolocatorPlatform.positionStreamRequestCount, 1);
    expect(geolocatorPlatform.currentPositionRequestCount, 0);
    expect(geolocatorPlatform.lastLocationSettings?.distanceFilter, 10);
    expect(
      (geolocatorPlatform.lastLocationSettings as AndroidSettings)
          .useMSLAltitude,
      isFalse,
    );
  });

  testWidgets('choosing current pickup location centers the map once', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: RideRequestScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Избери начална точка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTranslations.myLocation).last);
    await tester.pumpAndSettle();

    expect(geolocatorPlatform.currentPositionRequestCount, 1);
    expect(mapsPlatform.cameraUpdates, hasLength(1));
    final update = mapsPlatform.cameraUpdates.single.toJson() as List;
    expect((update[1] as Map)['zoom'], 17);
  });

  testWidgets(
    'manual pan interrupts queued GPS camera updates during animation',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: RideRequestScreen()));
      await tester.pumpAndSettle();

      final firstAnimation = Completer<void>();
      mapsPlatform.nextCameraAnimationCompleter = firstAnimation;
      geolocatorPlatform.emitPosition(_position(42.701, 23.321));
      await tester.pump();
      expect(mapsPlatform.cameraUpdates, hasLength(1));

      mapsPlatform.emitCameraMoveStarted();
      await tester.pump();
      expect(find.byIcon(Icons.my_location), findsOneWidget);

      geolocatorPlatform.emitPosition(_position(42.702, 23.322));
      await tester.pump();
      expect(mapsPlatform.cameraUpdates, hasLength(1));

      mapsPlatform.emitCameraIdle();
      await tester.pump();
      expect(mapsPlatform.cameraUpdates, hasLength(2));
      mapsPlatform.emitCameraMoveStarted();
      await tester.pump();
      expect(find.byIcon(Icons.my_location), findsOneWidget);

      final map = find.byType(GoogleMap);
      final gesture = await tester.startGesture(tester.getCenter(map));
      await gesture.moveBy(const Offset(36, 0));
      await tester.pump();
      expect(find.byIcon(Icons.location_searching), findsOneWidget);

      mapsPlatform.emitCameraMoveStarted();
      await tester.pump();
      expect(find.byIcon(Icons.location_searching), findsOneWidget);
      await gesture.up();
      await tester.pump();

      firstAnimation.complete();
      await tester.pumpAndSettle();
      mapsPlatform.emitCameraIdle();
      await tester.pump();
      expect(mapsPlatform.cameraUpdates, hasLength(2));

      await tester.tap(find.byTooltip(AppTranslations.myLocation));
      await tester.pumpAndSettle();
      expect(mapsPlatform.cameraUpdates, hasLength(3));
      mapsPlatform.emitCameraIdle();
      await tester.pump();
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    },
  );

  testWidgets(
    'GPS follow pauses on manual camera movement and resumes at current zoom',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: RideRequestScreen()));
      await tester.pumpAndSettle();

      geolocatorPlatform.emitPosition(_position(42.701, 23.321));
      await tester.pump();
      expect(mapsPlatform.cameraUpdates, isNotEmpty);
      expect(
        (mapsPlatform.cameraUpdates.last.toJson() as List<Object?>)[1],
        contains('target'),
      );
      mapsPlatform.emitCameraIdle();

      mapsPlatform.emitCameraMove(
        const CameraPosition(target: LatLng(42.701, 23.321), zoom: 14),
      );
      mapsPlatform.emitCameraIdle();
      mapsPlatform.emitCameraMoveStarted();
      await tester.pump();

      final cameraUpdatesBeforePause = mapsPlatform.cameraUpdates.length;
      geolocatorPlatform.emitPosition(_position(42.702, 23.322));
      await tester.pump();
      expect(mapsPlatform.cameraUpdates, hasLength(cameraUpdatesBeforePause));
      expect(geolocatorPlatform.activeStreamCount, 1);

      await tester.tap(find.byTooltip(AppTranslations.myLocation));
      await tester.pumpAndSettle();
      expect(
        mapsPlatform.cameraUpdates,
        hasLength(cameraUpdatesBeforePause + 1),
      );
      final recenterUpdate = mapsPlatform.cameraUpdates.last.toJson() as List;
      final recenterCameraPosition = recenterUpdate[1] as Map;
      expect(recenterCameraPosition['zoom'], 14);
      expect(geolocatorPlatform.positionStreamRequestCount, 1);

      mapsPlatform.emitCameraIdle();
      geolocatorPlatform.emitPosition(_position(42.703, 23.323));
      await tester.pump();
      expect(
        mapsPlatform.cameraUpdates,
        hasLength(cameraUpdatesBeforePause + 2),
      );
      expect(
        ((mapsPlatform.cameraUpdates.last.toJson() as List)[1] as Map)['zoom'],
        14,
      );
    },
  );

  testWidgets('GPS stream stops while map is inactive and resumes only once', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: RideRequestScreen(mapIsActive: false)),
    );
    await tester.pumpAndSettle();
    expect(geolocatorPlatform.positionStreamRequestCount, 0);
    expect(geolocatorPlatform.activeStreamCount, 0);

    await tester.pumpWidget(
      MaterialApp(home: RideRequestScreen(mapIsActive: true)),
    );
    await tester.pumpAndSettle();
    expect(geolocatorPlatform.positionStreamRequestCount, 1);
    expect(geolocatorPlatform.activeStreamCount, 1);

    await tester.tap(find.byTooltip(AppTranslations.myLocation));
    await tester.pumpAndSettle();
    expect(geolocatorPlatform.positionStreamRequestCount, 1);
    expect(geolocatorPlatform.activeStreamCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(geolocatorPlatform.activeStreamCount, 0);
  });

  testWidgets('navigation tabs stop and resume exactly one GPS subscription', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MainNavigationScreen(restoreActiveRide: false)),
    );
    await tester.pump();
    await tester.pump();
    expect(geolocatorPlatform.activeStreamCount, 1);
    expect(geolocatorPlatform.positionStreamRequestCount, 1);

    await tester.tap(find.text('Любими'));
    await tester.pump();
    await tester.pump();
    expect(geolocatorPlatform.activeStreamCount, 0);

    await tester.tap(find.text('Поръчай'));
    await pumpLocationUpdates(tester);
    expect(geolocatorPlatform.positionStreamRequestCount, 2);
    expect(geolocatorPlatform.activeStreamCount, 1);
  });

  testWidgets('GPS subscription stops while the ride summary covers the map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: SuccessfulRouteService(),
          placesService: const FakePlacesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(geolocatorPlatform.activeStreamCount, 1);

    final textFields = find.byType(TextField);
    await enableManualPickup(tester);
    await tester.enterText(textFields.at(0), 'Pickup address');
    await tester.enterText(textFields.at(1), 'Destination address');
    final confirmButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    confirmButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.byType(RideSummaryScreen), findsOneWidget);
    expect(geolocatorPlatform.activeStreamCount, 0);

    Navigator.of(tester.element(find.byType(RideSummaryScreen))).pop();
    await tester.pumpAndSettle();
    await pumpLocationUpdates(tester);
    expect(geolocatorPlatform.activeStreamCount, 1);
    expect(geolocatorPlatform.positionStreamRequestCount, 2);
  });

  testWidgets(
    'GPS subscription pauses in background and resumes on foreground',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: RideRequestScreen()));
      await tester.pumpAndSettle();
      expect(geolocatorPlatform.activeStreamCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(geolocatorPlatform.activeStreamCount, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await pumpLocationUpdates(tester);
      expect(geolocatorPlatform.activeStreamCount, 1);
      expect(geolocatorPlatform.positionStreamRequestCount, 2);
    },
  );

  testWidgets('denied location permission does not start a GPS stream', (
    WidgetTester tester,
  ) async {
    geolocatorPlatform.permission = LocationPermission.deniedForever;
    await tester.pumpWidget(MaterialApp(home: RideRequestScreen()));
    await tester.pumpAndSettle();

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.myLocationEnabled, isFalse);
    expect(geolocatorPlatform.permissionRequestCount, 0);
    expect(geolocatorPlatform.positionStreamRequestCount, 0);
    expect(geolocatorPlatform.activeStreamCount, 0);
  });

  testWidgets('passive GPS updates do not replace the selected pickup', (
    WidgetTester tester,
  ) async {
    geolocatorPlatform.currentPosition = _position(42.70, 23.32);
    await tester.pumpWidget(MaterialApp(home: RideRequestScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Избери начална точка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTranslations.myLocation).last);
    await tester.pumpAndSettle();
    final pickupField = tester.widget<TextField>(find.byType(TextField).first);
    final selectedPickup = pickupField.controller!.text;
    expect(selectedPickup, AppTranslations.myLocation);

    geolocatorPlatform.emitPosition(_position(42.75, 23.40));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      selectedPickup,
    );
  });

  testWidgets('selected GPS pickup coordinates reach the ride request', (
    WidgetTester tester,
  ) async {
    const latitude = 42.6977;
    const longitude = 23.3219;
    geolocatorPlatform.currentPosition = _position(latitude, longitude);
    final routeService = RecordingCoordinateRouteService();

    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: routeService,
          placesService: const FakePlacesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Избери начална точка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTranslations.myLocation).last);
    await tester.pumpAndSettle();

    // A later passive GPS fix must not replace the pickup the customer chose.
    geolocatorPlatform.emitPosition(_position(42.75, 23.40));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'Sofia Airport');

    final confirmButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    confirmButton.onPressed!();
    await tester.pumpAndSettle();

    final summary = tester.widget<RideSummaryScreen>(
      find.byType(RideSummaryScreen),
    );
    expect(summary.request.pickup, AppTranslations.myLocation);
    expect(summary.request.pickupLatitude, latitude);
    expect(summary.request.pickupLongitude, longitude);
    expect(routeService.pickupLatitude, latitude);
    expect(routeService.pickupLongitude, longitude);
    expect(summary.routeResult?.pickupLatitude, 42.75);
    expect(
      summary.request.pickupLatitude,
      isNot(summary.routeResult?.pickupLatitude),
    );
    expect(
      summary.request.pickupLongitude,
      isNot(summary.routeResult?.pickupLongitude),
    );
  });

  testWidgets(
    'English My location label retains the selected GPS coordinates',
    (WidgetTester tester) async {
      AppTranslations.currentLanguage = AppLanguage.english;
      addTearDown(() {
        AppTranslations.currentLanguage = AppLanguage.bulgarian;
      });
      geolocatorPlatform.currentPosition = _position(42.6977, 23.3219);
      final routeService = RecordingCoordinateRouteService();

      await tester.pumpWidget(
        MaterialApp(
          home: RideRequestScreen(
            routeService: routeService,
            placesService: const FakePlacesService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Избери начална точка'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppTranslations.myLocation).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Sofia Airport');

      final confirmButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      confirmButton.onPressed!();
      await tester.pumpAndSettle();

      final summary = tester.widget<RideSummaryScreen>(
        find.byType(RideSummaryScreen),
      );
      expect(summary.request.pickup, 'My location');
      expect(summary.request.pickupLatitude, 42.6977);
      expect(summary.request.pickupLongitude, 23.3219);
    },
  );

  testWidgets('changing language after GPS selection preserves coordinates', (
    WidgetTester tester,
  ) async {
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
    geolocatorPlatform.currentPosition = _position(42.6977, 23.3219);
    final routeService = RecordingCoordinateRouteService();
    final placesService = const FakePlacesService();

    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: routeService,
          placesService: placesService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Избери начална точка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTranslations.myLocation).last);
    await tester.pumpAndSettle();

    AppTranslations.currentLanguage = AppLanguage.english;
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: routeService,
          placesService: placesService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Sofia Airport');

    final confirmButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    confirmButton.onPressed!();
    await tester.pumpAndSettle();

    final summary = tester.widget<RideSummaryScreen>(
      find.byType(RideSummaryScreen),
    );
    expect(summary.request.pickup, 'Моето местоположение');
    expect(summary.request.pickupLatitude, 42.6977);
    expect(summary.request.pickupLongitude, 23.3219);
    expect(routeService.pickupLatitude, 42.6977);
    expect(routeService.pickupLongitude, 23.3219);
    AppTranslations.currentLanguage = AppLanguage.bulgarian;
  });

  testWidgets('changing GPS pickup to a manual address clears coordinates', (
    WidgetTester tester,
  ) async {
    geolocatorPlatform.currentPosition = _position(42.6977, 23.3219);
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: SuccessfulRouteService(),
          placesService: const FakePlacesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Избери начална точка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTranslations.myLocation).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Избери начална точка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Въведи адрес'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Manual pickup');
    await tester.enterText(find.byType(TextField).at(1), 'Sofia Airport');

    final confirmButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    confirmButton.onPressed!();
    await tester.pumpAndSettle();

    final summary = tester.widget<RideSummaryScreen>(
      find.byType(RideSummaryScreen),
    );
    expect(summary.request.pickup, 'Manual pickup');
    expect(summary.request.pickupLatitude, 42.70);
    expect(summary.request.pickupLongitude, 23.32);
  });

  testWidgets(
    'autocomplete pickup uses resolved coordinates instead of previous GPS',
    (WidgetTester tester) async {
      final routeService = RecordingCoordinateRouteService();
      geolocatorPlatform.currentPosition = _position(42.6977, 23.3219);
      await tester.pumpWidget(
        MaterialApp(
          home: RideRequestScreen(
            routeService: routeService,
            placesService: const FakePlacesService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Избери начална точка'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppTranslations.myLocation).last);
      await tester.pumpAndSettle();

      await enableManualPickup(tester);
      await tester.enterText(find.byType(TextField).at(0), 'бул. Вит');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('бул. „Витоша“, София, България'));
      await tester.enterText(find.byType(TextField).at(1), 'Sofia Airport');

      final confirmButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      confirmButton.onPressed!();
      await tester.pumpAndSettle();

      final summary = tester.widget<RideSummaryScreen>(
        find.byType(RideSummaryScreen),
      );
      expect(summary.request.pickup, 'бул. „Витоша“, София, България');
      expect(summary.request.pickupLatitude, 42.75);
      expect(summary.request.pickupLongitude, 23.40);
      expect(summary.request.pickupLatitude, isNot(42.6977));
      expect(summary.request.pickupLongitude, isNot(23.3219));
      expect(routeService.selectedPickupPlaceId, 'pickup-place-001');
      expect(routeService.pickupLatitude, isNull);
      expect(routeService.pickupLongitude, isNull);
    },
  );

  testWidgets('choosing a favorite pickup clears previous GPS coordinates', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'favoritePlaces': [
        '{"id":"home","name":"Home","address":"Home address",'
            '"placeId":"home-place"}',
      ],
    });
    geolocatorPlatform.currentPosition = _position(42.6977, 23.3219);
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: SuccessfulRouteService(),
          placesService: const FakePlacesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Избери начална точка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTranslations.myLocation).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Избери начална точка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Sofia Airport');

    final confirmButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    confirmButton.onPressed!();
    await tester.pumpAndSettle();

    final summary = tester.widget<RideSummaryScreen>(
      find.byType(RideSummaryScreen),
    );
    expect(summary.request.pickup, 'Home address');
    expect(summary.request.pickupLatitude, 42.70);
    expect(summary.request.pickupLongitude, 23.32);
  });

  testWidgets('GPS pickup with missing coordinates is blocked', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: SuccessfulRouteService(),
          placesService: const FakePlacesService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await enableManualPickup(tester);
    await tester.enterText(
      find.byType(TextField).at(0),
      AppTranslations.myLocation,
    );
    await tester.enterText(find.byType(TextField).at(1), 'Sofia Airport');

    final confirmButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    confirmButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.byType(RideSummaryScreen), findsNothing);
    expect(
      find.text(AppTranslations.pickupCoordinatesUnavailable),
      findsOneWidget,
    );
  });

  testWidgets('invalid GPS coordinates are not selected as a pickup', (
    WidgetTester tester,
  ) async {
    geolocatorPlatform.currentPosition = _position(91, 23.3219);
    await tester.pumpWidget(MaterialApp(home: RideRequestScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Избери начална точка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTranslations.myLocation).last);
    await tester.pumpAndSettle();

    expect(
      find.text(AppTranslations.pickupCoordinatesUnavailable),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    expect(find.byType(RideSummaryScreen), findsNothing);
  });

  testWidgets('RideRequestScreen handles route calculation error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: FailingRouteService(),
          placesService: const FakePlacesService(),
        ),
      ),
    );

    final textFields = find.byType(TextField);
    await enableManualPickup(tester);

    await tester.enterText(textFields.at(0), 'Pickup location');

    await tester.enterText(textFields.at(1), 'Destination location');

    final confirmButton = find.byType(ElevatedButton);

    final button = tester.widget<ElevatedButton>(confirmButton);

    button.onPressed!();

    await tester.pumpAndSettle();

    expect(find.text(AppTranslations.routeCalculationFailed), findsOneWidget);

    final buttonAfterError = tester.widget<ElevatedButton>(confirmButton);

    expect(buttonAfterError.onPressed, isNotNull);
  });
  testWidgets('RideRequestScreen passes route result to RideSummaryScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: SuccessfulRouteService(),
          placesService: const FakePlacesService(),
          now: () => DateTime(2026, 1, 1, 10, 0),
        ),
      ),
    );

    final textFields = find.byType(TextField);
    await enableManualPickup(tester);

    await tester.enterText(textFields.at(0), 'Pickup location');

    await tester.enterText(textFields.at(1), 'Destination location');

    final confirmButton = find.byType(ElevatedButton);

    final button = tester.widget<ElevatedButton>(confirmButton);

    button.onPressed!();

    await tester.pumpAndSettle();

    expect(find.byType(RideSummaryScreen), findsOneWidget);

    final summaryScreen = tester.widget<RideSummaryScreen>(
      find.byType(RideSummaryScreen),
    );

    expect(summaryScreen.routeResult, isNotNull);
    expect(summaryScreen.routeResult!.distanceKm, 12.5);
    expect(summaryScreen.routeResult!.durationMinutes, 25);
    expect(summaryScreen.estimatedPrice, closeTo(11.475, 0.001));
    expect(summaryScreen.request.status, RideRequestStatus.pending);
    expect(find.textContaining('12.5 km'), findsOneWidget);

    expect(
      find.textContaining('25 ${AppTranslations.minutes}'),
      findsOneWidget,
    );
    expect(find.textContaining('10:25'), findsOneWidget);
    final formattedPrice = summaryScreen.estimatedPrice!.toStringAsFixed(2);

    expect(find.textContaining(formattedPrice), findsOneWidget);
  });
  testWidgets('RideRequestScreen calculates night intercity estimated price', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: NightIntercityRouteService(),
          placesService: const FakePlacesService(),
          now: () => DateTime(2026, 1, 1, 23, 0),
        ),
      ),
    );

    final textFields = find.byType(TextField);
    await enableManualPickup(tester);

    await tester.enterText(textFields.at(0), 'Pickup location');

    await tester.enterText(textFields.at(1), 'Destination location');

    final intercityOption = find.text(AppTranslations.intercityRide);

    await tester.ensureVisible(intercityOption);
    await tester.tap(intercityOption);

    await tester.pump();

    final confirmButton = find.byType(ElevatedButton);

    final button = tester.widget<ElevatedButton>(confirmButton);

    button.onPressed!();

    await tester.pumpAndSettle();

    expect(find.byType(RideSummaryScreen), findsOneWidget);

    final summaryScreen = tester.widget<RideSummaryScreen>(
      find.byType(RideSummaryScreen),
    );

    expect(summaryScreen.estimatedPrice, closeTo(13.20, 0.001));

    final formattedPrice = summaryScreen.estimatedPrice!.toStringAsFixed(2);

    expect(find.textContaining(formattedPrice), findsOneWidget);
  });
  testWidgets(
    'RideRequestScreen passes card payment method to RideSummaryScreen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RideRequestScreen(
            routeService: SuccessfulRouteService(),
            placesService: const FakePlacesService(),
            now: () => DateTime(2026, 1, 1, 10, 0),
          ),
        ),
      );

      final textFields = find.byType(TextField);
      await enableManualPickup(tester);

      await tester.enterText(textFields.at(0), 'Pickup location');

      await tester.enterText(textFields.at(1), 'Destination location');
      await tester.ensureVisible(find.text(AppTranslations.card));

      await tester.tap(find.text(AppTranslations.card));

      await tester.pump();

      final confirmButton = find.byType(ElevatedButton);

      final button = tester.widget<ElevatedButton>(confirmButton);

      button.onPressed!();

      await tester.pumpAndSettle();

      expect(find.byType(RideSummaryScreen), findsOneWidget);

      final summaryScreen = tester.widget<RideSummaryScreen>(
        find.byType(RideSummaryScreen),
      );

      expect(summaryScreen.paymentMethod, RidePaymentMethod.card);
    },
  );
  testWidgets(
    'RideRequestScreen passes luggage selection to RideSummaryScreen',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RideRequestScreen(
            routeService: SuccessfulRouteService(),
            placesService: const FakePlacesService(),
            now: () => DateTime(2026, 1, 1, 10, 0),
          ),
        ),
      );

      final textFields = find.byType(TextField);
      await enableManualPickup(tester);

      await tester.enterText(textFields.at(0), 'Pickup location');
      await tester.enterText(textFields.at(1), 'Destination location');

      await tester.ensureVisible(find.text(AppTranslations.luggageNo));

      await tester.tap(find.text(AppTranslations.luggageNo));

      await tester.pump();

      final confirmButton = find.byType(ElevatedButton);
      final button = tester.widget<ElevatedButton>(confirmButton);

      button.onPressed!();

      await tester.pumpAndSettle();

      expect(find.byType(RideSummaryScreen), findsOneWidget);

      final summaryScreen = tester.widget<RideSummaryScreen>(
        find.byType(RideSummaryScreen),
      );

      expect(summaryScreen.request.hasLuggage, isTrue);
    },
  );
  testWidgets('RideRequestScreen keeps luggage selection false by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: SuccessfulRouteService(),
          placesService: const FakePlacesService(),
          now: () => DateTime(2026, 1, 1, 10, 0),
        ),
      ),
    );

    final textFields = find.byType(TextField);
    await enableManualPickup(tester);

    await tester.enterText(textFields.at(0), 'Pickup location');
    await tester.enterText(textFields.at(1), 'Destination location');

    final confirmButton = find.byType(ElevatedButton);
    final button = tester.widget<ElevatedButton>(confirmButton);

    button.onPressed!();

    await tester.pumpAndSettle();

    expect(find.byType(RideSummaryScreen), findsOneWidget);

    final summaryScreen = tester.widget<RideSummaryScreen>(
      find.byType(RideSummaryScreen),
    );

    expect(summaryScreen.request.hasLuggage, isFalse);
  });
  testWidgets('RideRequestScreen shows pickup autocomplete suggestions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(placesService: const FakePlacesService()),
      ),
    );

    final textFields = find.byType(TextField);
    await enableManualPickup(tester);

    await tester.enterText(textFields.at(0), 'бул. Вит');

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('бул. „Витоша“, София, България'), findsOneWidget);

    expect(find.text('бул. „Витоша“ 100, София, България'), findsOneWidget);
  });
  testWidgets('RideRequestScreen shows destination autocomplete suggestions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(placesService: const FakePlacesService()),
      ),
    );

    final textFields = find.byType(TextField);
    await enableManualPickup(tester);

    await tester.enterText(textFields.at(1), 'бул. Вит');

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('бул. „Витоша“, София, България'), findsOneWidget);

    expect(find.text('бул. „Витоша“ 100, София, България'), findsOneWidget);
  });
  testWidgets('RideRequestScreen passes selected place IDs to RouteService', (
    WidgetTester tester,
  ) async {
    final routeService = RecordingPlaceIdRouteService();

    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: routeService,
          placesService: const FakePlacesService(),
        ),
      ),
    );

    final textFields = find.byType(TextField);
    await enableManualPickup(tester);

    await tester.enterText(textFields.at(0), 'бул. Вит');

    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('бул. „Витоша“, София, България'));

    await tester.enterText(textFields.at(1), 'бул. Вит');

    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('бул. „Витоша“ 100, София, България'));

    final confirmButton = find.byType(ElevatedButton);

    final button = tester.widget<ElevatedButton>(confirmButton);

    button.onPressed!();

    await tester.pumpAndSettle();

    expect(routeService.pickupPlaceId, 'pickup-place-001');

    expect(routeService.destinationPlaceId, 'pickup-place-002');
  });
  testWidgets('RideRequestScreen clears pickup place ID after manual edit', (
    WidgetTester tester,
  ) async {
    final routeService = RecordingPlaceIdRouteService();

    await tester.pumpWidget(
      MaterialApp(
        home: RideRequestScreen(
          routeService: routeService,
          placesService: const FakePlacesService(),
        ),
      ),
    );

    final textFields = find.byType(TextField);
    await enableManualPickup(tester);

    await tester.enterText(textFields.at(0), 'бул. Вит');

    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('бул. „Витоша“, София, България'));

    await tester.enterText(textFields.at(0), 'Ръчно променен адрес');

    await tester.enterText(textFields.at(1), 'Destination');

    final confirmButton = find.byType(ElevatedButton);
    final button = tester.widget<ElevatedButton>(confirmButton);

    button.onPressed!();

    await tester.pumpAndSettle();

    expect(routeService.pickupPlaceId, isNull);
  });
}
