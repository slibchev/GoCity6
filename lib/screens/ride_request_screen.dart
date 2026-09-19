import 'dart:async';
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
import '../services/mock_ride_request_service.dart';
import '../services/mock_route_service.dart';
import '../models/place_suggestion.dart';
import '../services/backend_places_service.dart';
import 'package:geolocator/geolocator.dart';

class RideRequestScreen extends StatefulWidget {
  final RouteService? routeService;
  final BackendPlacesService placesService;
  final DateTime Function() now;

  RideRequestScreen({
    super.key,
    RouteService? routeService,
    BackendPlacesService? placesService,
    DateTime Function()? now,
  }) : routeService = routeService ?? MockRouteService(),
       placesService = placesService ?? const BackendPlacesService(),
       now = now ?? DateTime.now;

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  int passengers = 1;
  bool hasLuggage = false;
  RidePaymentMethod paymentMethod = RidePaymentMethod.cash;
  RideType rideType = RideType.city;
  bool isCalculatingRoute = false;

  final TextEditingController pickupController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
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
  Timer? _pickupDebounce;
  Timer? _destinationDebounce;
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

      setState(() {
        selectedPickupPlaceId = null;
        selectedPickupLatitude = position.latitude;
        selectedPickupLongitude = position.longitude;

        pickupController.text = AppTranslations.myLocation;

        pickupSuggestions = [];
        isLoadingPickupSuggestions = false;
      });

      FocusScope.of(context).unfocus();
    } finally {
      if (mounted) {
        setState(() {
          isGettingCurrentLocation = false;
        });
      }
    }
  }

  void _onPickupChanged(String input) {
    selectedPickupPlaceId = null;
    selectedPickupLatitude = null;
    selectedPickupLongitude = null;

    _pickupDebounce?.cancel();

    _pickupDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadPickupSuggestions(input);
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
    if (pickupController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppTranslations.pickupRequired)));
      return;
    }

    if (destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.destinationRequired)),
      );
      return;
    }

    if (widget.routeService == null) {
      final request = RideRequestData(
        pickup: pickupController.text.trim(),
        destination: destinationController.text.trim(),
        passengers: passengers,
        hasLuggage: hasLuggage,
        paymentMethod: paymentMethod,
        rideType: rideType,
        requestedAt: widget.now(),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideSummaryScreen.fromRequest(
            request: request,
            rideRequestService: MockRideRequestService(),
          ),
        ),
      );

      return;
    }

    setState(() {
      isCalculatingRoute = true;
    });

    try {
      final routeResult = await widget.routeService!.calculateRoute(
        pickup: pickupController.text.trim(),
        destination: destinationController.text.trim(),
        pickupPlaceId: selectedPickupPlaceId,
        destinationPlaceId: selectedDestinationPlaceId,
        pickupLatitude: selectedPickupLatitude,
        pickupLongitude: selectedPickupLongitude,
      );

      if (!mounted) {
        return;
      }
      final requestedAt = widget.now();

      final estimatedPrice = PricingCalculator.calculateEstimatedPrice(
        startTime: requestedAt,
        kilometers: routeResult.distanceKm,
        intercity: rideType == RideType.intercity,
      );

      final request = RideRequestData(
        pickup: pickupController.text.trim(),
        destination: destinationController.text.trim(),
        passengers: passengers,
        hasLuggage: hasLuggage,
        paymentMethod: paymentMethod,
        rideType: rideType,
        requestedAt: requestedAt,
        routeResult: routeResult,
        estimatedPrice: estimatedPrice,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideSummaryScreen.fromRequest(
            request: request,
            rideRequestService: MockRideRequestService(),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.routeCalculationFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          isCalculatingRoute = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pickupDebounce?.cancel();
    _destinationDebounce?.cancel();

    pickupController.dispose();
    destinationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              TapRegion(
                onTapOutside: (_) {
                  if (pickupSuggestions.isNotEmpty ||
                      isLoadingPickupSuggestions) {
                    setState(() {
                      pickupSuggestions = [];
                      isLoadingPickupSuggestions = false;
                    });

                    FocusScope.of(context).unfocus();
                  }
                },
                child: Column(
                  children: [
                    TextField(
                      controller: pickupController,
                      onChanged: _onPickupChanged,
                      decoration: InputDecoration(
                        labelText: AppTranslations.pickupLocation,
                        prefixIcon: const Icon(Icons.location_on),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: isGettingCurrentLocation
                            ? null
                            : _useCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          isGettingCurrentLocation
                              ? AppTranslations.processing
                              : AppTranslations.myLocation,
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
            text: AppTranslations.confirmRide,
            onPressed: isCalculatingRoute ? null : submitRide,
          ),
        ),
      ),
    );
  }
}
