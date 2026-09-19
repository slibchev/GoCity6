import 'package:flutter/material.dart';

class City6AppBarTitle extends StatelessWidget {
  const City6AppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/city6_logo.png',
      height: 34,
      fit: BoxFit.contain,
    );
  }
}