import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../widgets/city6_app_bar_title.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
          '\u0418\u0441\u0442\u043e\u0440\u0438\u044f',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}