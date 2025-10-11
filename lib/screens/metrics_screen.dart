import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.rhythmWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.rhythmWhite,
        elevation: 0,
        title: const Text(
          'Metrics',
          style: TextStyle(
            color: AppTheme.rhythmBlack,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 80,
                color: AppTheme.rhythmMediumGray,
              ),
              const SizedBox(height: AppTheme.spacePulse3),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.rhythmBlack,
                ),
              ),
              const SizedBox(height: AppTheme.spacePulse2),
              Text(
                'Metrics and analytics features\nare currently in development',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.rhythmMediumGray,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
