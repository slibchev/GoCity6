import 'dart:async';

import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../models/ride_request_data.dart';
import '../models/ride_request_status.dart';
import '../services/active_ride_store.dart';
import '../services/backend_ride_request_service.dart';
import '../services/backend_route_service.dart';
import '../services/ride_request_service.dart';
import 'favorites_screen.dart';
import 'ride_confirmation_screen.dart';
import 'ride_request_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final ActiveRideStore? activeRideStore;
  final RideRequestService? rideRequestService;

  const MainNavigationScreen({
    super.key,
    this.activeRideStore,
    this.rideRequestService,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final RideRequestService _rideRequestService;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _rideRequestService =
        widget.rideRequestService ?? BackendRideRequestService();

    _screens = [
      RideRequestScreen(
        routeService: const BackendRouteService(),
        rideRequestService: _rideRequestService,
        activeRideStore: widget.activeRideStore,
      ),
      const FavoritesScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreActiveRide());
    });
  }

  Future<void> _restoreActiveRide() async {
    final store = widget.activeRideStore;

    if (store == null) {
      return;
    }

    final storedRequest = store.load();

    if (storedRequest == null) {
      return;
    }

    if (_isTerminal(storedRequest.status)) {
      await _clearStoreSafely(store);
      return;
    }

    final requestId = storedRequest.requestId;

    if (requestId == null || requestId.trim().isEmpty) {
      await _clearStoreSafely(store);
      return;
    }

    RideRequestData requestToRestore;

    try {
      final refreshedRequest = await _rideRequestService.getRequestStatus(
        storedRequest,
      );

      if (_isTerminal(refreshedRequest.status)) {
        await _clearStoreSafely(store);
        return;
      }

      requestToRestore = refreshedRequest;

      try {
        await store.save(refreshedRequest);
      } catch (_) {
        // A persistence failure must not hide an active backend ride.
      }
    } catch (_) {
      // Keep the last known active ride visible when the backend is
      // temporarily unavailable. The confirmation screen will keep the
      // stored state and can resume status polling.
      requestToRestore = storedRequest;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RideConfirmationScreen(
          request: requestToRestore,
          rideRequestService: _rideRequestService,
          activeRideStore: store,
        ),
      ),
    );
  }

  Future<void> _clearStoreSafely(ActiveRideStore store) async {
    try {
      await store.clear();
    } catch (_) {
      // A local cleanup failure must not interrupt app startup.
    }
  }

  bool _isTerminal(RideRequestStatus status) {
    return status == RideRequestStatus.completed ||
        status == RideRequestStatus.cancelled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_taxi_outlined),
            activeIcon: Icon(Icons.local_taxi),
            label: 'Поръчай',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border),
            activeIcon: Icon(Icons.star),
            label: 'Любими',
          ),
        ],
      ),
    );
  }
}
