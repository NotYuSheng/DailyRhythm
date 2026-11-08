import '../../../shared/domain/name_matcher.dart';
import '../data/models/food_item.dart';

/// A food and how often it has been logged.
typedef FoodChoice = Choice<FoodItem>;

/// Matches typed text against the user's foods.
class FoodMatcher extends NameMatcher<FoodItem> {
  FoodMatcher(super.choices);

  List<FoodChoice> get foods => choices;

  @override
  String nameOf(FoodItem item) => item.name;

  @override
  List<String> aliasesOf(FoodItem item) => item.aliases;
}
