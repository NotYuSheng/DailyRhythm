/// What a version brought, shown once after updating to it and any time
/// from Settings > What's new. Newest first.
class ReleaseNote {
  const ReleaseNote(this.version, this.items, {this.dataUpdate});

  final String version;
  final List<String> items;

  /// What an AI tidy-up can fill in for entries logged before this
  /// version, or null when there's nothing to.
  final String? dataUpdate;
}

const releaseNotes = [
  ReleaseNote(
    '1.3.0',
    [
      'Meals, snacks and sides: a side sits under its meal, so a meal’s average cost counts the whole plate.',
      'Foods can say what they come with. Swap a side (corn instead of fries) or leave it out, and the calories and health follow.',
      'How it was made: less sugar, no butter, less rice and more, each moving calories and health a little.',
      'Foods remember their brand or chain, for better calorie lookups.',
      'A learning log on Today: what you learnt, and if you like, so what and now what.',
      'Exercise: sport, how hard it felt, an effort scale to suit you, and a weekly guide with advice.',
      'Log your weight on Today. A Time appearance: light by day, dark by night.',
      'Tidy up: look over any dates for snacks, sides, brands and slips, with an offer each month.',
    ],
    dataUpdate: 'Entries from before this version are all meals, with sides logged on their own and no brands. Your AI can suggest which were snacks, '
        'split names that were two foods, attach sides to their meals and add brands, for you to look over first. It sends only the foods’ names.',
  ),
];
