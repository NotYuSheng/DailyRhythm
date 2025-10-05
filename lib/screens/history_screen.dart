import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: Center(
        child: Text(
          'History coming soon',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.rhythmMediumGray,
              ),
        ),
      ),
    );
  }
}
