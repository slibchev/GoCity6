import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/ride_request_data.dart';
import '../models/ride_request_status.dart';
import 'ride_request_service.dart';
import '../models/driver_info.dart';

class BackendRideRequestService implements RideRequestService {
  final String? baseUrl;
  final http.Client client;
  final Duration pollInterval;

  BackendRideRequestService({
    this.baseUrl,
    http.Client? client,
    this.pollInterval = const Duration(seconds: 3),
  }) : client = client ?? http.Client();

  String get _baseUrl => baseUrl ?? BackendConfig.baseUrl;

  @override
  Future<RideRequestData> submitRequest(RideRequestData request) async {
    final response = await client.post(
      Uri.parse('$_baseUrl/rides'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'pickup': request.pickup,
        'destination': request.destination,
        'passengers': request.passengers,
        'hasLuggage': request.hasLuggage,
      }),
    );

    if (response.statusCode != 201) {
      throw StateError(
        'Ride creation failed with status ${response.statusCode}.',
      );
    }

    return _mergeBackendRide(request, _decodeRide(response.bodyBytes));
  }

  @override
  Future<RideRequestData> getRequestStatus(RideRequestData request) async {
    final requestId = _requireRequestId(request);

    final response = await client.get(
      Uri.parse('$_baseUrl/rides/$requestId'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw StateError(
        'Ride status request failed with status ${response.statusCode}.',
      );
    }

    return _mergeBackendRide(request, _decodeRide(response.bodyBytes));
  }

  @override
  Future<RideRequestData> cancelRequest(RideRequestData request) async {
    final requestId = _requireRequestId(request);

    final response = await client.post(
      Uri.parse('$_baseUrl/rides/$requestId/cancel'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );

    if (response.statusCode != 200) {
      throw StateError(
        'Ride cancellation failed with status ${response.statusCode}.',
      );
    }

    return _mergeBackendRide(request, _decodeRide(response.bodyBytes));
  }

  @override
  Stream<RideRequestData> watchRequestStatus(RideRequestData request) async* {
    var currentRequest = request;

    yield currentRequest;

    while (!_isTerminal(currentRequest.status)) {
      await Future<void>.delayed(pollInterval);

      currentRequest = await getRequestStatus(currentRequest);

      yield currentRequest;
    }
  }

  String _requireRequestId(RideRequestData request) {
    final requestId = request.requestId;

    if (requestId == null || requestId.trim().isEmpty) {
      throw StateError('Backend ride request id is missing.');
    }

    return requestId;
  }

  Map<String, dynamic> _decodeRide(List<int> bodyBytes) {
    final decoded = jsonDecode(utf8.decode(bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Backend ride response must be a JSON object.',
      );
    }

    return decoded;
  }

  RideRequestData _mergeBackendRide(
    RideRequestData localRequest,
    Map<String, dynamic> ride,
  ) {
    final id = ride['id'];
    final pickup = ride['pickup'];
    final destination = ride['destination'];
    final passengers = ride['passengers'];
    final hasLuggage = ride['hasLuggage'];
    final requestedAt = ride['requestedAt'];
    final status = ride['status'];

    if (id is! String ||
        id.isEmpty ||
        pickup is! String ||
        destination is! String ||
        passengers is! int ||
        hasLuggage is! bool ||
        requestedAt is! String ||
        status is! String) {
      throw const FormatException(
        'Backend ride response is missing required fields.',
      );
    }

    final parsedRequestedAt = DateTime.tryParse(requestedAt);

    if (parsedRequestedAt == null) {
      throw const FormatException('Backend ride requestedAt is invalid.');
    }

    RideRequestStatus parsedStatus;

    try {
      parsedStatus = RideRequestStatus.values.byName(status);
    } on ArgumentError {
      throw FormatException('Unknown backend ride status: $status');
    }

    final assignedDriverId = ride['assignedDriverId'];
    final assignedVehicleId = ride['assignedVehicleId'];
    final completedByDriverId = ride['completedByDriverId'];
    final completedAt = ride['completedAt'];
    final hasDriverInfo = ride.containsKey('driverInfo');
    final parsedDriverInfo = hasDriverInfo
        ? _parseDriverInfo(ride['driverInfo'])
        : null;

    if (assignedDriverId != null && assignedDriverId is! String) {
      throw const FormatException('Backend assignedDriverId is invalid.');
    }

    if (assignedVehicleId != null && assignedVehicleId is! String) {
      throw const FormatException('Backend assignedVehicleId is invalid.');
    }

    if (completedByDriverId != null && completedByDriverId is! String) {
      throw const FormatException('Backend completedByDriverId is invalid.');
    }

    DateTime? parsedCompletedAt;

    if (completedAt != null) {
      if (completedAt is! String) {
        throw const FormatException('Backend completedAt is invalid.');
      }

      parsedCompletedAt = DateTime.tryParse(completedAt);

      if (parsedCompletedAt == null) {
        throw const FormatException('Backend completedAt is invalid.');
      }
    }

    final mergedRequest = localRequest.copyWith(
      requestId: id,
      pickup: pickup,
      destination: destination,
      passengers: passengers,
      hasLuggage: hasLuggage,
      requestedAt: parsedRequestedAt.toLocal(),
      status: parsedStatus,
      assignedDriverId: assignedDriverId,
      assignedVehicleId: assignedVehicleId,
      completedByDriverId: completedByDriverId,
      completedAt: parsedCompletedAt?.toLocal(),
    );

    if (!hasDriverInfo) {
      return mergedRequest;
    }

    return mergedRequest.copyWith(driverInfo: parsedDriverInfo);
  }

  DriverInfo? _parseDriverInfo(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is! Map<String, dynamic>) {
      throw const FormatException('Backend driverInfo is invalid.');
    }

    final name = value['name'];
    final licensePlate = value['licensePlate'];
    final phoneNumber = value['phoneNumber'];

    if (name is! String ||
        name.trim().isEmpty ||
        licensePlate is! String ||
        licensePlate.trim().isEmpty ||
        (phoneNumber != null && phoneNumber is! String)) {
      throw const FormatException('Backend driverInfo is invalid.');
    }

    return DriverInfo(
      name: name,
      licensePlate: licensePlate,
      phoneNumber: phoneNumber as String?,
    );
  }

  bool _isTerminal(RideRequestStatus status) {
    return status == RideRequestStatus.completed ||
        status == RideRequestStatus.cancelled;
  }
}
