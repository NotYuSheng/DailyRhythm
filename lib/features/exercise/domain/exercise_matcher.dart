import '../../../shared/domain/name_matcher.dart';
import '../data/models/exercise_item.dart';

/// An exercise and how often it has been logged.
typedef ExerciseChoice = Choice<ExerciseItem>;

/// Matches typed text against the user's exercises.
class ExerciseMatcher extends NameMatcher<ExerciseItem> {
  ExerciseMatcher(super.choices);

  @override
  String nameOf(ExerciseItem item) => item.name;

  @override
  List<String> aliasesOf(ExerciseItem item) => item.aliases;
}
