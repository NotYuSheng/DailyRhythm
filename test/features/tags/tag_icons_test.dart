import 'package:daily_rhythm/features/tags/data/models/tag.dart';
import 'package:daily_rhythm/features/tags/presentation/tag_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Tag tag(String name, {String icon = 'tag', String kind = TagKind.activity}) =>
    Tag(name: name, emoji: icon, category: 'x', kind: kind);

void main() {
  test('a tag gets an icon from its name before its stored icon', () {
    expect(tagIcon(tag('Cab', icon: 'home')), Icons.local_taxi_outlined);
    expect(tagIcon(tag('Video Games')), Icons.sports_esports_outlined);
    expect(tagIcon(tag('Takeout', kind: TagKind.foodSource)), Icons.takeout_dining_outlined);
    expect(tagIcon(tag('Headache', kind: TagKind.symptom)), Icons.psychology_outlined);
  });

  test('otherwise its stored icon, then its kind', () {
    expect(tagIcon(tag('Gardening', icon: 'scissors')), Icons.content_cut);
    expect(tagIcon(tag('Something new')), Icons.local_activity_outlined);
    expect(tagIcon(tag('Hiccups', kind: TagKind.symptom)), Icons.healing_outlined);
  });
}
