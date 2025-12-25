import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/exercise_entry.dart';
import '../../../../shared/services/database/database_provider.dart';
import '../../data/providers/exercise_providers.dart';

class AddExerciseScreen extends ConsumerStatefulWidget {
  final ExerciseEntry? entry;

  const AddExerciseScreen({super.key, this.entry});

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

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _selectedType = widget.entry!.type;
      _selectedRunType = widget.entry!.runType ?? RunType.flat;
      _selectedEquipmentType = widget.entry!.equipmentType ?? EquipmentType.dumbbell;

      // Populate fields based on entry type
      if (_selectedType == ExerciseType.run) {
        if (widget.entry!.distance != null) {
          _distanceController.text = widget.entry!.distance!.toString();
        }

        if (_selectedRunType == RunType.flat) {
          if (widget.entry!.duration != null) {
            _durationMinutesController.text = (widget.entry!.duration!.inMinutes).toString();
            _durationSecondsController.text = (widget.entry!.duration!.inSeconds % 60).toString();
          }
          if (widget.entry!.pace != null) {
            _paceMinutesController.text = (widget.entry!.pace!.inMinutes).toString();
            _paceSecondsController.text = (widget.entry!.pace!.inSeconds % 60).toString();
          }
        } else {
          // Interval run
          if (widget.entry!.intervalTime != null) {
            _intervalTimeMinutesController.text = (widget.entry!.intervalTime!.inMinutes).toString();
            _intervalTimeSecondsController.text = (widget.entry!.intervalTime!.inSeconds % 60).toString();
          }
          if (widget.entry!.restTime != null) {
            _restTimeMinutesController.text = (widget.entry!.restTime!.inMinutes).toString();
            _restTimeSecondsController.text = (widget.entry!.restTime!.inSeconds % 60).toString();
          }
          if (widget.entry!.intervalCount != null) {
            _intervalCountController.text = widget.entry!.intervalCount!.toString();
          }
        }
      } else {
        // Weight lifting
        if (widget.entry!.exerciseName != null) {
          _exerciseNameController.text = widget.entry!.exerciseName!;
        }
        if (widget.entry!.reps != null) {
          _repsController.text = widget.entry!.reps!.toString();
        }
        if (widget.entry!.weight != null) {
          _weightController.text = widget.entry!.weight!.toString();
        }
        if (widget.entry!.sets != null) {
          _setsController.text = widget.entry!.sets!.toString();
        }
      }

      // Notes (common to both types)
      if (widget.entry!.notes != null) {
        _notesController.text = widget.entry!.notes!;
      }
    }
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

          // Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacePulse3),
              child: TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Add any notes...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
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
              border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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

      // Pace (Optional - can be calculated)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: Column(
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
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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
              border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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
              border: OutlineInputBorder(),
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
                    selectedColor: AppTheme.rhythmBlack,
                    labelStyle: TextStyle(
                      color: _selectedEquipmentType == type
                          ? AppTheme.rhythmWhite
                          : AppTheme.rhythmBlack,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: AppTheme.spacePulse3),

      // Exercise name
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePulse3),
          child: TextField(
            controller: _exerciseNameController,
            decoration: const InputDecoration(
              labelText: 'Exercise Name',
              hintText: 'Bench Press',
              border: OutlineInputBorder(),
            ),
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
                        border: OutlineInputBorder(),
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
                        border: const OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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
    try {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month, now.day);

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
            timestamp: now,
            type: ExerciseType.run,
            runType: RunType.flat,
            distance: distance,
            duration: Duration(minutes: durationMinutes, seconds: durationSeconds),
            pace: paceMinutes > 0 || paceSeconds > 0
                ? Duration(minutes: paceMinutes, seconds: paceSeconds)
                : null,
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
            timestamp: now,
            type: ExerciseType.run,
            runType: RunType.interval,
            distance: distance,
            intervalTime: Duration(minutes: intervalTimeMinutes, seconds: intervalTimeSeconds),
            restTime: Duration(minutes: restTimeMinutes, seconds: restTimeSeconds),
            intervalCount: intervalCount,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );
        }
      } else {
        // Weight lifting
        final exerciseName = _exerciseNameController.text.trim();
        final reps = int.tryParse(_repsController.text);
        final weight = double.tryParse(_weightController.text);
        final sets = int.tryParse(_setsController.text);

        if (exerciseName.isEmpty) {
          _showError('Please enter an exercise name');
          return;
        }
        if (reps == null || reps <= 0) {
          _showError('Please enter valid reps');
          return;
        }
        if (weight == null || weight <= 0) {
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
          timestamp: now,
          type: ExerciseType.weightLifting,
          exerciseName: exerciseName,
          equipmentType: _selectedEquipmentType,
          reps: reps,
          weight: weight,
          sets: sets,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
      }

      final db = ref.read(databaseProvider);
      if (widget.entry == null) {
        await db.createExerciseEntry(entry);
      } else {
        await db.updateExerciseEntry(entry);
      }

      // Refresh exercise data
      ref.invalidate(exerciseEntriesProvider(date));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.entry == null ? 'Exercise added!' : 'Exercise updated!'),
            backgroundColor: AppTheme.rhythmBlack,
          ),
        );
      }
    } catch (e) {
      _showError('Error saving exercise: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.rhythmBlack,
        ),
      );
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Exercise'),
          content: const Text('Are you sure you want to delete this exercise entry?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (widget.entry?.id != null) {
                  final db = ref.read(databaseProvider);
                  await db.deleteExerciseEntry(widget.entry!.id!);

                  if (mounted) {
                    // Invalidate the provider to refresh the list
                    ref.invalidate(exerciseEntriesProvider(widget.entry!.date));

                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close edit screen

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Exercise deleted'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: AppTheme.rhythmBlack)),
            ),
          ],
        );
      },
    );
  }
}
