import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/food_item.dart';
import '../../data/models/meal_entry.dart';
import '../../data/services/calorie_lookup.dart';
import '../../domain/food_matcher.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/repositories/catalog_repository.dart';
import '../../data/providers/meal_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../../shared/widgets/dialogs/delete_confirmation_dialog.dart';
import '../../../../shared/widgets/name_suggestions.dart';
import '../../../../shared/models/spending_entry.dart';
import '../../../../shared/services/database/repositories/spending_repository.dart';
import '../../../spending/data/spending_providers.dart';
import '../../../spending/presentation/add_spending_screen.dart';

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

  /// Where typed calories came from: 'off' after a lookup, else the user.
  String? _kcalSource;

  /// A looked-up value per serving, so the calories follow the quantity.
  double? _lookedUpPerServing;

  /// Whether the calories were typed or looked up on this screen; only
  /// then do they become the food's (editing an old meal shouldn't).
  bool _caloriesChanged = false;

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
    _quantityController.addListener(() => setState(() {
          if (_lookedUpPerServing case final kcal?) _caloriesController.text = '${(kcal * _quantity).round()}';
        }));
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

  int get _quantity => switch (int.tryParse(_quantityController.text.trim())) {
        final n? when n > 0 => n,
        _ => 1,
      };

  /// The known food's calories for this quantity, when it has them.
  double? get _inheritedCalories => switch (_matcher.exact(_nameController.text)?.item.kcal) {
        final kcal? => kcal * _quantity,
        null => null,
      };

  /// Asks Open Food Facts (only when tapped; only the name is sent) and
  /// fills the calories from the match the user picks.
  Future<void> _lookUpCalories() async {
    final name = _nameController.text.trim();
    // Asked once; the sheet may rebuild while it waits.
    final results = ref.read(calorieLookupProvider).search(name);
    final picked = await showModalBottomSheet<CalorieMatch>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: FutureBuilder<List<CalorieMatch>>(
          future: results,
          builder: (context, snapshot) {
            final theme = Theme.of(context);
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Text('Calories for “$name”', style: theme.textTheme.titleLarge),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'From Open Food Facts (ODbL). Estimates, not nutrition advice.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  else if (snapshot.hasError)
                    const Padding(padding: EdgeInsets.all(20), child: Text('Couldn’t reach Open Food Facts. Check the connection and try again.'))
                  else if (snapshot.data!.isEmpty)
                    const Padding(padding: EdgeInsets.all(20), child: Text('No matches. You can type the calories instead.'))
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final m in snapshot.data!)
                            ListTile(
                              title: Text(m.name),
                              subtitle: m.brand == null ? null : Text(m.brand!),
                              trailing: Text('${m.kcal.round()} kcal\nper ${m.basis}', textAlign: TextAlign.right),
                              onTap: () => Navigator.pop(context, m),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final perServing = picked.basis == 'serving';
    setState(() {
      _caloriesChanged = true;
      if (perServing) {
        _lookedUpPerServing = picked.kcal;
        _caloriesController.text = '${(picked.kcal * _quantity).round()}';
        _kcalSource = picked.source;
      } else {
        // Per 100 g isn't a serving: a starting point for the user to adjust,
        // so it's saved as theirs.
        _lookedUpPerServing = null;
        _caloriesController.text = '${picked.kcal.round()}';
        _kcalSource = null;
      }
    });
    if (!perServing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That’s per 100 g. Adjust it to what you had.')),
      );
    }
  }

  static String _formatPrice(double price) =>
      price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final text = _nameController.text;

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
                  NameSuggestions<FoodItem>(
                    text: text,
                    focused: _nameFocus.hasFocus,
                    matcher: _matcher,
                    usual: _usual,
                    trailing: (f) => f.lastPrice == null ? null : '\$${_formatPrice(f.lastPrice!)}',
                    onChoose: (f) {
                      _choose(f);
                      _nameFocus.unfocus();
                    },
                  ),
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
                  decoration: InputDecoration(
                    labelText: 'Calories (optional)',
                    // A known food's calories apply unless one is typed.
                    hintText: _inheritedCalories == null ? 'Enter calories' : '≈ ${_inheritedCalories!.round()} from ${_matcher.exact(text)!.item.name}',
                    suffixText: 'kcal',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    _kcalSource = null;
                    _lookedUpPerServing = null;
                    _caloriesChanged = true;
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: text.trim().isEmpty ? null : _lookUpCalories,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Look up calories'),
                  ),
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
          // Imported history mixes in group events and gifts; this moves one
          // out of food spending.
          if (widget.entry?.id != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacePulse2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _moveToSpending,
                  icon: const Icon(Icons.celebration_outlined),
                  label: const Text('Not a meal: move to events & gifts'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Turns this meal into an event or gift entry and removes the meal,
  /// after asking: the meal's food link, tags and calories don't carry over.
  Future<void> _moveToSpending() async {
    final meal = widget.entry!;
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to events & gifts?'),
        content: Text('“${meal.name}” stops counting as food. Its amount moves; its food link, tags and calories don’t.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Move')),
        ],
      ),
    );
    if (ok != true) return;
    final SpendingEntry moved;
    try {
      moved = await SpendingRepository(container.read(databaseProvider)).moveMeal(
        meal.id!,
        SpendingEntry(
          date: meal.date,
          // Imported meals have a placeholder time; don't pass it on as real.
          time: meal.timeKnown ? meal.time : null,
          label: meal.name,
          amount: meal.price ?? 0,
          currency: meal.currency,
          notes: meal.notes,
          rawText: meal.rawText,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Couldn’t move it: $e')));
      return;
    }
    container.invalidate(mealEntriesProvider(dayOf(meal.date)));
    container.invalidate(todayMealEntriesProvider);
    container.invalidate(spendingProvider(dayOf(meal.date)));
    if (!mounted) return;
    // Straight into the new entry, to pick event or gift.
    await navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => AddSpendingScreen(entry: moved)));
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

    final quantityText = _quantityController.text.trim();
    final quantity = quantityText.isEmpty ? 1 : int.tryParse(quantityText) ?? 0;
    if (quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be at least 1')));
      return;
    }

    // Parse calories (optional)
    int? calories;
    if (_caloriesController.text.trim().isNotEmpty) {
      calories = int.tryParse(_caloriesController.text.trim());
      if (calories == null || calories < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid calories')));
        return;
      }
    }
    final teach = calories != null && _caloriesChanged;

    try {
      final db = ref.read(databaseProvider);

      // Link to the canonical food (by name or alias), adding a new one if
      // needed, and remember the price for next time.
      final name = _nameController.text.trim();
      final known = _matcher.exact(name)?.item;
      // Typed calories become the food's, per serving, for next time.
      final foodItemId = await CatalogRepository(db).saveFood(
        FoodItem(
          name: known?.name ?? name,
          lastPrice: price,
          kcal: teach ? calories / quantity : null,
          kcalSource: teach ? _kcalSource ?? 'user' : null,
        ),
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
      ref.invalidate(foodCaloriesProvider);

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
