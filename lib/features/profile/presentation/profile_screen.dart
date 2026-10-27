import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../garden/presentation/garden_style.dart';
import '../../metrics/data/providers/metrics_providers.dart';
import '../data/profile_providers.dart';
import '../data/profile_repository.dart';
import '../data/weight_repository.dart';
import '../domain/profile.dart';

/// Age, height, weight and sex, for the typical sleep and calorie ranges
/// Metrics shows beside your numbers.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _birthYear = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  Sex? _sex;
  bool _loaded = false;

  @override
  void dispose() {
    _birthYear.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _fill(Profile p) {
    String text(num? v) => v == null ? '' : (v == v.roundToDouble() ? '${v.round()}' : '$v');
    _birthYear.text = text(p.birthYear);
    _height.text = text(p.heightCm);
    _weight.text = text(p.weightKg);
    _sex = p.sex;
    _loaded = true;
  }

  Profile get _entered {
    final year = int.tryParse(_birthYear.text.trim());
    final height = double.tryParse(_height.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    final thisYear = DateTime.now().year;
    return Profile(
      birthYear: year != null && year > 1900 && year <= thisYear ? year : null,
      heightCm: height != null && height >= 50 && height <= 250 ? height : null,
      weightKg: weight != null && weight >= 20 && weight <= 400 ? weight : null,
      sex: _sex,
    );
  }

  Future<void> _save(Profile p) async {
    await ProfileRepository().save(p);
    // A new weight is also today's entry in the weight log.
    final shown = ref.read(profileProvider).value?.weightKg;
    if (p.weightKg != null && p.weightKg != shown) await WeightRepository().log(DateTime.now(), p.weightKg!);
    ref.invalidate(profileProvider);
    ref.invalidate(weightsProvider);
    invalidateMetrics(ref);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final saved = ref.watch(profileProvider);
    if (!_loaded && saved.value != null) _fill(saved.value!);
    final entered = _entered;
    final today = DateTime.now();
    final sleep = PersonalRanges.sleepFor(entered.ageIn(today));
    final kcal = PersonalRanges.kcalFor(entered, today);

    InputDecoration field(String label, String suffix) => InputDecoration(labelText: label, suffixText: suffix, border: const OutlineInputBorder());
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(backgroundColor: colors.ground, title: const Text('Your profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Used only to show typical ranges for sleep and calories beside your numbers in Metrics. '
            'Every field is optional, and it stays on this device.',
            style: nunito(14, FontWeight.w600, colors.muted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _birthYear,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: field('Year of birth', ''),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: digits,
                  decoration: field('Height', 'cm'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: digits,
                  decoration: field('Weight', 'kg'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Sex, for the calorie formula', style: nunito(14, FontWeight.w800, colors.ink)),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<Sex?>(
              showSelectedIcon: false,
              segments: [
                for (final s in Sex.values) ButtonSegment<Sex?>(value: s, label: Text(s.label)),
                const ButtonSegment<Sex?>(value: null, label: Text('Skip')),
              ],
              selected: {_sex},
              onSelectionChanged: (s) => setState(() => _sex = s.first),
            ),
          ),
          Text('Skipped, the calorie range uses the average of both.', style: nunito(12, FontWeight.w600, colors.muted)),
          const SizedBox(height: 20),
          GardenSection(
            title: 'Your ranges',
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sleep: ${sleep.low.round()}–${sleep.high.round()} hours a night', style: nunito(15, FontWeight.w800, colors.ink)),
                Text(
                  entered.birthYear == null ? 'The adult range; add your year of birth for your age’s.' : 'Recommended for your age.',
                  style: nunito(13, FontWeight.w600, colors.muted),
                ),
                const SizedBox(height: 10),
                Text(
                  kcal == null ? 'Calories: add your year of birth, height and weight' : 'Calories: about ${_k(kcal.low)}–${_k(kcal.high)} a day',
                  style: nunito(15, FontWeight.w800, colors.ink),
                ),
                Text(
                  'Metrics narrows this using your average steps for the period shown.',
                  style: nunito(13, FontWeight.w600, colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => _save(entered),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Save'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _save(const Profile()),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: const Text('Clear profile'),
          ),
        ],
      ),
    );
  }

  static String _k(double kcal) {
    final n = kcal.round();
    return n >= 1000 ? '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}' : '$n';
  }
}
