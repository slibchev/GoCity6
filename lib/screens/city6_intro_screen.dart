import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/colors.dart';
import 'main_navigation_screen.dart';

class City6IntroScreen extends StatefulWidget {
  final String backgroundAsset;
  final String logoAsset;

  const City6IntroScreen({
    super.key,
    required this.backgroundAsset,
    required this.logoAsset,
  });

  @override
  State<City6IntroScreen> createState() => _City6IntroScreenState();
}

class _City6IntroScreenState extends State<City6IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _hasStarted = false;

  static const int _columns = 7;
  static const int _rows = 12;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_hasStarted) {
      return;
    }

    _hasStarted = true;
    _startIntro();
  }

  Future<void> _startIntro() async {
    await precacheImage(AssetImage(widget.backgroundAsset), context);

    await precacheImage(AssetImage(widget.logoAsset), context);

    if (!mounted) {
      return;
    }

    await _controller.forward();

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const MainNavigationScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  double _tileProgress({required int index, required double animationValue}) {
    const totalTiles = _columns * _rows;

    // Разбъркан, но напълно предвидим ред.
    final order = ((index * 37) % totalTiles) / totalTiles;

    final start = 0.04 + (order * 0.55);
    final end = (start + 0.20).clamp(0.0, 0.82);

    if (animationValue <= start) {
      return 0;
    }

    if (animationValue >= end) {
      return 1;
    }

    final localProgress = (animationValue - start) / (end - start);

    return Curves.easeOutCubic.transform(localProgress);
  }

  Widget _buildMosaic(Size size, double animationValue) {
    final tileWidth = size.width / _columns;
    final tileHeight = size.height / _rows;

    return Stack(
      children: List.generate(_columns * _rows, (index) {
        final column = index % _columns;
        final row = index ~/ _columns;

        final progress = _tileProgress(
          index: index,
          animationValue: animationValue,
        );

        final opacity = 1 - progress;

        final scale = lerpDouble(1.08, 0.82, progress) ?? 1;

        return Positioned(
          left: column * tileWidth,
          top: row * tileHeight,
          width: tileWidth + 1,
          height: tileHeight + 1,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.96),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.035),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLogo(double animationValue) {
    const logoStart = 0.62;
    const logoEnd = 0.98;

    double progress;

    if (animationValue <= logoStart) {
      progress = 0;
    } else if (animationValue >= logoEnd) {
      progress = 1;
    } else {
      progress = (animationValue - logoStart) / (logoEnd - logoStart);

      progress = Curves.easeOutCubic.transform(progress);
    }

    final scale = lerpDouble(0.82, 1.0, progress) ?? 1.0;

    final translateY = lerpDouble(24, 0, progress) ?? 0.0;

    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: scale,
          child: Image.asset(widget.logoAsset, width: 320, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;

          final imageProgress = Curves.easeOutCubic.transform(
            (value / 0.72).clamp(0.0, 1.0),
          );

          final blur = lerpDouble(14, 0, imageProgress) ?? 0;

          final imageScale = lerpDouble(1.10, 1.0, imageProgress) ?? 1;

          return LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Transform.scale(
                    scale: imageScale,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: Image.asset(
                        widget.backgroundAsset,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.42),
                        ],
                      ),
                    ),
                  ),

                  _buildMosaic(size, value),

                  Align(
                    alignment: const Alignment(0, 0.42),
                    child: _buildLogo(value),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
