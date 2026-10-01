import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Pantalla nativa / boot: logo FoodReto mientras arranca Firebase.
class BootSplash extends StatelessWidget {
  const BootSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/branding/splash_logo.png',
                width: 220,
                height: 220,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.flame,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
