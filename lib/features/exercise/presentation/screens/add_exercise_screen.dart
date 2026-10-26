import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/exercise_entry.dart';
import '../../data/models/exercise_item.dart';
import '../../domain/exercise_matcher.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../../../shared/services/database/repositories/catalog_repository.dart';
import '../../../../shared/widgets/name_suggestions.dart';
import '../../data/providers/exercise_providers.dart';
import '../../../../shared/utils/date_utils.dart';
import '../../../../shared/widgets/dialogs/delete_confirmation_dialog.dart';

class AddExerciseScreen extends ConsumerStatefulWidget {
  final ExerciseEntry? entry; // For editing existing entries
  final DateTime? date; // Day to log a new exercise on (defaults to today)

  const AddExerciseScreen({super.key, this.entry, this.date});

  @override
  ConsumerState<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends ConsumerState<AddExerciseScreen> {
  ExerciseType _selectedType = ExerciseType.run;
  RunType _selectedRunType = RunType.flat;
  EquipmentType _selectedEquipmentType = EquipmentType.dumbbell;

  // Run controllers
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _durationMinutesController = TextEditingController();
  final TextEditingController _durationSecondsController = TextEditingController();
  final TextEditingController _paceMinutesController = TextEditingController();
  final TextEditingController _paceSecondsController = TextEditingController();

  // Interval controllers
  final TextEditingController _intervalCountController = TextEditingController();
  final TextEditingController _intervalTimeMinutesController = TextEditingController();
  final TextEditingController _intervalTimeSecondsController = TextEditingController();
  final TextEditingController _restTimeMinutesController = TextEditingController();
  final TextEditingController _restTimeSecondsController = TextEditingController();

  // Weight lifting controllers
  final TextEditingController _exerciseNameController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  /// The user's exercises, for suggestions; empty until loaded.
  ExerciseMatcher _matcher = ExerciseMatcher(const []);
  List<ExerciseChoice> _usual = const [];

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _exerciseNameController.text = entry.exerciseName ?? '';
      _fill(entry);
      _notesController.text = entry.notes ?? '';
    }
    _exerciseNameController.addListener(() => setState(() {}));
    _loaded = _loadExercises();
  }

  /// Completes once suggestions are loaded; saving waits for it, so a
  /// typed alias is still saved under its exercise's name.
  late final Future<void> _loaded;

  /// Counts picks, so a slow lookup for an earlier pick can't fill the
  /// form after a later one.
  int _pick = 0;

  Future<void> _loadExercises() async {
    try {
      final catalog = CatalogRepository(ref.read(databaseProvider));
      final exercises = await catalog.exercisesWithUses();
      final day = dayOf(widget.date ?? DateTime.now());
      final usual = widget.entry == null ? await catalog.usualExercises(day) : const <ExerciseChoice>[];
      if (mounted) {
        setState(() {
          _matcher = ExerciseMatcher(exercises);
          _usual = usual;
        });
      }
    } catch (e) {
      debugPrint('Loading exercises for suggestions failed: $e');
    }
  }

  bool get _amountsEmpty => [
        _distanceController, _durationMinutesController, _durationSecondsController, _intervalCountController,
        _repsController, _weightController, _setsController,
      ].every((c) => c.text.trim().isEmpty);

  /// Sets the type and amounts from [e] (not its name or notes).
  void _fill(ExerciseEntry e) {
    _selectedType = e.type;
    _selectedRunType = e.runType ?? RunType.flat;
    _selectedEquipmentType = e.equipmentType ?? EquipmentType.dumbbell;
    String text(num? v) => v?.toString() ?? '';
    String minutes(Duration? d) => d == null ? '' : d.inMinutes.toString();
    String seconds(Duration? d) => d == null ? '' : (d.inSeconds % 60).toString();
    _distanceController.text = text(e.distance);
    _durationMinutesController.text = minutes(e.duration);
    _durationSecondsController.text = seconds(e.duration);
    _paceMinutesController.text = minutes(e.pace);
    _paceSecondsController.text = seconds(e.pace);
    _intervalTimeMinutesController.text = minutes(e.intervalTime);
    _intervalTimeSecondsController.text = seconds(e.intervalTime);
    _restTimeMinutesController.text = minutes(e.restTime);
    _restTimeSecondsController.text = seconds(e.restTime);
    _intervalCountController.text = text(e.intervalCount);
    _repsController.text = text(e.reps);
    _weightController.text = text(e.weight);
    _setsController.text = text(e.sets);
  }

  /// Picks a known exercise: its name, and the type and amounts from the
  /// last time it was logged, so a repeat needs only Save.
  /// Picks a known exercise: its name and, for a new entry with nothing
  /// typed yet, the type and amounts from the last time it was logged, so
  /// a repeat needs only Save. Pace isn't copied: it's hidden under More
  /// and wouldn't match a different run.
  Future<void> _choose(ExerciseItem item) async {
    _nameFocus.unfocus();
    final pick = ++_pick;
    setState(() {
      _exerciseNameController.text = item.name;
      _exerciseNameController.selection = TextSelection.collapsed(offset: item.name.length);
      if (item.category == ExerciseItem.cardio) _selectedType = ExerciseType.run;
    });
    if (item.id == null || widget.entry != null || !_amountsEmpty) return;
    final last = await CatalogRepository(ref.read(databaseProvider)).lastExercise(item.id!);
    if (last == null || !mounted || pick != _pick || !_amountsEmpty) return;
    setState(() {
      _fill(last);
      _paceMinutesController.clear();
      _paceSecondsController.clear();
    });
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _durationMinutesController.dispose();
    _durationSecondsController.dispose();
    _paceMinutesController.dispose();
    _paceSecondsController.dispose();
    _intervalCountController.dispose();
    _intervalTimeMinutesController.dispose();
    _intervalTimeSecondsController.dispose();
    _restTimeMinutesController.dispose();
    _restTimeSecondsController.dispose();
    _exerciseNameController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _setsController.dispose();
    _notesController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Add Exercise' : 'Edit Exercise'),
        actions: [
          if (widget.entry != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
          TextButton(
            onPressed: _saveExercise,
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
                      controller: _exerciseNameController,
                      focusNode: _nameFocus,
                      decoration: InputDecoration(
                        labelText: 'Exercise Name',
                        hintText: _selectedType == ExerciseType.run ? 'Run (optional)' : 'Bench Press',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  NameSuggestions<ExerciseItem>(
                    text: _exerciseNameController.text,
                    focused: _nameFocus.hasFocus,
                    matcher: _matcher,
                    usual: _usual,
                    onChoose: _choose,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacePulse3),

          // Exercise Type Selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercise Type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacePulse2),
                  SegmentedButton<ExerciseType>(
                    segments: const [
                      ButtonSegment(
                        value: ExerciseType.run,
                        label: Text('Run'),
                        icon: Icon(Icons.directions_run),
                      ),
                      ButtonSegment(
                        value: ExerciseType.weightLifting,
                        label: Text('Weights'),
                        icon: Icon(Icons.fitness_center),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<ExerciseType> newSelection) {
                      setState(() {
                        _selectedType = newSelection.first;
                        // A known exercise of the other kind ("Bench Press"
                        // when switching to Run) no longer names this one.
                        final known = _matcher.exact(_exerciseNameController.text)?.item;
                        if (known != null && (known.category == ExerciseItem.cardio) != (_selectedType == ExerciseType.run)) {
                          _exerciseNameController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacePulse3),

          // Type-specific forms
          if (_selectedType == ExerciseType.run) ..._buildRunForm(),
          if (_selectedType == ExerciseType.weightLifting) ..._buildWeightLiftingForm(),

          const SizedBox(height: AppTheme.spacePulse3),

          // Rarely needed: pace and notes.
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: const Text('More'),
              subtitle: const Text('Pace and notes'),
              childrenPadding: const EdgeInsets.fromLTRB(AppTheme.spacePulse3, 0, AppTheme.spacePulse3, AppTheme.spacePulse3),
              initiallyExpanded: _notesController.text.isNotEmpty || _paceMinutesController.text.isNotEmpty,
              children: [
                if (_selectedType == ExerciseType.run && _selectedRunType == RunType.flat) ...[
                  _buildPace(),
                  const SizedBox(height: AppTheme.spacePulse3),
                ],
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Add any notes...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRunForm() {
    return [
      // Run Type Selector
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Run Type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacePulse2),
              SegmentedButton<RunType>(
                segments: const [
                  ButtonSegment(
                    value: RunType.flat,
                    label: Text('Flat Run'),
                  ),
                  ButtonSegment(
                    value: RunType.interval,
                    label: Text('Intervals'),
                  ),
                ],
                selected: {_selectedRunType},
                onSelectionChanged: (Set<RunType> newSelection) {
                  setState(() {
                    _selectedRunType = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: AppTheme.spacePulse3),

      if (_selectedRunType == RunType.flat) ..._buildFlatRunForm(),
      if (_selectedRunType == RunType.interval) ..._buildIntervalRunForm(),
    ];
  }

  List<Widget> _buildFlatRunForm() {
    return [
      // Distance
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: TextField(
            controller: _distanceController,
            decoration: const InputDecoration(
              labelText: 'Distance (km)',
              hintText: '5.0',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ),

      const SizedBox(height: AppTheme.spacePulse3),

      // Duration
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duration',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacePulse2),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationMinutesController,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        hintText: '30',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacePulse2),
                  Expanded(
                    child: TextField(
                      controller: _durationSecondsController,
                      decoration: const InputDecoration(
                        labelText: 'Seconds',
                        hintText: '45',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

    ];
  }

  Widget _buildPace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pace per km (Optional)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.spacePulse2),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _paceMinutesController,
                decoration: const InputDecoration(
                  labelText: 'Minutes',
                  hintText: '5',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppTheme.spacePulse2),
            Expanded(
              child: TextField(
                controller: _paceSecondsController,
                decoration: const InputDecoration(
                  labelText: 'Seconds',
                  hintText: '30',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildIntervalRunForm() {
    return [
      // Distance per interval
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: TextField(
            controller: _distanceController,
            decoration: const InputDecoration(
              labelText: 'Distance per interval (km)',
              hintText: '0.4',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ),

      const SizedBox(height: AppTheme.spacePulse3),

      // Time per interval
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time per interval',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacePulse2),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _intervalTimeMinutesController,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        hintText: '2',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacePulse2),
                  Expanded(
                    child: TextField(
                      controller: _intervalTimeSecondsController,
                      decoration: const InputDecoration(
                        labelText: 'Seconds',
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: AppTheme.spacePulse3),

      // Rest time
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rest time',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacePulse2),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _restTimeMinutesController,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        hintText: '1',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacePulse2),
                  Expanded(
                    child: TextField(
                      controller: _restTimeSecondsController,
                      decoration: const InputDecoration(
                        labelText: 'Seconds',
                        hintText: '30',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: AppTheme.spacePulse3),

      // Number of intervals
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: TextField(
            controller: _intervalCountController,
            decoration: const InputDecoration(
              labelText: 'Number of intervals',
              hintText: '8',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildWeightLiftingForm() {
    return [
      // Equipment Type Selector
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Equipment',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacePulse2),
              Wrap(
                spacing: AppTheme.spacePulse2,
                runSpacing: AppTheme.spacePulse2,
                children: EquipmentType.values.map((type) {
                  return ChoiceChip(
                    label: Text(type.displayName),
                    selected: _selectedEquipmentType == type,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedEquipmentType = type;
                        });
                      }
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _selectedEquipmentType == type
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: AppTheme.spacePulse3),

      // Reps, Weight, Sets in a row
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _repsController,
                      decoration: const InputDecoration(
                        labelText: 'Reps',
                        hintText: '10',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacePulse2),
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      decoration: InputDecoration(
                        labelText: _selectedEquipmentType.weightLabel,
                        hintText: '60',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacePulse2),
                  Expanded(
                    child: TextField(
                      controller: _setsController,
                      decoration: const InputDecoration(
                        labelText: 'Sets',
                        hintText: '3',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Future<void> _saveExercise() async {
    await _loaded;
    try {
      // Editing keeps the entry on its original day and time.
      final now = DateTime.now();
      final date = dayOf(widget.entry?.date ?? widget.date ?? now);
      final timestamp = widget.entry?.timestamp ?? atTimeOfDay(date, now.hour, now.minute);

      ExerciseEntry entry;

      if (_selectedType == ExerciseType.run) {
        if (_selectedRunType == RunType.flat) {
          // Flat run
          final distance = double.tryParse(_distanceController.text);
          final durationMinutes = int.tryParse(_durationMinutesController.text) ?? 0;
          final durationSeconds = int.tryParse(_durationSecondsController.text) ?? 0;
          final paceMinutes = int.tryParse(_paceMinutesController.text) ?? 0;
          final paceSeconds = int.tryParse(_paceSecondsController.text) ?? 0;

          if (distance == null || distance <= 0) {
            _showError('Please enter a valid distance');
            return;
          }

          entry = ExerciseEntry(
            id: widget.entry?.id,
            date: date,
            timestamp: timestamp,
            type: ExerciseType.run,
            runType: RunType.flat,
            distance: distance,
            duration: Duration(minutes: durationMinutes, seconds: durationSeconds),
            pace: paceMinutes > 0 || paceSeconds > 0
                ? Duration(minutes: paceMinutes, seconds: paceSeconds)
                : null,
            exerciseName: _typedName,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );
        } else {
          // Interval run
          final distance = double.tryParse(_distanceController.text);
          final intervalTimeMinutes = int.tryParse(_intervalTimeMinutesController.text) ?? 0;
          final intervalTimeSeconds = int.tryParse(_intervalTimeSecondsController.text) ?? 0;
          final restTimeMinutes = int.tryParse(_restTimeMinutesController.text) ?? 0;
          final restTimeSeconds = int.tryParse(_restTimeSecondsController.text) ?? 0;
          final intervalCount = int.tryParse(_intervalCountController.text);

          if (distance == null || distance <= 0) {
            _showError('Please enter a valid distance per interval');
            return;
          }
          if (intervalCount == null || intervalCount <= 0) {
            _showError('Please enter a valid number of intervals');
            return;
          }

          entry = ExerciseEntry(
            id: widget.entry?.id,
            date: date,
            timestamp: timestamp,
            type: ExerciseType.run,
            runType: RunType.interval,
            distance: distance,
            intervalTime: Duration(minutes: intervalTimeMinutes, seconds: intervalTimeSeconds),
            restTime: Duration(minutes: restTimeMinutes, seconds: restTimeSeconds),
            intervalCount: intervalCount,
            exerciseName: _typedName,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );
        }
      } else {
        // Weight lifting
        final exerciseName = _typedName ?? '';
        final reps = int.tryParse(_repsController.text);
        final weightText = _weightController.text.trim();
        final weight = weightText.isEmpty ? null : double.tryParse(weightText);
        // Bodyweight sets (push-ups, sit-ups, planks) need no added weight.
        final weightRequired = _selectedEquipmentType != EquipmentType.bodyweight;
        final sets = int.tryParse(_setsController.text);

        if (exerciseName.isEmpty) {
          _showError('Please enter an exercise name');
          return;
        }
        if (reps == null || reps <= 0) {
          _showError('Please enter valid reps');
          return;
        }
        if (weightText.isNotEmpty && (weight == null || weight < 0)) {
          _showError('Please enter valid weight');
          return;
        }
        if (weightRequired && (weight == null || weight <= 0)) {
          _showError('Please enter valid weight');
          return;
        }
        if (sets == null || sets <= 0) {
          _showError('Please enter valid sets');
          return;
        }

        entry = ExerciseEntry(
          id: widget.entry?.id,
          date: date,
          timestamp: timestamp,
          type: ExerciseType.weightLifting,
          exerciseName: exerciseName,
          equipmentType: _selectedEquipmentType,
          reps: reps,
          weight: weight,
          sets: sets,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
      }

      // Link to the catalog (adding new exercises to it); a run with no
      // name is just "Run". An edit that keeps the name and type keeps its
      // link (imports can link a name to a differently named item), and
      // keeps the imported line.
      final db = ref.read(databaseProvider);
      final old = widget.entry;
      final unchanged = old != null &&
          old.type == entry.type &&
          (old.exerciseName ?? '').toLowerCase() == (entry.exerciseName ?? '').toLowerCase();
      final itemName = entry.exerciseName ?? (entry.type == ExerciseType.run ? 'Run' : null);
      final itemId = unchanged && old.exerciseItemId != null
          ? old.exerciseItemId
          : itemName == null
              ? null
              : await CatalogRepository(db).saveExercise(ExerciseItem(
                  name: itemName,
                  category: entry.type == ExerciseType.run ? ExerciseItem.cardio : ExerciseItem.strength,
                ));
      entry = entry.copyWith(exerciseItemId: itemId, rawText: widget.entry?.rawText);

      if (widget.entry == null) {
        await db.createExerciseEntry(entry);
      } else {
        await db.updateExerciseEntry(entry);
      }

      // Refresh exercise data
      ref.invalidate(exerciseEntriesProvider(date));
      if (widget.entry != null) {
        ref.invalidate(exerciseEntriesProvider(dayOf(widget.entry!.date)));
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(widget.entry == null ? 'Exercise added!' : 'Exercise updated!'),
          ),
        );
      }
    } catch (e) {
      _showError('Error saving exercise: $e');
    }
  }

  /// The typed name as the catalog spells it (an alias becomes its
  /// exercise's name), or null when nothing is typed.
  String? get _typedName {
    final typed = _exerciseNameController.text.trim();
    if (typed.isEmpty) return null;
    return _matcher.exact(typed)?.item.name ?? typed;
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    // Read before awaiting: ref can't be used once the screen is gone.
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Exercise',
      message: 'Are you sure you want to delete this exercise entry?',
    );
    if (!confirmed || widget.entry?.id == null) return;

    await container.read(databaseProvider).deleteExerciseEntry(widget.entry!.id!);
    container.invalidate(exerciseEntriesProvider(dayOf(widget.entry!.date)));
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Exercise deleted'), duration: Duration(seconds: 2)),
    );
  }
}
