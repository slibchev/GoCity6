import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../localization/translations.dart';
import '../models/ride.dart';
import '../models/ride_request_data.dart';
import '../models/route_result.dart';
import 'ride_confirmation_screen.dart';
import '../services/ride_request_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class RideSummaryScreen extends StatefulWidget {
  final String pickup;
  final String destination;
  final int passengers;
  final RidePaymentMethod paymentMethod;
  final RideType rideType;
  final RouteResult? routeResult;
  final RideRequestData request;
  final double? estimatedPrice;
  final RideRequestService? rideRequestService;

  RideSummaryScreen.fromRequest({
    super.key,
    required this.request,
    this.rideRequestService,
  }) : pickup = request.pickup,
       destination = request.destination,
       passengers = request.passengers,
       paymentMethod = request.paymentMethod,
       rideType = request.rideType,
       routeResult = request.routeResult,
       estimatedPrice = request.estimatedPrice;

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen> {
  static const CameraPosition _initialMapPosition = CameraPosition(
    target: LatLng(42.6977, 23.3219),
    zoom: 12,
  );

  Set<Marker> get _routeMarkers {
    final routeResult = widget.routeResult;

    if (routeResult == null) {
      return {};
    }

    final pickupLatitude = routeResult.pickupLatitude;
    final pickupLongitude = routeResult.pickupLongitude;
    final destinationLatitude = routeResult.destinationLatitude;
    final destinationLongitude = routeResult.destinationLongitude;

    if (pickupLatitude == null ||
        pickupLongitude == null ||
        destinationLatitude == null ||
        destinationLongitude == null) {
      return {};
    }

    return {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pickupLatitude, pickupLongitude),
        infoWindow: InfoWindow(title: AppTranslations.pickupLocation),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(destinationLatitude, destinationLongitude),
        infoWindow: InfoWindow(title: AppTranslations.destinationLocation),
      ),
    };
  }

  List<LatLng> _decodePolyline(String encoded) {
    return PolylinePoints.decodePolyline(
      encoded,
    ).map((point) => LatLng(point.latitude, point.longitude)).toList();
  }

  Set<Polyline> get _routePolylines {
    final encodedPolyline = widget.routeResult?.encodedPolyline;

    if (encodedPolyline == null || encodedPolyline.isEmpty) {
      return {};
    }

    final points = _decodePolyline(encodedPolyline);

    if (points.length < 2) {
      return {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        width: 5,
        color: AppColors.route,
      ),
    };
  }

  void _fitRouteOnMap(GoogleMapController controller) {
    final routeResult = widget.routeResult;

    if (routeResult == null) {
      return;
    }

    final pickupLatitude = routeResult.pickupLatitude;
    final pickupLongitude = routeResult.pickupLongitude;
    final destinationLatitude = routeResult.destinationLatitude;
    final destinationLongitude = routeResult.destinationLongitude;

    if (pickupLatitude == null ||
        pickupLongitude == null ||
        destinationLatitude == null ||
        destinationLongitude == null) {
      return;
    }

    final pickup = LatLng(pickupLatitude, pickupLongitude);

    final destination = LatLng(destinationLatitude, destinationLongitude);

    if (pickup == destination) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(pickup, 16));
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(
        pickupLatitude < destinationLatitude
            ? pickupLatitude
            : destinationLatitude,
        pickupLongitude < destinationLongitude
            ? pickupLongitude
            : destinationLongitude,
      ),
      northeast: LatLng(
        pickupLatitude > destinationLatitude
            ? pickupLatitude
            : destinationLatitude,
        pickupLongitude > destinationLongitude
            ? pickupLongitude
            : destinationLongitude,
      ),
    );

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  bool _isSubmitting = false;

  String get pickup => widget.pickup;
  String get destination => widget.destination;
  int get passengers => widget.passengers;
  RidePaymentMethod get paymentMethod => widget.paymentMethod;
  RideType get rideType => widget.rideType;
  RouteResult? get routeResult => widget.routeResult;
  RideRequestData get request => widget.request;
  double? get estimatedPrice => widget.estimatedPrice;
  RideRequestService? get rideRequestService => widget.rideRequestService;

  String getPaymentText() {
    switch (paymentMethod) {
      case RidePaymentMethod.cash:
        return AppTranslations.cash;

      case RidePaymentMethod.card:
        return AppTranslations.card;

      case RidePaymentMethod.voucher:
        return AppTranslations.voucher;
    }
  }

  String getEstimatedArrivalTime() {
    if (routeResult == null) {
      return AppTranslations.calculating;
    }

    final arrivalTime = request.requestedAt.add(
      Duration(minutes: routeResult!.durationMinutes.round()),
    );

    final hour = arrivalTime.hour.toString().padLeft(2, '0');
    final minute = arrivalTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _confirmRide(BuildContext context) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final service = rideRequestService;

    try {
      final submittedRequest = service == null
          ? request
          : await service.submitRequest(request);

      if (!context.mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideConfirmationScreen(
            request: submittedRequest,
            rideRequestService: service,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppTranslations.submitRideFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('City6'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: _initialMapPosition,
                    markers: _routeMarkers,
                    polylines: _routePolylines,
                    onMapCreated: _fitRouteOnMap,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppTranslations.rideSummary,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                '🚐 ${AppTranslations.vehicleInfo}',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              Text(
                '📍 ${AppTranslations.from}: $pickup',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 15),
              Text(
                '📍 ${AppTranslations.to}: $destination',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 15),
              Text(
                '👥 ${AppTranslations.passengersLabel}: $passengers',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 15),
              Text(
                '🚕 ${AppTranslations.rideType}: '
                '${rideType == RideType.city ? AppTranslations.cityRide : AppTranslations.intercityRide}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 15),
              Text(
                '💳 ${AppTranslations.paymentMethod}: ${getPaymentText()}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 15),
              Text(
                '🧳 ${AppTranslations.luggage}: '
                '${request.hasLuggage ? AppTranslations.luggageYes : AppTranslations.luggageNo}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 15),
              if (routeResult != null) ...[
                Text(
                  '🛣️ ${AppTranslations.distance}: '
                  '${routeResult!.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 15),
                Text(
                  '⏱️ ${AppTranslations.estimatedDuration}: '
                  '${routeResult!.durationMinutes.toStringAsFixed(0)} '
                  '${AppTranslations.minutes}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 15),
              ],
              Text(
                '🕒 ${AppTranslations.arrivalTime}: '
                '${getEstimatedArrivalTime()}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 15),
              Text(
                '💰 ${AppTranslations.priceLabel}: '
                '${estimatedPrice == null ? AppTranslations.calculating : '${estimatedPrice!.toStringAsFixed(2)} лв.'}',
                style: const TextStyle(
                  fontSize: 20,
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
          child: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    await _confirmRide(context);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.primary,
            ),
            child: Text(
              _isSubmitting
                  ? AppTranslations.processing
                  : AppTranslations.confirmRide,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
