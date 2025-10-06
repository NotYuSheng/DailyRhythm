import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/meal_entry.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';

class AddMealScreen extends ConsumerStatefulWidget {
  final MealEntry? entry;

  const AddMealScreen({super.key, this.entry});

  @override
  ConsumerState<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends ConsumerState<AddMealScreen> {
  late DateTime _date;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<String> _selectedTags = [];

  // Available meal tags
  final List<String> _availableTags = [
    'Home Cooked',
    'Fast Food',
    'Restaurant',
    'Takeout',
    'Delivery',
    'Food Court',
    'Free',
    'Cafe',
    'Meal Prep',
    'Special Occasion',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = widget.entry?.date ?? DateTime(now.year, now.month, now.day);
    _nameController.text = widget.entry?.name ?? '';
    _quantityController.text = widget.entry?.quantity.toString() ?? '1';
    _priceController.text = widget.entry?.price.toString() ?? '';
    _caloriesController.text = widget.entry?.calories?.toString() ?? '';
    _notesController.text = widget.entry?.notes ?? '';
    if (widget.entry != null) {
      _selectedTags.addAll(widget.entry!.tags);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _caloriesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Add Meal' : 'Edit Meal'),
        actions: [
          if (widget.entry != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
          TextButton(
            onPressed: _saveMeal,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacePulse3),
        children: [
          // Meal Name (Full Width)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Meal Name',
                  hintText: 'What did you eat?',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Quantity and Price (Side by Side)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity (Smaller)
              Expanded(
                flex: 1,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacePulse3),
                    child: TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        hintText: '1',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacePulse3),
              // Price (Larger)
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacePulse3),
                    child: TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        hintText: 'Enter amount',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Calories (Optional)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: TextField(
                controller: _caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Calories (Optional)',
                  hintText: 'Enter calories',
                  border: OutlineInputBorder(),
                  suffixText: 'cal',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Tags
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tags',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacePulse2),
                  Wrap(
                    spacing: AppTheme.spacePulse2,
                    runSpacing: AppTheme.spacePulse2,
                    children: _availableTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Any additional details...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMeal() async {
    // Validate inputs
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meal name')),
      );
      return;
    }

    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a price')),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    // Use current time if editing existing entry, otherwise use entry's time
    final time = widget.entry?.time ?? DateTime.now();

    // Parse quantity (default to 1)
    int quantity = 1;
    if (_quantityController.text.trim().isNotEmpty) {
      quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    }

    // Parse calories (optional)
    int? calories;
    if (_caloriesController.text.trim().isNotEmpty) {
      calories = int.tryParse(_caloriesController.text.trim());
    }

    final entry = MealEntry(
      id: widget.entry?.id,
      date: _date,
      time: time,
      name: _nameController.text.trim(),
      quantity: quantity,
      price: price,
      calories: calories,
      tags: _selectedTags,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    try {
      final db = ref.read(databaseProvider);

      if (widget.entry == null) {
        await db.createMealEntry(entry);
      } else {
        await db.updateMealEntry(entry);
      }

      // Refresh current day's meal data
      ref.invalidate(todayMealEntriesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal entry saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().split('\n').first}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Meal'),
          content: const Text('Are you sure you want to delete this meal entry?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (widget.entry?.id != null) {
                  final db = ref.read(databaseProvider);
                  await db.deleteMealEntry(widget.entry!.id!);

                  if (mounted) {
                    // Invalidate the provider to refresh the list
                    ref.invalidate(mealEntriesProvider(widget.entry!.date));

                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close edit screen

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Meal deleted'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
