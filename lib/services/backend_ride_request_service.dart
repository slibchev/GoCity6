import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/ride_request_data.dart';
import '../models/ride_request_status.dart';
import 'ride_request_service.dart';
import 'ride_bonus_decision_service.dart';
import '../models/driver_info.dart';

class _RideStatusHttpException extends StateError {
  _RideStatusHttpException(this.statusCode)
    : super('Ride status request failed with status $statusCode.');

  final int statusCode;
}

class BackendRideRequestService
    implements RideRequestService, RideBonusDecisionService {
  final String? baseUrl;
  final http.Client client;
  final Duration pollInterval;
  final Duration statusTimeout;
  final Duration retryBaseInterval;
  final Duration maxRetryInterval;
  final Future<void> Function(Duration duration) _pollDelay;
  final Duration submitTimeout;

  BackendRideRequestService({
    this.baseUrl,
    http.Client? client,
    this.pollInterval = const Duration(seconds: 3),
    this.statusTimeout = const Duration(seconds: 10),
    this.retryBaseInterval = const Duration(seconds: 3),
    this.maxRetryInterval = const Duration(seconds: 30),
    Future<void> Function(Duration duration)? pollDelay,
    this.submitTimeout = const Duration(seconds: 25),
  }) : client = client ?? http.Client(),
       _pollDelay = pollDelay ?? _defaultPollDelay;

  static Future<void> _defaultPollDelay(Duration duration) {
    return Future<void>.delayed(duration);
  }

  String get _baseUrl => baseUrl ?? BackendConfig.baseUrl;

  @override
  Future<RideRequestData> submitRequest(RideRequestData request) async {
    final response = await client
        .post(
          Uri.parse('$_baseUrl/rides'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'pickup': request.pickup,
            'destination': request.destination,
            'passengers': request.passengers,
            'hasLuggage': request.hasLuggage,
            if (request.clientRequestId != null)
              'clientRequestId': request.clientRequestId,
          }),
        )
        .timeout(submitTimeout);

    if (response.statusCode != 201) {
      throw StateError(
        'Ride creation failed with status ${response.statusCode}.',
      );
    }

    return _mergeBackendRide(request, _decodeRide(response.bodyBytes));
  }

  @override
  Future<RideRequestData> acceptBonus(RideRequestData request) {
    return _decideBonus(request, accept: true);
  }

  @override
  Future<RideRequestData> declineBonus(RideRequestData request) {
    return _decideBonus(request, accept: false);
  }

  Future<RideRequestData> _decideBonus(
    RideRequestData request, {
    required bool accept,
  }) async {
    final requestId = _requireRequestId(request);
    final action = accept ? 'accept' : 'decline';
    final expectedDecision = accept
        ? RideBonusDecision.accepted
        : RideBonusDecision.declined;

    http.Response? response;

    try {
      response = await client
          .post(
            Uri.parse('$_baseUrl/rides/$requestId/bonus/$action'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          )
          .timeout(submitTimeout);
    } on TimeoutException {
      // The backend may already have processed the decision.
    } on http.ClientException {
      // Check the authoritative backend state before reporting failure.
    }

    if (response?.statusCode == 200) {
      return _mergeBackendRide(request, _decodeRide(response!.bodyBytes));
    }

    // A 409, timeout, or server error can happen after the
    // backend has already committed the decision.
    final refreshed = await getRequestStatus(request).timeout(submitTimeout);

    if (refreshed.bonusDecision == expectedDecision) {
      return refreshed;
    }

    throw StateError('Bonus decision was not confirmed: $action');
  }

  @override
  Future<RideRequestData> getRequestStatus(RideRequestData request) async {
    final requestId = _requireRequestId(request);

    final uri = Uri.parse('$_baseUrl/rides/$requestId');
    final abortCompleter = Completer<void>();
    final statusRequest = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: abortCompleter.future,
    )..headers['Accept'] = 'application/json';

    late final http.Response response;

    try {
      response = await client
          .send(statusRequest)
          .then(http.Response.fromStream)
          .timeout(statusTimeout);
    } on TimeoutException {
      if (!abortCompleter.isCompleted) {
        abortCompleter.complete();
      }
      rethrow;
    } finally {
      // AbortableRequest is supported by the app's default IOClient. Custom
      // Client implementations may ignore abortTrigger, as allowed by
      // package:http; the timeout still bounds this method's wait in that case.
      if (!abortCompleter.isCompleted) {
        abortCompleter.complete();
      }
    }

    if (response.statusCode != 200) {
      throw _RideStatusHttpException(response.statusCode);
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
    var delayBeforeNextPoll = pollInterval;
    var retryDelay = retryBaseInterval;

    yield currentRequest;

    while (!_isTerminal(currentRequest.status)) {
      await _pollDelay(delayBeforeNextPoll);

      try {
        currentRequest = await getRequestStatus(currentRequest);
        delayBeforeNextPoll = pollInterval;
        retryDelay = retryBaseInterval;

        yield currentRequest;
      } catch (error, stackTrace) {
        if (!_isRetryableStatusError(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }

        delayBeforeNextPoll = retryDelay;
        retryDelay = _nextRetryDelay(retryDelay);
      }
    }
  }

  bool _isRetryableStatusError(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return true;
    }

    if (error is _RideStatusHttpException) {
      return error.statusCode == 408 ||
          error.statusCode == 429 ||
          error.statusCode >= 500;
    }

    return false;
  }

  Duration _nextRetryDelay(Duration currentDelay) {
    if (currentDelay >= maxRetryInterval) {
      return maxRetryInterval;
    }

    final doubledMicroseconds = currentDelay.inMicroseconds * 2;
    if (doubledMicroseconds >= maxRetryInterval.inMicroseconds) {
      return maxRetryInterval;
    }

    return Duration(microseconds: doubledMicroseconds);
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
    final parsedBonusDecision = switch (ride['bonusDecision']) {
      null || 'not_offered' => RideBonusDecision.notOffered,
      'awaiting_customer' => RideBonusDecision.awaitingCustomer,
      'accepted' => RideBonusDecision.accepted,
      'declined' => RideBonusDecision.declined,
      _ => throw const FormatException('Invalid backend bonus decision.'),
    };

    final bonusAmount = ride['driverBonusMinor'];
    if (bonusAmount != null && (bonusAmount is! int || bonusAmount < 0)) {
      throw const FormatException('Invalid backend bonus amount.');
    }

    final meterFareMinor = ride['meterFareMinor'];
    if (meterFareMinor != null &&
        (meterFareMinor is! int || meterFareMinor < 0)) {
      throw const FormatException('Invalid backend meter fare amount.');
    }

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
      bonusDecision: parsedBonusDecision,
      driverBonusMinor: (bonusAmount ?? 0) as int,
      pickup: pickup,
      destination: destination,
      passengers: passengers,
      hasLuggage: hasLuggage,
      requestedAt: parsedRequestedAt.toLocal(),
      status: parsedStatus,
      meterFareMinor: meterFareMinor as int?,
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
