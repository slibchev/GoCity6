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
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  bool _isManualPickupEntry = false;
  RidePaymentMethod paymentMethod = RidePaymentMethod.cash;
  RideType rideType = RideType.city;
  bool isCalculatingRoute = false;

  final TextEditingController pickupController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final MenuController _pickupMenuController = MenuController();
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

  LatLng? _currentClientPosition;

  bool _locationPermissionGranted = false;
  Timer? _pickupDebounce;
  Timer? _destinationDebounce;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentLocationForMap();
    });
  }

  Future<void> _loadCurrentLocationForMap() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      if (!mounted) {
        return;
      }

      final currentPosition = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentClientPosition = currentPosition;
        _locationPermissionGranted = true;
      });

      final controller = _requestMapController;

      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentPosition, zoom: 17),
          ),
        );
      }
    } catch (_) {
      // Не блокираме екрана, ако текущата позиция
      // временно не може да бъде заредена.
    }
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
      final currentPosition = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentClientPosition = currentPosition;
        _locationPermissionGranted = true;
        _isManualPickupEntry = false;

        _setPickupToCurrentLocation(currentPosition);
      });
      final controller = _requestMapController;

      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentPosition, zoom: 17),
          ),
        );
      }

      FocusScope.of(context).unfocus();
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
    _pickupFocusNode.dispose();

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
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(42.6977, 23.3219),
                      zoom: 12,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _requestMapController = controller;

                      if (_currentClientPosition != null) {
                        controller.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: _currentClientPosition!,
                              zoom: 17,
                            ),
                          ),
                        );
                      }
                    },
                    mapType: MapType.normal,
                    myLocationEnabled: _locationPermissionGranted,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    compassEnabled: true,
                    mapToolbarEnabled: false,
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
                          child: const Text(
                            '\u0412\u044a\u0432\u0435\u0434\u0438 \u0430\u0434\u0440\u0435\u0441',
                          ),
                        ),
                      ],
                      child: TextField(
                        controller: pickupController,
                        focusNode: _pickupFocusNode,
                        readOnly: !_isManualPickupEntry,
                        onTap: () {
                          if (!_isManualPickupEntry &&
                              !_pickupMenuController.isOpen) {
                            _pickupMenuController.open();
                          }
                        },
                        onChanged: _onPickupChanged,
                        decoration: InputDecoration(
                          labelText: AppTranslations.pickupLocation,
                          hintText: _isManualPickupEntry
                              ? '\u0412\u044a\u0432\u0435\u0434\u0435\u0442\u0435 \u043d\u0430\u0447\u0430\u043b\u0435\u043d \u0430\u0434\u0440\u0435\u0441'
                              : '\u0418\u0437\u0431\u0435\u0440\u0435\u0442\u0435 \u043d\u0430\u0447\u0430\u043b\u043d\u0430 \u0442\u043e\u0447\u043a\u0430',
                          prefixIcon: const Icon(Icons.location_on),
                          suffixIcon: IconButton(
                            tooltip:
                                '\u0418\u0437\u0431\u0435\u0440\u0438 \u043d\u0430\u0447\u0430\u043b\u043d\u0430 \u0442\u043e\u0447\u043a\u0430',
                            icon: const Icon(Icons.arrow_drop_down),
                            onPressed: () {
                              FocusScope.of(context).unfocus();

                              if (_pickupMenuController.isOpen) {
                                _pickupMenuController.close();
                              } else {
                                _pickupMenuController.open();
                              }
                            },
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
