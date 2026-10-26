import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/food_item.dart';
import '../../data/models/meal_entry.dart';
import '../../domain/food_matcher.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/repositories/catalog_repository.dart';
import '../../data/providers/meal_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../../shared/widgets/dialogs/delete_confirmation_dialog.dart';

class AddMealScreen extends ConsumerStatefulWidget {
  final MealEntry? entry; // For editing existing entries
  final DateTime? date; // Day to log a new meal on (defaults to today)

  const AddMealScreen({super.key, this.entry, this.date});

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
  final FocusNode _nameFocus = FocusNode();
  String? _foodSource;

  /// The user's foods, for suggestions; empty until loaded.
  FoodMatcher _matcher = FoodMatcher(const []);
  List<FoodChoice> _usual = const [];

  @override
  void initState() {
    super.initState();
    _date = dayOf(widget.entry?.date ?? widget.date ?? DateTime.now());
    _nameController.text = widget.entry?.name ?? '';
    _quantityController.text = widget.entry?.quantity.toString() ?? '1';
    _priceController.text = widget.entry?.price?.toString() ?? '';
    _caloriesController.text = widget.entry?.calories?.toString() ?? '';
    _notesController.text = widget.entry?.notes ?? '';
    _foodSource = widget.entry?.foodSource;
    _nameController.addListener(() => setState(() {}));
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    final catalog = CatalogRepository(ref.read(databaseProvider));
    final foods = await catalog.foodsWithUses();
    final usual = widget.entry == null ? await catalog.usualFoods(_date) : const <FoodChoice>[];
    if (mounted) {
      setState(() {
        _matcher = FoodMatcher(foods);
        _usual = usual;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _caloriesController.dispose();
    _notesController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Fills the form from a known food: its name and, if none is typed yet,
  /// the price it was last logged at.
  void _choose(FoodItem food) {
    setState(() {
      _nameController.text = food.name;
      _nameController.selection = TextSelection.collapsed(offset: food.name.length);
      if (_priceController.text.trim().isEmpty && food.lastPrice != null) {
        _priceController.text = _formatPrice(food.lastPrice!);
      }
    });
  }

  static String _formatPrice(double price) =>
      price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = _nameController.text;
    final suggestions = _nameFocus.hasFocus ? _matcher.suggest(text) : const <FoodChoice>[];
    final correction = _matcher.didYouMean(text);

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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Focus(
                    onFocusChange: (_) => setState(() {}),
                    child: TextField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      autofocus: widget.entry == null,
                      decoration: const InputDecoration(
                        labelText: 'Meal Name',
                        hintText: 'What did you eat?',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  // "maggie": do you mean Maggi?
                  if (correction != null) ...[
                    const SizedBox(height: AppTheme.spacePulse2),
                    Material(
                      color: colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _choose(correction.item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text.rich(TextSpan(children: [
                                  const TextSpan(text: 'Did you mean '),
                                  TextSpan(text: correction.item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const TextSpan(text: '?'),
                                ])),
                              ),
                              Text('Use it', style: TextStyle(color: colors.onTertiaryContainer, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  for (final s in suggestions)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(s.item.name),
                      subtitle: s.item.aliases.isEmpty ? null : Text('also ${s.item.aliases.take(3).join(', ')}', maxLines: 1),
                      trailing: s.item.lastPrice == null ? null : Text('\$${_formatPrice(s.item.lastPrice!)}'),
                      onTap: () {
                        _choose(s.item);
                        _nameFocus.unfocus();
                      },
                    ),
                  // Likely meals before anything is typed.
                  if (text.trim().isEmpty && _usual.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacePulse3),
                    Text('Your usual', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: AppTheme.spacePulse2),
                    Wrap(
                      spacing: AppTheme.spacePulse2,
                      runSpacing: AppTheme.spacePulse2,
                      children: [
                        for (final u in _usual)
                          ActionChip(
                            label: Text(u.item.name),
                            onPressed: () {
                              _choose(u.item);
                              _nameFocus.unfocus();
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Quantity and Price (Side by Side)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacePulse3),
                    child: TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Qty', hintText: '1'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacePulse3),
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacePulse3),
                    child: TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (optional)',
                        hintText: 'Enter amount',
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

          // Where it came from (one choice)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppTheme.spacePulse2),
                  Wrap(
                    spacing: AppTheme.spacePulse2,
                    runSpacing: AppTheme.spacePulse2,
                    children: [
                      for (final MapEntry(key: source, value: label) in FoodSource.labels.entries)
                        ChoiceChip(
                          label: Text(label),
                          selected: _foodSource == source,
                          onSelected: (on) => setState(() => _foodSource = on ? source : null),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacePulse3),

          // Rarely needed details, folded away to keep logging quick.
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: const Text('More'),
              subtitle: const Text('Calories, notes'),
              initiallyExpanded: (widget.entry?.calories != null) || (widget.entry?.notes?.isNotEmpty ?? false),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppTheme.spacePulse3, 0, AppTheme.spacePulse3, AppTheme.spacePulse3),
              children: [
                TextField(
                  controller: _caloriesController,
                  decoration: const InputDecoration(
                    labelText: 'Calories (Optional)',
                    hintText: 'Enter calories',
                    suffixText: 'cal',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppTheme.spacePulse3),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Any additional details...',
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
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

    // Price is optional (fruit, snacks and free food often have none)
    double? price;
    final priceText = _priceController.text.trim();
    if (priceText.isNotEmpty) {
      price = double.tryParse(priceText);
      if (price == null || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid price')),
        );
        return;
      }
    }

    // Keep the original time when editing; new meals use the current clock
    // time on the selected day.
    final now = DateTime.now();
    final time = widget.entry?.time ?? atTimeOfDay(_date, now.hour, now.minute);

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

    try {
      final db = ref.read(databaseProvider);

      // Link to the canonical food (by name or alias), adding a new one if
      // needed, and remember the price for next time.
      final name = _nameController.text.trim();
      final known = _matcher.exact(name)?.item;
      final foodItemId = await CatalogRepository(db).saveFood(
        FoodItem(name: known?.name ?? name, lastPrice: price),
      );

      final entry = MealEntry(
        id: widget.entry?.id,
        date: _date,
        time: time,
        name: known?.name ?? name,
        quantity: quantity,
        price: price,
        calories: calories,
        // Legacy free-text tags on older meals are kept as they were.
        tags: widget.entry?.tags ?? const [],
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        foodSource: _foodSource,
        foodItemId: foodItemId,
        currency: widget.entry?.currency ?? 'SGD',
        rawText: widget.entry?.rawText,
        timeKnown: widget.entry?.timeKnown ?? true,
      );

      if (widget.entry == null) {
        await db.createMealEntry(entry);
      } else {
        await db.updateMealEntry(entry);
      }

      // Refresh meal data for the entry's date
      final normalizedDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      ref.invalidate(mealEntriesProvider(normalizedDate));
      ref.invalidate(todayMealEntriesProvider);

      if (mounted) {
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

  Future<void> _confirmDelete() async {
    // Read before awaiting: ref can't be used once the screen is gone.
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Meal',
      message: 'Are you sure you want to delete this meal entry?',
    );
    if (!confirmed || widget.entry?.id == null) return;

    await container.read(databaseProvider).deleteMealEntry(widget.entry!.id!);
    container.invalidate(mealEntriesProvider(dayOf(widget.entry!.date)));
    container.invalidate(todayMealEntriesProvider);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Meal deleted'), duration: Duration(seconds: 2)),
    );
  }
}
