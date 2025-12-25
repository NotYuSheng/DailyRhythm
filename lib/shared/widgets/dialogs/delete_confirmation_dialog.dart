import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Shows a confirmation dialog for delete operations
/// Returns true if user confirmed, false if cancelled
Future<bool> showDeleteConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.rhythmBlack),
            ),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
