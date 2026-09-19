import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../localization/translations.dart';
import '../localization/app_language.dart';
import 'ride_request_screen.dart';
import '../services/backend_route_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOrderButtonPressed = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF183A63)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/city6_logo.png',
                        width: 280,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppTranslations.welcomeTagline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 75),
                      Listener(
                        onPointerDown: (_) {
                          setState(() {
                            _isOrderButtonPressed = true;
                          });
                        },
                        onPointerUp: (_) {
                          setState(() {
                            _isOrderButtonPressed = false;
                          });
                        },
                        onPointerCancel: (_) {
                          setState(() {
                            _isOrderButtonPressed = false;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 90),
                          curve: Curves.easeOut,
                          transform: Matrix4.diagonal3Values(
                            _isOrderButtonPressed ? 0.98 : 1.0,
                            _isOrderButtonPressed ? 0.92 : 1.0,
                            1.0,
                          ),
                          transformAlignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF7FDBFF),
                                Color(0xFF20C4FF),
                                Color(0xFF2F80FF),
                                Color(0xFFBFC7D1),
                              ],
                              stops: [0.0, 0.38, 0.78, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: _isOrderButtonPressed ? 0.06 : 0.22,
                                ),
                                blurRadius: _isOrderButtonPressed ? 1 : 10,
                                offset: Offset(
                                  0,
                                  _isOrderButtonPressed ? 0 : 5,
                                ),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 1.2,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RideRequestScreen(
                                    routeService: const BackendRouteService(),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 55,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              AppTranslations.orderButton,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 15,
                right: 15,
                child: ElevatedButton(
                  onPressed: () async {
                    final newLanguage =
                        AppTranslations.currentLanguage == AppLanguage.bulgarian
                        ? AppLanguage.english
                        : AppLanguage.bulgarian;

                    AppTranslations.currentLanguage = newLanguage;

                    final prefs = await SharedPreferences.getInstance();

                    await prefs.setString(
                      'language',
                      newLanguage == AppLanguage.english
                          ? 'english'
                          : 'bulgarian',
                    );

                    if (!mounted) {
                      return;
                    }

                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    AppTranslations.currentLanguage == AppLanguage.bulgarian
                        ? 'EN'
                        : 'БГ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
