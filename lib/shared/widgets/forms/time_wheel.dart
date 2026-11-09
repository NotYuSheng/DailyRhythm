import 'package:material_ui/material_ui.dart';

/// Asks for a time on two spinning wheels, hours and minutes, that loop
/// round. Scroll, drag or flick them; the time in the middle band is the
/// one picked. Null if dismissed.
Future<TimeOfDay?> showTimeWheel(BuildContext context, {required TimeOfDay initial, String title = 'Pick a time'}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    showDragHandle: true,
    // The wheels need more than the default half-screen on a short screen.
    isScrollControlled: true,
    builder: (_) => TimeWheel(initial: initial, title: title),
  );
}

class TimeWheel extends StatefulWidget {
  const TimeWheel({super.key, required this.initial, required this.title});

  final TimeOfDay initial;
  final String title;

  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late int _hour = widget.initial.hour;
  late int _minute = widget.initial.minute;
  late final _hours = FixedExtentScrollController(initialItem: _hour);
  late final _minutes = FixedExtentScrollController(initialItem: _minute);

  static const _itemHeight = 48.0;

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = theme.textTheme.headlineMedium!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: _itemHeight * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The band the picked time sits in.
                  Container(
                    height: _itemHeight,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _wheel('Hour', _hours, 24, digits, (v) => _hour = v)),
                      Text(':', style: digits),
                      Expanded(child: _wheel('Minute', _minutes, 60, digits, (v) => _minute = v)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(context, TimeOfDay(hour: _hour, minute: _minute)),
              child: Text('Set ${_two(_hour)}:${_two(_minute)}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel(String label, FixedExtentScrollController controller, int count, TextStyle style, void Function(int) onPick) {
    return Semantics(
      label: label,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _itemHeight,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 1.6,
        overAndUnderCenterOpacity: 0.45,
        onSelectedItemChanged: (i) => setState(() => onPick(i % count)),
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [for (var i = 0; i < count; i++) Center(child: Text(_two(i), style: style))],
        ),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
