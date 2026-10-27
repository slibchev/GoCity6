/// Authoritative pickup-area result returned by City6 Backend.
///
/// Passenger App stores and presents this value; it never calculates districts.
final class RidePickupDistrict {
  const RidePickupDistrict({
    this.status,
    this.objectId,
    this.name,
    this.resolution,
    this.candidateObjectIds = const [],
  });

  final String? status;
  final int? objectId;
  final String? name;
  final String? resolution;
  final List<int> candidateObjectIds;

  static RidePickupDistrict? fromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Backend pickupDistrict must be an object.');
    }

    final status = _optionalString(value['status'], 'status');
    final objectId = _optionalInt(value['objectId'], 'objectId');
    final name = _optionalString(value['name'], 'name');
    final resolution = _optionalString(value['resolution'], 'resolution');
    final candidateValues = value['candidateObjectIds'];
    final candidates = <int>[];

    if (candidateValues != null) {
      if (candidateValues is! List<dynamic>) {
        throw const FormatException(
          'Backend pickupDistrict candidateObjectIds must be a list.',
        );
      }
      for (final candidate in candidateValues) {
        final parsed = _optionalInt(candidate, 'candidateObjectIds item');
        if (parsed == null) {
          throw const FormatException(
            'Backend pickupDistrict candidateObjectIds contains null.',
          );
        }
        candidates.add(parsed);
      }
    }

    return RidePickupDistrict(
      status: status,
      objectId: objectId,
      name: name,
      resolution: resolution,
      candidateObjectIds: List.unmodifiable(candidates),
    );
  }

  Map<String, Object?> toJson() => {
    'status': status,
    'objectId': objectId,
    'name': name,
    'resolution': resolution,
    'candidateObjectIds': candidateObjectIds,
  };

  static String? _optionalString(Object? value, String field) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('Backend pickupDistrict $field must be a string.');
    }
    return value;
  }

  static int? _optionalInt(Object? value, String field) {
    if (value == null) {
      return null;
    }
    if (value is! num || !value.isFinite || value.toInt() != value) {
      throw FormatException(
        'Backend pickupDistrict $field must be an integer.',
      );
    }
    return value.toInt();
  }
}
