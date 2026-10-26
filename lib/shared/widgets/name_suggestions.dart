import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../domain/name_matcher.dart';

/// Goes under a name field: "Did you mean …?" for an alias or a close
/// typo, matches while typing, and the usual choices before anything is
/// typed. Tapping any of them calls [onChoose].
class NameSuggestions<T> extends StatelessWidget {
  const NameSuggestions({
    super.key,
    required this.text,
    required this.focused,
    required this.matcher,
    required this.usual,
    required this.onChoose,
    this.trailing,
  });

  final String text;

  /// Whether the field has focus; matches only show while typing.
  final bool focused;
  final NameMatcher<T> matcher;
  final List<Choice<T>> usual;
  final ValueChanged<T> onChoose;

  /// Extra detail on a match, such as the last price.
  final String? Function(T item)? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final suggestions = focused ? matcher.suggest(text) : <Choice<T>>[];
    final correction = matcher.didYouMean(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // "maggie": do you mean Maggi?
        if (correction != null) ...[
          const SizedBox(height: AppTheme.spacePulse2),
          Material(
            color: colors.tertiaryContainer,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChoose(correction.item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Did you mean '),
                        TextSpan(text: matcher.nameOf(correction.item), style: const TextStyle(fontWeight: FontWeight.w800)),
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
            title: Text(matcher.nameOf(s.item)),
            subtitle: matcher.aliasesOf(s.item).isEmpty
                ? null
                : Text('also ${matcher.aliasesOf(s.item).take(3).join(', ')}', maxLines: 1),
            trailing: switch (trailing?.call(s.item)) {
              final t? => Text(t),
              null => null,
            },
            onTap: () => onChoose(s.item),
          ),
        // Likely choices before anything is typed.
        if (text.trim().isEmpty && usual.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacePulse3),
          Text('Your usual', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppTheme.spacePulse2),
          Wrap(
            spacing: AppTheme.spacePulse2,
            runSpacing: AppTheme.spacePulse2,
            children: [
              for (final u in usual) ActionChip(label: Text(matcher.nameOf(u.item)), onPressed: () => onChoose(u.item)),
            ],
          ),
        ],
      ],
    );
  }
}
