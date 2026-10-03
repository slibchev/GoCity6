import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../localization/translations.dart';
import '../models/ride_request_data.dart';
import '../models/ride_request_status.dart';
import '../services/active_ride_store.dart';
import '../services/backend_ride_request_service.dart';
import '../services/ride_request_service.dart';
import '../widgets/city6_primary_button.dart';
import 'main_navigation_screen.dart';
import 'ride_confirmation_screen.dart';

class City6IntroScreen extends StatefulWidget {
  final String backgroundAsset;
  final String logoAsset;
  final ActiveRideStore? activeRideStore;
  final RideRequestService? rideRequestService;
  final bool skipIntroAnimation;

  const City6IntroScreen({
    super.key,
    required this.backgroundAsset,
    required this.logoAsset,
    this.activeRideStore,
    this.rideRequestService,
    this.skipIntroAnimation = false,
  });

  @override
  State<City6IntroScreen> createState() => _City6IntroScreenState();
}

class _City6IntroScreenState extends State<City6IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final RideRequestService _rideRequestService;

  bool _hasStarted = false;
  bool _introFinished = false;
  bool _isCheckingRide = true;
  bool _isOpeningOrder = false;
  bool _isCancelling = false;

  RideRequestData? _recoverableRide;

  static const int _columns = 7;
  static const int _rows = 12;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );

    _rideRequestService =
        widget.rideRequestService ?? BackendRideRequestService();
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
    if (widget.skipIntroAnimation) {
      setState(() {
        _introFinished = true;
      });

      final recoverableRide = await _loadRecoverableRide();

      if (!mounted) {
        return;
      }

      setState(() {
        _recoverableRide = recoverableRide;
        _isCheckingRide = false;
      });

      return;
    }
    final backgroundPrecache = precacheImage(
      AssetImage(widget.backgroundAsset),
      context,
    );

    final logoPrecache = precacheImage(AssetImage(widget.logoAsset), context);

    await Future.wait([backgroundPrecache, logoPrecache]);

    if (!mounted) {
      return;
    }

    await _controller.forward();

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) {
      return;
    }

    setState(() {
      _introFinished = true;
    });

    final recoverableRide = await _loadRecoverableRide();

    if (!mounted) {
      return;
    }

    setState(() {
      _recoverableRide = recoverableRide;
      _isCheckingRide = false;
    });
  }

  bool _isRecoverableStatus(RideRequestStatus status) {
    return status == RideRequestStatus.accepted ||
        status == RideRequestStatus.driverArriving ||
        status == RideRequestStatus.inProgress;
  }

  bool _isTerminalStatus(RideRequestStatus status) {
    return status == RideRequestStatus.completed ||
        status == RideRequestStatus.cancelled;
  }

  Future<void> _clearStoreSafely() async {
    final store = widget.activeRideStore;

    if (store == null) {
      return;
    }

    try {
      await store.clear();
    } catch (_) {
      // Local cleanup must not break the intro screen.
    }
  }

  Future<void> _saveStoreSafely(RideRequestData request) async {
    final store = widget.activeRideStore;

    if (store == null) {
      return;
    }

    try {
      await store.save(request);
    } catch (_) {
      // Backend state remains authoritative.
    }
  }

  Future<RideRequestData?> _loadRecoverableRide() async {
    final store = widget.activeRideStore;

    if (store == null) {
      return null;
    }

    final storedRequest = store.load();

    if (storedRequest == null) {
      return null;
    }

    if (_isTerminalStatus(storedRequest.status)) {
      await _clearStoreSafely();
      return null;
    }

    final requestId = storedRequest.requestId;

    if (requestId == null || requestId.trim().isEmpty) {
      await _clearStoreSafely();
      return null;
    }

    RideRequestData currentRequest;

    try {
      currentRequest = await _rideRequestService.getRequestStatus(
        storedRequest,
      );

      if (_isTerminalStatus(currentRequest.status)) {
        await _clearStoreSafely();
        return null;
      }

      await _saveStoreSafely(currentRequest);
    } catch (_) {
      currentRequest = storedRequest;
    }

    if (_isRecoverableStatus(currentRequest.status)) {
      return currentRequest;
    }

    return null;
  }

  Future<bool> _prepareForNewOrder() async {
    final store = widget.activeRideStore;

    if (store == null) {
      return true;
    }

    final storedRequest = store.load();

    if (storedRequest == null) {
      return true;
    }

    if (_isTerminalStatus(storedRequest.status)) {
      await _clearStoreSafely();
      return true;
    }

    final requestId = storedRequest.requestId;

    if (requestId == null || requestId.trim().isEmpty) {
      await _clearStoreSafely();
      return true;
    }

    RideRequestData refreshedRequest;

    try {
      refreshedRequest = await _rideRequestService.getRequestStatus(
        storedRequest,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.previousRideCheckFailed)),
        );
      }

      return false;
    }

    if (_isTerminalStatus(refreshedRequest.status)) {
      await _clearStoreSafely();
      return true;
    }

    await _saveStoreSafely(refreshedRequest);

    if (_isRecoverableStatus(refreshedRequest.status)) {
      if (mounted) {
        setState(() {
          _recoverableRide = refreshedRequest;
        });
      }

      return false;
    }

    if (!refreshedRequest.status.canBeCancelled) {
      return false;
    }

    try {
      final cancelledRequest = await _rideRequestService.cancelRequest(
        refreshedRequest,
      );

      if (cancelledRequest.status != RideRequestStatus.cancelled) {
        return false;
      }

      await _clearStoreSafely();

      return true;
    } catch (_) {
      final recoverableRide = await _loadRecoverableRide();

      if (mounted) {
        setState(() {
          _recoverableRide = recoverableRide;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.previousRideCheckFailed)),
        );
      }

      return false;
    }
  }

  Future<void> _openOrderFlow() async {
    if (_isOpeningOrder) {
      return;
    }

    setState(() {
      _isOpeningOrder = true;
    });

    final canOpen = await _prepareForNewOrder();

    if (!mounted) {
      return;
    }

    if (!canOpen) {
      setState(() {
        _isOpeningOrder = false;
      });

      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return MainNavigationScreen(
            activeRideStore: widget.activeRideStore,
            rideRequestService: _rideRequestService,
            restoreActiveRide: false,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    final recoverableRide = await _loadRecoverableRide();

    if (!mounted) {
      return;
    }

    setState(() {
      _recoverableRide = recoverableRide;
      _isOpeningOrder = false;
    });
  }

  Future<void> _openRecoverableRide() async {
    final ride = _recoverableRide;

    if (ride == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return RideConfirmationScreen(
            request: ride,
            rideRequestService: _rideRequestService,
            activeRideStore: widget.activeRideStore,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    final recoverableRide = await _loadRecoverableRide();

    if (!mounted) {
      return;
    }

    setState(() {
      _recoverableRide = recoverableRide;
    });
  }

  Future<bool> _confirmRideCancellation() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppTranslations.cancelRideConfirmationTitle),
          content: Text(AppTranslations.cancelRideConfirmationMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(AppTranslations.keepRide),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(AppTranslations.cancelRide),
            ),
          ],
        );
      },
    );

    return shouldCancel ?? false;
  }

  Future<void> _cancelRecoverableRide() async {
    final ride = _recoverableRide;

    if (ride == null || !ride.status.canBeCancelled || _isCancelling) {
      return;
    }

    final confirmed = await _confirmRideCancellation();

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      final cancelledRide = await _rideRequestService.cancelRequest(ride);

      if (!mounted) {
        return;
      }

      if (cancelledRide.status == RideRequestStatus.cancelled) {
        await _clearStoreSafely();

        if (!mounted) {
          return;
        }

        setState(() {
          _recoverableRide = null;
          _isCancelling = false;
        });

        return;
      }

      setState(() {
        _recoverableRide = _isRecoverableStatus(cancelledRide.status)
            ? cancelledRide
            : null;
        _isCancelling = false;
      });
    } catch (_) {
      final recoverableRide = await _loadRecoverableRide();

      if (!mounted) {
        return;
      }

      setState(() {
        _recoverableRide = recoverableRide;
        _isCancelling = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppTranslations.cancelRideFailed)));
    }
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  double _tileProgress({required int index, required double animationValue}) {
    const totalTiles = _columns * _rows;

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

  Widget _buildActions() {
    if (!_introFinished) {
      return const SizedBox.shrink();
    }

    if (_isCheckingRide) {
      return const Center(child: CircularProgressIndicator());
    }

    final recoverableRide = _recoverableRide;

    if (recoverableRide == null) {
      return City6PrimaryButton(
        text: _isOpeningOrder
            ? AppTranslations.processing
            : AppTranslations.orderTaxi,
        onPressed: _isOpeningOrder ? null : _openOrderFlow,
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppTranslations.activeRideNotice,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          City6PrimaryButton(
            text: AppTranslations.returnToActiveRide,
            onPressed: _openRecoverableRide,
          ),
          if (recoverableRide.status.canBeCancelled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _cancelRecoverableRide,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  _isCancelling
                      ? AppTranslations.processing
                      : AppTranslations.cancelActiveRide,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
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
                          Colors.black.withValues(alpha: 0.52),
                        ],
                      ),
                    ),
                  ),
                  _buildMosaic(size, value),
                  Align(
                    alignment: const Alignment(0, 0.18),
                    child: _buildLogo(value),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                        child: _buildActions(),
                      ),
                    ),
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
