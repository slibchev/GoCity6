import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../widgets/city6_app_bar_title.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const City6AppBarTitle(),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '\u041b\u044e\u0431\u0438\u043c\u0438 \u0430\u0434\u0440\u0435\u0441\u0438',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}