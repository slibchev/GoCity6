import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../widgets/city6_app_bar_title.dart';
import '../widgets/city6_primary_button.dart';
import '../localization/translations.dart';
import '../models/ride.dart';
import '../models/ride_request_data.dart';
import '../services/route_service.dart';
import 'ride_summary_screen.dart';
import '../services/pricing_calculator.dart';
import '../services/backend_ride_request_service.dart';
import '../services/ride_request_service.dart';
import '../services/backend_route_service.dart';
import '../models/place_suggestion.dart';
import '../models/favorite_place.dart';
import '../services/backend_places_service.dart';
import '../services/favorites_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/active_ride_store.dart';

class RideRequestScreen extends StatefulWidget {
  final RouteService? routeService;
  final BackendPlacesService placesService;
  final RideRequestService rideRequestService;
  final ActiveRideStore? activeRideStore;
  final DateTime Function() now;
  final bool mapIsActive;

  RideRequestScreen({
    super.key,
    RouteService? routeService,
    BackendPlacesService? placesService,
    RideRequestService? rideRequestService,
    this.activeRideStore,
    DateTime Function()? now,
    this.mapIsActive = true,
  }) : routeService = routeService ?? const BackendRouteService(),
       placesService = placesService ?? const BackendPlacesService(),
       rideRequestService = rideRequestService ?? BackendRideRequestService(),
       now = now ?? DateTime.now;

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen>
    with WidgetsBindingObserver {
  int passengers = 1;
  bool hasLuggage = false;
  bool _isManualPickupEntry = false;
  RidePaymentMethod paymentMethod = RidePaymentMethod.cash;
  RideType rideType = RideType.city;
  bool isCalculatingRoute = false;

  final TextEditingController pickupController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final MenuController _pickupMenuController = MenuController();
  final FavoritesService _favoritesService = const FavoritesService();

  List<FavoritePlace> _favoritePlaces = [];

  BackendPlacesService get placesService => widget.placesService;

  List<PlaceSuggestion> pickupSuggestions = [];
  bool isLoadingPickupSuggestions = false;
  List<PlaceSuggestion> destinationSuggestions = [];
  bool isLoadingDestinationSuggestions = false;
  String? selectedPickupPlaceId;
  String? selectedDestinationPlaceId;
  double? selectedPickupLatitude;
  double? selectedPickupLongitude;
  bool isGettingCurrentLocation = false;
  GoogleMapController? _requestMapController;
  StreamSubscription<Position>? _locationSubscription;
  Future<void>? _locationStopFuture;
  bool _isStartingLocationStream = false;
  bool _isAppInForeground = true;
  bool _isRouteVisible = true;
  bool _isFollowingLocation = true;
  bool _hasCenteredOnFirstLocation = false;
  int _locationGeneration = 0;
  int _programmaticCameraMoveGeneration = 0;
  int? _activeProgrammaticCameraMoveId;
  LatLng? _pendingProgrammaticCameraPosition;
  double _currentMapZoom = 12;

  LatLng? _currentClientPosition;

  bool _locationPermissionGranted = false;
  Timer? _pickupDebounce;
  Timer? _destinationDebounce;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isAppInForeground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    _loadFavoritePlaces();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncLocationTracking();
    });
  }

  @override
  void didUpdateWidget(covariant RideRequestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapIsActive != widget.mapIsActive) {
      _syncLocationTracking();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (_isAppInForeground == isForeground) {
      return;
    }

    _isAppInForeground = isForeground;
    if (mounted) {
      setState(() {});
    }
    _syncLocationTracking();
  }

  bool get _shouldTrackLocation =>
      widget.mapIsActive && _isAppInForeground && _isRouteVisible;

  void _syncLocationTracking() {
    final generation = ++_locationGeneration;
    if (_shouldTrackLocation) {
      unawaited(_startLocationTracking(generation));
    } else {
      _invalidateProgrammaticCameraMove();
      unawaited(_stopLocationTracking());
    }
  }

  Future<void> _startLocationTracking(int generation) async {
    final pendingStop = _locationStopFuture;
    if (pendingStop != null) {
      await pendingStop;
    }

    if (!mounted ||
        !_shouldTrackLocation ||
        generation != _locationGeneration ||
        _locationSubscription != null ||
        _isStartingLocationStream) {
      return;
    }

    _isStartingLocationStream = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_canStartLocationTracking(generation)) {
        return;
      }

      if (!serviceEnabled) {
        _setLocationPermissionGranted(false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!_canStartLocationTracking(generation)) {
        return;
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setLocationPermissionGranted(false);
        return;
      }

      _setLocationPermissionGranted(true);
      final settings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
              intervalDuration: const Duration(seconds: 5),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            );

      final subscription =
          Geolocator.getPositionStream(locationSettings: settings).listen(
            (position) => _onLocationUpdate(position, generation),
            onError: (Object _) => _onLocationStreamError(generation),
            onDone: () => _onLocationStreamError(generation),
          );

      if (!_canStartLocationTracking(generation)) {
        await subscription.cancel();
        return;
      }
      _locationSubscription = subscription;
    } catch (_) {
      if (generation == _locationGeneration) {
        _setLocationPermissionGranted(false);
      }
    } finally {
      _isStartingLocationStream = false;
      if (mounted &&
          _shouldTrackLocation &&
          generation != _locationGeneration &&
          _locationSubscription == null) {
        _syncLocationTracking();
      }
    }
  }

  bool _canStartLocationTracking(int generation) =>
      mounted && _shouldTrackLocation && generation == _locationGeneration;

  void _setLocationPermissionGranted(bool granted) {
    if (!mounted || _locationPermissionGranted == granted) {
      return;
    }

    setState(() {
      _locationPermissionGranted = granted;
    });
  }

  void _onLocationUpdate(Position position, int generation) {
    if (!_canStartLocationTracking(generation)) {
      return;
    }

    final currentPosition = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentClientPosition = currentPosition;
    });

    if (!_isFollowingLocation) {
      return;
    }

    final controller = _requestMapController;
    if (controller == null) {
      return;
    }

    final zoom = _hasCenteredOnFirstLocation ? _currentMapZoom : 17.0;
    _currentMapZoom = zoom;
    _hasCenteredOnFirstLocation = true;
    if (_activeProgrammaticCameraMoveId != null) {
      _pendingProgrammaticCameraPosition = currentPosition;
      return;
    }
    unawaited(_animateCameraToPosition(currentPosition, zoom: zoom));
  }

  void _onLocationStreamError(int generation) {
    if (generation != _locationGeneration) {
      return;
    }

    _locationGeneration++;
    unawaited(_stopLocationTracking());
  }

  Future<void> _stopLocationTracking() {
    final subscription = _locationSubscription;
    if (subscription == null) {
      return _locationStopFuture ?? Future<void>.value();
    }

    _locationSubscription = null;
    final stopFuture = subscription.cancel();
    _locationStopFuture = stopFuture;
    return stopFuture.whenComplete(() {
      if (identical(_locationStopFuture, stopFuture)) {
        _locationStopFuture = null;
      }
    });
  }

  Future<void> _animateCameraToPosition(
    LatLng position, {
    required double zoom,
  }) async {
    final controller = _requestMapController;
    if (controller == null) {
      return;
    }

    if (_activeProgrammaticCameraMoveId != null) {
      _pendingProgrammaticCameraPosition = position;
      return;
    }

    final moveId = ++_programmaticCameraMoveGeneration;
    _activeProgrammaticCameraMoveId = moveId;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: zoom),
        ),
      );
    } catch (_) {
      _finishProgrammaticCameraMove(moveId, followPendingPosition: false);
      // A temporary map platform error must not disable GPS tracking.
    }
  }

  void _onCameraMoveStarted() {
    if (_activeProgrammaticCameraMoveId != null || !_isFollowingLocation) {
      return;
    }

    _pauseLocationFollowing();
  }

  void _onCameraMove(CameraPosition position) {
    _currentMapZoom = position.zoom;
  }

  void _onCameraIdle() {
    final moveId = _activeProgrammaticCameraMoveId;
    if (moveId != null) {
      _finishProgrammaticCameraMove(moveId);
    }
  }

  void _finishProgrammaticCameraMove(
    int moveId, {
    bool followPendingPosition = true,
  }) {
    if (_activeProgrammaticCameraMoveId != moveId) {
      return;
    }

    _activeProgrammaticCameraMoveId = null;
    final pendingPosition = _pendingProgrammaticCameraPosition;
    _pendingProgrammaticCameraPosition = null;

    if (followPendingPosition &&
        pendingPosition != null &&
        _isFollowingLocation &&
        _shouldTrackLocation) {
      unawaited(
        _animateCameraToPosition(pendingPosition, zoom: _currentMapZoom),
      );
    }
  }

  void _invalidateProgrammaticCameraMove() {
    _programmaticCameraMoveGeneration++;
    _activeProgrammaticCameraMoveId = null;
    _pendingProgrammaticCameraPosition = null;
  }

  void _pauseLocationFollowing() {
    _invalidateProgrammaticCameraMove();
    if (!_isFollowingLocation || !mounted) {
      return;
    }

    setState(() {
      _isFollowingLocation = false;
    });
  }

  void _resumeLocationFollowing() {
    if (!_isFollowingLocation) {
      setState(() {
        _isFollowingLocation = true;
      });
    }

    if (!_shouldTrackLocation) {
      return;
    }

    final currentPosition = _currentClientPosition;
    if (currentPosition != null) {
      unawaited(
        _animateCameraToPosition(currentPosition, zoom: _currentMapZoom),
      );
    }
    if (_locationSubscription == null) {
      _syncLocationTracking();
    }
  }

  Future<void> _setRouteVisible(bool visible) async {
    if (_isRouteVisible == visible) {
      return;
    }

    setState(() {
      _isRouteVisible = visible;
    });
    _syncLocationTracking();

    if (!visible) {
      await _locationStopFuture;
    }
  }

  Future<void> _loadFavoritePlaces() async {
    try {
      final favorites = await _favoritesService.getFavorites();

      if (!mounted) {
        return;
      }

      setState(() {
        _favoritePlaces = favorites;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _favoritePlaces = [];
      });
    }
  }

  void _openPickupMenu() {
    FocusScope.of(context).unfocus();

    if (_pickupMenuController.isOpen) {
      _pickupMenuController.close();
      return;
    }

    _pickupMenuController.open();

    _loadFavoritePlaces();
  }

  void _selectFavoriteAsPickup(FavoritePlace favorite) {
    setState(() {
      _isManualPickupEntry = false;

      pickupController.text = favorite.address;

      // При любим адрес маршрутизираме по адрес.
      selectedPickupPlaceId = null;

      selectedPickupLatitude = null;
      selectedPickupLongitude = null;

      pickupSuggestions = [];
      isLoadingPickupSuggestions = false;
    });

    FocusScope.of(context).unfocus();
  }

  void _selectFavoriteAsDestination(FavoritePlace favorite) {
    setState(() {
      destinationController.text = favorite.address;

      // При любим адрес маршрутизираме по адрес.
      selectedDestinationPlaceId = null;

      destinationSuggestions = [];
      isLoadingDestinationSuggestions = false;
    });

    FocusScope.of(context).unfocus();
  }

  Future<void> _showDestinationFavorites() async {
    FocusScope.of(context).unfocus();

    await _loadFavoritePlaces();

    if (!mounted) {
      return;
    }

    if (_favoritePlaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ÐÑÐ¼Ð°Ñ‚Ðµ Ð·Ð°Ð¿Ð°Ð·ÐµÐ½Ð¸ Ð»ÑŽÐ±Ð¸Ð¼Ð¸ Ð°Ð´Ñ€ÐµÑÐ¸.',
          ),
        ),
      );

      return;
    }

    await _setRouteVisible(false);
    if (!mounted) {
      return;
    }

    FavoritePlace? favorite;
    try {
      favorite = await showModalBottomSheet<FavoritePlace>(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Изберете любим адрес',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _favoritePlaces.length,
                    itemBuilder: (context, index) {
                      final favorite = _favoritePlaces[index];

                      return ListTile(
                        leading: Icon(Icons.star, color: AppColors.primary),
                        title: Text(
                          favorite.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(favorite.address),
                        onTap: () {
                          Navigator.pop(context, favorite);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        await _setRouteVisible(true);
      }
    }

    if (favorite == null || !mounted) {
      return;
    }

    _selectFavoriteAsDestination(favorite);
  }

  Future<void> _useCurrentLocation() async {
    if (isGettingCurrentLocation) {
      return;
    }

    setState(() {
      isGettingCurrentLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.locationServicesDisabled)),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.locationPermissionDenied)),
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.locationPermissionDeniedForever),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      if (!mounted) {
        return;
      }
      if (!RideRequestData.isValidPickupCoordinatePair(
        position.latitude,
        position.longitude,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.pickupCoordinatesUnavailable)),
        );
        return;
      }

      final currentPosition = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentClientPosition = currentPosition;
        _locationPermissionGranted = true;
        _isManualPickupEntry = false;

        _setPickupToCurrentLocation(currentPosition);
      });
      _currentMapZoom = 17;
      _hasCenteredOnFirstLocation = true;
      _resumeLocationFollowing();

      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } finally {
      if (mounted) {
        setState(() {
          isGettingCurrentLocation = false;
        });
      }
    }
  }

  void _setPickupToCurrentLocation(LatLng position) {
    selectedPickupPlaceId = null;
    selectedPickupLatitude = position.latitude;
    selectedPickupLongitude = position.longitude;

    pickupSuggestions = [];
    isLoadingPickupSuggestions = false;

    pickupController.value = TextEditingValue(
      text: AppTranslations.myLocation,
      selection: TextSelection.collapsed(
        offset: AppTranslations.myLocation.length,
      ),
    );
  }

  void _onPickupChanged(String input) {
    _pickupDebounce?.cancel();

    selectedPickupPlaceId = null;
    selectedPickupLatitude = null;
    selectedPickupLongitude = null;

    final query = input.trim();

    if (query.isEmpty) {
      setState(() {
        pickupSuggestions = [];
        isLoadingPickupSuggestions = false;
      });

      return;
    }

    _pickupDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadPickupSuggestions(query);
    });
  }

  void _onDestinationChanged(String input) {
    selectedDestinationPlaceId = null;

    _destinationDebounce?.cancel();

    _destinationDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadDestinationSuggestions(input);
    });
  }

  Future<void> _loadPickupSuggestions(String input) async {
    final query = input.trim();

    if (query.length < 3) {
      if (!mounted) {
        return;
      }

      setState(() {
        pickupSuggestions = [];
        isLoadingPickupSuggestions = false;
      });

      return;
    }

    setState(() {
      isLoadingPickupSuggestions = true;
    });

    try {
      final suggestions = await placesService.autocomplete(input: query);

      if (!mounted) {
        return;
      }

      if (pickupController.text.trim() != query) {
        return;
      }

      setState(() {
        pickupSuggestions = suggestions;
        isLoadingPickupSuggestions = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        pickupSuggestions = [];
        isLoadingPickupSuggestions = false;
      });
    }
  }

  Future<void> _loadDestinationSuggestions(String input) async {
    final query = input.trim();

    if (query.length < 3) {
      if (!mounted) {
        return;
      }

      setState(() {
        destinationSuggestions = [];
        isLoadingDestinationSuggestions = false;
      });

      return;
    }

    setState(() {
      isLoadingDestinationSuggestions = true;
    });

    try {
      final suggestions = await placesService.autocomplete(input: query);

      if (!mounted) {
        return;
      }

      if (destinationController.text.trim() != query) {
        return;
      }

      setState(() {
        destinationSuggestions = suggestions;
        isLoadingDestinationSuggestions = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        destinationSuggestions = [];
        isLoadingDestinationSuggestions = false;
      });
    }
  }

  Future<void> submitRide() async {
    final pickup = pickupController.text.trim();
    final destination = destinationController.text.trim();

    if (pickup.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppTranslations.pickupRequired)));
      return;
    }

    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.destinationRequired)),
      );
      return;
    }

    final isCurrentLocationPickup = _isCurrentLocationPickupLabel(pickup);
    final pickupLatitude = selectedPickupLatitude;
    final pickupLongitude = selectedPickupLongitude;
    final hasValidPickupCoordinates =
        RideRequestData.isValidPickupCoordinatePair(
          pickupLatitude,
          pickupLongitude,
        );

    if (isCurrentLocationPickup && !hasValidPickupCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.pickupCoordinatesUnavailable)),
      );
      return;
    }

    final requestPickupLatitude = isCurrentLocationPickup
        ? pickupLatitude
        : null;
    final requestPickupLongitude = isCurrentLocationPickup
        ? pickupLongitude
        : null;
    final pickupPlaceId = selectedPickupPlaceId;
    final destinationPlaceId = selectedDestinationPlaceId;

    if (widget.routeService == null) {
      if (!hasValidPickupCoordinates) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.pickupCoordinatesUnavailable)),
        );
        return;
      }

      final request = RideRequestData(
        clientRequestId: const Uuid().v4(),
        pickup: pickup,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        destination: destination,
        passengers: passengers,
        hasLuggage: hasLuggage,
        paymentMethod: paymentMethod,
        rideType: rideType,
        requestedAt: widget.now(),
      );

      await _pushRideSummary(request);

      return;
    }

    setState(() {
      isCalculatingRoute = true;
    });

    try {
      final routeResult = await widget.routeService!.calculateRoute(
        pickup: pickup,
        destination: destination,
        pickupPlaceId: pickupPlaceId,
        destinationPlaceId: destinationPlaceId,
        pickupLatitude: requestPickupLatitude,
        pickupLongitude: requestPickupLongitude,
      );

      if (!mounted) {
        return;
      }

      if (pickupController.text.trim() != pickup ||
          selectedPickupPlaceId != pickupPlaceId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.pickupCoordinatesUnavailable)),
        );
        return;
      }

      final resolvedPickupLatitude = isCurrentLocationPickup
          ? requestPickupLatitude
          : routeResult.pickupLatitude;
      final resolvedPickupLongitude = isCurrentLocationPickup
          ? requestPickupLongitude
          : routeResult.pickupLongitude;

      if (!RideRequestData.isValidPickupCoordinatePair(
        resolvedPickupLatitude,
        resolvedPickupLongitude,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.pickupCoordinatesUnavailable)),
        );
        return;
      }

      if (!isCurrentLocationPickup) {
        setState(() {
          selectedPickupLatitude = resolvedPickupLatitude;
          selectedPickupLongitude = resolvedPickupLongitude;
        });
      }

      final requestedAt = widget.now();

      final estimatedPrice = PricingCalculator.calculateEstimatedPrice(
        startTime: requestedAt,
        kilometers: routeResult.distanceKm,
        intercity: rideType == RideType.intercity,
      );

      final request = RideRequestData(
        clientRequestId: const Uuid().v4(),
        pickup: pickup,
        pickupLatitude: resolvedPickupLatitude,
        pickupLongitude: resolvedPickupLongitude,
        destination: destination,
        passengers: passengers,
        hasLuggage: hasLuggage,
        paymentMethod: paymentMethod,
        rideType: rideType,
        requestedAt: requestedAt,
        routeResult: routeResult,
        estimatedPrice: estimatedPrice,
      );

      await _pushRideSummary(request);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCurrentLocationPickup
                ? AppTranslations.routeCalculationFailed
                : AppTranslations.pickupCoordinatesUnavailable,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isCalculatingRoute = false;
        });
      }
    }
  }

  bool _isCurrentLocationPickupLabel(String pickup) =>
      pickup == AppTranslations.myLocation ||
      pickup == 'Моето местоположение' ||
      pickup == 'My location';

  Future<void> _pushRideSummary(RideRequestData request) async {
    final visibilityChange = _setRouteVisible(false);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (context) => RideSummaryScreen.fromRequest(
            request: request,
            rideRequestService: widget.rideRequestService,
            activeRideStore: widget.activeRideStore,
          ),
        ),
      );
    } finally {
      if (mounted) {
        await visibilityChange;
        await _setRouteVisible(true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationGeneration++;
    _invalidateProgrammaticCameraMove();
    unawaited(_stopLocationTracking());
    _pickupDebounce?.cancel();
    _destinationDebounce?.cancel();

    pickupController.dispose();
    destinationController.dispose();
    _pickupFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationLayerEnabled =
        _locationPermissionGranted && _shouldTrackLocation;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const City6AppBarTitle(),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (const bool.fromEnvironment(
                'CITY6_PASSENGER_MAP_ENABLED',
                defaultValue: true,
              ))
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Listener(
                            onPointerMove: (_) => _pauseLocationFollowing(),
                            child: GoogleMap(
                              liteModeEnabled: false,
                              initialCameraPosition: const CameraPosition(
                                target: LatLng(42.6977, 23.3219),
                                zoom: 12,
                              ),
                              gestureRecognizers:
                                  <Factory<OneSequenceGestureRecognizer>>{
                                    Factory<EagerGestureRecognizer>(
                                      () => EagerGestureRecognizer(),
                                    ),
                                  },
                              onMapCreated: (GoogleMapController controller) {
                                _requestMapController = controller;
                                final currentPosition = _currentClientPosition;
                                if (_shouldTrackLocation &&
                                    _isFollowingLocation &&
                                    currentPosition != null &&
                                    !_hasCenteredOnFirstLocation) {
                                  _currentMapZoom = 17;
                                  _hasCenteredOnFirstLocation = true;
                                  unawaited(
                                    _animateCameraToPosition(
                                      currentPosition,
                                      zoom: 17,
                                    ),
                                  );
                                }
                              },
                              onCameraMoveStarted: _onCameraMoveStarted,
                              onCameraMove: _onCameraMove,
                              onCameraIdle: _onCameraIdle,
                              mapType: MapType.normal,
                              myLocationEnabled: locationLayerEnabled,
                              myLocationButtonEnabled: false,
                              scrollGesturesEnabled: true,
                              zoomGesturesEnabled: true,
                              zoomControlsEnabled: true,
                              compassEnabled: true,
                              mapToolbarEnabled: false,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              tooltip: AppTranslations.myLocation,
                              onPressed: _resumeLocationFollowing,
                              icon: Icon(
                                _isFollowingLocation
                                    ? Icons.my_location
                                    : Icons.location_searching,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              TapRegion(
                onTapOutside: (_) {
                  if (pickupSuggestions.isNotEmpty ||
                      isLoadingPickupSuggestions) {
                    setState(() {
                      pickupSuggestions = [];
                      isLoadingPickupSuggestions = false;
                    });
                  }

                  FocusScope.of(context).unfocus();
                },
                child: Column(
                  children: [
                    MenuAnchor(
                      controller: _pickupMenuController,
                      alignmentOffset: const Offset(0, 4),
                      menuChildren: [
                        MenuItemButton(
                          leadingIcon: Icon(
                            Icons.my_location,
                            color: AppColors.primary,
                          ),
                          onPressed: () async {
                            FocusScope.of(context).unfocus();
                            await _useCurrentLocation();
                          },
                          child: Text(AppTranslations.myLocation),
                        ),

                        MenuItemButton(
                          leadingIcon: Icon(
                            Icons.edit_location_alt_outlined,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _isManualPickupEntry = true;

                              pickupController.clear();

                              selectedPickupPlaceId = null;
                              selectedPickupLatitude = null;
                              selectedPickupLongitude = null;

                              pickupSuggestions = [];
                              isLoadingPickupSuggestions = false;
                            });

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _pickupFocusNode.requestFocus();
                              }
                            });
                          },
                          child: const Text('Въведи адрес'),
                        ),

                        if (_favoritePlaces.isNotEmpty) const Divider(),

                        ..._favoritePlaces.map((favorite) {
                          return MenuItemButton(
                            leadingIcon: Icon(
                              Icons.star,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              _selectFavoriteAsPickup(favorite);
                            },
                            child: SizedBox(
                              width: 240,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    favorite.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    favorite.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                      child: TextField(
                        controller: pickupController,
                        focusNode: _pickupFocusNode,
                        readOnly: !_isManualPickupEntry,
                        onTap: () {
                          if (!_isManualPickupEntry) {
                            _openPickupMenu();
                          }
                        },
                        onChanged: _onPickupChanged,
                        decoration: InputDecoration(
                          labelText: AppTranslations.pickupLocation,
                          hintText: _isManualPickupEntry
                              ? 'Въведете начален адрес'
                              : 'Изберете начална точка',
                          prefixIcon: const Icon(Icons.location_on),
                          suffixIcon: IconButton(
                            tooltip: 'Избери начална точка',
                            icon: const Icon(Icons.arrow_drop_down),
                            onPressed: _openPickupMenu,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),

                    if (isLoadingPickupSuggestions)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(AppTranslations.processing),
                      ),

                    if (pickupSuggestions.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: pickupSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = pickupSuggestions[index];

                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(
                                suggestion.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                setState(() {
                                  pickupController.text = suggestion.text;
                                  selectedPickupPlaceId = suggestion.placeId;
                                  selectedPickupLatitude = null;
                                  selectedPickupLongitude = null;
                                  pickupSuggestions = [];
                                  isLoadingPickupSuggestions = false;
                                });

                                FocusScope.of(context).unfocus();
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              TapRegion(
                onTapOutside: (_) {
                  if (destinationSuggestions.isNotEmpty ||
                      isLoadingDestinationSuggestions) {
                    setState(() {
                      destinationSuggestions = [];
                      isLoadingDestinationSuggestions = false;
                    });

                    FocusScope.of(context).unfocus();
                  }
                },
                child: Column(
                  children: [
                    TextField(
                      controller: destinationController,
                      onChanged: _onDestinationChanged,
                      decoration: InputDecoration(
                        labelText: AppTranslations.destinationLocation,
                        prefixIcon: const Icon(Icons.flag),
                        suffixIcon: IconButton(
                          tooltip: 'Ð›ÑŽÐ±Ð¸Ð¼Ð¸ Ð°Ð´Ñ€ÐµÑÐ¸',
                          icon: const Icon(Icons.star_outline),
                          onPressed: _showDestinationFavorites,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    if (isLoadingDestinationSuggestions)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(AppTranslations.processing),
                      ),

                    if (destinationSuggestions.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: destinationSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = destinationSuggestions[index];

                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(
                                suggestion.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                setState(() {
                                  destinationController.text = suggestion.text;
                                  selectedDestinationPlaceId =
                                      suggestion.placeId;
                                  destinationSuggestions = [];
                                  isLoadingDestinationSuggestions = false;
                                });

                                FocusScope.of(context).unfocus();
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Text(
                AppTranslations.passengers,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (passengers > 1) {
                        setState(() {
                          passengers--;
                        });
                      }
                    },
                    icon: const Icon(Icons.remove_circle),
                  ),

                  Text('$passengers', style: const TextStyle(fontSize: 24)),

                  IconButton(
                    onPressed: () {
                      if (passengers < 6) {
                        setState(() {
                          passengers++;
                        });
                      }
                    },
                    icon: const Icon(Icons.add_circle),
                  ),
                ],
              ),

              Text(
                AppTranslations.rideType,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              RadioListTile<RideType>(
                title: Text(AppTranslations.cityRide),
                value: RideType.city,
                groupValue: rideType,
                onChanged: (RideType? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    rideType = value;
                  });
                },
              ),

              RadioListTile<RideType>(
                title: Text(AppTranslations.intercityRide),
                value: RideType.intercity,
                groupValue: rideType,
                onChanged: (RideType? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    rideType = value;
                  });
                },
              ),

              const SizedBox(height: 20),
              const SizedBox(height: 20),

              Text(
                AppTranslations.luggage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SwitchListTile(
                title: Text(
                  hasLuggage
                      ? AppTranslations.luggageYes
                      : AppTranslations.luggageNo,
                ),
                value: hasLuggage,
                onChanged: (bool value) {
                  setState(() {
                    hasLuggage = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              Text(
                AppTranslations.payment,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              RadioListTile<RidePaymentMethod>(
                title: Text(AppTranslations.cash),
                value: RidePaymentMethod.cash,
                groupValue: paymentMethod,
                onChanged: (RidePaymentMethod? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    paymentMethod = value;
                  });
                },
              ),

              RadioListTile<RidePaymentMethod>(
                title: Text(AppTranslations.card),
                value: RidePaymentMethod.card,
                groupValue: paymentMethod,
                onChanged: (RidePaymentMethod? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    paymentMethod = value;
                  });
                },
              ),

              RadioListTile<RidePaymentMethod>(
                title: Text(AppTranslations.voucher),
                value: RidePaymentMethod.voucher,
                groupValue: paymentMethod,
                onChanged: (RidePaymentMethod? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    paymentMethod = value;
                  });
                },
              ),

              const SizedBox(height: 20),

              Text(
                AppTranslations.estimatedPrice,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: City6PrimaryButton(
            text: AppTranslations.placeOrder,
            onPressed: isCalculatingRoute ? null : submitRide,
          ),
        ),
      ),
    );
  }
}
