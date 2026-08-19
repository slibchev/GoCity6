import 'ride_segment.dart';

enum RidePaymentMethod {
  cash,
  card,
  voucher,
}

enum RideType {
  city,
  intercity,
}

class Ride {
  final String pickup;
  final String destination;

  final int passengers;

  final RidePaymentMethod paymentMethod;
  final RideType rideType;

  final DateTime startTime;
  final DateTime? endTime;

  final List<RideSegment> segments;

  final double price;

  const Ride({
    required this.pickup,
    required this.destination,
    required this.passengers,
    required this.paymentMethod,
    required this.rideType,
    required this.startTime,
    this.endTime,
    required this.segments,
    required this.price,
  });
}