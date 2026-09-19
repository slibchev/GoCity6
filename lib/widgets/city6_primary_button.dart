import 'package:flutter/material.dart';

import '../config/colors.dart';

class City6PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;

  const City6PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 55,
  });

  @override
  State<City6PrimaryButton> createState() => _City6PrimaryButtonState();
}

class _City6PrimaryButtonState extends State<City6PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return Listener(
      onPointerDown: (_) {
        if (isDisabled) {
          return;
        }

        setState(() {
          _isPressed = true;
        });
      },
      onPointerUp: (_) {
        if (isDisabled) {
          return;
        }

        setState(() {
          _isPressed = false;
        });
      },
      onPointerCancel: (_) {
        if (isDisabled) {
          return;
        }

        setState(() {
          _isPressed = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        height: widget.height,
        width: double.infinity,
        transform: Matrix4.diagonal3Values(
          _isPressed ? 0.98 : 1.0,
          _isPressed ? 0.92 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: isDisabled
              ? const LinearGradient(
                  colors: [
                    Color(0xFFD7DEE6),
                    Color(0xFFBFC7D1),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7FDBFF),
                    Color(0xFF20C4FF),
                    Color(0xFF2F80FF),
                    Color(0xFFBFC7D1),
                  ],
                  stops: [
                    0.0,
                    0.38,
                    0.78,
                    1.0,
                  ],
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _isPressed ? 0.06 : 0.22,
              ),
              blurRadius: _isPressed ? 1 : 10,
              offset: Offset(
                0,
                _isPressed ? 0 : 5,
              ),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1.2,
          ),
        ),
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: isDisabled
                ? AppColors.textSecondary
                : AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
