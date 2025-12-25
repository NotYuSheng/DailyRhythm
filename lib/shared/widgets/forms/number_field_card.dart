import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// A reusable numeric input field wrapped in a Card
/// Specialized for numbers with optional suffix text
class NumberFieldCard extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? suffixText;
  final bool allowDecimals;

  const NumberFieldCard({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.suffixText,
    this.allowDecimals = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            border: const OutlineInputBorder(),
            suffixText: suffixText,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: allowDecimals),
        ),
      ),
    );
  }
}
