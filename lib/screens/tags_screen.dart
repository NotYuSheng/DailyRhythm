import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      body: Center(
        child: Text(
          'Tag management coming soon',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.rhythmMediumGray,
              ),
        ),
      ),
    );
  }
}
