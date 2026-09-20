import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../services/backend_route_service.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'ride_request_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      RideRequestScreen(
        routeService: const BackendRouteService(),
      ),
      const FavoritesScreen(),
      const HistoryScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
            label:
                '\u041f\u043e\u0440\u044a\u0447\u0430\u0439',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border),
            activeIcon: Icon(Icons.star),
            label:
                '\u041b\u044e\u0431\u0438\u043c\u0438',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label:
                '\u0418\u0441\u0442\u043e\u0440\u0438\u044f',
          ),
        ],
      ),
    );
  }
}