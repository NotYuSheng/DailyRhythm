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
    this.spelling,
    this.onCorrect,
  });

  final String text;

  /// Whether the field has focus; matches only show while typing.
  final bool focused;
  final NameMatcher<T> matcher;
  final List<Choice<T>> usual;
  final ValueChanged<T> onChoose;

  /// Extra detail on a match, such as the last price.
  final String? Function(T item)? trailing;

  /// A corrected spelling of the typed text, for names that aren't in the
  /// list yet (a new dish); [onCorrect] takes it.
  final String? Function(String text, {bool typing})? spelling;
  final ValueChanged<String>? onCorrect;

  @override
  Widget build(BuildContext context) {
    final suggestions = focused ? matcher.suggest(text) : <Choice<T>>[];
    final correction = matcher.didYouMean(text);
    // Nothing logged is close: check the spelling word by word, unless the
    // name is already a logged one.
    final respelt = correction == null && onCorrect != null && matcher.exact(text) == null ? spelling?.call(text, typing: focused) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // "maggie": do you mean Maggi? "chiken rice": chicken rice?
        if (correction != null)
          _DidYouMean(name: matcher.nameOf(correction.item), onTap: () => onChoose(correction.item))
        else if (respelt != null)
          _DidYouMean(name: respelt, onTap: () => onCorrect!(respelt)),
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

class _DidYouMean extends StatelessWidget {
  const _DidYouMean({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacePulse2),
      child: Material(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Did you mean '),
                    TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const TextSpan(text: '?'),
                  ])),
                ),
                Text('Use it', style: TextStyle(color: colors.onTertiaryContainer, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
